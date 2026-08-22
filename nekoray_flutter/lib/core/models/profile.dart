// Data models for proxy profiles, groups, and routing — mirroring the C++
// NekoGui JsonStore / AbstractBean classes so that existing JSON config
// files stay 100% compatible.
//
// See: fmt/AbstractBean.hpp, main/NekoGui_DataStore.hpp

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

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
@freezed
class StreamSettings with _$StreamSettings {
  const factory StreamSettings({
    @Default('') String network,           // tcp, ws, grpc, h2, quic, httpupgrade
    @Default('') String security,          // tls, reality, none
    @Default(false) bool allowInsecure,
    String? sni,
    String? alpn,
    String? fingerprint,                   // uTLS fingerprint
    String? clientFingerprint,
    String? publicKey,                     // reality
    String? shortId,
    String? spiderX,
    String? serverName,                    // reality
    // ws
    String? wsPath,
    String? wsHost,
    String? wsEarlyDataHeaderName,
    int? wsMaxEarlyData,
    // grpc
    String? grpcServiceName,
    String? grpcAuthority,
    // h2
    List<String>? h2Host,
    String? h2Path,
    // quic
    String? quicSecurity,
    String? quicKey,
    String? quicHeaderType,
    // httpupgrade
    String? httpupgradePath,
    String? httpupgradeHost,
    // tls cert
    String? certificates,
  }) = _StreamSettings;

  factory StreamSettings.fromJson(Map<String, dynamic> json) =>
      _$StreamSettingsFromJson(json);
}

/// Base bean — protocol-agnostic fields shared by all proxy types.
@freezed
class AbstractBean with _$AbstractBean {
  const factory AbstractBean({
    @JsonKey(name: 'server') required String serverAddress,
    @JsonKey(name: 'server_port') required int serverPort,
    StreamSettings? stream,
    String? password,
    String? uuid,
    @Default(0) int alterId,
    String? method,                       // SS cipher / HTTP auth method
    String? sni,
    String? obfs,
    String? obfsParam,
    String? path,
    String? host,
    @Default('') String username,
    // VMess
    String? id,
    String? aid,
    String? net,
    String? tls,
    // VLESS flow
    String? flow,
    // QUIC
    @JsonKey(name: 'up_mbps') int? upMbps,
    @JsonKey(name: 'down_mbps') int? downMbps,
    @JsonKey(name: 'obfs_password') String? obfsPassword,
    // TUIC
    @JsonKey(name: 'uuid') String? tuicUuid,
    @JsonKey(name: 'congestion_control') String? congestionControl,
    @JsonKey(name: 'udp_relay_mode') String? udpRelayMode,
    int? alpn,
    // custom
    String? customConfig,
    String? customOutbound,
  }) = _AbstractBean;

  factory AbstractBean.fromJson(Map<String, dynamic> json) =>
      _$AbstractBeanFromJson(json);
}

/// A proxy profile — mirrors `NekoGui::ProxyEntity`.
@freezed
class ProxyEntity with _$ProxyEntity {
  const factory ProxyEntity({
    required int id,
    @Default(0) int gid,
    required String type,
    @Default('') String name,
    required AbstractBean bean,
    StreamSettings? stream,
    @Default(0) int latency,
    @Default(0) int trafficUp,
    @Default(0) int trafficDown,
    @JsonKey(name: 'max_link') int? maxLink,
    @Default(false) bool dyslexia,
    String? customCore,
    @JsonKey(name: 'location') String? location,
  }) = _ProxyEntity;

  factory ProxyEntity.fromJson(Map<String, dynamic> json) =>
      _$ProxyEntityFromJson(json);
}

/// A group of profiles — mirrors `NekoGui::Group`.
@freezed
class ProfileGroup with _$ProfileGroup {
  const factory ProfileGroup({
    required int id,
    @Default(0) int archive,
    @Default('') String name,
    @Default([]) List<int> profiles,
    @Default('') String url,
    @Default(0) int cycleTime,
    @Default(0) int subLastUpdate,
    @Default(false) bool subAutoUpdate,
    @Default([]) List<int> subSupport,
  }) = _ProfileGroup;

  factory ProfileGroup.fromJson(Map<String, dynamic> json) =>
      _$ProfileGroupFromJson(json);
}

/// Outbound / DNS / route rule targets.
@freezed
class RoutingRule with _$RoutingRule {
  const factory RoutingRule({
    @Default([]) List<String> domains,
    @Default([]) List<String> ip,
    @Default([]) List<String> port,
    @Default([]) List<String> source,
    @Default([]) List<String> sourcePort,
    @Default('') String outbound,
    @Default('') String protocol,
    @Default('') String inbound,
    @Default('') String network,
    String? domainMatcher,
  }) = _RoutingRule;

  factory RoutingRule.fromJson(Map<String, dynamic> json) =>
      _$RoutingRuleFromJson(json);
}
