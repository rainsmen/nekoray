package main

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

// maxEntrySize caps a single archive entry (256 MiB) so a decompression bomb
// cannot exhaust the disk.
const maxEntrySize = 256 << 20

// maxTotalSize caps the whole extraction (1 GiB).
const maxTotalSize = 1 << 30

func Updater() {
	if err := runUpdater(); err != nil {
		MessageBoxPlain("NekoGui Updater", "Update failed. Please close running instances and try again.\n\n"+err.Error())
		log.Println("updater error:", err)
		os.Exit(1)
	}
}

func runUpdater() error {
	// Find the update package without touching the existing installation. The
	// package is extracted into a private staging directory first; cleanup and
	// replacement only begin after extraction and payload validation succeed.
	var updatePackagePath string
	if len(os.Args) == 2 && Exist(os.Args[1]) {
		updatePackagePath = os.Args[1]
	} else if Exist("./nekoray-update.zip") {
		updatePackagePath = "./nekoray-update.zip"
	} else if Exist("./nekoray-update.tar.gz") {
		updatePackagePath = "./nekoray-update.tar.gz"
	} else if Exist("./nekoray.zip") {
		updatePackagePath = "./nekoray.zip"
	} else if Exist("./nekoray.tar.gz") {
		updatePackagePath = "./nekoray.tar.gz"
	} else {
		return fmt.Errorf("no update package found")
	}
	log.Println("updating from", updatePackagePath)

	stagingDir, err := extractUpdatePackage(updatePackagePath)
	if err != nil {
		return fmt.Errorf("update package is invalid or unsafe: %w", err)
	}
	// Keep the staging directory alive through Mv below. It is removed only
	// after replacement succeeds (or on an early validation failure).
	stagingOwned := true
	defer func() {
		if stagingOwned {
			_ = os.RemoveAll(stagingDir)
		}
	}()

	// The archive is considered valid only when it contains the payload that
	// Mv below expects. This check must precede any destructive cleanup.
	payload := filepath.Join(stagingDir, "nekoray")
	if !Exist(payload) {
		return fmt.Errorf("update package has no nekoray payload")
	}

	// Replace the installation transactionally. Existing top-level entries are
	// moved to a private backup directory before any new payload entry is
	// installed. If a later rename fails, the already-installed entries are
	// removed and the backup is restored, so a partial update cannot strand the
	// application in a mixed old/new state.
	if err := replacePayload(payload, ".", runtime.GOOS == "linux"); err != nil {
		return fmt.Errorf("update payload replacement failed: %w", err)
	}
	stagingOwned = false
	_ = os.RemoveAll(stagingDir)

	_ = os.Remove("./nekoray-update.zip")
	_ = os.Remove("./nekoray-update.tar.gz")
	_ = os.Remove("./nekoray.zip")
	_ = os.Remove("./nekoray.tar.gz")
	return nil
}

// extractUpdatePackage validates and extracts an update into a newly-created
// staging directory. The caller owns the returned directory and must remove it.
func extractUpdatePackage(src string) (string, error) {
	stagingDir, err := os.MkdirTemp(filepath.Dir(src), ".nekoray-update-stage-*")
	if err != nil {
		return "", err
	}
	cleanup := true
	defer func() {
		if cleanup {
			os.RemoveAll(stagingDir)
		}
	}()

	switch {
	case strings.HasSuffix(src, ".zip"):
		err = extractZip(src, stagingDir)
	case strings.HasSuffix(src, ".tar.gz"):
		err = extractTarGz(src, stagingDir)
	default:
		err = fmt.Errorf("unsupported package format: %s", src)
	}
	if err != nil {
		return "", err
	}
	cleanup = false
	return stagingDir, nil
}

