package main

// Android in-process core entry points, reached from Flutter via dart:ffi.
//
// On desktop the GUI spawns `nekobox_core` as a child process; on Android
// the core is compiled into `libnekobox.so` (`-buildmode=c-shared`) and
// runs inside the app process, so there is no executable to spawn and no
// stdout to parse. These exports mirror `main()`'s wiring and the
// start/stop lifecycle instead.

// #include <stdlib.h>
import "C"

import (
	"sync"
	"unsafe"

	"grpc_server"
)
var mobileMu sync.Mutex
var mobileRunning bool

// NekoboxStart launches the gRPC core inside this process.
//
//   - port: gRPC listen port. Pass 0 only if the caller discovers it
//     elsewhere; unlike the desktop binary there is no stdout to parse, so
//     callers must pass an explicit port (the Flutter client substitutes its
//     configured core port, defaulting to 19821).
//   - token: gRPC auth token (empty string falls back to
//     $NEKORAY_AUTH_TOKEN, same as the desktop binary).
//
// Returns an empty string on success, or a human-readable error (C string,
// free it with NekoboxFree). Runs the server on a goroutine and returns
// once the listener is bound — i.e. by the time it returns, the port is
// connectable.
//export NekoboxStart
func NekoboxStart(port C.int, ctoken *C.char) *C.char {
	mobileMu.Lock()
	defer mobileMu.Unlock()

	if mobileRunning {
		return C.CString("")
	}

	token := ""
	if ctoken != nil {
		token = C.GoString(ctoken)
	}

	grpc_server.SetVersion(CoreVersion)
	grpc_server.SetProxyHttpClientFactory(resolveProxyClient)
	grpc_server.SetUdpDialFunc(resolveProxyUDPDialer)
	grpc_server.SetShutdownHook(shutdownCoreInstance)

	ready := make(chan error, 1)
	go func() {
		ready <- grpc_server.RunCoreBound(token, int(port), Debug, &server{})
	}()
	if err := <-ready; err != nil {
		return C.CString(err.Error())
	}
	mobileRunning = true
	return C.CString("")
}

// NekoboxStop shuts the in-process core down. Safe to call when stopped.
//export NekoboxStop
func NekoboxStop() {
	mobileMu.Lock()
	defer mobileMu.Unlock()

	if !mobileRunning {
		return
	}
	mobileRunning = false
	grpc_server.StopServer()
}

// NekoboxFree releases a string returned by NekoboxStart.
//export NekoboxFree
func NekoboxFree(s *C.char) {
	C.free(unsafe.Pointer(s))
}
