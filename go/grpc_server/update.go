package grpc_server

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"grpc_server/gen"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"google.golang.org/grpc/metadata"
)

// UpdateSessionMetadataKey is the gRPC metadata key used to bind a Check
// request to its subsequent Download request. The client must generate a fresh
// opaque value for each check/download flow and send it on both calls.
const UpdateSessionMetadataKey = "nekoray-update-session"

// updateSession is the release asset selected by one Check call. Keeping this
// state per session prevents a concurrent check in another UI/request from
// silently changing what a Download call installs.
type updateSession struct {
	downloadURL string
	assetName   string
	// checksumURL points at the release's checksums asset, when it publishes one.
	checksumURL string
	createdAt   time.Time
}

var updateState struct {
	sync.Mutex
	sessions map[string]updateSession
}

const maxUpdateSessions = 32
const updateSessionTTL = 15 * time.Minute

// CurrentVersion is the version string used for update checking.
// Set via SetVersion from nekobox_core main, but defaults to a compile-time string.
var CurrentVersion = "5.0.0-beta.13"

// maxUpdateBytes caps a downloaded update package (512 MiB).
const maxUpdateBytes = 512 << 20

// allowedUpdateHosts is the set of hosts an update package may be fetched from.
// GitHub serves release assets from objects.githubusercontent.com after a
// redirect, so both are accepted; anything else is refused.
var allowedUpdateHosts = map[string]bool{
	"github.com":                           true,
	"api.github.com":                       true,
	"objects.githubusercontent.com":        true,
	"release-assets.githubusercontent.com": true,
}

// proxyHttpClient returns an HTTP client. When running through the core,
// the instance's proxy is used; otherwise a direct client is returned.
// This replaces the libneko neko_common.CreateProxyHttpClient helper.
var proxyHttpClient func() *http.Client = func() *http.Client {
	return &http.Client{Timeout: 30 * time.Second}
}

// SetProxyHttpClientFactory allows the core to inject a factory that
// routes requests through the running sing-box instance.
func SetProxyHttpClientFactory(f func() *http.Client) {
	proxyHttpClient = f
}

// SetVersion sets the version string used for update comparisons.
func SetVersion(v string) {
	if v != "" {
		CurrentVersion = v
	}
}

type ghAsset struct {
	Name               string `json:"name"`
	BrowserDownloadUrl string `json:"browser_download_url"`
}

type ghRelease struct {
	TagName    string    `json:"tag_name"`
	HtmlUrl    string    `json:"html_url"`
	Assets     []ghAsset `json:"assets"`
	Prerelease bool      `json:"prerelease"`
	Draft      bool      `json:"draft"`
	Body       string    `json:"body"`
}

func (s *BaseServer) Update(ctx context.Context, in *gen.UpdateReq) (*gen.UpdateResp, error) {
	ret := &gen.UpdateResp{}
	client := clientWithUpdateRedirectPolicy(proxyHttpClient())
	sessionID := updateSessionID(ctx)

	switch in.Action {
	case gen.UpdateAction_Check:
		if sessionID == "" {
			ret.Error = "missing update session ID"
			return ret, nil
		}
		if err := checkUpdate(ctx, client, in.CheckPreRelease, ret, sessionID); err != nil {
			ret.Error = err.Error()
		}
		return ret, nil
	case gen.UpdateAction_Download:
		// handled below
	default:
		ret.Error = fmt.Sprintf("unsupported update action %d", in.Action)
		return ret, nil
	}

	if sessionID == "" {
		ret.Error = "missing update session ID"
		return ret, nil
	}
	if err := downloadUpdate(ctx, client, ret, sessionID); err != nil {
		ret.Error = err.Error()
	}
	return ret, nil
}

// updateSessionID extracts the opaque per-flow identifier from incoming gRPC
// metadata. It intentionally does not use the auth token or peer address:
// those are shared by every request in a process and cannot bind Check to
// Download.
func updateSessionID(ctx context.Context) string {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return ""
	}
	values := md.Get(UpdateSessionMetadataKey)
	if len(values) == 0 {
		return ""
	}
	return strings.TrimSpace(values[0])
}

