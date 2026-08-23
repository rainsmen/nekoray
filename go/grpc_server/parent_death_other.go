//go:build !linux

package grpc_server

func setupParentDeathSignal() bool {
	return false
}
