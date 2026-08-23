// Package ruleset manages sing-box rule_set subscriptions (MRS binary format).
//
// Phase-1 MVP: download remote rule_set files to a local cache directory so
// the config builder can reference them via local path. Full rule_set
// lifecycle management (auto-update, cache_file integration) is deferred to
// phase 2.
package ruleset

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

// isHTTPURL reports whether raw is an absolute http/https URL.
func isHTTPURL(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil {
		return false
	}
	return (u.Scheme == "http" || u.Scheme == "https") && u.Host != ""
}

// Manager caches remote rule_set files locally.
type Manager struct {
	mu       sync.RWMutex
	cacheDir string
	items    map[string]*Info
}

// Info describes a cached rule_set.
type Info struct {
	Tag       string
	Type      string // "remote" or "local"
	Format    string // "source" or "binary"
	URL       string
	UpdatedAt int64
	Size      int64
	LocalPath string
}

// NewManager creates a Manager rooted at cacheDir.
func NewManager(cacheDir string) *Manager {
	if cacheDir == "" {
		cacheDir = defaultCacheDir()
	}
	if abs, err := filepath.Abs(cacheDir); err == nil {
		cacheDir = abs
	}
	return &Manager{
		cacheDir: cacheDir,
		items:    map[string]*Info{},
	}
}

// defaultCacheDir returns an absolute cache directory that does not depend on
// the process working directory (which the GUI does not control).
func defaultCacheDir() string {
	if d, err := os.UserCacheDir(); err == nil {
		return filepath.Join(d, "nekoray", "ruleset")
	}
	return filepath.Join(os.TempDir(), "nekoray-ruleset")
}

// validTag matches tags that are safe to use as a bare file name.
var validTag = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`)

// safeTagPath maps a rule_set tag to a path inside the cache directory.
//
// The tag arrives over gRPC and is attacker-controlled, so it is restricted to
// a conservative character set and re-checked against the cache root after
// joining — a tag such as "../../.bashrc" must never escape the cache dir.
func (m *Manager) safeTagPath(tag, ext string) (string, error) {
	if !validTag.MatchString(tag) {
		return "", fmt.Errorf("invalid rule_set tag %q: must match %s", tag, validTag.String())
	}
	if tag != filepath.Base(tag) || tag == "." || tag == ".." {
		return "", fmt.Errorf("invalid rule_set tag %q", tag)
	}
	path := filepath.Join(m.cacheDir, tag+ext)
	if rel, err := filepath.Rel(m.cacheDir, path); err != nil ||
		rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("rule_set tag %q escapes cache directory", tag)
	}
	return path, nil
}

// maxRuleSetBytes caps a single rule_set download (32 MiB).
const maxRuleSetBytes = 32 << 20

// Register records a rule_set without downloading it.
func (m *Manager) Register(tag, format, url string) error {
	if !validTag.MatchString(tag) {
		return fmt.Errorf("invalid rule_set tag %q", tag)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.items[tag] == nil {
		m.items[tag] = &Info{Tag: tag, Type: "remote", Format: format, URL: url}
	} else {
		m.items[tag].URL = url
		m.items[tag].Format = format
	}
	return nil
}

// Download fetches the rule_set content and caches it locally.
//
// Returns the local file path.
func (m *Manager) Download(ctx context.Context, tag, format, url string) (string, error) {
	if url == "" {
		return "", fmt.Errorf("empty url")
	}
	if format == "" {
		format = "binary"
	}
	if !isHTTPURL(url) {
		return "", fmt.Errorf("rule_set url must be http(s): %q", url)
	}

	ext := ".mrs"
	if format == "source" {
		ext = ".json"
	}
	path, err := m.safeTagPath(tag, ext)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return "", err
	}
	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("http %d", resp.StatusCode)
	}

	if err := os.MkdirAll(m.cacheDir, 0o755); err != nil {
		return "", err
	}

	tmp, err := os.CreateTemp(m.cacheDir, tag+".*.tmp")
	if err != nil {
		return "", err
	}
	tmpPath := tmp.Name()
	// Cap the download so a hostile or misconfigured server cannot fill the disk.
	n, err := io.Copy(tmp, io.LimitReader(resp.Body, maxRuleSetBytes+1))
	if err == nil && n > maxRuleSetBytes {
		err = fmt.Errorf("rule_set exceeds %d bytes", maxRuleSetBytes)
	}
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(tmpPath)
		return "", err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		os.Remove(tmpPath)
		return "", err
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	m.items[tag] = &Info{
		Tag:       tag,
		Type:      "remote",
		Format:    format,
		URL:       url,
		UpdatedAt: time.Now().Unix(),
		Size:      n,
		LocalPath: path,
	}
	return path, nil
}

// List returns info about all registered rule_sets.
func (m *Manager) List() []*Info {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]*Info, 0, len(m.items))
	for _, v := range m.items {
		cp := *v
		out = append(out, &cp)
	}
	return out
}

// Path returns the local cache path for a tag (empty if not cached).
func (m *Manager) Path(tag string) string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if v, ok := m.items[tag]; ok {
		return v.LocalPath
	}
	return ""
}