func firstUpdateSessionID(sessionIDs []string) string {
	if len(sessionIDs) == 0 {
		return ""
	}
	return strings.TrimSpace(sessionIDs[0])
}

func discardUpdateSession(sessionID string) {
	updateState.Lock()
	delete(updateState.sessions, sessionID)
	updateState.Unlock()
}

func checkUpdate(ctx context.Context, client *http.Client, allowPreRelease bool, ret *gen.UpdateResp, sessionIDs ...string) error {
	sessionID := firstUpdateSessionID(sessionIDs)
	if sessionID == "" {
		return fmt.Errorf("missing update session ID")
	}
	// A retry with the same session must not be able to consume a result from
	// an earlier check if this request fails or reports that no update exists.
	discardUpdateSession(sessionID)
	ctx, cancel := context.WithTimeout(ctx, time.Second*10)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET",
		"https://api.github.com/repos/rainsmen/nekoray/releases", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("github api returned %d", resp.StatusCode)
	}

	var releases []ghRelease
	// Bound the API response too — it is untrusted input.
	if err := json.NewDecoder(io.LimitReader(resp.Body, 8<<20)).Decode(&releases); err != nil {
		return err
	}

	search, err := platformAssetTag()
	if err != nil {
		return err
	}

	for _, release := range releases {
		if release.Draft {
			continue
		}
		if release.Prerelease && !allowPreRelease {
			continue
		}
		// Only offer a release that is actually newer than what we run.
		if compareVersions(strings.TrimPrefix(release.TagName, "v"), CurrentVersion) <= 0 {
			return nil // up to date
		}
		var asset *ghAsset
		for i := range release.Assets {
			if strings.Contains(release.Assets[i].Name, search) {
				asset = &release.Assets[i]
				break
			}
		}
		if asset == nil {
			continue
		}

		updateState.Lock()
		if updateState.sessions == nil {
			updateState.sessions = make(map[string]updateSession)
		}
		now := time.Now()
		for id, state := range updateState.sessions {
			if now.Sub(state.createdAt) > updateSessionTTL {
				delete(updateState.sessions, id)
			}
		}
		// Bound memory even if a client creates many abandoned sessions. The
		// oldest entry is safe to evict because a Download must consume its
		// matching entry before use.
		if len(updateState.sessions) >= maxUpdateSessions {
			var oldest string
			var oldestAt time.Time
			for id, state := range updateState.sessions {
				if oldest == "" || state.createdAt.Before(oldestAt) {
					oldest, oldestAt = id, state.createdAt
				}
			}
			delete(updateState.sessions, oldest)
		}
		updateState.sessions[sessionID] = updateSession{
			downloadURL: asset.BrowserDownloadUrl,
			assetName:   asset.Name,
			checksumURL: findChecksumAsset(release.Assets),
			createdAt:   time.Now(),
		}
		updateState.Unlock()

		ret.AssetsName = asset.Name
		ret.DownloadUrl = asset.BrowserDownloadUrl
		ret.ReleaseUrl = release.HtmlUrl
		ret.ReleaseNote = release.Body
		ret.IsPreRelease = release.Prerelease
		return nil
	}
	return nil
}

// findChecksumAsset locates the release asset holding SHA-256 sums, if any.
func findChecksumAsset(assets []ghAsset) string {
	for _, a := range assets {
		n := strings.ToLower(a.Name)
		if strings.Contains(n, "sha256") || strings.Contains(n, "checksum") {
			return a.BrowserDownloadUrl
		}
	}
	return ""
}

func platformAssetTag() (string, error) {
	switch {
	case runtime.GOOS == "windows" && runtime.GOARCH == "amd64":
		return "windows64", nil
	case runtime.GOOS == "linux" && runtime.GOARCH == "amd64":
		return "linux64", nil
	case runtime.GOOS == "darwin":
		return "macos-" + runtime.GOARCH, nil
	case runtime.GOOS == "android":
		return "android-" + runtime.GOARCH, nil
	default:
		return "", fmt.Errorf("unsupported platform %s/%s", runtime.GOOS, runtime.GOARCH)
	}
}