// safeJoin resolves name against destRoot, refusing any path that would escape
// it. This is the ZipSlip guard: an archive entry named "../../etc/cron.d/x"
// must never be written outside the extraction directory.
func safeJoin(destRoot, name string) (string, error) {
	if name == "" {
		return "", fmt.Errorf("archive entry with empty name")
	}
	if filepath.IsAbs(name) || strings.HasPrefix(name, "/") || strings.HasPrefix(name, `\`) {
		return "", fmt.Errorf("archive entry %q is an absolute path", name)
	}
	// Normalize separators before cleaning: zip always uses '/'.
	clean := filepath.Clean(filepath.FromSlash(name))
	if clean == ".." || strings.HasPrefix(clean, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("archive entry %q escapes the destination", name)
	}
	target := filepath.Join(destRoot, clean)
	rel, err := filepath.Rel(destRoot, target)
	if err != nil {
		return "", err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("archive entry %q escapes the destination", name)
	}
	return target, nil
}

// writeEntry copies at most maxEntrySize bytes from r into target.
func writeEntry(target string, mode os.FileMode, r io.Reader, budget *int64) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	// O_EXCL is deliberate: an archive must not overwrite a file another entry
	// already produced, and it defeats symlink-swap races in the staging dir.
	f, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_EXCL, mode.Perm())
	if err != nil {
		return err
	}
	n, err := io.Copy(f, io.LimitReader(r, maxEntrySize+1))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	if n > maxEntrySize {
		return fmt.Errorf("archive entry %q exceeds %d bytes", target, maxEntrySize)
	}
	*budget -= n
	if *budget < 0 {
		return fmt.Errorf("archive exceeds %d bytes in total", maxTotalSize)
	}
	return nil
}

func extractZip(src, dest string) error {
	destRoot, err := filepath.Abs(dest)
	if err != nil {
		return err
	}
	zr, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer zr.Close()

	if err := os.MkdirAll(destRoot, 0o755); err != nil {
		return err
	}
	budget := int64(maxTotalSize)

	for _, entry := range zr.File {
		target, err := safeJoin(destRoot, entry.Name)
		if err != nil {
			return err
		}
		info := entry.FileInfo()
		switch {
		case info.IsDir():
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
		case info.Mode()&os.ModeSymlink != 0:
			// Symlinks in an update package have no legitimate use here and
			// are the second half of most ZipSlip chains.
			return fmt.Errorf("archive entry %q is a symlink", entry.Name)
		case info.Mode().IsRegular():
			rc, err := entry.Open()
			if err != nil {
				return err
			}
			err = writeEntry(target, info.Mode(), rc, &budget)
			rc.Close()
			if err != nil {
				return err
			}
		default:
			return fmt.Errorf("archive entry %q has unsupported type", entry.Name)
		}
	}
	return nil
}

func extractTarGz(src, dest string) error {
	destRoot, err := filepath.Abs(dest)
	if err != nil {
		return err
	}
	f, err := os.Open(src)
	if err != nil {
		return err
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return err
	}
	defer gz.Close()

	if err := os.MkdirAll(destRoot, 0o755); err != nil {
		return err
	}
	budget := int64(maxTotalSize)
	tr := tar.NewReader(gz)

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		target, err := safeJoin(destRoot, hdr.Name)
		if err != nil {
			return err
		}
		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := writeEntry(target, os.FileMode(hdr.Mode), tr, &budget); err != nil {
				return err
			}
		case tar.TypeSymlink, tar.TypeLink:
			return fmt.Errorf("archive entry %q is a link", hdr.Name)
		default:
			// Skip devices, fifos, xattr headers, etc.
			continue
		}
	}
}

func Exist(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func FindExist(paths []string) string {
	for _, path := range paths {
		if Exist(path) {
			return path
		}
	}
	return ""
}

// replacePayload installs the contents of payload into dest with rollback.
// The payload is expected to contain only regular files/directories produced by
// extractUpdatePackage, so moving each top-level entry is sufficient and keeps
// renames on the same filesystem.
func replacePayload(payload, dest string, removeUsr bool) error {
	entries, err := os.ReadDir(payload)
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		return fmt.Errorf("update payload is empty")
	}

	backup, err := os.MkdirTemp(filepath.Dir(dest), ".nekoray-update-backup-*")
	if err != nil {
		return err
	}
	backupOwned := true
	defer func() {
		if backupOwned {
			_ = os.RemoveAll(backup)
		}
	}()

	// Include stale files from older layouts in the transaction. They are only
	// deleted after the new payload has been installed successfully.
	stale := make([]string, 0, 4)
	if removeUsr {
		stale = append(stale, filepath.Join(dest, "usr"))
	}
	stale = append(stale, filepath.Join(dest, "nekoray_update"))
	for _, pattern := range []string{"*.dll", "*.dmp"} {
		matches, _ := filepath.Glob(filepath.Join(dest, pattern))
		for _, match := range matches {
			stale = append(stale, match)
		}
	}

	// Build a de-duplicated list of targets to back up. Paths are kept relative
	// to dest so the backup tree can be restored with the same names.
	targets := make([]string, 0, len(entries)+len(stale))
	seen := make(map[string]struct{}, len(entries)+len(stale))
	addTarget := func(path string) {
		rel, relErr := filepath.Rel(dest, path)
		if relErr != nil || rel == "." || rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
			return
		}
		if _, ok := seen[rel]; ok {
			return
		}
		seen[rel] = struct{}{}
		targets = append(targets, rel)
	}
	for _, entry := range entries {
		addTarget(filepath.Join(dest, entry.Name()))
	}
	for _, path := range stale {
		addTarget(path)
	}
	sort.Strings(targets)

	backedUp := make([]string, 0, len(targets))
	restoreBackups := func() {
		for i := len(backedUp) - 1; i >= 0; i-- {
			rel := backedUp[i]
			from := filepath.Join(backup, rel)
			to := filepath.Join(dest, rel)
			if _, err := os.Lstat(from); err == nil {
				_ = os.MkdirAll(filepath.Dir(to), 0o755)
				_ = os.Rename(from, to)
			}
		}
	}
	for _, rel := range targets {
		target := filepath.Join(dest, rel)
		if _, err := os.Lstat(target); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			restoreBackups()
			return err
		}
		backupPath := filepath.Join(backup, rel)
		if err := os.MkdirAll(filepath.Dir(backupPath), 0o755); err != nil {
			restoreBackups()
			return err
		}
		if err := os.Rename(target, backupPath); err != nil {
			restoreBackups()
			return fmt.Errorf("backup %s: %w", rel, err)
		}
		backedUp = append(backedUp, rel)
	}

	installed := make([]string, 0, len(entries))
	rollback := func() {
		for i := len(installed) - 1; i >= 0; i-- {
			_ = os.RemoveAll(filepath.Join(dest, installed[i]))
		}
		restoreBackups()
	}

	for _, entry := range entries {
		rel := entry.Name()
		if err := os.Rename(filepath.Join(payload, rel), filepath.Join(dest, rel)); err != nil {
			rollback()
			return fmt.Errorf("install %s: %w", rel, err)
		}
		installed = append(installed, rel)
	}
	if err := os.RemoveAll(backup); err != nil {
		// The installation itself succeeded; retaining a backup is safer than
		// reporting failure and attempting to roll back a live installation.
		return nil
	}
	backupOwned = false
	return nil
}

func Mv(src, dst string) error {
	s, err := os.Stat(src)
	if err != nil {
		return err
	}
	if s.IsDir() {
		es, err := os.ReadDir(src)
		if err != nil {
			return err
		}
		for _, e := range es {
			err = Mv(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name()))
			if err != nil {
				return err
			}
		}
	} else {
		err = os.MkdirAll(filepath.Dir(dst), 0o755)
		if err != nil {
			return err
		}
		err = os.Rename(src, dst)
		if err != nil {
			return err
		}
	}
	return nil
}

func removeAll(glob string) {
	files, _ := filepath.Glob(glob)
	for _, f := range files {
		os.Remove(f)
	}
}
