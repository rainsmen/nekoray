// gRPC client for talking to the nekobox_core process.
//
// Phase-2: a thin wrapper around the generated LibcoreServiceClient. The
// Flutter UI never touches sing-box directly — all config building,
// subscription parsing, and stats querying go through this client.

import 'package:grpc/grpc.dart';

import 'generated/libcore.pbgrpc.dart';

class GrpcClient {
  GrpcClient._();

  ClientChannel? _channel;
  LibcoreServiceClient? _stub;

  bool get isConnected => _channel != null;

  /// Connects to the local nekobox_core gRPC endpoint.
  Future<void> connect({
    String host = '127.0.0.1',
    int port = 19821,
    String token = '',
  }) async {
    await _channel?.shutdown();

    final channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
        idleTimeout: const Duration(minutes: 5),
      ),
    );

    _channel = channel;
    _stub = LibcoreServiceClient(
      channel,
      options: CallOptions(
        metadata: token.isEmpty ? {} : {'nekoray_auth': token},
        timeout: const Duration(seconds: 10),
      ),
    );
  }

  LibcoreServiceClient get stub {
    final s = _stub;
    if (s == null) {
      throw StateError('GrpcClient not connected — call connect() first');
    }
    return s;
  }

  Future<void> disconnect() async {
    await _channel?.shutdown();
    _channel = null;
    _stub = null;
  }

  // --- Convenience wrappers ----------------------------------------------

  Future<BuildConfigResp> buildConfig(BuildConfigReq req) {
    return stub.buildConfig(req);
  }

  Future<ParseSubResp> parseSubscription(ParseSubReq req) {
    return stub.parseSubscription(req);
  }

  Future<ShareLinkResp> generateShareLink(ShareLinkReq req) {
    return stub.generateShareLink(req);
  }

  Future<QueryStatsResp> queryStats(String tag, String direction) {
    return stub.queryStats(QueryStatsReq(tag: tag, direct: direction));
  }

  Future<ErrorResp> startCore(String coreConfig,
      {bool enableConnections = false, List<String> statsOutbounds = const []}) {
    return stub.start(LoadConfigReq(
      coreConfig: coreConfig,
      enableNekorayConnections: enableConnections,
      statsOutbounds: statsOutbounds,
    ));
  }

  Future<ErrorResp> stopCore() => stub.stop(EmptyReq());

  Future<ListRuleSetsResp> listRuleSets() => stub.listRuleSets(EmptyReq());

  Future<ErrorResp> updateRuleSet(UpdateRuleSetReq req) => stub.updateRuleSet(req);
}
