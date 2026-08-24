// Data models for proxy profiles, groups, and routing.
//
// The wire format is defined by the Go core (`go/grpc_server/core/fmt`):
//
//   { "type": "vmess", "id": 1, "gid": 0, "latency": 0,
//     "bean": { "name": "...", "addr": "...", "port": 443, ... } }
//
// The bean payload is protocol-specific and its keys are the JSON tags of the
// corresponding Go struct (`addr`, `port`, `pbk`, `allowInsecure`, ...). It is
// deliberately kept as a raw map here rather than mirrored into typed Dart
// fields: a typed mirror silently dropped every key it did not know about, so
// editing a node destroyed its transport settings. Keeping the map means the
// UI can round-trip protocols it does not fully understand.

import 'dart:convert';

/// Protocol type identifiers — must match `fmt.BeanType` in the Go core.
class ProxyType {
  static const vmess = 'vmess';
  static const vless = 'vless';
  static const trojan = 'trojan';
  static const shadowsocks = 'shadowsocks';
  static const socks = 'socks';
  static const http = 'http';
  static const hysteria2 = 'hysteria2';
  static const tuic = 'tuic';
  static const naive = 'naive';
  static const anytls = 'anytls';
  static const wireguard = 'wireguard';
  static const ssh = 'ssh';
  static const custom = 'custom';

  static const all = [
    vmess, vless, trojan, shadowsocks, hysteria2, tuic,
    naive, anytls, socks, http, wireguard, ssh, custom,
  ];
}

/// Discriminator values the Go beans use to distinguish protocols that share a
/// struct (`TrojanVLESSBean`, `QUICBean`, `SocksHttpBean`).
class BeanDiscriminator {
  static const trojanVless = 'proxy_type';
  static const quic = 'proxy_type';
  static const socksHttp = 'socks_http_type';

  static const trojan = 0;
  static const vless = 1;
  static const hysteria2 = 3;
  static const tuic = 1;
  static const socksTypeSocks = 1;
  static const socksTypeHttp = 2;

  /// Stamps the discriminator the Go core reads for [type] into [bean].
  static void apply(String type, Map<String, dynamic> bean) {
    switch (type) {
      case ProxyType.trojan:
        bean[trojanVless] = trojan;
        break;
      case ProxyType.vless:
        bean[trojanVless] = vless;
        break;
      case ProxyType.hysteria2:
        bean[quic] = hysteria2;
        break;
      case ProxyType.tuic:
        bean[quic] = tuic;
        break;
      case ProxyType.socks:
        bean[socksHttp] = socksTypeSocks;
        break;
      case ProxyType.http:
        bean[socksHttp] = socksTypeHttp;
        break;
    }
  }
}

/// Protocols whose Go bean carries a nested `stream` object.
const _protocolsWithStream = {
  ProxyType.vmess,
  ProxyType.vless,
  ProxyType.trojan,
  ProxyType.shadowsocks,
  ProxyType.socks,
  ProxyType.http,
};

bool protocolHasStream(String type) => _protocolsWithStream.contains(type);

/// A proxy profile — mirrors `fmt.ProxyEntity` in the Go core.
class ProxyEntity {
  final int id;
  int gid;
  String type;
  int latency;
  String fullTestReport;

  /// Protocol-specific payload, keyed by the Go bean's JSON tags.
  final Map<String, dynamic> bean;

  ProxyEntity({
    required this.id,
    required this.type,
    Map<String, dynamic>? bean,
    this.gid = 0,
    this.latency = 0,
    this.fullTestReport = '',
  }) : bean = bean ?? <String, dynamic>{};

  // --- Convenience accessors over the bean ------------------------------

  String get name => (bean['name'] as String?) ?? '';
  set name(String v) => bean['name'] = v;

  String get serverAddress => (bean['addr'] as String?) ?? '';
  int get serverPort => _asInt(bean['port']);

  /// `host:port`, bracketing IPv6 literals so the result is a valid authority.
  String get address {
    final a = serverAddress;
    if (a.isEmpty) return '';
    final host = a.contains(':') && !a.startsWith('[') ? '[$a]' : a;
    return '$host:$serverPort';
  }

