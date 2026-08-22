//
//  Generated code. Do not modify.
//  source: libcore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'libcore.pb.dart' as $0;

export 'libcore.pb.dart';

@$pb.GrpcServiceName('libcore.LibcoreService')
class LibcoreServiceClient extends $grpc.Client {
  static final _$exit = $grpc.ClientMethod<$0.EmptyReq, $0.EmptyResp>(
      '/libcore.LibcoreService/Exit',
      ($0.EmptyReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.EmptyResp.fromBuffer(value));
  static final _$update = $grpc.ClientMethod<$0.UpdateReq, $0.UpdateResp>(
      '/libcore.LibcoreService/Update',
      ($0.UpdateReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UpdateResp.fromBuffer(value));
  static final _$start = $grpc.ClientMethod<$0.LoadConfigReq, $0.ErrorResp>(
      '/libcore.LibcoreService/Start',
      ($0.LoadConfigReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ErrorResp.fromBuffer(value));
  static final _$stop = $grpc.ClientMethod<$0.EmptyReq, $0.ErrorResp>(
      '/libcore.LibcoreService/Stop',
      ($0.EmptyReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ErrorResp.fromBuffer(value));
  static final _$test = $grpc.ClientMethod<$0.TestReq, $0.TestResp>(
      '/libcore.LibcoreService/Test',
      ($0.TestReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TestResp.fromBuffer(value));
  static final _$queryStats = $grpc.ClientMethod<$0.QueryStatsReq, $0.QueryStatsResp>(
      '/libcore.LibcoreService/QueryStats',
      ($0.QueryStatsReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.QueryStatsResp.fromBuffer(value));
  static final _$listConnections = $grpc.ClientMethod<$0.EmptyReq, $0.ListConnectionsResp>(
      '/libcore.LibcoreService/ListConnections',
      ($0.EmptyReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListConnectionsResp.fromBuffer(value));
  static final _$buildConfig = $grpc.ClientMethod<$0.BuildConfigReq, $0.BuildConfigResp>(
      '/libcore.LibcoreService/BuildConfig',
      ($0.BuildConfigReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.BuildConfigResp.fromBuffer(value));
  static final _$parseSubscription = $grpc.ClientMethod<$0.ParseSubReq, $0.ParseSubResp>(
      '/libcore.LibcoreService/ParseSubscription',
      ($0.ParseSubReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ParseSubResp.fromBuffer(value));
  static final _$generateShareLink = $grpc.ClientMethod<$0.ShareLinkReq, $0.ShareLinkResp>(
      '/libcore.LibcoreService/GenerateShareLink',
      ($0.ShareLinkReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ShareLinkResp.fromBuffer(value));
  static final _$updateRuleSet = $grpc.ClientMethod<$0.UpdateRuleSetReq, $0.ErrorResp>(
      '/libcore.LibcoreService/UpdateRuleSet',
      ($0.UpdateRuleSetReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ErrorResp.fromBuffer(value));
  static final _$listRuleSets = $grpc.ClientMethod<$0.EmptyReq, $0.ListRuleSetsResp>(
      '/libcore.LibcoreService/ListRuleSets',
      ($0.EmptyReq value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListRuleSetsResp.fromBuffer(value));

  LibcoreServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.EmptyResp> exit($0.EmptyReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$exit, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateResp> update($0.UpdateReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$update, request, options: options);
  }

  $grpc.ResponseFuture<$0.ErrorResp> start($0.LoadConfigReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$start, request, options: options);
  }

  $grpc.ResponseFuture<$0.ErrorResp> stop($0.EmptyReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$stop, request, options: options);
  }

  $grpc.ResponseFuture<$0.TestResp> test($0.TestReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$test, request, options: options);
  }

  $grpc.ResponseFuture<$0.QueryStatsResp> queryStats($0.QueryStatsReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$queryStats, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListConnectionsResp> listConnections($0.EmptyReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listConnections, request, options: options);
  }

  $grpc.ResponseFuture<$0.BuildConfigResp> buildConfig($0.BuildConfigReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$buildConfig, request, options: options);
  }

  $grpc.ResponseFuture<$0.ParseSubResp> parseSubscription($0.ParseSubReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$parseSubscription, request, options: options);
  }

  $grpc.ResponseFuture<$0.ShareLinkResp> generateShareLink($0.ShareLinkReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$generateShareLink, request, options: options);
  }

  $grpc.ResponseFuture<$0.ErrorResp> updateRuleSet($0.UpdateRuleSetReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateRuleSet, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListRuleSetsResp> listRuleSets($0.EmptyReq request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listRuleSets, request, options: options);
  }
}

@$pb.GrpcServiceName('libcore.LibcoreService')
abstract class LibcoreServiceBase extends $grpc.Service {
  $core.String get $name => 'libcore.LibcoreService';

  LibcoreServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.EmptyReq, $0.EmptyResp>(
        'Exit',
        exit_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EmptyReq.fromBuffer(value),
        ($0.EmptyResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateReq, $0.UpdateResp>(
        'Update',
        update_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateReq.fromBuffer(value),
        ($0.UpdateResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LoadConfigReq, $0.ErrorResp>(
        'Start',
        start_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LoadConfigReq.fromBuffer(value),
        ($0.ErrorResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EmptyReq, $0.ErrorResp>(
        'Stop',
        stop_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EmptyReq.fromBuffer(value),
        ($0.ErrorResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TestReq, $0.TestResp>(
        'Test',
        test_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TestReq.fromBuffer(value),
        ($0.TestResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.QueryStatsReq, $0.QueryStatsResp>(
        'QueryStats',
        queryStats_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.QueryStatsReq.fromBuffer(value),
        ($0.QueryStatsResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EmptyReq, $0.ListConnectionsResp>(
        'ListConnections',
        listConnections_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EmptyReq.fromBuffer(value),
        ($0.ListConnectionsResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BuildConfigReq, $0.BuildConfigResp>(
        'BuildConfig',
        buildConfig_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BuildConfigReq.fromBuffer(value),
        ($0.BuildConfigResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ParseSubReq, $0.ParseSubResp>(
        'ParseSubscription',
        parseSubscription_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ParseSubReq.fromBuffer(value),
        ($0.ParseSubResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ShareLinkReq, $0.ShareLinkResp>(
        'GenerateShareLink',
        generateShareLink_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ShareLinkReq.fromBuffer(value),
        ($0.ShareLinkResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateRuleSetReq, $0.ErrorResp>(
        'UpdateRuleSet',
        updateRuleSet_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateRuleSetReq.fromBuffer(value),
        ($0.ErrorResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EmptyReq, $0.ListRuleSetsResp>(
        'ListRuleSets',
        listRuleSets_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EmptyReq.fromBuffer(value),
        ($0.ListRuleSetsResp value) => value.writeToBuffer()));
  }

  $async.Future<$0.EmptyResp> exit_Pre($grpc.ServiceCall call, $async.Future<$0.EmptyReq> request) async {
    return exit(call, await request);
  }

  $async.Future<$0.UpdateResp> update_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateReq> request) async {
    return update(call, await request);
  }

  $async.Future<$0.ErrorResp> start_Pre($grpc.ServiceCall call, $async.Future<$0.LoadConfigReq> request) async {
    return start(call, await request);
  }

  $async.Future<$0.ErrorResp> stop_Pre($grpc.ServiceCall call, $async.Future<$0.EmptyReq> request) async {
    return stop(call, await request);
  }

  $async.Future<$0.TestResp> test_Pre($grpc.ServiceCall call, $async.Future<$0.TestReq> request) async {
    return test(call, await request);
  }

  $async.Future<$0.QueryStatsResp> queryStats_Pre($grpc.ServiceCall call, $async.Future<$0.QueryStatsReq> request) async {
    return queryStats(call, await request);
  }

  $async.Future<$0.ListConnectionsResp> listConnections_Pre($grpc.ServiceCall call, $async.Future<$0.EmptyReq> request) async {
    return listConnections(call, await request);
  }

  $async.Future<$0.BuildConfigResp> buildConfig_Pre($grpc.ServiceCall call, $async.Future<$0.BuildConfigReq> request) async {
    return buildConfig(call, await request);
  }

  $async.Future<$0.ParseSubResp> parseSubscription_Pre($grpc.ServiceCall call, $async.Future<$0.ParseSubReq> request) async {
    return parseSubscription(call, await request);
  }

  $async.Future<$0.ShareLinkResp> generateShareLink_Pre($grpc.ServiceCall call, $async.Future<$0.ShareLinkReq> request) async {
    return generateShareLink(call, await request);
  }

  $async.Future<$0.ErrorResp> updateRuleSet_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateRuleSetReq> request) async {
    return updateRuleSet(call, await request);
  }

  $async.Future<$0.ListRuleSetsResp> listRuleSets_Pre($grpc.ServiceCall call, $async.Future<$0.EmptyReq> request) async {
    return listRuleSets(call, await request);
  }

  $async.Future<$0.EmptyResp> exit($grpc.ServiceCall call, $0.EmptyReq request);
  $async.Future<$0.UpdateResp> update($grpc.ServiceCall call, $0.UpdateReq request);
  $async.Future<$0.ErrorResp> start($grpc.ServiceCall call, $0.LoadConfigReq request);
  $async.Future<$0.ErrorResp> stop($grpc.ServiceCall call, $0.EmptyReq request);
  $async.Future<$0.TestResp> test($grpc.ServiceCall call, $0.TestReq request);
  $async.Future<$0.QueryStatsResp> queryStats($grpc.ServiceCall call, $0.QueryStatsReq request);
  $async.Future<$0.ListConnectionsResp> listConnections($grpc.ServiceCall call, $0.EmptyReq request);
  $async.Future<$0.BuildConfigResp> buildConfig($grpc.ServiceCall call, $0.BuildConfigReq request);
  $async.Future<$0.ParseSubResp> parseSubscription($grpc.ServiceCall call, $0.ParseSubReq request);
  $async.Future<$0.ShareLinkResp> generateShareLink($grpc.ServiceCall call, $0.ShareLinkReq request);
  $async.Future<$0.ErrorResp> updateRuleSet($grpc.ServiceCall call, $0.UpdateRuleSetReq request);
  $async.Future<$0.ListRuleSetsResp> listRuleSets($grpc.ServiceCall call, $0.EmptyReq request);
}
