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
	"strings"
)

// maxEntrySize caps a single archive entry (256 MiB) so a decompression bomb
// cannot exhaust the disk.
const maxEntrySize = 256 << 20

// maxTotalSize caps the whole extraction (1 GiB).
const maxTotalSize = 1 << 30

func Updater() {
	pre_cleanup := func() {
		if runtime.GOOS == "linux" {
			os.RemoveAll("./usr")
		}
		os.RemoveAll("./nekoray_update")
	}

	// find update package
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
		log.Fatalln("no update")
	}
	log.Println("updating from", updatePackagePath)

	// extract update package
	var err error
	switch {
	case strings.HasSuffix(updatePackagePath, ".zip"):
		pre_cleanup()
		err = extractZip(updatePackagePath, "./nekoray_update")
	case strings.HasSuffix(updatePackagePath, ".tar.gz"):
		pre_cleanup()
		err = extractTarGz(updatePackagePath, "./nekoray_update")
	default:
		log.Fatalln("unsupported package format:", updatePackagePath)
	}
	if err != nil {
		MessageBoxPlain("NekoGui Updater", "Update package is invalid or unsafe.\n\n"+err.Error())
		log.Fatalln(err.Error())
	}

	// remove old file
	removeAll("./*.dll")
	removeAll("./*.dmp")

	// update move
	if err := Mv("./nekoray_update/nekoray", "./"); err != nil {
		MessageBoxPlain("NekoGui Updater", "Update failed. Please close the running instance and run the updater again.\n\n"+err.Error())
		log.Fatalln(err.Error())
	}

	os.RemoveAll("./nekoray_update")
	os.Remove("./nekoray-update.zip")
	os.Remove("./nekoray-update.tar.gz")
	os.Remove("./nekoray.zip")
	os.Remove("./nekoray.tar.gz")
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
	f, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode.Perm())
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
