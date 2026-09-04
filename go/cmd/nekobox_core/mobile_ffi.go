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
	"os"
	"path/filepath"
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
//
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
//
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
//
//export NekoboxFree
func NekoboxFree(s *C.char) {
	C.free(unsafe.Pointer(s))
}

// NekoboxInitPaths initializes application private paths (dataDir, cacheDir).
// This guarantees that all temporary files and ruleset caches live inside the
// Android app's private sandbox (/data/user/0/<package>/...) instead of trying
// to write to /data/local and failing with EPERM.
//
//export NekoboxInitPaths
func NekoboxInitPaths(cdataDir *C.char, ccacheDir *C.char) {
	if ccacheDir != nil {
		cacheDir := C.GoString(ccacheDir)
		if cacheDir != "" {
			_ = os.Setenv("TMPDIR", cacheDir)
			_ = os.Setenv("NEKORAY_CACHE_DIR", cacheDir)
			grpc_server.SetRuleSetCacheDir(filepath.Join(cacheDir, "ruleset"))
		}
	}
	if cdataDir != nil {
		dataDir := C.GoString(cdataDir)
		if dataDir != "" {
			_ = os.Setenv("NEKORAY_DATA_DIR", dataDir)
		}
	}
}

// NekoboxSetTunFd stores the native TUN file descriptor created by Android VpnService.
//
//export NekoboxSetTunFd
func NekoboxSetTunFd(fd C.int) {
	grpc_server.SetMobileTunFd(int(fd))
}

// NekoboxGetTunFd retrieves the current native TUN file descriptor.
//
//export NekoboxGetTunFd
func NekoboxGetTunFd() C.int {
	return C.int(grpc_server.GetMobileTunFd())
}
