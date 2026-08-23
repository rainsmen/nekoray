// gRPC client for talking to the nekobox_core process.

import 'dart:math';
//
// The Flutter UI never touches sing-box directly — all config building,
// subscription parsing and stats querying go through this client.

import 'package:grpc/grpc.dart';

import 'generated/libcore.pbgrpc.dart';

/// Per-call deadlines. A single global timeout was wrong in both directions:
/// 10s is an eternity for a stats poll and far too short for a rule_set
/// download, which the core allows 60s for.
class _Deadlines {
  static const fast = Duration(seconds: 5); // stats, stop
  static const normal = Duration(seconds: 15); // build, parse
  static const slow = Duration(seconds: 90); // downloads, tests
}

class GrpcClient {
  GrpcClient();

  ClientChannel? _channel;
  LibcoreServiceClient? _stub;
  String _token = '';

  /// True only after a successful call; a non-null channel proves nothing,
  /// since the core may have exited since it was opened.
  bool _healthy = false;
  bool get isConnected => _channel != null && _healthy;

  /// Connects to the local nekobox_core gRPC endpoint and verifies the
  /// connection with a real authenticated call.
  Future<void> connect({
    String host = '127.0.0.1',
    required int port,
    required String token,
  }) async {
    if (token.isEmpty) {
      throw ArgumentError('an auth token is required — the core rejects '
          'unauthenticated requests');
    }
    await disconnect();

    final channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(), // loopback only
        idleTimeout: Duration(minutes: 5),
        connectionTimeout: Duration(seconds: 5),
      ),
    );

    _channel = channel;
    _token = token;
    _stub = LibcoreServiceClient(channel, options: _options(_Deadlines.normal));

    try {
      await ping();
      _healthy = true;
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  CallOptions _options(Duration timeout) => CallOptions(
        metadata: {'nekoray_auth': _token},
        timeout: timeout,
      );

  LibcoreServiceClient get _client {
    final s = _stub;
    if (s == null) {
      throw StateError('GrpcClient not connected — call connect() first');
    }
    return s;
  }

  /// Cheap authenticated round-trip used as a health check.
  Future<void> ping() async {
    await _client.listRuleSets(EmptyReq(), options: _options(_Deadlines.fast));
  }

  /// Re-checks liveness, flipping [isConnected] when the core has gone away.
  Future<bool> checkHealth() async {
    if (_channel == null) return false;
    try {
      await ping();
      _healthy = true;
    } catch (_) {
      _healthy = false;
    }
    return _healthy;
  }

  Future<void> disconnect() async {
    _healthy = false;
    final channel = _channel;
    _channel = null;
    _stub = null;
    _token = '';
    if (channel != null) {
      try {
        await channel.shutdown();
      } catch (_) {
        // Already broken; nothing useful to do.
      }
    }
  }

  /// Runs [call] and marks the connection unhealthy if the transport failed,
  /// so the next action reconnects instead of retrying into a dead socket.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      final result = await call();
      _healthy = true;
      return result;
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unavailable ||
          e.code == StatusCode.deadlineExceeded ||
          e.code == StatusCode.unauthenticated) {
        _healthy = false;
      }
      rethrow;
    } catch (_) {
      _healthy = false;
      rethrow;
    }
  }

  // --- Convenience wrappers ----------------------------------------------

  Future<BuildConfigResp> buildConfig(BuildConfigReq req) =>
      _guard(() => _client.buildConfig(req, options: _options(_Deadlines.normal)));

  Future<ParseSubResp> parseSubscription(ParseSubReq req) =>
      _guard(() => _client.parseSubscription(req, options: _options(_Deadlines.normal)));

  Future<ShareLinkResp> generateShareLink(ShareLinkReq req) =>
      _guard(() => _client.generateShareLink(req, options: _options(_Deadlines.fast)));

  Future<QueryStatsResp> queryStats(String tag, String direction) =>
      _guard(() => _client.queryStats(
            QueryStatsReq(tag: tag, direct: direction),
            options: _options(_Deadlines.fast),
          ));

  Future<ErrorResp> startCore(
    String coreConfig, {
    bool enableConnections = false,
    List<String> statsOutbounds = const [],
  }) =>
      _guard(() => _client.start(
            LoadConfigReq(
              coreConfig: coreConfig,
              enableNekorayConnections: enableConnections,
              statsOutbounds: statsOutbounds,
            ),
            options: _options(_Deadlines.slow),
          ));

  Future<ErrorResp> stopCore() =>
      _guard(() => _client.stop(EmptyReq(), options: _options(_Deadlines.fast)));

  Future<ListRuleSetsResp> listRuleSets() =>
      _guard(() => _client.listRuleSets(EmptyReq(), options: _options(_Deadlines.fast)));

  /// Rule_set updates download over the network; the core allows 60s, so the
  /// client deadline must be larger, not smaller.
  Future<ErrorResp> updateRuleSet(UpdateRuleSetReq req) =>
      _guard(() => _client.updateRuleSet(req, options: _options(_Deadlines.slow)));

  static const _updateSessionMetadata = 'nekoray-update-session';

  String newUpdateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  CallOptions _updateOptions(Duration timeout, String sessionId) => CallOptions(
        metadata: {
          'nekoray_auth': _token,
          _updateSessionMetadata: sessionId,
        },
        timeout: timeout,
      );

  Future<UpdateResp> checkForUpdates({
    required String sessionId,
    bool includePreRelease = false,
  }) =>
      _guard(() => _client.update(
            UpdateReq(
              action: UpdateAction.Check,
              checkPreRelease: includePreRelease,
            ),
            options: _updateOptions(_Deadlines.normal, sessionId),
          ));

  Future<UpdateResp> downloadUpdate({required String sessionId}) =>
      _guard(() => _client.update(
            UpdateReq(action: UpdateAction.Download),
            options: _updateOptions(_Deadlines.slow, sessionId),
          ));

  Future<TestResp> test(TestReq req) =>
      _guard(() => _client.test(req, options: _options(_Deadlines.slow)));
}
