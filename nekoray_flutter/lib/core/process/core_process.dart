// Supervises the nekobox_core child process.
//
// The Flutter app is a thin client: it owns the core's lifetime, generates the
// gRPC auth token, and hands that token over via the environment rather than
// argv (argv is world-readable through the process table).
//
// Port selection is delegated to the core: it is started with `--port 0`, binds
// an ephemeral port, and prints the address it settled on. Parsing that line is
// race-free, unlike probing for a free port in the client and hoping it is
// still free a moment later.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Where the core is listening, plus the token needed to talk to it.
class CoreEndpoint {
  final String host;
  final int port;
  final String token;

  const CoreEndpoint({
    required this.host,
    required this.port,
    required this.token,
  });
}

class CoreProcessException implements Exception {
  final String message;
  CoreProcessException(this.message);
  @override
  String toString() => 'CoreProcessException: $message';
}

/// Starts, supervises and stops `nekobox_core`.
class CoreProcess {
  CoreProcess({this.onLog});

  /// Receives core stdout/stderr lines, for the log view.
  final void Function(String line)? onLog;

  Process? _process;
  CoreEndpoint? _endpoint;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Future<CoreEndpoint>? _starting;

  bool get isRunning => _process != null;
  CoreEndpoint? get endpoint => _endpoint;

  /// Matches the address line printed by `RunCore`.
  static final _listenPattern =
      RegExp(r'nekobox_core listening on\s+(?:\[([^\]]+)\]|([^:\s]+)):(\d+)');

  /// Starts the core if it is not already running and returns its endpoint.
  ///
  /// Concurrent callers share a single start attempt.
  Future<CoreEndpoint> ensureStarted({
    int requestedPort = 0,
    bool debug = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final existing = _endpoint;
    if (existing != null && isRunning) return existing;

    final inFlight = _starting;
    if (inFlight != null) {
      await inFlight;
      final ready = _endpoint;
      if (ready != null && isRunning) return ready;
    }

    final attempt = _start(requestedPort: requestedPort, debug: debug, timeout: timeout);
    _starting = attempt;
    try {
      final endpoint = await attempt;
      _endpoint = endpoint;
      return endpoint;
    } finally {
      _starting = null;
    }
  }

  Future<CoreEndpoint> _start({
    required int requestedPort,
    required bool debug,
    required Duration timeout,
  }) async {
    final exe = await resolveCoreExecutable();
    if (exe == null) {
      throw CoreProcessException(
        'nekobox_core binary not found. Looked alongside the app bundle '
        'and on PATH. Run libs/build_go.sh to compile it.',
      );
    }

    final token = generateToken();
    final args = <String>[
      '--token',
      token,
      if (requestedPort > 0) ...['--port', requestedPort.toString()],
      if (debug) '--debug',
    ];

    final Process process;
    try {
      // Inherit the caller's environment so PATH, system proxy env vars and
      // dynamic linker paths remain intact, but pass the token via env as well
      // so tooling that inspects ps args does not see it.
      process = await Process.start(
        exe,
        args,
        environment: {...Platform.environment, 'NEKORAY_AUTH_TOKEN': token},
      );
    } catch (e) {
      throw CoreProcessException('failed to spawn $exe: $e');
    }

    _process = process;

    final ready = Completer<int>();

    void handleLine(String line) {
      onLog?.call(line);
      if (ready.isCompleted) return;
      final m = _listenPattern.firstMatch(line);
      if (m != null) {
        final port = int.tryParse(m.group(3)!);
        if (port != null) ready.complete(port);
      }
    }

    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);
    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);

    // If the core dies during startup, fail fast instead of waiting out the
    // timeout with no explanation.
    unawaited(process.exitCode.then((code) {
      final wasCurrent = identical(_process, process);
      if (wasCurrent) {
        _process = null;
        _endpoint = null;
      }
      if (!ready.isCompleted) {
        ready.completeError(
            CoreProcessException('core exited with code $code during startup'));
      }
    }));

    // Close stdin so the core never blocks on an interactive token prompt.
    try {
      await process.stdin.close();
    } catch (_) {}

    final int port;
    try {
      port = await ready.future.timeout(
        timeout,
        onTimeout: () => throw CoreProcessException(
            'core did not report a listening address within ${timeout.inSeconds}s'),
      );
    } catch (_) {
      await stop();
      rethrow;
    }

    _endpoint = CoreEndpoint(host: '127.0.0.1', port: port, token: token);
  }

  /// Stops the core, escalating to SIGKILL if it does not exit promptly.
  Future<void> stop({Duration grace = const Duration(seconds: 3)}) async {
    final process = _process;
    _process = null;
    _endpoint = null;

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;

    if (process == null) return;

    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(grace);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  /// Generates a 256-bit token using the platform CSPRNG.
  static String generateToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<String> _candidateNames() =>
      Platform.isWindows ? ['nekobox_core.exe'] : ['nekobox_core'];

  /// Finds the core binary shipped alongside the application.
  ///
  /// Search order: `$NEKORAY_CORE_PATH`, the directory holding the Flutter
  /// executable, its `..`/`Resources` siblings (macOS bundle layout), and
  /// finally `PATH`.
  static Future<String?> resolveCoreExecutable() async {
    final override = Platform.environment['NEKORAY_CORE_PATH'];
    if (override != null && override.isNotEmpty) {
      if (await File(override).exists()) return override;
    }

    final exeDir = File(Platform.resolvedExecutable).parent;
    final searchDirs = <Directory>[
      exeDir,
      exeDir.parent,
      Directory('${exeDir.path}/core'),
      // macOS: Contents/MacOS/<app>, core may sit in Contents/Resources
      Directory('${exeDir.parent.path}/Resources'),
    ];

    for (final dir in searchDirs) {
      for (final name in _candidateNames()) {
        final candidate = File('${dir.path}/$name');
        if (await candidate.exists()) return candidate.path;
      }
    }

    // Fall back to PATH so a developer build can point at an installed core.
    for (final name in _candidateNames()) {
      final which = Platform.isWindows ? 'where' : 'which';
      try {
        final r = await Process.run(which, [name]);
        if (r.exitCode == 0) {
          final first = (r.stdout as String)
              .split('\n')
              .map((s) => s.trim())
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');
          if (first.isNotEmpty) return first;
        }
      } catch (_) {}
    }
    return null;
  }
}

/// Test-only access to internals that are otherwise private.
class CoreProcessTestHooks {
  static RegExp get listenPattern => CoreProcess._listenPattern;
}
