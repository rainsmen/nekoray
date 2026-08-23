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
