//
//  Generated code. Do not modify.
//  source: libcore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'libcore.pbenum.dart';

export 'libcore.pbenum.dart';

class EmptyReq extends $pb.GeneratedMessage {
  factory EmptyReq() => create();
  EmptyReq._() : super();
  factory EmptyReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EmptyReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EmptyReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EmptyReq clone() => EmptyReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EmptyReq copyWith(void Function(EmptyReq) updates) => super.copyWith((message) => updates(message as EmptyReq)) as EmptyReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EmptyReq create() => EmptyReq._();
  EmptyReq createEmptyInstance() => create();
  static $pb.PbList<EmptyReq> createRepeated() => $pb.PbList<EmptyReq>();
  @$core.pragma('dart2js:noInline')
  static EmptyReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EmptyReq>(create);
  static EmptyReq? _defaultInstance;
}

class EmptyResp extends $pb.GeneratedMessage {
  factory EmptyResp() => create();
  EmptyResp._() : super();
  factory EmptyResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EmptyResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EmptyResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EmptyResp clone() => EmptyResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EmptyResp copyWith(void Function(EmptyResp) updates) => super.copyWith((message) => updates(message as EmptyResp)) as EmptyResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EmptyResp create() => EmptyResp._();
  EmptyResp createEmptyInstance() => create();
  static $pb.PbList<EmptyResp> createRepeated() => $pb.PbList<EmptyResp>();
  @$core.pragma('dart2js:noInline')
  static EmptyResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EmptyResp>(create);
  static EmptyResp? _defaultInstance;
}

