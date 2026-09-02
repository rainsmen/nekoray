package main

import (
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

func main() {
	// update & launcher
	exe, err := os.Executable()
	if err != nil {
		panic(err.Error())
	}

	wd := filepath.Dir(exe)
	if err := os.Chdir(wd); err != nil {
		log.Fatalln("chdir:", err)
	}
	exe = filepath.Base(os.Args[0])
	log.Println("exe:", exe, "exe dir:", wd)

	if strings.HasPrefix(strings.ToLower(exe), "updater") {
		if runtime.GOOS == "windows" {
			if strings.HasPrefix(strings.ToLower(exe), "updater.old") {
				// 2. "updater.old" update files
				time.Sleep(time.Second)
				Updater()
				// 3. start
				start("./nekoray.exe")
			} else {
				// 1. main prog quit and run "updater.exe"
				if err := Copy("./updater.exe", "./updater.old"); err != nil {
					log.Fatalln("stage updater:", err)
				}
				start("./updater.old", os.Args[1:]...)
			}
		} else if runtime.GOOS == "darwin" {
			// 1. update files
			Updater()
			// 2. start
			if Exist("./nekoray.app") {
				start("open", "./nekoray.app")
			} else {
				start("./nekoray")
			}
		} else {
			// 1. update files
			Updater()
			// 2. start
			if os.Getenv("NKR_FROM_LAUNCHER") == "1" {
				Launcher()
			} else {
				start("./nekoray")
			}
		}
		return
	} else if strings.HasPrefix(strings.ToLower(exe), "launcher") {
		Launcher()
		return
	}
	log.Fatalf("wrong name")
}

// start launches a detached process, logging (rather than swallowing) failures.
func start(name string, args ...string) {
	if err := exec.Command(name, args...).Start(); err != nil {
		log.Println("failed to start", name+":", err)
	}
}

// Copy copies src to dst, streaming rather than buffering the whole file.
func Copy(src string, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
