package ruleset

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSafeTagPathRejectsTraversal(t *testing.T) {
	m := NewManager(t.TempDir())

	bad := []string{
		"../evil",
		"../../etc/cron.d/pwn",
		"..",
		".",
		"/etc/passwd",
		`..\windows\system32\evil`,
		"sub/dir",
		"",
		"tag with space",
		"tag$(whoami)",
		strings.Repeat("a", 65),
	}
	for _, tag := range bad {
		if _, err := m.safeTagPath(tag, ".mrs"); err == nil {
			t.Errorf("safeTagPath(%q) accepted a tag it must reject", tag)
		}
	}
}

func TestSafeTagPathAcceptsPlainTags(t *testing.T) {
	root := t.TempDir()
	m := NewManager(root)

	for _, tag := range []string{"geosite-cn", "geoip_cn", "rules.v2", "a"} {
		got, err := m.safeTagPath(tag, ".mrs")
		if err != nil {
			t.Fatalf("safeTagPath(%q) unexpected error: %v", tag, err)
		}
		want := filepath.Join(root, tag+".mrs")
		if got != want {
			t.Errorf("safeTagPath(%q) = %q, want %q", tag, got, want)
		}
	}
}

func TestRegisterRejectsBadTag(t *testing.T) {
	m := NewManager(t.TempDir())
	if err := m.Register("../evil", "binary", "https://example.com/x.mrs"); err == nil {
		t.Fatal("Register accepted a traversing tag")
	}
	if err := m.Register("ok-tag", "binary", "https://example.com/x.mrs"); err != nil {
		t.Fatalf("Register rejected a valid tag: %v", err)
	}
	if len(m.List()) != 1 {
		t.Fatalf("expected exactly one registered rule_set, got %d", len(m.List()))
	}
}

func TestDownloadRejectsNonHTTPURL(t *testing.T) {
	m := NewManager(t.TempDir())
	for _, u := range []string{"file:///etc/passwd", "ftp://example.com/x", "notaurl"} {
		if _, err := m.Download(t.Context(), "tag", "binary", u); err == nil {
			t.Errorf("Download accepted non-http url %q", u)
		}
	}
}

func TestDefaultCacheDirIsAbsolute(t *testing.T) {
	m := NewManager("")
	if !filepath.IsAbs(m.cacheDir) {
		t.Fatalf("default cache dir %q is not absolute; it would follow the process cwd", m.cacheDir)
	}
	// Must not be the bare relative "ruleset" of the previous implementation.
	if m.cacheDir == "ruleset" {
		t.Fatal("default cache dir is still cwd-relative")
	}
	_ = os.TempDir()
}
