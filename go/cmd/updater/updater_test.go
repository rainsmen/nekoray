package main

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"os"
	"path/filepath"
	"testing"
)

func TestSafeJoinRejectsTraversal(t *testing.T) {
	root := t.TempDir()
	bad := []string{
		"../evil",
		"../../etc/cron.d/pwn",
		"a/../../../evil",
		"/etc/passwd",
		`\windows\system32\evil`,
		"..",
		"",
	}
	for _, name := range bad {
		if _, err := safeJoin(root, name); err == nil {
			t.Errorf("safeJoin(%q) accepted an entry that escapes the destination", name)
		}
	}
}

func TestSafeJoinAcceptsNormalEntries(t *testing.T) {
	root := t.TempDir()
	for _, name := range []string{"nekoray/nekobox", "a/b/c.txt", "file.dll"} {
		got, err := safeJoin(root, name)
		if err != nil {
			t.Fatalf("safeJoin(%q) unexpected error: %v", name, err)
		}
		if rel, _ := filepath.Rel(root, got); rel == ".." {
			t.Errorf("safeJoin(%q) escaped root", name)
		}
	}
}

// TestExtractZipBlocksZipSlip builds a malicious archive whose entry name walks
// out of the destination directory and asserts that nothing is written there.
func TestExtractZipBlocksZipSlip(t *testing.T) {
	dir := t.TempDir()
	archivePath := filepath.Join(dir, "evil.zip")
	dest := filepath.Join(dir, "out")
	escaped := filepath.Join(dir, "pwned.txt")

	f, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	w, err := zw.Create("../pwned.txt")
	if err != nil {
		t.Fatal(err)
	}
	w.Write([]byte("owned"))
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	f.Close()

	if err := extractZip(archivePath, dest); err == nil {
		t.Fatal("extractZip accepted a ZipSlip archive")
	}
	if _, err := os.Stat(escaped); err == nil {
		t.Fatalf("ZipSlip succeeded: %s was written", escaped)
	}
}

func TestExtractTarGzBlocksTraversalAndLinks(t *testing.T) {
	dir := t.TempDir()
	archivePath := filepath.Join(dir, "evil.tar.gz")
	dest := filepath.Join(dir, "out")
	escaped := filepath.Join(dir, "pwned.txt")

	f, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	gw := gzip.NewWriter(f)
	tw := tar.NewWriter(gw)
	body := []byte("owned")
	if err := tw.WriteHeader(&tar.Header{
		Name:     "../pwned.txt",
		Mode:     0o644,
		Size:     int64(len(body)),
		Typeflag: tar.TypeReg,
	}); err != nil {
		t.Fatal(err)
	}
	tw.Write(body)
	tw.Close()
	gw.Close()
	f.Close()

	if err := extractTarGz(archivePath, dest); err == nil {
		t.Fatal("extractTarGz accepted a traversing archive")
	}
	if _, err := os.Stat(escaped); err == nil {
		t.Fatalf("traversal succeeded: %s was written", escaped)
	}
}

func TestExtractZipRejectsSymlinks(t *testing.T) {
	dir := t.TempDir()
	archivePath := filepath.Join(dir, "link.zip")

	f, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	hdr := &zip.FileHeader{Name: "link"}
	hdr.SetMode(os.ModeSymlink | 0o777)
	w, err := zw.CreateHeader(hdr)
	if err != nil {
		t.Fatal(err)
	}
	w.Write([]byte("/etc/passwd"))
	zw.Close()
	f.Close()

	if err := extractZip(archivePath, filepath.Join(dir, "out")); err == nil {
		t.Fatal("extractZip accepted a symlink entry")
	}
}

func TestExtractZipHappyPath(t *testing.T) {
	dir := t.TempDir()
	archivePath := filepath.Join(dir, "good.zip")
	dest := filepath.Join(dir, "out")

	f, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	w, _ := zw.Create("nekoray/nekobox")
	w.Write([]byte("binary"))
	zw.Close()
	f.Close()

	if err := extractZip(archivePath, dest); err != nil {
		t.Fatalf("extractZip rejected a valid archive: %v", err)
	}
	got, err := os.ReadFile(filepath.Join(dest, "nekoray", "nekobox"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "binary" {
		t.Errorf("extracted content = %q, want %q", got, "binary")
	}
}

func TestExtractUpdatePackageStagesBeforeReplacement(t *testing.T) {
	dir := t.TempDir()
	archivePath := filepath.Join(dir, "bad.zip")
	f, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	w, err := zw.Create("../outside.txt")
	if err != nil {
		t.Fatal(err)
	}
	_, _ = w.Write([]byte("unsafe"))
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}

	// This represents files from the currently-installed version. A failed
	// extraction must not remove or alter them.
	oldInstall := filepath.Join(dir, "nekoray_update", "old.txt")
	if err := os.MkdirAll(filepath.Dir(oldInstall), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(oldInstall, []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := extractUpdatePackage(archivePath); err == nil {
		t.Fatal("extractUpdatePackage accepted an unsafe archive")
	}
	got, err := os.ReadFile(oldInstall)
	if err != nil {
		t.Fatalf("existing install was removed after failed validation: %v", err)
	}
	if string(got) != "old" {
		t.Fatalf("existing install changed after failed validation: %q", got)
	}
}

func TestExtractUpdatePackageRequiresPayload(t *testing.T) {
	dir := t.TempDir()
	archivePath := filepath.Join(dir, "missing-payload.zip")
	f, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	w, err := zw.Create("README.txt")
	if err != nil {
		t.Fatal(err)
	}
	_, _ = w.Write([]byte("not an update"))
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}

	staging, err := extractUpdatePackage(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(staging)
	if _, err := os.Stat(filepath.Join(staging, "nekoray")); !os.IsNotExist(err) {
		t.Fatalf("test archive unexpectedly contains payload: %v", err)
	}
}

func TestReplacePayloadReplacesAndCleansStaleFiles(t *testing.T) {
	root := t.TempDir()
	payload := filepath.Join(root, "stage", "nekoray")
	if err := os.MkdirAll(payload, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(payload, "nekobox"), []byte("new"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(payload, "new.dll"), []byte("dll"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "nekobox"), []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "old.dll"), []byte("old dll"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(root, "nekoray_update"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := replacePayload(payload, root, false); err != nil {
		t.Fatalf("replacePayload failed: %v", err)
	}
	got, err := os.ReadFile(filepath.Join(root, "nekobox"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "new" {
		t.Fatalf("installed payload = %q, want new", got)
	}
	if _, err := os.Stat(filepath.Join(root, "old.dll")); !os.IsNotExist(err) {
		t.Fatalf("stale dll was not removed: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "nekoray_update")); !os.IsNotExist(err) {
		t.Fatalf("stale update directory was not removed: %v", err)
	}
}
