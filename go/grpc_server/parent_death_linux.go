//go:build linux

package grpc_server

import (
	"syscall"
)

func setupParentDeathSignal() bool {
	// PR_SET_PDEATHSIG is 1. We ask the kernel to send SIGTERM (15) to this process when its parent dies.
	_, _, errno := syscall.RawSyscall(syscall.SYS_PRCTL, 1, uintptr(syscall.SIGTERM), 0)
	return errno == 0
}