class ErrorResp extends $pb.GeneratedMessage {
  factory ErrorResp({
    $core.String? error,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  ErrorResp._() : super();
  factory ErrorResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ErrorResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ErrorResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ErrorResp clone() => ErrorResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ErrorResp copyWith(void Function(ErrorResp) updates) => super.copyWith((message) => updates(message as ErrorResp)) as ErrorResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ErrorResp create() => ErrorResp._();
  ErrorResp createEmptyInstance() => create();
  static $pb.PbList<ErrorResp> createRepeated() => $pb.PbList<ErrorResp>();
  @$core.pragma('dart2js:noInline')
  static ErrorResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ErrorResp>(create);
  static ErrorResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => clearField(1);
}

class LoadConfigReq extends $pb.GeneratedMessage {
  factory LoadConfigReq({
    $core.String? coreConfig,
    $core.bool? enableNekorayConnections,
    $core.Iterable<$core.String>? statsOutbounds,
  }) {
    final $result = create();
    if (coreConfig != null) {
      $result.coreConfig = coreConfig;
    }
    if (enableNekorayConnections != null) {
      $result.enableNekorayConnections = enableNekorayConnections;
    }
    if (statsOutbounds != null) {
      $result.statsOutbounds.addAll(statsOutbounds);
    }
    return $result;
  }
  LoadConfigReq._() : super();
  factory LoadConfigReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoadConfigReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoadConfigReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'coreConfig')
    ..aOB(2, _omitFieldNames ? '' : 'enableNekorayConnections')
    ..pPS(3, _omitFieldNames ? '' : 'statsOutbounds')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoadConfigReq clone() => LoadConfigReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoadConfigReq copyWith(void Function(LoadConfigReq) updates) => super.copyWith((message) => updates(message as LoadConfigReq)) as LoadConfigReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadConfigReq create() => LoadConfigReq._();
  LoadConfigReq createEmptyInstance() => create();
  static $pb.PbList<LoadConfigReq> createRepeated() => $pb.PbList<LoadConfigReq>();
  @$core.pragma('dart2js:noInline')
  static LoadConfigReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoadConfigReq>(create);
  static LoadConfigReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get coreConfig => $_getSZ(0);
  @$pb.TagNumber(1)
  set coreConfig($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCoreConfig() => $_has(0);
  @$pb.TagNumber(1)
  void clearCoreConfig() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get enableNekorayConnections => $_getBF(1);
  @$pb.TagNumber(2)
  set enableNekorayConnections($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEnableNekorayConnections() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnableNekorayConnections() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get statsOutbounds => $_getList(2);
}

class TestReq extends $pb.GeneratedMessage {
  factory TestReq({
    TestMode? mode,
    $core.String? address,
    LoadConfigReq? config,
    $core.String? inbound,
    $core.String? url,
    $core.int? timeout,
    $core.String? inAddress,
    $core.bool? fullLatency,
    $core.bool? fullSpeed,
    $core.bool? fullInOut,
  @$core.Deprecated('This field is deprecated.')
    $core.bool? fullNat,
    $core.bool? fullUdpLatency,
    $core.String? fullSpeedUrl,
    $core.int? fullSpeedTimeout,
  }) {
    final $result = create();
    if (mode != null) {
      $result.mode = mode;
    }
    if (address != null) {
      $result.address = address;
    }
    if (config != null) {
      $result.config = config;
    }
    if (inbound != null) {
      $result.inbound = inbound;
    }
    if (url != null) {
      $result.url = url;
    }
    if (timeout != null) {
      $result.timeout = timeout;
    }
    if (inAddress != null) {
      $result.inAddress = inAddress;
    }
    if (fullLatency != null) {
      $result.fullLatency = fullLatency;
    }
    if (fullSpeed != null) {
      $result.fullSpeed = fullSpeed;
    }
    if (fullInOut != null) {
      $result.fullInOut = fullInOut;
    }
    if (fullNat != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.fullNat = fullNat;
    }
    if (fullUdpLatency != null) {
      $result.fullUdpLatency = fullUdpLatency;
    }
    if (fullSpeedUrl != null) {
      $result.fullSpeedUrl = fullSpeedUrl;
    }
    if (fullSpeedTimeout != null) {
      $result.fullSpeedTimeout = fullSpeedTimeout;
    }
    return $result;
  }
  TestReq._() : super();
  factory TestReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TestReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TestReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..e<TestMode>(1, _omitFieldNames ? '' : 'mode', $pb.PbFieldType.OE, defaultOrMaker: TestMode.TcpPing, valueOf: TestMode.valueOf, enumValues: TestMode.values)
    ..aOS(2, _omitFieldNames ? '' : 'address')
    ..aOM<LoadConfigReq>(3, _omitFieldNames ? '' : 'config', subBuilder: LoadConfigReq.create)
    ..aOS(4, _omitFieldNames ? '' : 'inbound')
    ..aOS(5, _omitFieldNames ? '' : 'url')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'timeout', $pb.PbFieldType.O3)
    ..aOS(7, _omitFieldNames ? '' : 'inAddress')
    ..aOB(8, _omitFieldNames ? '' : 'fullLatency')
    ..aOB(9, _omitFieldNames ? '' : 'fullSpeed')
    ..aOB(10, _omitFieldNames ? '' : 'fullInOut')
    ..aOB(11, _omitFieldNames ? '' : 'fullNat')
    ..aOB(12, _omitFieldNames ? '' : 'fullUdpLatency')
    ..aOS(13, _omitFieldNames ? '' : 'fullSpeedUrl')
    ..a<$core.int>(14, _omitFieldNames ? '' : 'fullSpeedTimeout', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TestReq clone() => TestReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TestReq copyWith(void Function(TestReq) updates) => super.copyWith((message) => updates(message as TestReq)) as TestReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TestReq create() => TestReq._();
  TestReq createEmptyInstance() => create();
  static $pb.PbList<TestReq> createRepeated() => $pb.PbList<TestReq>();
  @$core.pragma('dart2js:noInline')
  static TestReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestReq>(create);
  static TestReq? _defaultInstance;

  @$pb.TagNumber(1)
  TestMode get mode => $_getN(0);
  @$pb.TagNumber(1)
  set mode(TestMode v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => clearField(1);

  /// TcpPing
  @$pb.TagNumber(2)
  $core.String get address => $_getSZ(1);
  @$pb.TagNumber(2)
  set address($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddress() => clearField(2);

  /// UrlTest
  @$pb.TagNumber(3)
  LoadConfigReq get config => $_getN(2);
  @$pb.TagNumber(3)
  set config(LoadConfigReq v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasConfig() => $_has(2);
  @$pb.TagNumber(3)
  void clearConfig() => clearField(3);
  @$pb.TagNumber(3)
  LoadConfigReq ensureConfig() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get inbound => $_getSZ(3);
  @$pb.TagNumber(4)
  set inbound($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasInbound() => $_has(3);
  @$pb.TagNumber(4)
  void clearInbound() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get url => $_getSZ(4);
  @$pb.TagNumber(5)
  set url($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearUrl() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get timeout => $_getIZ(5);
  @$pb.TagNumber(6)
  set timeout($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTimeout() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimeout() => clearField(6);

  /// FullTest
  @$pb.TagNumber(7)
  $core.String get inAddress => $_getSZ(6);
  @$pb.TagNumber(7)
  set inAddress($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasInAddress() => $_has(6);
  @$pb.TagNumber(7)
  void clearInAddress() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get fullLatency => $_getBF(7);
  @$pb.TagNumber(8)
  set fullLatency($core.bool v) { $_setBool(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasFullLatency() => $_has(7);
  @$pb.TagNumber(8)
  void clearFullLatency() => clearField(8);

  @$pb.TagNumber(9)
  $core.bool get fullSpeed => $_getBF(8);
  @$pb.TagNumber(9)
  set fullSpeed($core.bool v) { $_setBool(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasFullSpeed() => $_has(8);
  @$pb.TagNumber(9)
  void clearFullSpeed() => clearField(9);

  @$pb.TagNumber(10)
  $core.bool get fullInOut => $_getBF(9);
  @$pb.TagNumber(10)
  set fullInOut($core.bool v) { $_setBool(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasFullInOut() => $_has(9);
  @$pb.TagNumber(10)
  void clearFullInOut() => clearField(10);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  $core.bool get fullNat => $_getBF(10);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  set fullNat($core.bool v) { $_setBool(10, v); }
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  $core.bool hasFullNat() => $_has(10);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  void clearFullNat() => clearField(11);

  @$pb.TagNumber(12)
  $core.bool get fullUdpLatency => $_getBF(11);
  @$pb.TagNumber(12)
  set fullUdpLatency($core.bool v) { $_setBool(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasFullUdpLatency() => $_has(11);
  @$pb.TagNumber(12)
  void clearFullUdpLatency() => clearField(12);

  @$pb.TagNumber(13)
  $core.String get fullSpeedUrl => $_getSZ(12);
  @$pb.TagNumber(13)
  set fullSpeedUrl($core.String v) { $_setString(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasFullSpeedUrl() => $_has(12);
  @$pb.TagNumber(13)
  void clearFullSpeedUrl() => clearField(13);

  @$pb.TagNumber(14)
  $core.int get fullSpeedTimeout => $_getIZ(13);
  @$pb.TagNumber(14)
  set fullSpeedTimeout($core.int v) { $_setSignedInt32(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasFullSpeedTimeout() => $_has(13);
  @$pb.TagNumber(14)
  void clearFullSpeedTimeout() => clearField(14);
}

class TestResp extends $pb.GeneratedMessage {
  factory TestResp({
    $core.String? error,
    $core.int? ms,
    $core.String? fullReport,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    if (ms != null) {
      $result.ms = ms;
    }
    if (fullReport != null) {
      $result.fullReport = fullReport;
    }
    return $result;
  }
  TestResp._() : super();
  factory TestResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TestResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TestResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'ms', $pb.PbFieldType.O3)
    ..aOS(3, _omitFieldNames ? '' : 'fullReport')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TestResp clone() => TestResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TestResp copyWith(void Function(TestResp) updates) => super.copyWith((message) => updates(message as TestResp)) as TestResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TestResp create() => TestResp._();
  TestResp createEmptyInstance() => create();
  static $pb.PbList<TestResp> createRepeated() => $pb.PbList<TestResp>();
  @$core.pragma('dart2js:noInline')
  static TestResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestResp>(create);
  static TestResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get ms => $_getIZ(1);
  @$pb.TagNumber(2)
  set ms($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearMs() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get fullReport => $_getSZ(2);
  @$pb.TagNumber(3)
  set fullReport($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFullReport() => $_has(2);
  @$pb.TagNumber(3)
  void clearFullReport() => clearField(3);
}

class QueryStatsReq extends $pb.GeneratedMessage {
  factory QueryStatsReq({
    $core.String? tag,
    $core.String? direct,
  }) {
    final $result = create();
    if (tag != null) {
      $result.tag = tag;
    }
    if (direct != null) {
      $result.direct = direct;
    }
    return $result;
  }
  QueryStatsReq._() : super();
  factory QueryStatsReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QueryStatsReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QueryStatsReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'tag')
    ..aOS(2, _omitFieldNames ? '' : 'direct')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QueryStatsReq clone() => QueryStatsReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QueryStatsReq copyWith(void Function(QueryStatsReq) updates) => super.copyWith((message) => updates(message as QueryStatsReq)) as QueryStatsReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueryStatsReq create() => QueryStatsReq._();
  QueryStatsReq createEmptyInstance() => create();
  static $pb.PbList<QueryStatsReq> createRepeated() => $pb.PbList<QueryStatsReq>();
  @$core.pragma('dart2js:noInline')
  static QueryStatsReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueryStatsReq>(create);
  static QueryStatsReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tag => $_getSZ(0);
  @$pb.TagNumber(1)
  set tag($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTag() => $_has(0);
  @$pb.TagNumber(1)
  void clearTag() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get direct => $_getSZ(1);
  @$pb.TagNumber(2)
  set direct($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDirect() => $_has(1);
  @$pb.TagNumber(2)
  void clearDirect() => clearField(2);
}

class QueryStatsResp extends $pb.GeneratedMessage {
  factory QueryStatsResp({
    $fixnum.Int64? traffic,
  }) {
    final $result = create();
    if (traffic != null) {
      $result.traffic = traffic;
    }
    return $result;
  }
  QueryStatsResp._() : super();
  factory QueryStatsResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QueryStatsResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QueryStatsResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'traffic')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QueryStatsResp clone() => QueryStatsResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QueryStatsResp copyWith(void Function(QueryStatsResp) updates) => super.copyWith((message) => updates(message as QueryStatsResp)) as QueryStatsResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueryStatsResp create() => QueryStatsResp._();
  QueryStatsResp createEmptyInstance() => create();
  static $pb.PbList<QueryStatsResp> createRepeated() => $pb.PbList<QueryStatsResp>();
  @$core.pragma('dart2js:noInline')
  static QueryStatsResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueryStatsResp>(create);
  static QueryStatsResp? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get traffic => $_getI64(0);
  @$pb.TagNumber(1)
  set traffic($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTraffic() => $_has(0);
  @$pb.TagNumber(1)
  void clearTraffic() => clearField(1);
}

class UpdateReq extends $pb.GeneratedMessage {
  factory UpdateReq({
    UpdateAction? action,
    $core.bool? checkPreRelease,
  }) {
    final $result = create();
    if (action != null) {
      $result.action = action;
    }
    if (checkPreRelease != null) {
      $result.checkPreRelease = checkPreRelease;
    }
    return $result;
  }
  UpdateReq._() : super();
  factory UpdateReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..e<UpdateAction>(1, _omitFieldNames ? '' : 'action', $pb.PbFieldType.OE, defaultOrMaker: UpdateAction.Check, valueOf: UpdateAction.valueOf, enumValues: UpdateAction.values)
    ..aOB(2, _omitFieldNames ? '' : 'checkPreRelease')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateReq clone() => UpdateReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateReq copyWith(void Function(UpdateReq) updates) => super.copyWith((message) => updates(message as UpdateReq)) as UpdateReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateReq create() => UpdateReq._();
  UpdateReq createEmptyInstance() => create();
  static $pb.PbList<UpdateReq> createRepeated() => $pb.PbList<UpdateReq>();
  @$core.pragma('dart2js:noInline')
  static UpdateReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateReq>(create);
  static UpdateReq? _defaultInstance;

  @$pb.TagNumber(1)
  UpdateAction get action => $_getN(0);
  @$pb.TagNumber(1)
  set action(UpdateAction v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasAction() => $_has(0);
  @$pb.TagNumber(1)
  void clearAction() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get checkPreRelease => $_getBF(1);
  @$pb.TagNumber(2)
  set checkPreRelease($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCheckPreRelease() => $_has(1);
  @$pb.TagNumber(2)
  void clearCheckPreRelease() => clearField(2);
}

class UpdateResp extends $pb.GeneratedMessage {
  factory UpdateResp({
    $core.String? error,
    $core.String? assetsName,
    $core.String? downloadUrl,
    $core.String? releaseUrl,
    $core.String? releaseNote,
    $core.bool? isPreRelease,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    if (assetsName != null) {
      $result.assetsName = assetsName;
    }
    if (downloadUrl != null) {
      $result.downloadUrl = downloadUrl;
    }
    if (releaseUrl != null) {
      $result.releaseUrl = releaseUrl;
    }
    if (releaseNote != null) {
      $result.releaseNote = releaseNote;
    }
    if (isPreRelease != null) {
      $result.isPreRelease = isPreRelease;
    }
    return $result;
  }
  UpdateResp._() : super();
  factory UpdateResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..aOS(2, _omitFieldNames ? '' : 'assetsName')
    ..aOS(3, _omitFieldNames ? '' : 'downloadUrl')
    ..aOS(4, _omitFieldNames ? '' : 'releaseUrl')
    ..aOS(5, _omitFieldNames ? '' : 'releaseNote')
    ..aOB(6, _omitFieldNames ? '' : 'isPreRelease')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateResp clone() => UpdateResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateResp copyWith(void Function(UpdateResp) updates) => super.copyWith((message) => updates(message as UpdateResp)) as UpdateResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateResp create() => UpdateResp._();
  UpdateResp createEmptyInstance() => create();
  static $pb.PbList<UpdateResp> createRepeated() => $pb.PbList<UpdateResp>();
  @$core.pragma('dart2js:noInline')
  static UpdateResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateResp>(create);
  static UpdateResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get assetsName => $_getSZ(1);
  @$pb.TagNumber(2)
  set assetsName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAssetsName() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssetsName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get downloadUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set downloadUrl($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDownloadUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearDownloadUrl() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get releaseUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set releaseUrl($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasReleaseUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearReleaseUrl() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get releaseNote => $_getSZ(4);
  @$pb.TagNumber(5)
  set releaseNote($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasReleaseNote() => $_has(4);
  @$pb.TagNumber(5)
  void clearReleaseNote() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isPreRelease => $_getBF(5);
  @$pb.TagNumber(6)
  set isPreRelease($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsPreRelease() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsPreRelease() => clearField(6);
}

class ListConnectionsResp extends $pb.GeneratedMessage {
  factory ListConnectionsResp({
    $core.String? nekorayConnectionsJson,
  }) {
    final $result = create();
    if (nekorayConnectionsJson != null) {
      $result.nekorayConnectionsJson = nekorayConnectionsJson;
    }
    return $result;
  }
  ListConnectionsResp._() : super();
  factory ListConnectionsResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListConnectionsResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListConnectionsResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nekorayConnectionsJson')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListConnectionsResp clone() => ListConnectionsResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListConnectionsResp copyWith(void Function(ListConnectionsResp) updates) => super.copyWith((message) => updates(message as ListConnectionsResp)) as ListConnectionsResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListConnectionsResp create() => ListConnectionsResp._();
  ListConnectionsResp createEmptyInstance() => create();
  static $pb.PbList<ListConnectionsResp> createRepeated() => $pb.PbList<ListConnectionsResp>();
  @$core.pragma('dart2js:noInline')
  static ListConnectionsResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListConnectionsResp>(create);
  static ListConnectionsResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nekorayConnectionsJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set nekorayConnectionsJson($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNekorayConnectionsJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearNekorayConnectionsJson() => clearField(1);
}

class BuildConfigReq extends $pb.GeneratedMessage {
  factory BuildConfigReq({
    $core.List<$core.int>? profileJson,
    $core.List<$core.int>? groupJson,
    $core.List<$core.int>? routingJson,
    $core.List<$core.int>? datastoreJson,
    $core.bool? forTest,
    $core.bool? forExport,
  }) {
    final $result = create();
    if (profileJson != null) {
      $result.profileJson = profileJson;
    }
    if (groupJson != null) {
      $result.groupJson = groupJson;
    }
    if (routingJson != null) {
      $result.routingJson = routingJson;
    }
    if (datastoreJson != null) {
      $result.datastoreJson = datastoreJson;
    }
    if (forTest != null) {
      $result.forTest = forTest;
    }
    if (forExport != null) {
      $result.forExport = forExport;
    }
    return $result;
  }
  BuildConfigReq._() : super();
  factory BuildConfigReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BuildConfigReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BuildConfigReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'profileJson', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'groupJson', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'routingJson', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'datastoreJson', $pb.PbFieldType.OY)
    ..aOB(5, _omitFieldNames ? '' : 'forTest')
    ..aOB(6, _omitFieldNames ? '' : 'forExport')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BuildConfigReq clone() => BuildConfigReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BuildConfigReq copyWith(void Function(BuildConfigReq) updates) => super.copyWith((message) => updates(message as BuildConfigReq)) as BuildConfigReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BuildConfigReq create() => BuildConfigReq._();
  BuildConfigReq createEmptyInstance() => create();
  static $pb.PbList<BuildConfigReq> createRepeated() => $pb.PbList<BuildConfigReq>();
  @$core.pragma('dart2js:noInline')
  static BuildConfigReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BuildConfigReq>(create);
  static BuildConfigReq? _defaultInstance;

  /// Serialized NekoGui data (JSON), mirroring the C++ JsonStore layout.
  @$pb.TagNumber(1)
  $core.List<$core.int> get profileJson => $_getN(0);
  @$pb.TagNumber(1)
  set profileJson($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasProfileJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileJson() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get groupJson => $_getN(1);
  @$pb.TagNumber(2)
  set groupJson($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasGroupJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupJson() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get routingJson => $_getN(2);
  @$pb.TagNumber(3)
  set routingJson($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRoutingJson() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoutingJson() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get datastoreJson => $_getN(3);
  @$pb.TagNumber(4)
  set datastoreJson($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDatastoreJson() => $_has(3);
  @$pb.TagNumber(4)
  void clearDatastoreJson() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get forTest => $_getBF(4);
  @$pb.TagNumber(5)
  set forTest($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasForTest() => $_has(4);
  @$pb.TagNumber(5)
  void clearForTest() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get forExport => $_getBF(5);
  @$pb.TagNumber(6)
  set forExport($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasForExport() => $_has(5);
  @$pb.TagNumber(6)
  void clearForExport() => clearField(6);
}

class BuildConfigResp extends $pb.GeneratedMessage {
  factory BuildConfigResp({
    $core.String? error,
    $core.String? coreConfig,
    $core.List<$core.int>? extResults,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    if (coreConfig != null) {
      $result.coreConfig = coreConfig;
    }
    if (extResults != null) {
      $result.extResults = extResults;
    }
    return $result;
  }
  BuildConfigResp._() : super();
  factory BuildConfigResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BuildConfigResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BuildConfigResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..aOS(2, _omitFieldNames ? '' : 'coreConfig')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'extResults', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BuildConfigResp clone() => BuildConfigResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BuildConfigResp copyWith(void Function(BuildConfigResp) updates) => super.copyWith((message) => updates(message as BuildConfigResp)) as BuildConfigResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BuildConfigResp create() => BuildConfigResp._();
  BuildConfigResp createEmptyInstance() => create();
  static $pb.PbList<BuildConfigResp> createRepeated() => $pb.PbList<BuildConfigResp>();
  @$core.pragma('dart2js:noInline')
  static BuildConfigResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BuildConfigResp>(create);
  static BuildConfigResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get coreConfig => $_getSZ(1);
  @$pb.TagNumber(2)
  set coreConfig($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCoreConfig() => $_has(1);
  @$pb.TagNumber(2)
  void clearCoreConfig() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get extResults => $_getN(2);
  @$pb.TagNumber(3)
  set extResults($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasExtResults() => $_has(2);
  @$pb.TagNumber(3)
  void clearExtResults() => clearField(3);
}

class ParseSubReq extends $pb.GeneratedMessage {
  factory ParseSubReq({
    $core.String? content,
    $core.String? format,
  }) {
    final $result = create();
    if (content != null) {
      $result.content = content;
    }
    if (format != null) {
      $result.format = format;
    }
    return $result;
  }
  ParseSubReq._() : super();
  factory ParseSubReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ParseSubReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ParseSubReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..aOS(2, _omitFieldNames ? '' : 'format')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ParseSubReq clone() => ParseSubReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ParseSubReq copyWith(void Function(ParseSubReq) updates) => super.copyWith((message) => updates(message as ParseSubReq)) as ParseSubReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParseSubReq create() => ParseSubReq._();
  ParseSubReq createEmptyInstance() => create();
  static $pb.PbList<ParseSubReq> createRepeated() => $pb.PbList<ParseSubReq>();
  @$core.pragma('dart2js:noInline')
  static ParseSubReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseSubReq>(create);
  static ParseSubReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get format => $_getSZ(1);
  @$pb.TagNumber(2)
  set format($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => clearField(2);
}

class ParseSubResp extends $pb.GeneratedMessage {
  factory ParseSubResp({
    $core.String? error,
    $core.Iterable<$core.List<$core.int>>? profiles,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    if (profiles != null) {
      $result.profiles.addAll(profiles);
    }
    return $result;
  }
  ParseSubResp._() : super();
  factory ParseSubResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ParseSubResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ParseSubResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'profiles', $pb.PbFieldType.PY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ParseSubResp clone() => ParseSubResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ParseSubResp copyWith(void Function(ParseSubResp) updates) => super.copyWith((message) => updates(message as ParseSubResp)) as ParseSubResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParseSubResp create() => ParseSubResp._();
  ParseSubResp createEmptyInstance() => create();
  static $pb.PbList<ParseSubResp> createRepeated() => $pb.PbList<ParseSubResp>();
  @$core.pragma('dart2js:noInline')
  static ParseSubResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseSubResp>(create);
  static ParseSubResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get profiles => $_getList(1);
}

class ShareLinkReq extends $pb.GeneratedMessage {
  factory ShareLinkReq({
    $core.List<$core.int>? profileJson,
    $core.String? format,
  }) {
    final $result = create();
    if (profileJson != null) {
      $result.profileJson = profileJson;
    }
    if (format != null) {
      $result.format = format;
    }
    return $result;
  }
  ShareLinkReq._() : super();
  factory ShareLinkReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShareLinkReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShareLinkReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'profileJson', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'format')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShareLinkReq clone() => ShareLinkReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShareLinkReq copyWith(void Function(ShareLinkReq) updates) => super.copyWith((message) => updates(message as ShareLinkReq)) as ShareLinkReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShareLinkReq create() => ShareLinkReq._();
  ShareLinkReq createEmptyInstance() => create();
  static $pb.PbList<ShareLinkReq> createRepeated() => $pb.PbList<ShareLinkReq>();
  @$core.pragma('dart2js:noInline')
  static ShareLinkReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareLinkReq>(create);
  static ShareLinkReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get profileJson => $_getN(0);
  @$pb.TagNumber(1)
  set profileJson($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasProfileJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileJson() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get format => $_getSZ(1);
  @$pb.TagNumber(2)
  set format($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => clearField(2);
}

class ShareLinkResp extends $pb.GeneratedMessage {
  factory ShareLinkResp({
    $core.String? error,
    $core.String? link,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    if (link != null) {
      $result.link = link;
    }
    return $result;
  }
  ShareLinkResp._() : super();
  factory ShareLinkResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShareLinkResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShareLinkResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..aOS(2, _omitFieldNames ? '' : 'link')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShareLinkResp clone() => ShareLinkResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShareLinkResp copyWith(void Function(ShareLinkResp) updates) => super.copyWith((message) => updates(message as ShareLinkResp)) as ShareLinkResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShareLinkResp create() => ShareLinkResp._();
  ShareLinkResp createEmptyInstance() => create();
  static $pb.PbList<ShareLinkResp> createRepeated() => $pb.PbList<ShareLinkResp>();
  @$core.pragma('dart2js:noInline')
  static ShareLinkResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareLinkResp>(create);
  static ShareLinkResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get link => $_getSZ(1);
  @$pb.TagNumber(2)
  set link($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLink() => $_has(1);
  @$pb.TagNumber(2)
  void clearLink() => clearField(2);
}

class UpdateRuleSetReq extends $pb.GeneratedMessage {
  factory UpdateRuleSetReq({
    $core.String? url,
    $core.String? tag,
    $core.String? format,
    $core.bool? download,
  }) {
    final $result = create();
    if (url != null) {
      $result.url = url;
    }
    if (tag != null) {
      $result.tag = tag;
    }
    if (format != null) {
      $result.format = format;
    }
    if (download != null) {
      $result.download = download;
    }
    return $result;
  }
  UpdateRuleSetReq._() : super();
  factory UpdateRuleSetReq.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateRuleSetReq.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateRuleSetReq', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'tag')
    ..aOS(3, _omitFieldNames ? '' : 'format')
    ..aOB(4, _omitFieldNames ? '' : 'download')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateRuleSetReq clone() => UpdateRuleSetReq()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateRuleSetReq copyWith(void Function(UpdateRuleSetReq) updates) => super.copyWith((message) => updates(message as UpdateRuleSetReq)) as UpdateRuleSetReq;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateRuleSetReq create() => UpdateRuleSetReq._();
  UpdateRuleSetReq createEmptyInstance() => create();
  static $pb.PbList<UpdateRuleSetReq> createRepeated() => $pb.PbList<UpdateRuleSetReq>();
  @$core.pragma('dart2js:noInline')
  static UpdateRuleSetReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateRuleSetReq>(create);
  static UpdateRuleSetReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get tag => $_getSZ(1);
  @$pb.TagNumber(2)
  set tag($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTag() => $_has(1);
  @$pb.TagNumber(2)
  void clearTag() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get format => $_getSZ(2);
  @$pb.TagNumber(3)
  set format($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormat() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get download => $_getBF(3);
  @$pb.TagNumber(4)
  set download($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDownload() => $_has(3);
  @$pb.TagNumber(4)
  void clearDownload() => clearField(4);
}

class RuleSetInfo extends $pb.GeneratedMessage {
  factory RuleSetInfo({
    $core.String? tag,
    $core.String? type,
    $core.String? format,
    $core.String? url,
    $fixnum.Int64? updatedAt,
    $fixnum.Int64? size,
  }) {
    final $result = create();
    if (tag != null) {
      $result.tag = tag;
    }
    if (type != null) {
      $result.type = type;
    }
    if (format != null) {
      $result.format = format;
    }
    if (url != null) {
      $result.url = url;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    if (size != null) {
      $result.size = size;
    }
    return $result;
  }
  RuleSetInfo._() : super();
  factory RuleSetInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RuleSetInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RuleSetInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'tag')
    ..aOS(2, _omitFieldNames ? '' : 'type')
    ..aOS(3, _omitFieldNames ? '' : 'format')
    ..aOS(4, _omitFieldNames ? '' : 'url')
    ..aInt64(5, _omitFieldNames ? '' : 'updatedAt')
    ..aInt64(6, _omitFieldNames ? '' : 'size')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RuleSetInfo clone() => RuleSetInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RuleSetInfo copyWith(void Function(RuleSetInfo) updates) => super.copyWith((message) => updates(message as RuleSetInfo)) as RuleSetInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RuleSetInfo create() => RuleSetInfo._();
  RuleSetInfo createEmptyInstance() => create();
  static $pb.PbList<RuleSetInfo> createRepeated() => $pb.PbList<RuleSetInfo>();
  @$core.pragma('dart2js:noInline')
  static RuleSetInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RuleSetInfo>(create);
  static RuleSetInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tag => $_getSZ(0);
  @$pb.TagNumber(1)
  set tag($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTag() => $_has(0);
  @$pb.TagNumber(1)
  void clearTag() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get format => $_getSZ(2);
  @$pb.TagNumber(3)
  set format($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormat() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get url => $_getSZ(3);
  @$pb.TagNumber(4)
  set url($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearUrl() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get updatedAt => $_getI64(4);
  @$pb.TagNumber(5)
  set updatedAt($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasUpdatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearUpdatedAt() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get size => $_getI64(5);
  @$pb.TagNumber(6)
  set size($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearSize() => clearField(6);
}

class ListRuleSetsResp extends $pb.GeneratedMessage {
  factory ListRuleSetsResp({
    $core.Iterable<RuleSetInfo>? ruleSets,
  }) {
    final $result = create();
    if (ruleSets != null) {
      $result.ruleSets.addAll(ruleSets);
    }
    return $result;
  }
  ListRuleSetsResp._() : super();
  factory ListRuleSetsResp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListRuleSetsResp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListRuleSetsResp', package: const $pb.PackageName(_omitMessageNames ? '' : 'libcore'), createEmptyInstance: create)
    ..pc<RuleSetInfo>(1, _omitFieldNames ? '' : 'ruleSets', $pb.PbFieldType.PM, subBuilder: RuleSetInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListRuleSetsResp clone() => ListRuleSetsResp()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListRuleSetsResp copyWith(void Function(ListRuleSetsResp) updates) => super.copyWith((message) => updates(message as ListRuleSetsResp)) as ListRuleSetsResp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListRuleSetsResp create() => ListRuleSetsResp._();
  ListRuleSetsResp createEmptyInstance() => create();
  static $pb.PbList<ListRuleSetsResp> createRepeated() => $pb.PbList<ListRuleSetsResp>();
  @$core.pragma('dart2js:noInline')
  static ListRuleSetsResp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListRuleSetsResp>(create);
  static ListRuleSetsResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<RuleSetInfo> get ruleSets => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
