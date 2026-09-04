// Schema-driven protocol form definitions.
//
// Each protocol registers a list of FieldSchema; DynamicForm renders them, so
// adding a protocol requires no UI code.
//
// IMPORTANT: `key` is the JSON tag of the corresponding field in the Go bean
// (`go/grpc_server/core/fmt/bean.go`) and `group` says whether it lives on the
// bean itself or in the nested `stream` object. These must stay in sync with
// the Go structs — a mismatched key is silently dropped by the core.

import '../../core/i18n.dart';

/// Localized display label for [f]. Looks up `fld_<inputKey>` in the string
/// table and falls back to the schema's English label when untranslated, so
/// a missing key degrades to English instead of a raw key.
String schemaLabel(FieldSchema f) {
  final k = 'fld_${f.inputKey}';
  final v = I18n.t(k);
  return v == k ? f.label : v;
}

enum FieldType { text, number, password, combo, bool_, multiline }

/// Where a field is written inside the profile bean.
enum FieldGroup { bean, stream }

class FieldSchema {
  /// Storage key inside the bean/stream JSON.
  final String key;
  /// Optional unique key used by the flat form state. This is needed when a
  /// bean field and a nested stream field legitimately share the same JSON key.
  final String? formKey;
  final String label;
  final FieldType type;
  final FieldGroup group;
  final List<String>? options; // for combo
  final String? hint;
  final bool required;

  const FieldSchema(
    this.key,
    this.label,
    this.type, {
    this.formKey,
    this.group = FieldGroup.bean,
    this.options,
    this.hint,
    this.required = false,
  });

  bool get multiline => type == FieldType.multiline;
  String get inputKey => formKey ?? key;
}

/// Fields shared by every protocol.
const _common = <FieldSchema>[
  FieldSchema('name', 'Name', FieldType.text, required: true),
  FieldSchema('addr', 'Address', FieldType.text, required: true),
  FieldSchema('port', 'Port', FieldType.number, required: true),
];

/// V2Ray-style transport fields, written into the nested `stream` object.
const _stream = <FieldSchema>[
  FieldSchema('net', 'Network', FieldType.combo,
      group: FieldGroup.stream,
      options: ['tcp', 'ws', 'grpc', 'http', 'quic', 'httpupgrade']),
  FieldSchema('sec', 'Security', FieldType.combo,
      group: FieldGroup.stream, options: ['', 'tls', 'reality']),
  FieldSchema('path', 'Path', FieldType.text, group: FieldGroup.stream),
  FieldSchema('host', 'Host', FieldType.text, group: FieldGroup.stream),
  FieldSchema('sni', 'SNI', FieldType.text, group: FieldGroup.stream),
  FieldSchema('alpn', 'ALPN', FieldType.text,
      group: FieldGroup.stream, hint: 'h2,http/1.1'),
  FieldSchema('utls', 'uTLS Fingerprint', FieldType.combo,
      group: FieldGroup.stream,
      options: ['', 'chrome', 'firefox', 'safari', 'ios', 'android', 'edge', 'random']),
  FieldSchema('pbk', 'Reality Public Key', FieldType.text, group: FieldGroup.stream),
  FieldSchema('sid', 'Reality Short ID', FieldType.text, group: FieldGroup.stream),
  FieldSchema('spx', 'Reality SpiderX', FieldType.text, group: FieldGroup.stream),
  FieldSchema('insecure', 'Allow Insecure', FieldType.bool_, group: FieldGroup.stream),
];

