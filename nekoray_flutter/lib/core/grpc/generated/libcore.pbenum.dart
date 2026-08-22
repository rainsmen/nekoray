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

import 'package:protobuf/protobuf.dart' as $pb;

class TestMode extends $pb.ProtobufEnum {
  static const TestMode TcpPing = TestMode._(0, _omitEnumNames ? '' : 'TcpPing');
  static const TestMode UrlTest = TestMode._(1, _omitEnumNames ? '' : 'UrlTest');
  static const TestMode FullTest = TestMode._(2, _omitEnumNames ? '' : 'FullTest');

  static const $core.List<TestMode> values = <TestMode> [
    TcpPing,
    UrlTest,
    FullTest,
  ];

  static final $core.Map<$core.int, TestMode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static TestMode? valueOf($core.int value) => _byValue[value];

  const TestMode._($core.int v, $core.String n) : super(v, n);
}

class UpdateAction extends $pb.ProtobufEnum {
  static const UpdateAction Check = UpdateAction._(0, _omitEnumNames ? '' : 'Check');
  static const UpdateAction Download = UpdateAction._(1, _omitEnumNames ? '' : 'Download');

  static const $core.List<UpdateAction> values = <UpdateAction> [
    Check,
    Download,
  ];

  static final $core.Map<$core.int, UpdateAction> _byValue = $pb.ProtobufEnum.initByValue(values);
  static UpdateAction? valueOf($core.int value) => _byValue[value];

  const UpdateAction._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
