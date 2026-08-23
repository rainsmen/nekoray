//go:build !linux && !windows

package grpc_server

func setupParentDeathSignal() bool {
	return false
}