func downloadUpdate(ctx context.Context, client *http.Client, ret *gen.UpdateResp, sessionIDs ...string) error {
	sessionID := firstUpdateSessionID(sessionIDs)
	if sessionID == "" {
		return fmt.Errorf("missing update session ID")
	}
	updateState.Lock()
	session, ok := updateState.sessions[sessionID]
	// Consume the check result before doing network/disk work. This prevents
	// replay and makes concurrent Download calls deterministic.
	if ok {
		delete(updateState.sessions, sessionID)
	}
	updateState.Unlock()
	if !ok {
		return fmt.Errorf("no update URL for session — run a check first")
	}
	rawURL := session.downloadURL
	assetName := session.assetName
	checksumURL := session.checksumURL

	if rawURL == "" {
		return fmt.Errorf("no download URL — run a check first")
	}
	if err := validateUpdateURL(rawURL); err != nil {
		return err
	}
	// An unverifiable update package must not be written to disk: the updater
	// unpacks it over the installation directory with the user's privileges.
	if checksumURL == "" {
		return fmt.Errorf("release publishes no SHA-256 checksums; refusing unverified update")
	}
	if err := validateUpdateURL(checksumURL); err != nil {
		return err
	}

	client = clientWithUpdateRedirectPolicy(client)
	wantSum, err := fetchChecksum(ctx, client, checksumURL, assetName)
	if err != nil {
		return err
	}

	dest, err := updatePackagePath(assetName)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "GET", rawURL, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("download returned %d", resp.StatusCode)
	}

	tmp, err := os.CreateTemp(filepath.Dir(dest), ".nekoray-update-*.part")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath) // no-op once renamed

	hasher := sha256.New()
	n, err := io.Copy(io.MultiWriter(tmp, hasher), io.LimitReader(resp.Body, maxUpdateBytes+1))
	if err == nil && n > maxUpdateBytes {
		err = fmt.Errorf("update package exceeds %d bytes", maxUpdateBytes)
	}
	if serr := tmp.Sync(); err == nil {
		err = serr
	}
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}

	gotSum := hex.EncodeToString(hasher.Sum(nil))
	if !strings.EqualFold(gotSum, wantSum) {
		return fmt.Errorf("checksum mismatch: expected %s, got %s", wantSum, gotSum)
	}

	if err := os.Rename(tmpPath, dest); err != nil {
		return err
	}
	ret.AssetsName = filepath.Base(dest)
	return nil
}

// validateUpdateURL refuses any URL that is not an https GitHub release asset.
func validateUpdateURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return err
	}
	if u.Scheme != "https" {
		return fmt.Errorf("update URL must be https, got %q", u.Scheme)
	}
	host := strings.ToLower(strings.TrimSuffix(u.Hostname(), "."))
	if !allowedUpdateHosts[host] {
		return fmt.Errorf("refusing update from unexpected host %q", u.Hostname())
	}
	return nil
}

// clientWithUpdateRedirectPolicy returns a shallow copy of client that checks
// every redirect target.  GitHub release URLs normally redirect from github.com
// to objects.githubusercontent.com, but a redirect to an arbitrary host must
// never be allowed to bypass validateUpdateURL's allowlist.
func clientWithUpdateRedirectPolicy(client *http.Client) *http.Client {
	copy := *client
	previous := client.CheckRedirect
	copy.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		if len(via) >= 10 {
			return fmt.Errorf("stopped after 10 redirects")
		}
		if err := validateUpdateURL(req.URL.String()); err != nil {
			return err
		}
		if previous != nil {
			return previous(req, via)
		}
		return nil
	}
	return &copy
}