/// Protocol schema registry — maps protocol type → field list.
final protocolSchemas = <String, List<FieldSchema>>{
  'vmess': [
    ..._common,
    const FieldSchema('id', 'UUID', FieldType.text, required: true),
    const FieldSchema('aid', 'Alter ID', FieldType.number),
    const FieldSchema('sec', 'Encryption', FieldType.combo,
        formKey: 'vmess_encryption',
        options: ['auto', 'aes-128-gcm', 'chacha20-ietf-poly1305', 'none', 'zero']),
    ..._stream,
  ],
  'vless': [
    ..._common,
    const FieldSchema('password', 'UUID', FieldType.text, required: true),
    const FieldSchema('flow', 'Flow', FieldType.combo,
        options: ['', 'xtls-rprx-vision']),
    ..._stream,
  ],
  'trojan': [
    ..._common,
    const FieldSchema('password', 'Password', FieldType.password, required: true),
    ..._stream,
  ],
  'shadowsocks': [
    ..._common,
    const FieldSchema('method', 'Method', FieldType.combo, options: [
      '2022-blake3-aes-128-gcm', '2022-blake3-aes-256-gcm',
      '2022-blake3-chacha20-poly1305',
      'aes-128-gcm', 'aes-192-gcm', 'aes-256-gcm',
      'chacha20-ietf-poly1305', 'xchacha20-ietf-poly1305',
      'none',
    ]),
    const FieldSchema('password', 'Password', FieldType.password, required: true),
    const FieldSchema('plugin', 'Plugin', FieldType.text,
        hint: 'e.g. obfs-local;obfs=http;obfs-host=example.com'),
    const FieldSchema('uot', 'UDP over TCP', FieldType.number, hint: '0 = off'),
    ..._stream,
  ],
  'hysteria2': [
    ..._common,
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('obfsPassword', 'Obfs Password', FieldType.password),
    const FieldSchema('uploadMbps', 'Up Mbps', FieldType.number),
    const FieldSchema('downloadMbps', 'Down Mbps', FieldType.number),
    const FieldSchema('hopPort', 'Port Hopping', FieldType.text, hint: 'e.g. 20000-30000'),
    const FieldSchema('hopInterval', 'Hop Interval (s)', FieldType.number),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('alpn', 'ALPN', FieldType.text, hint: 'h3'),
    const FieldSchema('allowInsecure', 'Allow Insecure', FieldType.bool_),
    const FieldSchema('disableMtuDiscovery', 'Disable MTU Discovery', FieldType.bool_),
  ],
  'tuic': [
    ..._common,
    const FieldSchema('uuid', 'UUID', FieldType.text, required: true),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('congestionControl', 'Congestion Control', FieldType.combo,
        options: ['bbr', 'cubic', 'new_reno']),
    const FieldSchema('udpRelayMode', 'UDP Relay Mode', FieldType.combo,
        options: ['native', 'quic']),
    const FieldSchema('zeroRttHandshake', 'Zero-RTT Handshake', FieldType.bool_),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('alpn', 'ALPN', FieldType.text),
    const FieldSchema('allowInsecure', 'Allow Insecure', FieldType.bool_),
  ],
  'naive': [
    ..._common,
    const FieldSchema('username', 'Username', FieldType.text, required: true),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('alpn', 'ALPN', FieldType.text, hint: 'h2,http/1.1'),
    const FieldSchema('allowInsecure', 'Allow Insecure', FieldType.bool_),
    const FieldSchema('insecureConcurrency', 'Insecure Concurrency', FieldType.number,
        hint: '0 = disabled'),
    const FieldSchema('udpOverTcp', 'UDP over TCP', FieldType.bool_),
    const FieldSchema('quic', 'QUIC', FieldType.bool_),
  ],
  'anytls': [
    ..._common,
    const FieldSchema('password', 'Password', FieldType.password, required: true),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('alpn', 'ALPN', FieldType.text, hint: 'h2'),
    const FieldSchema('allowInsecure', 'Allow Insecure', FieldType.bool_),
    const FieldSchema('minIdleSession', 'Min Idle Session', FieldType.number),
    const FieldSchema('clientMetadata', 'Client Metadata', FieldType.text),
    const FieldSchema('idleSessionCheckInterval', 'Idle Check Interval', FieldType.text,
        hint: 'e.g. 30s'),
    const FieldSchema('idleSessionTimeout', 'Idle Timeout', FieldType.text,
        hint: 'e.g. 30s'),
  ],
  'socks': [
    ..._common,
    const FieldSchema('username', 'Username', FieldType.text),
    const FieldSchema('password', 'Password', FieldType.password),
    ..._stream,
  ],
  'http': [
    ..._common,
    const FieldSchema('username', 'Username', FieldType.text),
    const FieldSchema('password', 'Password', FieldType.password),
    ..._stream,
  ],
  'wireguard': [
    ..._common,
    const FieldSchema('privateKey', 'Private Key', FieldType.password,
        required: true, hint: 'Base64-encoded WireGuard private key'),
    const FieldSchema('address', 'Interface Address', FieldType.text,
        hint: 'Comma-separated CIDR, e.g. 10.0.0.2/32'),
    const FieldSchema('mtu', 'MTU', FieldType.number, hint: 'Default 1280'),
    const FieldSchema('peerPublicKey', 'Peer Public Key', FieldType.text),
    const FieldSchema('peerPreSharedKey', 'Pre-shared Key', FieldType.password),
    const FieldSchema('peerAllowedIPs', 'Allowed IPs', FieldType.text,
        hint: 'Comma-separated CIDR'),
    const FieldSchema('peerKeepAlive', 'Keepalive (s)', FieldType.number),
    const FieldSchema('peerReserved', 'Reserved', FieldType.text,
        hint: 'Comma-separated uint8, e.g. 0,0,0'),
    const FieldSchema('interfaceName', 'Interface Name', FieldType.text),
    const FieldSchema('system', 'System Interface', FieldType.bool_),
  ],
  'ssh': [
    ..._common,
    const FieldSchema('user', 'Username', FieldType.text, required: true),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('privateKey', 'Private Key', FieldType.multiline,
        hint: 'OpenSSH private key (optional)'),
    const FieldSchema('privateKeyPath', 'Private Key Path', FieldType.text,
        hint: 'Path to key file on disk'),
    const FieldSchema('privateKeyPassphrase', 'Key Passphrase', FieldType.password),
    const FieldSchema('hostKeyAlgorithms', 'Host Key Algorithms', FieldType.text,
        hint: 'Comma-separated, e.g. ssh-ed25519,rsa-sha2-256'),
    const FieldSchema('clientVersion', 'Client Version', FieldType.text,
        hint: 'e.g. SSH-2.0-OpenSSH_9.0'),
  ],
  'custom': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('addr', 'Address', FieldType.text),
    const FieldSchema('port', 'Port', FieldType.number),
    const FieldSchema('c_out', 'Outbound JSON', FieldType.multiline,
        hint: 'Full sing-box outbound object'),
    const FieldSchema('c_cfg', 'Extra Config', FieldType.multiline),
  ],
};

/// Gets the list of protocol types for dropdowns.
final protocolTypes = protocolSchemas.keys.toList();

/// Field keys that hold secrets — used to decide what to encrypt at rest.
const secretFieldKeys = <String>{
  'password',
  'obfsPassword',
  'privateKey',
  'privateKeyPassphrase',
  'peerPreSharedKey',
  'uuid',
  'id',
};
