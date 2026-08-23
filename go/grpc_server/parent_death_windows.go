//go:build windows

package grpc_server

import (
	"log"
	"os"
	"syscall"
)

const (
	processQueryLimitedInformation = 0x1000
	processSynchronize             = 0x00100000
	waitObject0                    = 0x00000000
	waitFailed                     = 0xFFFFFFFF
	infinite                       = 0xFFFFFFFF
)

var (
	kernel32        = syscall.NewLazyDLL("kernel32.dll")
	openProcessProc = kernel32.NewProc("OpenProcess")
	waitObjectProc  = kernel32.NewProc("WaitForSingleObject")
	closeHandleProc = kernel32.NewProc("CloseHandle")
)

// setupParentDeathSignal emulates Unix parent-death supervision on Windows by
// waiting on a handle for the process that launched us. PPID polling is not
// reliable on Windows because an orphan can keep the same recorded PPID.
func setupParentDeathSignal() bool {
	ppid := os.Getppid()
	if ppid <= 0 {
		return false
	}
	h, _, _ := openProcessProc.Call(processQueryLimitedInformation|processSynchronize, 0, uintptr(ppid))
	if h == 0 {
		return false
	}
	go func() {
		defer closeHandleProc.Call(h)
		result, _, _ := waitObjectProc.Call(h, infinite)
		if result == waitObject0 {
			log.Printf("parent process %d exited", ppid)
			os.Exit(0)
		}
		if result == waitFailed {
			log.Printf("failed waiting for parent process %d", ppid)
		}
	}()
	return true
}
