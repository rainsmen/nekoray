//
//  Generated code. Do not modify.
//  source: libcore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use testModeDescriptor instead')
const TestMode$json = {
  '1': 'TestMode',
  '2': [
    {'1': 'TcpPing', '2': 0},
    {'1': 'UrlTest', '2': 1},
    {'1': 'FullTest', '2': 2},
  ],
};

/// Descriptor for `TestMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List testModeDescriptor = $convert.base64Decode(
    'CghUZXN0TW9kZRILCgdUY3BQaW5nEAASCwoHVXJsVGVzdBABEgwKCEZ1bGxUZXN0EAI=');

@$core.Deprecated('Use updateActionDescriptor instead')
const UpdateAction$json = {
  '1': 'UpdateAction',
  '2': [
    {'1': 'Check', '2': 0},
    {'1': 'Download', '2': 1},
  ],
};

/// Descriptor for `UpdateAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List updateActionDescriptor = $convert.base64Decode(
    'CgxVcGRhdGVBY3Rpb24SCQoFQ2hlY2sQABIMCghEb3dubG9hZBAB');

@$core.Deprecated('Use emptyReqDescriptor instead')
const EmptyReq$json = {
  '1': 'EmptyReq',
};

/// Descriptor for `EmptyReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyReqDescriptor = $convert.base64Decode(
    'CghFbXB0eVJlcQ==');

@$core.Deprecated('Use emptyRespDescriptor instead')
const EmptyResp$json = {
  '1': 'EmptyResp',
};

/// Descriptor for `EmptyResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyRespDescriptor = $convert.base64Decode(
    'CglFbXB0eVJlc3A=');

@$core.Deprecated('Use errorRespDescriptor instead')
const ErrorResp$json = {
  '1': 'ErrorResp',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ErrorResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorRespDescriptor = $convert.base64Decode(
    'CglFcnJvclJlc3ASFAoFZXJyb3IYASABKAlSBWVycm9y');

@$core.Deprecated('Use loadConfigReqDescriptor instead')
const LoadConfigReq$json = {
  '1': 'LoadConfigReq',
  '2': [
    {'1': 'core_config', '3': 1, '4': 1, '5': 9, '10': 'coreConfig'},
    {'1': 'enable_nekoray_connections', '3': 2, '4': 1, '5': 8, '10': 'enableNekorayConnections'},
    {'1': 'stats_outbounds', '3': 3, '4': 3, '5': 9, '10': 'statsOutbounds'},
  ],
};

/// Descriptor for `LoadConfigReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadConfigReqDescriptor = $convert.base64Decode(
    'Cg1Mb2FkQ29uZmlnUmVxEh8KC2NvcmVfY29uZmlnGAEgASgJUgpjb3JlQ29uZmlnEjwKGmVuYW'
    'JsZV9uZWtvcmF5X2Nvbm5lY3Rpb25zGAIgASgIUhhlbmFibGVOZWtvcmF5Q29ubmVjdGlvbnMS'
    'JwoPc3RhdHNfb3V0Ym91bmRzGAMgAygJUg5zdGF0c091dGJvdW5kcw==');

@$core.Deprecated('Use testReqDescriptor instead')
const TestReq$json = {
  '1': 'TestReq',
  '2': [
    {'1': 'mode', '3': 1, '4': 1, '5': 14, '6': '.libcore.TestMode', '10': 'mode'},
    {'1': 'timeout', '3': 6, '4': 1, '5': 5, '10': 'timeout'},
    {'1': 'address', '3': 2, '4': 1, '5': 9, '10': 'address'},
    {'1': 'config', '3': 3, '4': 1, '5': 11, '6': '.libcore.LoadConfigReq', '10': 'config'},
    {'1': 'inbound', '3': 4, '4': 1, '5': 9, '10': 'inbound'},
    {'1': 'url', '3': 5, '4': 1, '5': 9, '10': 'url'},
    {'1': 'in_address', '3': 7, '4': 1, '5': 9, '10': 'inAddress'},
    {'1': 'full_latency', '3': 8, '4': 1, '5': 8, '10': 'fullLatency'},
    {'1': 'full_speed', '3': 9, '4': 1, '5': 8, '10': 'fullSpeed'},
    {'1': 'full_speed_url', '3': 13, '4': 1, '5': 9, '10': 'fullSpeedUrl'},
    {'1': 'full_speed_timeout', '3': 14, '4': 1, '5': 5, '10': 'fullSpeedTimeout'},
    {'1': 'full_in_out', '3': 10, '4': 1, '5': 8, '10': 'fullInOut'},
    {'1': 'full_udp_latency', '3': 12, '4': 1, '5': 8, '10': 'fullUdpLatency'},
    {
      '1': 'full_nat',
      '3': 11,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'fullNat',
    },
  ],
};

