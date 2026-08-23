package main

import (
	"flag"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

// Launcher starts the bundled Flutter binary with the bundled shared libraries
// on the search path.
func Launcher() {
	log.Println("Running as launcher")
	wd, _ := filepath.Abs(".")

	_debug := flag.Bool("debug", false, "Debug mode")
	flag.Parse()

	cmd := exec.Command("./nekobox", flag.Args()...)

	ldEnv := "LD_LIBRARY_PATH=" + filepath.Join(wd, "./lib")

	cmd.Env = append(os.Environ(), "NKR_FROM_LAUNCHER=1", ldEnv)
	log.Println(ldEnv, cmd)

	if *_debug {
		cmd.Stdin = os.Stdin
		cmd.Stderr = os.Stderr
		cmd.Stdout = os.Stdout
		if err := cmd.Run(); err != nil {
			log.Println("nekobox exited:", err)
		}
		return
	}
	if err := cmd.Start(); err != nil {
		log.Println("failed to start nekobox:", err)
	}
}