  /// The nested stream settings map, or null for protocols without one.
  Map<String, dynamic>? get stream {
    final s = bean['stream'];
    return s is Map ? Map<String, dynamic>.from(s) : null;
  }

  ProxyEntity copyWith({
    int? id,
    int? gid,
    String? type,
    Map<String, dynamic>? bean,
    int? latency,
  }) {
    return ProxyEntity(
      id: id ?? this.id,
      gid: gid ?? this.gid,
      type: type ?? this.type,
      bean: bean ?? _deepCopyMap(this.bean),
      latency: latency ?? this.latency,
      fullTestReport: fullTestReport,
    );
  }

  factory ProxyEntity.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] as String?) ?? '';
    final rawBean = j['bean'];

    final Map<String, dynamic> bean;
    if (rawBean is Map) {
      bean = Map<String, dynamic>.from(rawBean);
    } else {
      // Tolerate the flat layout written by 5.0.0-beta builds, whose model did
      // not nest the bean. Without this, upgrading loses every saved profile.
      bean = _beanFromLegacyFlat(j);
    }

    return ProxyEntity(
      id: _asInt(j['id']),
      gid: _asInt(j['gid']),
      type: type,
      bean: bean,
      latency: _asInt(j['latency']),
      fullTestReport: (j['full_test_report'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final out = _deepCopyMap(bean);
    BeanDiscriminator.apply(type, out);
    out.putIfAbsent('_v', () => 0);
    return {
      'type': type,
      'id': id,
      'gid': gid,
      'latency': latency,
      'full_test_report': fullTestReport,
      'bean': out,
    };
  }

  /// Converts a beta-era flat profile map into a Go-shaped bean.
  static Map<String, dynamic> _beanFromLegacyFlat(Map<String, dynamic> j) {
    final bean = <String, dynamic>{
      'name': j['name'] ?? '',
      'addr': j['server'] ?? j['addr'] ?? '',
      'port': _asInt(j['server_port'] ?? j['port']),
    };

    void put(String beanKey, Object? value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      bean[beanKey] = value;
    }

    put('password', j['password']);
    put('method', j['method']);
    put('username', j['username']);
    put('flow', j['flow']);
    put('id', j['id_uuid'] ?? j['uuid']);
    put('uuid', j['uuid']);
    put('aid', j['alter_id']);
    put('c_cfg', j['custom_config']);
    put('c_out', j['custom_outbound']);
    put('sni', j['sni']);
    put('uploadMbps', j['up_mbps']);
    put('downloadMbps', j['down_mbps']);
    put('obfsPassword', j['obfs_password']);
    put('congestionControl', j['congestion_control']);
    put('udpRelayMode', j['udp_relay_mode']);

    final legacyStream = j['stream'];
    if (legacyStream is Map) {
      final s = <String, dynamic>{};
      void putS(String k, Object? v) {
        if (v == null) return;
        if (v is String && v.isEmpty) return;
        s[k] = v;
      }

      putS('net', legacyStream['network'] ?? j['net']);
      putS('sec', legacyStream['security'] ?? j['tls']);
      putS('path', legacyStream['ws_path'] ?? j['path']);
      putS('host', legacyStream['ws_host'] ?? j['host']);
      putS('sni', legacyStream['sni'] ?? j['sni']);
      putS('alpn', legacyStream['alpn']);
      putS('utls', legacyStream['fingerprint']);
      putS('pbk', legacyStream['public_key']);
      putS('sid', legacyStream['short_id']);
      putS('spx', legacyStream['spider_x']);
      putS('cert', legacyStream['certificates']);
      if (legacyStream['allow_insecure'] == true) s['insecure'] = true;
      if (s.isNotEmpty) bean['stream'] = s;
    }

    return bean;
  }
}

/// A group of profiles — mirrors `fmt.Group` in the Go core.
///
/// Note `archive` is a bool on the wire: the previous Dart model emitted an
/// int, which made every `BuildConfig` call fail to unmarshal the group.
class ProfileGroup {
  final int id;
  bool archive;
  String name;
  String url;
  String info;
  int subLastUpdate;
  int frontProxyId;
  bool skipAutoUpdate;
  List<int> order;

  ProfileGroup({
    required this.id,
    this.archive = false,
    this.name = '',
    this.url = '',
    this.info = '',
    this.subLastUpdate = 0,
    this.frontProxyId = 0,
    this.skipAutoUpdate = false,
    List<int>? order,
  }) : order = order ?? <int>[];

  factory ProfileGroup.fromJson(Map<String, dynamic> j) => ProfileGroup(
        id: _asInt(j['id']),
        // Tolerate the beta-era int encoding.
        archive: j['archive'] is bool ? j['archive'] as bool : _asInt(j['archive']) != 0,
        name: (j['name'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
        info: (j['info'] as String?) ?? '',
        subLastUpdate: _asInt(j['sub_last_update']),
        frontProxyId: _asInt(j['front_proxy_id']),
        skipAutoUpdate: j['skip_auto_update'] == true,
        order: _asIntList(j['order'] ?? j['profiles']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'archive': archive,
        'skip_auto_update': skipAutoUpdate,
        'name': name,
        'url': url,
        'info': info,
        'sub_last_update': subLastUpdate,
        'front_proxy_id': frontProxyId,
        'order': order,
      };
}

/// A routing rule as edited in the UI.
class RoutingRule {
  String name;
  bool enabled;
  List<String> domains;
  List<String> ip;
  List<String> port;
  List<String> source;
  List<String> sourcePort;
  String outbound;
  String protocol;
  String inbound;
  String network;

  RoutingRule({
    this.name = '',
    this.enabled = true,
    List<String>? domains,
    List<String>? ip,
    List<String>? port,
    List<String>? source,
    List<String>? sourcePort,
    this.outbound = 'direct',
    this.protocol = '',
    this.inbound = '',
    this.network = '',
  })  : domains = domains ?? <String>[],
        ip = ip ?? <String>[],
        port = port ?? <String>[],
        source = source ?? <String>[],
        sourcePort = sourcePort ?? <String>[];

  factory RoutingRule.fromJson(Map<String, dynamic> j) => RoutingRule(
        name: (j['name'] as String?) ?? '',
        enabled: j['enabled'] != false,
        domains: _asStringList(j['domains']),
        ip: _asStringList(j['ip']),
        port: _asStringList(j['port']),
        source: _asStringList(j['source']),
        sourcePort: _asStringList(j['source_port']),
        outbound: (j['outbound'] as String?) ?? 'direct',
        protocol: (j['protocol'] as String?) ?? '',
        inbound: (j['inbound'] as String?) ?? '',
        network: (j['network'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'enabled': enabled,
        'domains': domains,
        'ip': ip,
        'port': port,
        'source': source,
        'source_port': sourcePort,
        'outbound': outbound,
        'protocol': protocol,
        'inbound': inbound,
        'network': network,
      };

  RoutingRule copyWith({
    String? name,
    bool? enabled,
    List<String>? domains,
    List<String>? ip,
    List<String>? port,
    List<String>? source,
    List<String>? sourcePort,
    String? outbound,
    String? protocol,
    String? inbound,
    String? network,
  }) =>
      RoutingRule(
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        domains: domains ?? List.from(this.domains),
        ip: ip ?? List.from(this.ip),
        port: port ?? List.from(this.port),
        source: source ?? List.from(this.source),
        sourcePort: sourcePort ?? List.from(this.sourcePort),
        outbound: outbound ?? this.outbound,
        protocol: protocol ?? this.protocol,
        inbound: inbound ?? this.inbound,
        network: network ?? this.network,
      );
}

// --- helpers ------------------------------------------------------------

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

List<int> _asIntList(Object? v) {
  if (v is! List) return <int>[];
  return v.map(_asInt).toList();
}

List<String> _asStringList(Object? v) {
  if (v is! List) return <String>[];
  return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> src) {
  return jsonDecode(jsonEncode(src)) as Map<String, dynamic>;
}

/// Convenience helpers.
String encodeJson(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

Map<String, dynamic> decodeJson(String src) =>
    jsonDecode(src) as Map<String, dynamic>;
