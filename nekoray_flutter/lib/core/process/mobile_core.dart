// In-process core for Android, reached via dart:ffi.
//
// Desktop spawns `nekobox_core` as a child process; on Android the core is
// compiled into `libnekobox.so` (bundled in the APK's jniLibs) and runs
// inside the app process, so there is no executable to spawn. This class
// mirrors [CoreProcess]'s start/stop contract over the `Nekobox*` C exports
// (see `go/cmd/nekobox_core/mobile_ffi.go`).
//
// Only used when `Platform.isAndroid` — importing dart:ffi is harmless on
// other platforms as long as nothing calls into it.

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import 'core_process.dart';

/// gRPC port used when the settings ask for automatic (0). Unlike desktop,
/// there is no stdout handshake to discover an ephemeral port, so mobile
/// needs a fixed one.
const mobileDefaultCorePort = 19821;

typedef _StartC = Pointer<Utf8> Function(Int32 port, Pointer<Utf8> token);
typedef _StartDart = Pointer<Utf8> Function(int port, Pointer<Utf8> token);
typedef _FreeC = Void Function(Pointer<Utf8> s);
typedef _FreeDart = void Function(Pointer<Utf8> s);
typedef _StopC = Void Function();
typedef _StopDart = void Function();
typedef _InitPathsC = Void Function(Pointer<Utf8> dataDir, Pointer<Utf8> cacheDir);
typedef _InitPathsDart = void Function(Pointer<Utf8> dataDir, Pointer<Utf8> cacheDir);
typedef _SetTunFdC = Void Function(Int32 fd);
typedef _SetTunFdDart = void Function(int fd);

/// Supervises the in-process Android core.
class MobileCoreProcess {
  MobileCoreProcess();

  DynamicLibrary? _lib;
  CoreEndpoint? _endpoint;
  Future<CoreEndpoint>? _starting;
  bool get isRunning => _endpoint != null;
  CoreEndpoint? get endpoint => _endpoint;

  DynamicLibrary _load() {
    final loaded = _lib;
    if (loaded != null) return loaded;
    // Throws if the .so is missing from the APK — callers translate that
    // into the same friendly "core not found" error as desktop.
    final lib = DynamicLibrary.open('libnekobox.so');
    _lib = lib;
    return lib;
  }

  /// Starts the core if needed and returns its endpoint.
  ///
  /// Concurrent callers share a single start attempt, mirroring
  /// [CoreProcess.ensureStarted].
  Future<CoreEndpoint> ensureStarted({
    int requestedPort = 0,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final existing = _endpoint;
    if (existing != null && isRunning) return existing;

    final inFlight = _starting;
    if (inFlight != null) return inFlight;

    final attempt =
        _start(port: requestedPort == 0 ? mobileDefaultCorePort : requestedPort)
            .timeout(
      timeout,
      onTimeout: () => throw CoreProcessException(
          'core did not start within ${timeout.inSeconds}s'),
    );
    _starting = attempt;
    try {
      final ep = await attempt;
      _endpoint = ep;
      return ep;
    } finally {
      _starting = null;
    }
  }

  Future<CoreEndpoint> _start({required int port}) async {
    final DynamicLibrary lib;
    try {
      lib = _load();
    } catch (e) {
      throw CoreProcessException(
        'nekobox core library not found in the app. '
        'Reinstall the APK from the release page. ($e)',
      );
    }

    // Initialize sandbox paths for Android so ruleset cache and temporary
    // files are stored within the app sandbox without permission errors.
    try {
      final supportDir = await getApplicationSupportDirectory();
      final cacheDir = await getTemporaryDirectory();
      final initPaths =
          lib.lookupFunction<_InitPathsC, _InitPathsDart>('NekoboxInitPaths');
      final dataDirPtr = supportDir.path.toNativeUtf8();
      final cacheDirPtr = cacheDir.path.toNativeUtf8();
      initPaths(dataDirPtr, cacheDirPtr);
      calloc.free(dataDirPtr);
      calloc.free(cacheDirPtr);
    } catch (_) {
      // Best-effort: keep starting even if path lookup fails
    }

    final token = CoreProcess.generateToken();
    final start = lib.lookupFunction<_StartC, _StartDart>('NekoboxStart');
    final free = lib.lookupFunction<_FreeC, _FreeDart>('NekoboxFree');

    final tokenPtr = token.toNativeUtf8();
    final errPtr = start(port, tokenPtr);
    calloc.free(tokenPtr);
    String err;
    try {
      err = errPtr.toDartString();
    } finally {
      free(errPtr);
    }
    if (err.isNotEmpty) {
      throw CoreProcessException('failed to start in-process core: $err');
    }
    return CoreEndpoint(host: '127.0.0.1', port: port, token: token);
  }

  /// Sets the native TUN file descriptor created by Android VpnService.
  void setTunFd(int fd) {
    try {
      final lib = _load();
      lib.lookupFunction<_SetTunFdC, _SetTunFdDart>('NekoboxSetTunFd')(fd);
    } catch (_) {
      // Ignored if library is not yet loaded or symbol not present
    }
  }

  /// Stops the in-process core.
  Future<void> stop() async {
    setTunFd(-1);
    _endpoint = null;
    final lib = _lib;
    if (lib == null) return;
    try {
      lib.lookupFunction<_StopC, _StopDart>('NekoboxStop')();
    } catch (_) {
      // Already unloaded or never started; nothing to do.
    }
  }
}