/// Descriptor for `TestReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testReqDescriptor = $convert.base64Decode(
    'CgdUZXN0UmVxEiUKBG1vZGUYASABKA4yES5saWJjb3JlLlRlc3RNb2RlUgRtb2RlEhgKB3RpbW'
    'VvdXQYBiABKAVSB3RpbWVvdXQSGAoHYWRkcmVzcxgCIAEoCVIHYWRkcmVzcxIuCgZjb25maWcY'
    'AyABKAsyFi5saWJjb3JlLkxvYWRDb25maWdSZXFSBmNvbmZpZxIYCgdpbmJvdW5kGAQgASgJUg'
    'dpbmJvdW5kEhAKA3VybBgFIAEoCVIDdXJsEh0KCmluX2FkZHJlc3MYByABKAlSCWluQWRkcmVz'
    'cxIhCgxmdWxsX2xhdGVuY3kYCCABKAhSC2Z1bGxMYXRlbmN5Eh0KCmZ1bGxfc3BlZWQYCSABKA'
    'hSCWZ1bGxTcGVlZBIkCg5mdWxsX3NwZWVkX3VybBgNIAEoCVIMZnVsbFNwZWVkVXJsEiwKEmZ1'
    'bGxfc3BlZWRfdGltZW91dBgOIAEoBVIQZnVsbFNwZWVkVGltZW91dBIeCgtmdWxsX2luX291dB'
    'gKIAEoCFIJZnVsbEluT3V0EigKEGZ1bGxfdWRwX2xhdGVuY3kYDCABKAhSDmZ1bGxVZHBMYXRl'
    'bmN5Eh0KCGZ1bGxfbmF0GAsgASgIQgIYAVIHZnVsbE5hdA==');

@$core.Deprecated('Use testRespDescriptor instead')
const TestResp$json = {
  '1': 'TestResp',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 9, '10': 'error'},
    {'1': 'ms', '3': 2, '4': 1, '5': 5, '10': 'ms'},
    {'1': 'full_report', '3': 3, '4': 1, '5': 9, '10': 'fullReport'},
  ],
};

/// Descriptor for `TestResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testRespDescriptor = $convert.base64Decode(
    'CghUZXN0UmVzcBIUCgVlcnJvchgBIAEoCVIFZXJyb3ISDgoCbXMYAiABKAVSAm1zEh8KC2Z1bG'
    'xfcmVwb3J0GAMgASgJUgpmdWxsUmVwb3J0');

@$core.Deprecated('Use queryStatsReqDescriptor instead')
const QueryStatsReq$json = {
  '1': 'QueryStatsReq',
  '2': [
    {'1': 'tag', '3': 1, '4': 1, '5': 9, '10': 'tag'},
    {'1': 'direct', '3': 2, '4': 1, '5': 9, '10': 'direct'},
  ],
};

/// Descriptor for `QueryStatsReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queryStatsReqDescriptor = $convert.base64Decode(
    'Cg1RdWVyeVN0YXRzUmVxEhAKA3RhZxgBIAEoCVIDdGFnEhYKBmRpcmVjdBgCIAEoCVIGZGlyZW'
    'N0');

@$core.Deprecated('Use queryStatsRespDescriptor instead')
const QueryStatsResp$json = {
  '1': 'QueryStatsResp',
  '2': [
    {'1': 'traffic', '3': 1, '4': 1, '5': 3, '10': 'traffic'},
  ],
};

/// Descriptor for `QueryStatsResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queryStatsRespDescriptor = $convert.base64Decode(
    'Cg5RdWVyeVN0YXRzUmVzcBIYCgd0cmFmZmljGAEgASgDUgd0cmFmZmlj');

@$core.Deprecated('Use updateReqDescriptor instead')
const UpdateReq$json = {
  '1': 'UpdateReq',
  '2': [
    {'1': 'action', '3': 1, '4': 1, '5': 14, '6': '.libcore.UpdateAction', '10': 'action'},
    {'1': 'check_pre_release', '3': 2, '4': 1, '5': 8, '10': 'checkPreRelease'},
  ],
};

/// Descriptor for `UpdateReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateReqDescriptor = $convert.base64Decode(
    'CglVcGRhdGVSZXESLQoGYWN0aW9uGAEgASgOMhUubGliY29yZS5VcGRhdGVBY3Rpb25SBmFjdG'
    'lvbhIqChFjaGVja19wcmVfcmVsZWFzZRgCIAEoCFIPY2hlY2tQcmVSZWxlYXNl');

@$core.Deprecated('Use updateRespDescriptor instead')
const UpdateResp$json = {
  '1': 'UpdateResp',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 9, '10': 'error'},
    {'1': 'assets_name', '3': 2, '4': 1, '5': 9, '10': 'assetsName'},
    {'1': 'download_url', '3': 3, '4': 1, '5': 9, '10': 'downloadUrl'},
    {'1': 'release_url', '3': 4, '4': 1, '5': 9, '10': 'releaseUrl'},
    {'1': 'release_note', '3': 5, '4': 1, '5': 9, '10': 'releaseNote'},
    {'1': 'is_pre_release', '3': 6, '4': 1, '5': 8, '10': 'isPreRelease'},
  ],
};

