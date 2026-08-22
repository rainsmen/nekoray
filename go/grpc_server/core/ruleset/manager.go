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
	"os"
	"path/filepath"
	"sync"
	"time"
)

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
		cacheDir = "ruleset"
	}
	return &Manager{
		cacheDir: cacheDir,
		items:    map[string]*Info{},
	}
}

// Register records a rule_set without downloading it.
func (m *Manager) Register(tag, format, url string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.items[tag] == nil {
		m.items[tag] = &Info{Tag: tag, Type: "remote", Format: format, URL: url}
	} else {
		m.items[tag].URL = url
		m.items[tag].Format = format
	}
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

	if err := os.MkdirAll(m.cacheDir, 0755); err != nil {
		return "", err
	}

	ext := ".mrs"
	if format == "source" {
		ext = ".json"
	}
	path := filepath.Join(m.cacheDir, tag+ext)
	f, err := os.Create(path)
	if err != nil {
		return "", err
	}
	n, err := io.Copy(f, resp.Body)
	f.Close()
	if err != nil {
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
