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
	"strconv"
	"strings"
	"sync"
	"time"
)

// updateState guards the URL handed from a Check call to a Download call.
// Both are RPC entry points and may be called concurrently.
var updateState struct {
	sync.Mutex
	downloadURL string
	assetName   string
	// checksumURL points at the release's checksums asset, when it publishes one.
	checksumURL string
}

// CurrentVersion is the version string used for update checking.
// It is set by the core on startup via SetVersion.
var CurrentVersion = "5.0.0"

// maxUpdateBytes caps a downloaded update package (512 MiB).
const maxUpdateBytes = 512 << 20

// allowedUpdateHosts is the set of hosts an update package may be fetched from.
// GitHub serves release assets from objects.githubusercontent.com after a
// redirect, so both are accepted; anything else is refused.
var allowedUpdateHosts = map[string]bool{
	"github.com":                   true,
	"api.github.com":               true,
	"objects.githubusercontent.com": true,
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
	client := proxyHttpClient()

	if in.Action == gen.UpdateAction_Check {
		if err := checkUpdate(ctx, client, in.CheckPreRelease, ret); err != nil {
			ret.Error = err.Error()
		}
		return ret, nil
	}

	if err := downloadUpdate(ctx, client, ret); err != nil {
		ret.Error = err.Error()
	}
	return ret, nil
}

func checkUpdate(ctx context.Context, client *http.Client, allowPreRelease bool, ret *gen.UpdateResp) error {
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
		updateState.downloadURL = asset.BrowserDownloadUrl
		updateState.assetName = asset.Name
		updateState.checksumURL = findChecksumAsset(release.Assets)
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

func downloadUpdate(ctx context.Context, client *http.Client, ret *gen.UpdateResp) error {
	updateState.Lock()
	rawURL := updateState.downloadURL
	assetName := updateState.assetName
	checksumURL := updateState.checksumURL
	updateState.Unlock()

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
	if !allowedUpdateHosts[u.Hostname()] {
		return fmt.Errorf("refusing update from unexpected host %q", u.Hostname())
	}
	return nil
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

// compareVersions compares dotted versions such as "5.0.0-beta.3".
// Returns -1 if a < b, 0 if equal, 1 if a > b. A pre-release sorts before the
// corresponding final release.
func compareVersions(a, b string) int {
	aCore, aPre := splitPreRelease(a)
	bCore, bPre := splitPreRelease(b)

	aParts := strings.Split(aCore, ".")
	bParts := strings.Split(bCore, ".")
	for i := 0; i < len(aParts) || i < len(bParts); i++ {
		av, bv := 0, 0
		if i < len(aParts) {
			av, _ = strconv.Atoi(aParts[i])
		}
		if i < len(bParts) {
			bv, _ = strconv.Atoi(bParts[i])
		}
		if av != bv {
			if av < bv {
				return -1
			}
			return 1
		}
	}

	switch {
	case aPre == "" && bPre == "":
		return 0
	case aPre == "": // a is final, b is pre-release
		return 1
	case bPre == "":
		return -1
	case aPre < bPre:
		return -1
	case aPre > bPre:
		return 1
	}
	return 0
}

func splitPreRelease(v string) (core, pre string) {
	if i := strings.IndexAny(v, "-+"); i >= 0 {
		return v[:i], v[i+1:]
	}
	return v, ""
}