/// Descriptor for `UpdateResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateRespDescriptor = $convert.base64Decode(
    'CgpVcGRhdGVSZXNwEhQKBWVycm9yGAEgASgJUgVlcnJvchIfCgthc3NldHNfbmFtZRgCIAEoCV'
    'IKYXNzZXRzTmFtZRIhCgxkb3dubG9hZF91cmwYAyABKAlSC2Rvd25sb2FkVXJsEh8KC3JlbGVh'
    'c2VfdXJsGAQgASgJUgpyZWxlYXNlVXJsEiEKDHJlbGVhc2Vfbm90ZRgFIAEoCVILcmVsZWFzZU'
    '5vdGUSJAoOaXNfcHJlX3JlbGVhc2UYBiABKAhSDGlzUHJlUmVsZWFzZQ==');

@$core.Deprecated('Use listConnectionsRespDescriptor instead')
const ListConnectionsResp$json = {
  '1': 'ListConnectionsResp',
  '2': [
    {'1': 'nekoray_connections_json', '3': 1, '4': 1, '5': 9, '10': 'nekorayConnectionsJson'},
  ],
};

/// Descriptor for `ListConnectionsResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listConnectionsRespDescriptor = $convert.base64Decode(
    'ChNMaXN0Q29ubmVjdGlvbnNSZXNwEjgKGG5la29yYXlfY29ubmVjdGlvbnNfanNvbhgBIAEoCV'
    'IWbmVrb3JheUNvbm5lY3Rpb25zSnNvbg==');

@$core.Deprecated('Use buildConfigReqDescriptor instead')
const BuildConfigReq$json = {
  '1': 'BuildConfigReq',
  '2': [
    {'1': 'profile_json', '3': 1, '4': 1, '5': 12, '10': 'profileJson'},
    {'1': 'group_json', '3': 2, '4': 1, '5': 12, '10': 'groupJson'},
    {'1': 'routing_json', '3': 3, '4': 1, '5': 12, '10': 'routingJson'},
    {'1': 'datastore_json', '3': 4, '4': 1, '5': 12, '10': 'datastoreJson'},
    {'1': 'for_test', '3': 5, '4': 1, '5': 8, '10': 'forTest'},
    {'1': 'for_export', '3': 6, '4': 1, '5': 8, '10': 'forExport'},
  ],
};

/// Descriptor for `BuildConfigReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buildConfigReqDescriptor = $convert.base64Decode(
    'Cg5CdWlsZENvbmZpZ1JlcRIhCgxwcm9maWxlX2pzb24YASABKAxSC3Byb2ZpbGVKc29uEh0KCm'
    'dyb3VwX2pzb24YAiABKAxSCWdyb3VwSnNvbhIhCgxyb3V0aW5nX2pzb24YAyABKAxSC3JvdXRp'
    'bmdKc29uEiUKDmRhdGFzdG9yZV9qc29uGAQgASgMUg1kYXRhc3RvcmVKc29uEhkKCGZvcl90ZX'
    'N0GAUgASgIUgdmb3JUZXN0Eh0KCmZvcl9leHBvcnQYBiABKAhSCWZvckV4cG9ydA==');

@$core.Deprecated('Use buildConfigRespDescriptor instead')
const BuildConfigResp$json = {
  '1': 'BuildConfigResp',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 9, '10': 'error'},
    {'1': 'core_config', '3': 2, '4': 1, '5': 9, '10': 'coreConfig'},
    {'1': 'ext_results', '3': 3, '4': 1, '5': 12, '10': 'extResults'},
  ],
};

/// Descriptor for `BuildConfigResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buildConfigRespDescriptor = $convert.base64Decode(
    'Cg9CdWlsZENvbmZpZ1Jlc3ASFAoFZXJyb3IYASABKAlSBWVycm9yEh8KC2NvcmVfY29uZmlnGA'
    'IgASgJUgpjb3JlQ29uZmlnEh8KC2V4dF9yZXN1bHRzGAMgASgMUgpleHRSZXN1bHRz');

@$core.Deprecated('Use parseSubReqDescriptor instead')
const ParseSubReq$json = {
  '1': 'ParseSubReq',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
  ],
};

/// Descriptor for `ParseSubReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseSubReqDescriptor = $convert.base64Decode(
    'CgtQYXJzZVN1YlJlcRIYCgdjb250ZW50GAEgASgJUgdjb250ZW50EhYKBmZvcm1hdBgCIAEoCV'
    'IGZm9ybWF0');

