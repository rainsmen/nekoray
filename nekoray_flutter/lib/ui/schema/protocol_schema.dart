// Schema-driven protocol form definitions.
//
// Instead of one form file per protocol, each protocol registers a list of
// FieldSchema. The DynamicForm widget renders fields from the schema, so
// adding a new protocol only requires registering a new schema — no UI code
// changes.

enum FieldType { text, number, password, combo, bool_, tls, stream }

class FieldSchema {
  final String key;
  final String label;
  final FieldType type;
  final List<String>? options; // for combo
  final String? hint;
  final bool required;
  final bool multiline;

  const FieldSchema(
    this.key,
    this.label,
    this.type, {
    this.options,
    this.hint,
    this.required = false,
    this.multiline = false,
  });
}

/// Protocol schema registry — maps protocol type → field list.
final protocolSchemas = <String, List<FieldSchema>>{
  'vmess': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('id', 'UUID', FieldType.text, required: true),
    const FieldSchema('alter_id', 'Alter ID', FieldType.number),
    const FieldSchema('security', 'Security', FieldType.combo,
        options: ['auto', 'aes-128-gcm', 'chacha20-ietf-poly1305', 'none']),
    const FieldSchema('net', 'Network', FieldType.combo,
        options: ['tcp', 'ws', 'grpc', 'h2', 'quic']),
    const FieldSchema('tls', 'TLS', FieldType.combo,
        options: ['', 'tls', 'reality']),
    const FieldSchema('path', 'Path', FieldType.text),
    const FieldSchema('host', 'Host', FieldType.text),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('allow_insecure', 'Allow Insecure', FieldType.bool_),
  ],
  'vless': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('uuid', 'UUID', FieldType.text, required: true),
    const FieldSchema('flow', 'Flow', FieldType.combo,
        options: ['', 'xtls-rprx-vision']),
    const FieldSchema('net', 'Network', FieldType.combo,
        options: ['tcp', 'ws', 'grpc', 'h2', 'quic']),
    const FieldSchema('tls', 'TLS', FieldType.combo,
        options: ['', 'tls', 'reality']),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('public_key', 'Reality Public Key', FieldType.text),
    const FieldSchema('short_id', 'Reality Short ID', FieldType.text),
    const FieldSchema('fingerprint', 'uTLS Fingerprint', FieldType.combo,
        options: ['', 'chrome', 'firefox', 'safari', 'ios', 'android', 'edge']),
    const FieldSchema('path', 'Path', FieldType.text),
    const FieldSchema('host', 'Host', FieldType.text),
    const FieldSchema('allow_insecure', 'Allow Insecure', FieldType.bool_),
  ],
  'trojan': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('password', 'Password', FieldType.password, required: true),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('allow_insecure', 'Allow Insecure', FieldType.bool_),
  ],
  'shadowsocks': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('method', 'Method', FieldType.combo,
        options: [
          '2022-blake3-aes-128-gcm', '2022-blake3-aes-256-gcm',
          '2022-blake3-chacha20-poly1305',
          'aes-128-gcm', 'aes-192-gcm', 'aes-256-gcm',
          'chacha20-ietf-poly1305', 'xchacha20-ietf-poly1305',
          'none', 'rc4-md5',
        ]),
    const FieldSchema('password', 'Password', FieldType.password, required: true),
  ],
  'hysteria2': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('up_mbps', 'Up Mbps', FieldType.number),
    const FieldSchema('down_mbps', 'Down Mbps', FieldType.number),
    const FieldSchema('obfs_password', 'Obfs Password', FieldType.text),
    const FieldSchema('allow_insecure', 'Allow Insecure', FieldType.bool_),
  ],
  'tuic': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('uuid', 'UUID', FieldType.text, required: true),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('congestion_control', 'Congestion Control', FieldType.combo,
        options: ['bbr', 'cubic', 'new_reno']),
    const FieldSchema('udp_relay_mode', 'UDP Relay Mode', FieldType.combo,
        options: ['native', 'quic']),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('allow_insecure', 'Allow Insecure', FieldType.bool_),
  ],
  'socks': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('username', 'Username', FieldType.text),
    const FieldSchema('password', 'Password', FieldType.password),
  ],
  'http': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('username', 'Username', FieldType.text),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('tls', 'TLS', FieldType.bool_),
  ],
  'wireguard': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('privateKey', 'Private Key', FieldType.password, required: true,
        hint: 'Base64-encoded WireGuard private key'),
    const FieldSchema('address', 'Interface Address', FieldType.text,
        hint: 'Comma-separated CIDR, e.g. 10.0.0.2/32'),
    const FieldSchema('mtu', 'MTU', FieldType.number, hint: 'Default 1280'),
    const FieldSchema('peerPublicKey', 'Peer Public Key', FieldType.text),
    const FieldSchema('peerPreSharedKey', 'Pre-shared Key', FieldType.text),
    const FieldSchema('peerAllowedIPs', 'Allowed IPs', FieldType.text,
        hint: 'Comma-separated CIDR'),
    const FieldSchema('peerKeepAlive', 'Keepalive (s)', FieldType.number),
    const FieldSchema('peerReserved', 'Reserved', FieldType.text,
        hint: 'Comma-separated uint8, e.g. 0,0,0'),
  ],
  'ssh': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('user', 'Username', FieldType.text, required: true),
    const FieldSchema('password', 'Password', FieldType.password),
    const FieldSchema('private_key', 'Private Key', FieldType.text, multiline: true,
        hint: 'OpenSSH/PuTTY private key (optional)'),
    const FieldSchema('private_key_path', 'Private Key Path', FieldType.text,
        hint: 'Path to key file on disk'),
    const FieldSchema('private_key_passphrase', 'Key Passphrase', FieldType.password),
    const FieldSchema('host_key_algorithms', 'Host Key Algorithms', FieldType.text,
        hint: 'Comma-separated, e.g. ssh-ed25519,rsa-sha2-256'),
    const FieldSchema('client_version', 'Client Version', FieldType.text,
        hint: 'e.g. SSH-2.0-OpenSSH_9.0'),
  ],
  'naive': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
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
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('server', 'Address', FieldType.text, required: true),
    const FieldSchema('server_port', 'Port', FieldType.number, required: true),
    const FieldSchema('password', 'Password', FieldType.password, required: true),
    const FieldSchema('sni', 'SNI', FieldType.text),
    const FieldSchema('alpn', 'ALPN', FieldType.text, hint: 'h2'),
    const FieldSchema('allowInsecure', 'Allow Insecure', FieldType.bool_),
    const FieldSchema('minIdleSession', 'Min Idle Session', FieldType.number,
        hint: 'Default 0 (auto)'),
    const FieldSchema('clientMetadata', 'Client Metadata', FieldType.text),
    const FieldSchema('idleSessionCheckInterval', 'Idle Check Interval', FieldType.text,
        hint: 'e.g. 30s'),
    const FieldSchema('idleSessionTimeout', 'Idle Timeout', FieldType.text,
        hint: 'e.g. 30s'),
  ],
  'custom': [
    const FieldSchema('name', 'Name', FieldType.text, required: true),
    const FieldSchema('custom_config', 'Config', FieldType.text,
        multiline: true, hint: 'Full sing-box outbound JSON'),
  ],
};

/// Gets the list of protocol types for dropdowns.
final protocolTypes = protocolSchemas.keys.toList();