// fetchChecksum downloads a `sha256sum`-style file and returns the digest
// recorded for assetName.
func fetchChecksum(ctx context.Context, client *http.Client, checksumURL, assetName string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", checksumURL, nil)
	if err != nil {
		return "", err
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("checksum file returned %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", err
	}

	for _, line := range strings.Split(string(body), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		// "<hex>  <name>" (sha256sum) — name may carry a leading '*'.
		name := strings.TrimPrefix(fields[len(fields)-1], "*")
		if filepath.Base(name) == assetName {
			sum := fields[0]
			if len(sum) != 64 {
				return "", fmt.Errorf("malformed checksum for %s", assetName)
			}
			if _, err := hex.DecodeString(sum); err != nil {
				return "", fmt.Errorf("malformed checksum for %s", assetName)
			}
			return sum, nil
		}
	}
	return "", fmt.Errorf("no checksum published for %s", assetName)
}

// updatePackagePath returns an absolute, deterministic destination next to the
// running executable. The previous code wrote to "../nekoray-update.zip",
// which resolved against whatever working directory the process inherited.
func updatePackagePath(assetName string) (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	dir := filepath.Dir(exe)
	name := "nekoray-update.zip"
	if strings.HasSuffix(assetName, ".tar.gz") {
		name = "nekoray-update.tar.gz"
	}
	return filepath.Join(dir, name), nil
}

// compareVersions compares SemVer-like versions such as "5.0.0-beta.3".
// Returns -1 if a < b, 0 if equal, 1 if a > b. Pre-release identifiers are
// compared numerically where possible (beta.2 < beta.10), and build metadata
// does not affect ordering.
func compareVersions(a, b string) int {
	aCore, aPre := splitPreRelease(strings.TrimPrefix(strings.TrimSpace(a), "v"))
	bCore, bPre := splitPreRelease(strings.TrimPrefix(strings.TrimSpace(b), "v"))

	aParts := strings.Split(aCore, ".")
	bParts := strings.Split(bCore, ".")
	for i := 0; i < len(aParts) || i < len(bParts); i++ {
		av, bv := "0", "0"
		if i < len(aParts) && aParts[i] != "" {
			av = aParts[i]
		}
		if i < len(bParts) && bParts[i] != "" {
			bv = bParts[i]
		}
		if cmp := compareNumericIdentifier(av, bv); cmp != 0 {
			return cmp
		}
	}

	// A version without a pre-release is newer than one with a pre-release.
	if aPre == "" && bPre == "" {
		return 0
	}
	if aPre == "" {
		return 1
	}
	if bPre == "" {
		return -1
	}

	aIDs := strings.Split(aPre, ".")
	bIDs := strings.Split(bPre, ".")
	for i := 0; i < len(aIDs) && i < len(bIDs); i++ {
		if cmp := comparePreReleaseIdentifier(aIDs[i], bIDs[i]); cmp != 0 {
			return cmp
		}
	}
	switch {
	case len(aIDs) < len(bIDs):
		return -1
	case len(aIDs) > len(bIDs):
		return 1
	default:
		return 0
	}
}

// splitPreRelease separates core, pre-release, and build metadata. Build
// metadata is deliberately discarded because SemVer excludes it from order.
func splitPreRelease(v string) (core, pre string) {
	if i := strings.IndexByte(v, '+'); i >= 0 {
		v = v[:i]
	}
	if i := strings.IndexByte(v, '-'); i >= 0 {
		return v[:i], v[i+1:]
	}
	return v, ""
}

func comparePreReleaseIdentifier(a, b string) int {
	aNumeric, bNumeric := isNumericIdentifier(a), isNumericIdentifier(b)
	switch {
	case aNumeric && bNumeric:
		return compareNumericIdentifier(a, b)
	case aNumeric:
		return -1
	case bNumeric:
		return 1
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func isNumericIdentifier(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// compareNumericIdentifier compares arbitrary-length decimal identifiers
// without overflowing strconv.Atoi. Non-numeric core components retain the
// old tolerant ordering by comparing them lexically after numeric values.
func compareNumericIdentifier(a, b string) int {
	if isNumericIdentifier(a) && isNumericIdentifier(b) {
		a = strings.TrimLeft(a, "0")
		b = strings.TrimLeft(b, "0")
		if a == "" {
			a = "0"
		}
		if b == "" {
			b = "0"
		}
		if len(a) != len(b) {
			if len(a) < len(b) {
				return -1
			}
			return 1
		}
		if a < b {
			return -1
		}
		if a > b {
			return 1
		}
		return 0
	}
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}