@$core.Deprecated('Use parseSubRespDescriptor instead')
const ParseSubResp$json = {
  '1': 'ParseSubResp',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 9, '10': 'error'},
    {'1': 'profiles', '3': 2, '4': 3, '5': 12, '10': 'profiles'},
  ],
};

/// Descriptor for `ParseSubResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseSubRespDescriptor = $convert.base64Decode(
    'CgxQYXJzZVN1YlJlc3ASFAoFZXJyb3IYASABKAlSBWVycm9yEhoKCHByb2ZpbGVzGAIgAygMUg'
    'hwcm9maWxlcw==');

@$core.Deprecated('Use shareLinkReqDescriptor instead')
const ShareLinkReq$json = {
  '1': 'ShareLinkReq',
  '2': [
    {'1': 'profile_json', '3': 1, '4': 1, '5': 12, '10': 'profileJson'},
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
  ],
};

/// Descriptor for `ShareLinkReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareLinkReqDescriptor = $convert.base64Decode(
    'CgxTaGFyZUxpbmtSZXESIQoMcHJvZmlsZV9qc29uGAEgASgMUgtwcm9maWxlSnNvbhIWCgZmb3'
    'JtYXQYAiABKAlSBmZvcm1hdA==');

@$core.Deprecated('Use shareLinkRespDescriptor instead')
const ShareLinkResp$json = {
  '1': 'ShareLinkResp',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 9, '10': 'error'},
    {'1': 'link', '3': 2, '4': 1, '5': 9, '10': 'link'},
  ],
};

/// Descriptor for `ShareLinkResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareLinkRespDescriptor = $convert.base64Decode(
    'Cg1TaGFyZUxpbmtSZXNwEhQKBWVycm9yGAEgASgJUgVlcnJvchISCgRsaW5rGAIgASgJUgRsaW'
    '5r');

@$core.Deprecated('Use updateRuleSetReqDescriptor instead')
const UpdateRuleSetReq$json = {
  '1': 'UpdateRuleSetReq',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'tag', '3': 2, '4': 1, '5': 9, '10': 'tag'},
    {'1': 'format', '3': 3, '4': 1, '5': 9, '10': 'format'},
    {'1': 'download', '3': 4, '4': 1, '5': 8, '10': 'download'},
  ],
};

/// Descriptor for `UpdateRuleSetReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateRuleSetReqDescriptor = $convert.base64Decode(
    'ChBVcGRhdGVSdWxlU2V0UmVxEhAKA3VybBgBIAEoCVIDdXJsEhAKA3RhZxgCIAEoCVIDdGFnEh'
    'YKBmZvcm1hdBgDIAEoCVIGZm9ybWF0EhoKCGRvd25sb2FkGAQgASgIUghkb3dubG9hZA==');

@$core.Deprecated('Use ruleSetInfoDescriptor instead')
const RuleSetInfo$json = {
  '1': 'RuleSetInfo',
  '2': [
    {'1': 'tag', '3': 1, '4': 1, '5': 9, '10': 'tag'},
    {'1': 'type', '3': 2, '4': 1, '5': 9, '10': 'type'},
    {'1': 'format', '3': 3, '4': 1, '5': 9, '10': 'format'},
    {'1': 'url', '3': 4, '4': 1, '5': 9, '10': 'url'},
    {'1': 'updated_at', '3': 5, '4': 1, '5': 3, '10': 'updatedAt'},
    {'1': 'size', '3': 6, '4': 1, '5': 3, '10': 'size'},
  ],
};

/// Descriptor for `RuleSetInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ruleSetInfoDescriptor = $convert.base64Decode(
    'CgtSdWxlU2V0SW5mbxIQCgN0YWcYASABKAlSA3RhZxISCgR0eXBlGAIgASgJUgR0eXBlEhYKBm'
    'Zvcm1hdBgDIAEoCVIGZm9ybWF0EhAKA3VybBgEIAEoCVIDdXJsEh0KCnVwZGF0ZWRfYXQYBSAB'
    'KANSCXVwZGF0ZWRBdBISCgRzaXplGAYgASgDUgRzaXpl');

@$core.Deprecated('Use listRuleSetsRespDescriptor instead')
const ListRuleSetsResp$json = {
  '1': 'ListRuleSetsResp',
  '2': [
    {'1': 'rule_sets', '3': 1, '4': 3, '5': 11, '6': '.libcore.RuleSetInfo', '10': 'ruleSets'},
  ],
};

/// Descriptor for `ListRuleSetsResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listRuleSetsRespDescriptor = $convert.base64Decode(
    'ChBMaXN0UnVsZVNldHNSZXNwEjEKCXJ1bGVfc2V0cxgBIAMoCzIULmxpYmNvcmUuUnVsZVNldE'
    'luZm9SCHJ1bGVTZXRz');

