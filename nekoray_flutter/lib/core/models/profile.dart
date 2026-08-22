// Data models for proxy profiles, groups, and routing.
//
// Mirrors the C++ NekoGui JsonStore / AbstractBean classes so that existing
// JSON config files stay 100% compatible.
//
// See: fmt/AbstractBean.hpp, main/NekoGui_DataStore.hpp
//
// Note: uses plain Dart classes (no freezed codegen) to avoid version-solver
// conflicts between freezed and json_serializable on Dart 3.9+.

import 'dart:convert';

/// Protocol type string constants (match C++ `V2rayOutboundType_*`).
class ProxyType {
  static const vmess = 'vmess';
  static const vless = 'vless';
  static const trojan = 'trojan';
  static const shadowsocks = 'shadowsocks';
  static const socks = 'socks';
  static const http = 'http';
  static const quic = 'hysteria2';
  static const tuic = 'tuic';
  static const wireguard = 'wireguard';
  static const ssh = 'ssh';
  static const custom = 'custom';
}

/// Common stream settings (transport + TLS), mirrors V2RayStreamSettings.hpp.
class StreamSettings {
  String network;         // tcp, ws, grpc, h2, quic, httpupgrade
  String security;        // tls, reality, none
  bool allowInsecure;
  String? sni;
  String? alpn;
  String? fingerprint;    // uTLS fingerprint
  String? clientFingerprint;
  String? publicKey;      // reality
  String? shortId;
  String? spiderX;
  String? serverName;     // reality
  // ws
  String? wsPath;
  String? wsHost;
  String? wsEarlyDataHeaderName;
  int? wsMaxEarlyData;
  // grpc
  String? grpcServiceName;
  String? grpcAuthority;
  // h2
  List<String>? h2Host;
  String? h2Path;
  // quic
  String? quicSecurity;
  String? quicKey;
  String? quicHeaderType;
  // httpupgrade
  String? httpupgradePath;
  String? httpupgradeHost;
  // tls cert
  String? certificates;

  StreamSettings({
    this.network = '',
    this.security = '',
    this.allowInsecure = false,
    this.sni,
    this.alpn,
    this.fingerprint,
    this.clientFingerprint,
    this.publicKey,
    this.shortId,
    this.spiderX,
    this.serverName,
    this.wsPath,
    this.wsHost,
    this.wsEarlyDataHeaderName,
    this.wsMaxEarlyData,
    this.grpcServiceName,
    this.grpcAuthority,
    this.h2Host,
    this.h2Path,
    this.quicSecurity,
    this.quicKey,
    this.quicHeaderType,
    this.httpupgradePath,
    this.httpupgradeHost,
    this.certificates,
  });

  factory StreamSettings.fromJson(Map<String, dynamic> j) => StreamSettings(
    network: j['network'] ?? '',
    security: j['security'] ?? '',
    allowInsecure: j['allow_insecure'] ?? false,
    sni: j['sni'],
    alpn: j['alpn'] is String ? j['alpn'] : (j['alpn'] is List ? (j['alpn'] as List).join(',') : null),
    fingerprint: j['fingerprint'],
    clientFingerprint: j['client_fingerprint'],
    publicKey: j['public_key'],
    shortId: j['short_id'],
    spiderX: j['spider_x'],
    serverName: j['server_name'],
    wsPath: j['ws_path'],
    wsHost: j['ws_host'],
    wsEarlyDataHeaderName: j['ws_early_data_header_name'],
    wsMaxEarlyData: j['ws_max_early_data'],
    grpcServiceName: j['grpc_service_name'],
    grpcAuthority: j['grpc_authority'],
    h2Host: (j['h2_host'] as List?)?.cast<String>(),
    h2Path: j['h2_path'],
    quicSecurity: j['quic_security'],
    quicKey: j['quic_key'],
    quicHeaderType: j['quic_header_type'],
    httpupgradePath: j['httpupgrade_path'],
    httpupgradeHost: j['httpupgrade_host'],
    certificates: j['certificates'],
  );

  Map<String, dynamic> toJson() => {
    'network': network,
    'security': security,
    'allow_insecure': allowInsecure,
    if (sni != null) 'sni': sni,
    if (alpn != null) 'alpn': alpn,
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (clientFingerprint != null) 'client_fingerprint': clientFingerprint,
    if (publicKey != null) 'public_key': publicKey,
    if (shortId != null) 'short_id': shortId,
    if (spiderX != null) 'spider_x': spiderX,
    if (serverName != null) 'server_name': serverName,
    if (wsPath != null) 'ws_path': wsPath,
    if (wsHost != null) 'ws_host': wsHost,
    if (wsEarlyDataHeaderName != null) 'ws_early_data_header_name': wsEarlyDataHeaderName,
    if (wsMaxEarlyData != null) 'ws_max_early_data': wsMaxEarlyData,
    if (grpcServiceName != null) 'grpc_service_name': grpcServiceName,
    if (grpcAuthority != null) 'grpc_authority': grpcAuthority,
    if (h2Host != null) 'h2_host': h2Host,
    if (h2Path != null) 'h2_path': h2Path,
    if (quicSecurity != null) 'quic_security': quicSecurity,
    if (quicKey != null) 'quic_key': quicKey,
    if (quicHeaderType != null) 'quic_header_type': quicHeaderType,
    if (httpupgradePath != null) 'httpupgrade_path': httpupgradePath,
    if (httpupgradeHost != null) 'httpupgrade_host': httpupgradeHost,
    if (certificates != null) 'certificates': certificates,
  };
}

/// Base bean — protocol-agnostic fields shared by all proxy types.
class AbstractBean {
  String serverAddress;
  int serverPort;
  StreamSettings? stream;
  String? password;
  String? uuid;
  int alterId;
  String? method;
  String? sni;
  String? obfs;
  String? obfsParam;
  String? path;
  String? host;
  String username;
  String? id;             // VMess id (= uuid)
  String? aid;            // VMess alterId (string form)
  String? net;           // VMess network
  String? tls;           // VMess tls
  String? flow;          // VLESS flow
  int? upMbps;
  int? downMbps;
  String? obfsPassword;
  String? congestionControl;
  String? udpRelayMode;
  String? customConfig;
  String? customOutbound;

  AbstractBean({
    required this.serverAddress,
    required this.serverPort,
    this.stream,
    this.password,
    this.uuid,
    this.alterId = 0,
    this.method,
    this.sni,
    this.obfs,
    this.obfsParam,
    this.path,
    this.host,
    this.username = '',
    this.id,
    this.aid,
    this.net,
    this.tls,
    this.flow,
    this.upMbps,
    this.downMbps,
    this.obfsPassword,
    this.congestionControl,
    this.udpRelayMode,
    this.customConfig,
    this.customOutbound,
  });

  factory AbstractBean.fromJson(Map<String, dynamic> j) => AbstractBean(
    serverAddress: j['server'] ?? '',
    serverPort: j['server_port'] ?? 0,
    stream: j['stream'] is Map<String, dynamic>
        ? StreamSettings.fromJson(j['stream'])
        : null,
    password: j['password'],
    uuid: j['uuid'],
    alterId: j['alter_id'] ?? 0,
    method: j['method'],
    sni: j['sni'],
    obfs: j['obfs'],
    obfsParam: j['obfs_param'],
    path: j['path'],
    host: j['host'],
    username: j['username'] ?? '',
    id: j['id'],
    aid: j['aid'],
    net: j['net'],
    tls: j['tls'],
    flow: j['flow'],
    upMbps: j['up_mbps'],
    downMbps: j['down_mbps'],
    obfsPassword: j['obfs_password'],
    congestionControl: j['congestion_control'],
    udpRelayMode: j['udp_relay_mode'],
    customConfig: j['custom_config'],
    customOutbound: j['custom_outbound'],
  );

  Map<String, dynamic> toJson() => {
    'server': serverAddress,
    'server_port': serverPort,
    if (stream != null) 'stream': stream!.toJson(),
    if (password != null) 'password': password,
    if (uuid != null) 'uuid': uuid,
    'alter_id': alterId,
    if (method != null) 'method': method,
    if (sni != null) 'sni': sni,
    if (obfs != null) 'obfs': obfs,
    if (obfsParam != null) 'obfs_param': obfsParam,
    if (path != null) 'path': path,
    if (host != null) 'host': host,
    'username': username,
    if (id != null) 'id': id,
    if (aid != null) 'aid': aid,
    if (net != null) 'net': net,
    if (tls != null) 'tls': tls,
    if (flow != null) 'flow': flow,
    if (upMbps != null) 'up_mbps': upMbps,
    if (downMbps != null) 'down_mbps': downMbps,
    if (obfsPassword != null) 'obfs_password': obfsPassword,
    if (congestionControl != null) 'congestion_control': congestionControl,
    if (udpRelayMode != null) 'udp_relay_mode': udpRelayMode,
    if (customConfig != null) 'custom_config': customConfig,
    if (customOutbound != null) 'custom_outbound': customOutbound,
  };
}

/// A proxy profile — mirrors `NekoGui::ProxyEntity`.
class ProxyEntity {
  final int id;
  int gid;
  String type;
  String name;
  AbstractBean bean;
  StreamSettings? stream;
  int latency;
  int trafficUp;
  int trafficDown;
  int? maxLink;
  bool dyslexia;
  String? customCore;
  String? location;

  ProxyEntity({
    required this.id,
    this.gid = 0,
    required this.type,
    this.name = '',
    required this.bean,
    this.stream,
    this.latency = 0,
    this.trafficUp = 0,
    this.trafficDown = 0,
    this.maxLink,
    this.dyslexia = false,
    this.customCore,
    this.location,
  });

  factory ProxyEntity.fromJson(Map<String, dynamic> j) => ProxyEntity(
    id: j['id'] ?? 0,
    gid: j['gid'] ?? 0,
    type: j['type'] ?? '',
    name: j['name'] ?? '',
    bean: AbstractBean.fromJson(j),
    stream: j['stream'] is Map<String, dynamic>
        ? StreamSettings.fromJson(j['stream'])
        : null,
    latency: j['latency'] ?? 0,
    trafficUp: j['traffic_up'] ?? 0,
    trafficDown: j['traffic_down'] ?? 0,
    maxLink: j['max_link'],
    dyslexia: j['dyslexia'] ?? false,
    customCore: j['custom_core'],
    location: j['location'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'gid': gid,
    'type': type,
    'name': name,
    ...bean.toJson(),
    if (stream != null) 'stream': stream!.toJson(),
    'latency': latency,
    'traffic_up': trafficUp,
    'traffic_down': trafficDown,
    if (maxLink != null) 'max_link': maxLink,
    'dyslexia': dyslexia,
    if (customCore != null) 'custom_core': customCore,
    if (location != null) 'location': location,
  };

  String get address => '${bean.serverAddress}:${bean.serverPort}';
  String get displayType => type;
}

/// A group of profiles — mirrors `NekoGui::Group`.
class ProfileGroup {
  final int id;
  int archive;
  String name;
  List<int> profiles;
  String url;
  int cycleTime;
  int subLastUpdate;
  bool subAutoUpdate;
  List<int> subSupport;

  ProfileGroup({
    required this.id,
    this.archive = 0,
    this.name = '',
    this.profiles = const [],
    this.url = '',
    this.cycleTime = 0,
    this.subLastUpdate = 0,
    this.subAutoUpdate = false,
    this.subSupport = const [],
  });

  factory ProfileGroup.fromJson(Map<String, dynamic> j) => ProfileGroup(
    id: j['id'] ?? 0,
    archive: j['archive'] ?? 0,
    name: j['name'] ?? '',
    profiles: (j['profiles'] as List?)?.cast<int>() ?? [],
    url: j['url'] ?? '',
    cycleTime: j['cycle_time'] ?? 0,
    subLastUpdate: j['sub_last_update'] ?? 0,
    subAutoUpdate: j['sub_auto_update'] ?? false,
    subSupport: (j['sub_support'] as List?)?.cast<int>() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'archive': archive,
    'name': name,
    'profiles': profiles,
    'url': url,
    'cycle_time': cycleTime,
    'sub_last_update': subLastUpdate,
    'sub_auto_update': subAutoUpdate,
    'sub_support': subSupport,
  };
}

/// Outbound / DNS / route rule targets.
class RoutingRule {
  List<String> domains;
  List<String> ip;
  List<String> port;
  List<String> source;
  List<String> sourcePort;
  String outbound;
  String protocol;
  String inbound;
  String network;
  String? domainMatcher;

  RoutingRule({
    this.domains = const [],
    this.ip = const [],
    this.port = const [],
    this.source = const [],
    this.sourcePort = const [],
    this.outbound = '',
    this.protocol = '',
    this.inbound = '',
    this.network = '',
    this.domainMatcher,
  });

  factory RoutingRule.fromJson(Map<String, dynamic> j) => RoutingRule(
    domains: (j['domains'] as List?)?.cast<String>() ?? [],
    ip: (j['ip'] as List?)?.cast<String>() ?? [],
    port: (j['port'] as List?)?.cast<String>() ?? [],
    source: (j['source'] as List?)?.cast<String>() ?? [],
    sourcePort: (j['source_port'] as List?)?.cast<String>() ?? [],
    outbound: j['outbound'] ?? '',
    protocol: j['protocol'] ?? '',
    inbound: j['inbound'] ?? '',
    network: j['network'] ?? '',
    domainMatcher: j['domain_matcher'],
  );

  Map<String, dynamic> toJson() => {
    'domains': domains,
    'ip': ip,
    'port': port,
    'source': source,
    'source_port': sourcePort,
    'outbound': outbound,
    'protocol': protocol,
    'inbound': inbound,
    'network': network,
    if (domainMatcher != null) 'domain_matcher': domainMatcher,
  };
}

/// Convenience helpers.
String encodeJson(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

Map<String, dynamic> decodeJson(String src) =>
    jsonDecode(src) as Map<String, dynamic>;
