// This is a generated file - do not edit.
//
// Generated from busydata.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'busydata.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'busydata.pbenum.dart';

/// Aggregate private diagnostics only: no SQL, credentials, row payloads or paths.
class RuntimeStatsReply extends $pb.GeneratedMessage {
  factory RuntimeStatsReply({
    $core.String? instanceId,
    $core.String? javaVersion,
    $fixnum.Int64? heapUsedBytes,
    $fixnum.Int64? heapCommittedBytes,
    $fixnum.Int64? directBufferBytes,
    $fixnum.Int64? mappedBufferBytes,
    $fixnum.Int64? retainedBytes,
    $fixnum.Int64? transferSnapshotBytes,
    $core.int? physicalSessions,
    $core.int? activeJobs,
    $core.Iterable<$core.String>? garbageCollectors,
  }) {
    final result = create();
    if (instanceId != null) result.instanceId = instanceId;
    if (javaVersion != null) result.javaVersion = javaVersion;
    if (heapUsedBytes != null) result.heapUsedBytes = heapUsedBytes;
    if (heapCommittedBytes != null)
      result.heapCommittedBytes = heapCommittedBytes;
    if (directBufferBytes != null) result.directBufferBytes = directBufferBytes;
    if (mappedBufferBytes != null) result.mappedBufferBytes = mappedBufferBytes;
    if (retainedBytes != null) result.retainedBytes = retainedBytes;
    if (transferSnapshotBytes != null)
      result.transferSnapshotBytes = transferSnapshotBytes;
    if (physicalSessions != null) result.physicalSessions = physicalSessions;
    if (activeJobs != null) result.activeJobs = activeJobs;
    if (garbageCollectors != null)
      result.garbageCollectors.addAll(garbageCollectors);
    return result;
  }

  RuntimeStatsReply._();

  factory RuntimeStatsReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RuntimeStatsReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RuntimeStatsReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'instanceId')
    ..aOS(2, _omitFieldNames ? '' : 'javaVersion')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'heapUsedBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'heapCommittedBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'directBufferBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'mappedBufferBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'retainedBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'transferSnapshotBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(9, _omitFieldNames ? '' : 'physicalSessions',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'activeJobs',
        fieldType: $pb.PbFieldType.OU3)
    ..pPS(11, _omitFieldNames ? '' : 'garbageCollectors')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RuntimeStatsReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RuntimeStatsReply copyWith(void Function(RuntimeStatsReply) updates) =>
      super.copyWith((message) => updates(message as RuntimeStatsReply))
          as RuntimeStatsReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RuntimeStatsReply create() => RuntimeStatsReply._();
  @$core.override
  RuntimeStatsReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RuntimeStatsReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RuntimeStatsReply>(create);
  static RuntimeStatsReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get instanceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set instanceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInstanceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInstanceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get javaVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set javaVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJavaVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearJavaVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get heapUsedBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set heapUsedBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeapUsedBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeapUsedBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get heapCommittedBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set heapCommittedBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHeapCommittedBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeapCommittedBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get directBufferBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set directBufferBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDirectBufferBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearDirectBufferBytes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get mappedBufferBytes => $_getI64(5);
  @$pb.TagNumber(6)
  set mappedBufferBytes($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMappedBufferBytes() => $_has(5);
  @$pb.TagNumber(6)
  void clearMappedBufferBytes() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get retainedBytes => $_getI64(6);
  @$pb.TagNumber(7)
  set retainedBytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRetainedBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearRetainedBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get transferSnapshotBytes => $_getI64(7);
  @$pb.TagNumber(8)
  set transferSnapshotBytes($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTransferSnapshotBytes() => $_has(7);
  @$pb.TagNumber(8)
  void clearTransferSnapshotBytes() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get physicalSessions => $_getIZ(8);
  @$pb.TagNumber(9)
  set physicalSessions($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPhysicalSessions() => $_has(8);
  @$pb.TagNumber(9)
  void clearPhysicalSessions() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get activeJobs => $_getIZ(9);
  @$pb.TagNumber(10)
  set activeJobs($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasActiveJobs() => $_has(9);
  @$pb.TagNumber(10)
  void clearActiveJobs() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get garbageCollectors => $_getList(10);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class Context extends $pb.GeneratedMessage {
  factory Context({
    $core.String? instanceId,
    $core.String? requestId,
    $core.int? protocolVersion,
  }) {
    final result = create();
    if (instanceId != null) result.instanceId = instanceId;
    if (requestId != null) result.requestId = requestId;
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    return result;
  }

  Context._();

  factory Context.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Context.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Context',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'instanceId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aI(3, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Context clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Context copyWith(void Function(Context) updates) =>
      super.copyWith((message) => updates(message as Context)) as Context;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Context create() => Context._();
  @$core.override
  Context createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Context getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Context>(create);
  static Context? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get instanceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set instanceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInstanceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInstanceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get protocolVersion => $_getIZ(2);
  @$pb.TagNumber(3)
  set protocolVersion($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProtocolVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearProtocolVersion() => $_clearField(3);
}

class BackendInfo extends $pb.GeneratedMessage {
  factory BackendInfo({
    $core.String? instanceId,
    $core.int? protocolVersion,
    $core.String? version,
  }) {
    final result = create();
    if (instanceId != null) result.instanceId = instanceId;
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (version != null) result.version = version;
    return result;
  }

  BackendInfo._();

  factory BackendInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackendInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackendInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'instanceId')
    ..aI(2, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackendInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackendInfo copyWith(void Function(BackendInfo) updates) =>
      super.copyWith((message) => updates(message as BackendInfo))
          as BackendInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackendInfo create() => BackendInfo._();
  @$core.override
  BackendInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BackendInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackendInfo>(create);
  static BackendInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get instanceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set instanceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInstanceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInstanceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get protocolVersion => $_getIZ(1);
  @$pb.TagNumber(2)
  set protocolVersion($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProtocolVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearProtocolVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get version => $_getSZ(2);
  @$pb.TagNumber(3)
  set version($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersion() => $_clearField(3);
}

class Tls extends $pb.GeneratedMessage {
  factory Tls({
    TlsMode? mode,
    $core.String? caFile,
    $core.String? clientCert,
    $core.String? clientKey,
    $core.bool? javaTrust,
    $core.bool? systemTrust,
    $core.String? keyCredentialRef,
    TlsMode? configuredMode,
  }) {
    final result = create();
    if (mode != null) result.mode = mode;
    if (caFile != null) result.caFile = caFile;
    if (clientCert != null) result.clientCert = clientCert;
    if (clientKey != null) result.clientKey = clientKey;
    if (javaTrust != null) result.javaTrust = javaTrust;
    if (systemTrust != null) result.systemTrust = systemTrust;
    if (keyCredentialRef != null) result.keyCredentialRef = keyCredentialRef;
    if (configuredMode != null) result.configuredMode = configuredMode;
    return result;
  }

  Tls._();

  factory Tls.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Tls.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Tls',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aE<TlsMode>(1, _omitFieldNames ? '' : 'mode', enumValues: TlsMode.values)
    ..aOS(2, _omitFieldNames ? '' : 'caFile')
    ..aOS(3, _omitFieldNames ? '' : 'clientCert')
    ..aOS(4, _omitFieldNames ? '' : 'clientKey')
    ..aOB(5, _omitFieldNames ? '' : 'javaTrust')
    ..aOB(6, _omitFieldNames ? '' : 'systemTrust')
    ..aOS(7, _omitFieldNames ? '' : 'keyCredentialRef')
    ..aE<TlsMode>(8, _omitFieldNames ? '' : 'configuredMode',
        enumValues: TlsMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tls clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tls copyWith(void Function(Tls) updates) =>
      super.copyWith((message) => updates(message as Tls)) as Tls;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Tls create() => Tls._();
  @$core.override
  Tls createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Tls getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Tls>(create);
  static Tls? _defaultInstance;

  @$pb.TagNumber(1)
  TlsMode get mode => $_getN(0);
  @$pb.TagNumber(1)
  set mode(TlsMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get caFile => $_getSZ(1);
  @$pb.TagNumber(2)
  set caFile($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCaFile() => $_has(1);
  @$pb.TagNumber(2)
  void clearCaFile() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get clientCert => $_getSZ(2);
  @$pb.TagNumber(3)
  set clientCert($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClientCert() => $_has(2);
  @$pb.TagNumber(3)
  void clearClientCert() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get clientKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set clientKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasClientKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearClientKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get javaTrust => $_getBF(4);
  @$pb.TagNumber(5)
  set javaTrust($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasJavaTrust() => $_has(4);
  @$pb.TagNumber(5)
  void clearJavaTrust() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get systemTrust => $_getBF(5);
  @$pb.TagNumber(6)
  set systemTrust($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSystemTrust() => $_has(5);
  @$pb.TagNumber(6)
  void clearSystemTrust() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get keyCredentialRef => $_getSZ(6);
  @$pb.TagNumber(7)
  set keyCredentialRef($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasKeyCredentialRef() => $_has(6);
  @$pb.TagNumber(7)
  void clearKeyCredentialRef() => $_clearField(7);

  @$pb.TagNumber(8)
  TlsMode get configuredMode => $_getN(7);
  @$pb.TagNumber(8)
  set configuredMode(TlsMode value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasConfiguredMode() => $_has(7);
  @$pb.TagNumber(8)
  void clearConfiguredMode() => $_clearField(8);
}

class Ssh extends $pb.GeneratedMessage {
  factory Ssh({
    $core.bool? enabled,
    $core.String? host,
    $core.int? port,
    $core.String? user,
    $core.String? knownHosts,
    $core.String? privateKey,
    $core.bool? agent,
    $core.String? agentSocket,
    $core.String? agentKeyFingerprint,
    $core.String? trustRef,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (user != null) result.user = user;
    if (knownHosts != null) result.knownHosts = knownHosts;
    if (privateKey != null) result.privateKey = privateKey;
    if (agent != null) result.agent = agent;
    if (agentSocket != null) result.agentSocket = agentSocket;
    if (agentKeyFingerprint != null)
      result.agentKeyFingerprint = agentKeyFingerprint;
    if (trustRef != null) result.trustRef = trustRef;
    return result;
  }

  Ssh._();

  factory Ssh.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ssh.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ssh',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aOS(2, _omitFieldNames ? '' : 'host')
    ..aI(3, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'user')
    ..aOS(5, _omitFieldNames ? '' : 'knownHosts')
    ..aOS(6, _omitFieldNames ? '' : 'privateKey')
    ..aOB(7, _omitFieldNames ? '' : 'agent')
    ..aOS(8, _omitFieldNames ? '' : 'agentSocket')
    ..aOS(9, _omitFieldNames ? '' : 'agentKeyFingerprint')
    ..aOS(10, _omitFieldNames ? '' : 'trustRef')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ssh clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ssh copyWith(void Function(Ssh) updates) =>
      super.copyWith((message) => updates(message as Ssh)) as Ssh;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ssh create() => Ssh._();
  @$core.override
  Ssh createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ssh getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ssh>(create);
  static Ssh? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get host => $_getSZ(1);
  @$pb.TagNumber(2)
  set host($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHost() => $_has(1);
  @$pb.TagNumber(2)
  void clearHost() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get port => $_getIZ(2);
  @$pb.TagNumber(3)
  set port($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPort() => $_has(2);
  @$pb.TagNumber(3)
  void clearPort() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get user => $_getSZ(3);
  @$pb.TagNumber(4)
  set user($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUser() => $_has(3);
  @$pb.TagNumber(4)
  void clearUser() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get knownHosts => $_getSZ(4);
  @$pb.TagNumber(5)
  set knownHosts($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKnownHosts() => $_has(4);
  @$pb.TagNumber(5)
  void clearKnownHosts() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get privateKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set privateKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPrivateKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearPrivateKey() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get agent => $_getBF(6);
  @$pb.TagNumber(7)
  set agent($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAgent() => $_has(6);
  @$pb.TagNumber(7)
  void clearAgent() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get agentSocket => $_getSZ(7);
  @$pb.TagNumber(8)
  set agentSocket($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAgentSocket() => $_has(7);
  @$pb.TagNumber(8)
  void clearAgentSocket() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get agentKeyFingerprint => $_getSZ(8);
  @$pb.TagNumber(9)
  set agentKeyFingerprint($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAgentKeyFingerprint() => $_has(8);
  @$pb.TagNumber(9)
  void clearAgentKeyFingerprint() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get trustRef => $_getSZ(9);
  @$pb.TagNumber(10)
  set trustRef($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTrustRef() => $_has(9);
  @$pb.TagNumber(10)
  void clearTrustRef() => $_clearField(10);
}

/// SSH authentication only. No database endpoint, credentials, TLS or JDBC session.
/// The backend applies its bounded SSH probe budget; profile_id scopes host trust.
class SshTestRequest extends $pb.GeneratedMessage {
  factory SshTestRequest({
    Context? context,
    $core.String? profileId,
    Ssh? ssh,
    $core.String? sshPassword,
    $core.String? keyPassphrase,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (profileId != null) result.profileId = profileId;
    if (ssh != null) result.ssh = ssh;
    if (sshPassword != null) result.sshPassword = sshPassword;
    if (keyPassphrase != null) result.keyPassphrase = keyPassphrase;
    return result;
  }

  SshTestRequest._();

  factory SshTestRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SshTestRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SshTestRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'profileId')
    ..aOM<Ssh>(3, _omitFieldNames ? '' : 'ssh', subBuilder: Ssh.create)
    ..aOS(4, _omitFieldNames ? '' : 'sshPassword')
    ..aOS(5, _omitFieldNames ? '' : 'keyPassphrase')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTestRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTestRequest copyWith(void Function(SshTestRequest) updates) =>
      super.copyWith((message) => updates(message as SshTestRequest))
          as SshTestRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SshTestRequest create() => SshTestRequest._();
  @$core.override
  SshTestRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SshTestRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SshTestRequest>(create);
  static SshTestRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get profileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set profileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProfileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfileId() => $_clearField(2);

  @$pb.TagNumber(3)
  Ssh get ssh => $_getN(2);
  @$pb.TagNumber(3)
  set ssh(Ssh value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSsh() => $_has(2);
  @$pb.TagNumber(3)
  void clearSsh() => $_clearField(3);
  @$pb.TagNumber(3)
  Ssh ensureSsh() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get sshPassword => $_getSZ(3);
  @$pb.TagNumber(4)
  set sshPassword($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSshPassword() => $_has(3);
  @$pb.TagNumber(4)
  void clearSshPassword() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get keyPassphrase => $_getSZ(4);
  @$pb.TagNumber(5)
  set keyPassphrase($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKeyPassphrase() => $_has(4);
  @$pb.TagNumber(5)
  void clearKeyPassphrase() => $_clearField(5);
}

class SshTestReply extends $pb.GeneratedMessage {
  factory SshTestReply({
    $core.String? host,
    $core.int? port,
    $core.String? user,
    $core.String? algorithm,
    $core.String? fingerprint,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (user != null) result.user = user;
    if (algorithm != null) result.algorithm = algorithm;
    if (fingerprint != null) result.fingerprint = fingerprint;
    return result;
  }

  SshTestReply._();

  factory SshTestReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SshTestReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SshTestReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'user')
    ..aOS(4, _omitFieldNames ? '' : 'algorithm')
    ..aOS(5, _omitFieldNames ? '' : 'fingerprint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTestReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTestReply copyWith(void Function(SshTestReply) updates) =>
      super.copyWith((message) => updates(message as SshTestReply))
          as SshTestReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SshTestReply create() => SshTestReply._();
  @$core.override
  SshTestReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SshTestReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SshTestReply>(create);
  static SshTestReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get user => $_getSZ(2);
  @$pb.TagNumber(3)
  set user($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearUser() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get algorithm => $_getSZ(3);
  @$pb.TagNumber(4)
  set algorithm($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAlgorithm() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlgorithm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fingerprint => $_getSZ(4);
  @$pb.TagNumber(5)
  set fingerprint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFingerprint() => $_has(4);
  @$pb.TagNumber(5)
  void clearFingerprint() => $_clearField(5);
}

class SshTrustRequest extends $pb.GeneratedMessage {
  factory SshTrustRequest({
    Context? context,
    Profile? profile,
    $core.String? approvalToken,
    $core.String? algorithm,
    $core.String? fingerprint,
    $core.bool? replaceChangedKey,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (profile != null) result.profile = profile;
    if (approvalToken != null) result.approvalToken = approvalToken;
    if (algorithm != null) result.algorithm = algorithm;
    if (fingerprint != null) result.fingerprint = fingerprint;
    if (replaceChangedKey != null) result.replaceChangedKey = replaceChangedKey;
    return result;
  }

  SshTrustRequest._();

  factory SshTrustRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SshTrustRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SshTrustRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOM<Profile>(2, _omitFieldNames ? '' : 'profile',
        subBuilder: Profile.create)
    ..aOS(3, _omitFieldNames ? '' : 'approvalToken')
    ..aOS(4, _omitFieldNames ? '' : 'algorithm')
    ..aOS(5, _omitFieldNames ? '' : 'fingerprint')
    ..aOB(6, _omitFieldNames ? '' : 'replaceChangedKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTrustRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTrustRequest copyWith(void Function(SshTrustRequest) updates) =>
      super.copyWith((message) => updates(message as SshTrustRequest))
          as SshTrustRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SshTrustRequest create() => SshTrustRequest._();
  @$core.override
  SshTrustRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SshTrustRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SshTrustRequest>(create);
  static SshTrustRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  Profile get profile => $_getN(1);
  @$pb.TagNumber(2)
  set profile(Profile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfile() => $_clearField(2);
  @$pb.TagNumber(2)
  Profile ensureProfile() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get approvalToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set approvalToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasApprovalToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearApprovalToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get algorithm => $_getSZ(3);
  @$pb.TagNumber(4)
  set algorithm($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAlgorithm() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlgorithm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fingerprint => $_getSZ(4);
  @$pb.TagNumber(5)
  set fingerprint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFingerprint() => $_has(4);
  @$pb.TagNumber(5)
  void clearFingerprint() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get replaceChangedKey => $_getBF(5);
  @$pb.TagNumber(6)
  set replaceChangedKey($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReplaceChangedKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearReplaceChangedKey() => $_clearField(6);
}

class SshTrustReply extends $pb.GeneratedMessage {
  factory SshTrustReply({
    $core.String? host,
    $core.int? port,
    $core.String? algorithm,
    $core.String? fingerprint,
    $core.String? previousFingerprint,
    $core.bool? known,
    $core.bool? changed,
    $core.String? approvalToken,
    $core.String? trustRef,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (algorithm != null) result.algorithm = algorithm;
    if (fingerprint != null) result.fingerprint = fingerprint;
    if (previousFingerprint != null)
      result.previousFingerprint = previousFingerprint;
    if (known != null) result.known = known;
    if (changed != null) result.changed = changed;
    if (approvalToken != null) result.approvalToken = approvalToken;
    if (trustRef != null) result.trustRef = trustRef;
    return result;
  }

  SshTrustReply._();

  factory SshTrustReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SshTrustReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SshTrustReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'algorithm')
    ..aOS(4, _omitFieldNames ? '' : 'fingerprint')
    ..aOS(5, _omitFieldNames ? '' : 'previousFingerprint')
    ..aOB(6, _omitFieldNames ? '' : 'known')
    ..aOB(7, _omitFieldNames ? '' : 'changed')
    ..aOS(8, _omitFieldNames ? '' : 'approvalToken')
    ..aOS(9, _omitFieldNames ? '' : 'trustRef')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTrustReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SshTrustReply copyWith(void Function(SshTrustReply) updates) =>
      super.copyWith((message) => updates(message as SshTrustReply))
          as SshTrustReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SshTrustReply create() => SshTrustReply._();
  @$core.override
  SshTrustReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SshTrustReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SshTrustReply>(create);
  static SshTrustReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get algorithm => $_getSZ(2);
  @$pb.TagNumber(3)
  set algorithm($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAlgorithm() => $_has(2);
  @$pb.TagNumber(3)
  void clearAlgorithm() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get fingerprint => $_getSZ(3);
  @$pb.TagNumber(4)
  set fingerprint($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFingerprint() => $_has(3);
  @$pb.TagNumber(4)
  void clearFingerprint() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get previousFingerprint => $_getSZ(4);
  @$pb.TagNumber(5)
  set previousFingerprint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPreviousFingerprint() => $_has(4);
  @$pb.TagNumber(5)
  void clearPreviousFingerprint() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get known => $_getBF(5);
  @$pb.TagNumber(6)
  set known($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasKnown() => $_has(5);
  @$pb.TagNumber(6)
  void clearKnown() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get changed => $_getBF(6);
  @$pb.TagNumber(7)
  set changed($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasChanged() => $_has(6);
  @$pb.TagNumber(7)
  void clearChanged() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get approvalToken => $_getSZ(7);
  @$pb.TagNumber(8)
  set approvalToken($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasApprovalToken() => $_has(7);
  @$pb.TagNumber(8)
  void clearApprovalToken() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get trustRef => $_getSZ(8);
  @$pb.TagNumber(9)
  set trustRef($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTrustRef() => $_has(8);
  @$pb.TagNumber(9)
  void clearTrustRef() => $_clearField(9);
}

class Profile extends $pb.GeneratedMessage {
  factory Profile({
    $core.String? id,
    $core.String? name,
    Engine? engine,
    $core.String? host,
    $core.int? port,
    $core.String? database,
    $core.String? user,
    Environment? environment,
    $core.bool? readOnly,
    $core.int? connectTimeoutSeconds,
    $core.int? queryTimeoutSeconds,
    Tls? tls,
    Ssh? ssh,
    $core.String? credentialRef,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? options,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (engine != null) result.engine = engine;
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (database != null) result.database = database;
    if (user != null) result.user = user;
    if (environment != null) result.environment = environment;
    if (readOnly != null) result.readOnly = readOnly;
    if (connectTimeoutSeconds != null)
      result.connectTimeoutSeconds = connectTimeoutSeconds;
    if (queryTimeoutSeconds != null)
      result.queryTimeoutSeconds = queryTimeoutSeconds;
    if (tls != null) result.tls = tls;
    if (ssh != null) result.ssh = ssh;
    if (credentialRef != null) result.credentialRef = credentialRef;
    if (options != null) result.options.addEntries(options);
    return result;
  }

  Profile._();

  factory Profile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Profile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Profile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<Engine>(3, _omitFieldNames ? '' : 'engine', enumValues: Engine.values)
    ..aOS(4, _omitFieldNames ? '' : 'host')
    ..aI(5, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'database')
    ..aOS(7, _omitFieldNames ? '' : 'user')
    ..aE<Environment>(8, _omitFieldNames ? '' : 'environment',
        enumValues: Environment.values)
    ..aOB(9, _omitFieldNames ? '' : 'readOnly')
    ..aI(10, _omitFieldNames ? '' : 'connectTimeoutSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(11, _omitFieldNames ? '' : 'queryTimeoutSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Tls>(12, _omitFieldNames ? '' : 'tls', subBuilder: Tls.create)
    ..aOM<Ssh>(13, _omitFieldNames ? '' : 'ssh', subBuilder: Ssh.create)
    ..aOS(14, _omitFieldNames ? '' : 'credentialRef')
    ..m<$core.String, $core.String>(15, _omitFieldNames ? '' : 'options',
        entryClassName: 'Profile.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('busydata.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Profile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Profile copyWith(void Function(Profile) updates) =>
      super.copyWith((message) => updates(message as Profile)) as Profile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Profile create() => Profile._();
  @$core.override
  Profile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Profile getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Profile>(create);
  static Profile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  Engine get engine => $_getN(2);
  @$pb.TagNumber(3)
  set engine(Engine value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasEngine() => $_has(2);
  @$pb.TagNumber(3)
  void clearEngine() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get host => $_getSZ(3);
  @$pb.TagNumber(4)
  set host($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHost() => $_has(3);
  @$pb.TagNumber(4)
  void clearHost() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get port => $_getIZ(4);
  @$pb.TagNumber(5)
  set port($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPort() => $_has(4);
  @$pb.TagNumber(5)
  void clearPort() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get database => $_getSZ(5);
  @$pb.TagNumber(6)
  set database($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDatabase() => $_has(5);
  @$pb.TagNumber(6)
  void clearDatabase() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get user => $_getSZ(6);
  @$pb.TagNumber(7)
  set user($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUser() => $_has(6);
  @$pb.TagNumber(7)
  void clearUser() => $_clearField(7);

  @$pb.TagNumber(8)
  Environment get environment => $_getN(7);
  @$pb.TagNumber(8)
  set environment(Environment value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasEnvironment() => $_has(7);
  @$pb.TagNumber(8)
  void clearEnvironment() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get readOnly => $_getBF(8);
  @$pb.TagNumber(9)
  set readOnly($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasReadOnly() => $_has(8);
  @$pb.TagNumber(9)
  void clearReadOnly() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get connectTimeoutSeconds => $_getIZ(9);
  @$pb.TagNumber(10)
  set connectTimeoutSeconds($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasConnectTimeoutSeconds() => $_has(9);
  @$pb.TagNumber(10)
  void clearConnectTimeoutSeconds() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get queryTimeoutSeconds => $_getIZ(10);
  @$pb.TagNumber(11)
  set queryTimeoutSeconds($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasQueryTimeoutSeconds() => $_has(10);
  @$pb.TagNumber(11)
  void clearQueryTimeoutSeconds() => $_clearField(11);

  @$pb.TagNumber(12)
  Tls get tls => $_getN(11);
  @$pb.TagNumber(12)
  set tls(Tls value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasTls() => $_has(11);
  @$pb.TagNumber(12)
  void clearTls() => $_clearField(12);
  @$pb.TagNumber(12)
  Tls ensureTls() => $_ensure(11);

  @$pb.TagNumber(13)
  Ssh get ssh => $_getN(12);
  @$pb.TagNumber(13)
  set ssh(Ssh value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasSsh() => $_has(12);
  @$pb.TagNumber(13)
  void clearSsh() => $_clearField(13);
  @$pb.TagNumber(13)
  Ssh ensureSsh() => $_ensure(12);

  @$pb.TagNumber(14)
  $core.String get credentialRef => $_getSZ(13);
  @$pb.TagNumber(14)
  set credentialRef($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCredentialRef() => $_has(13);
  @$pb.TagNumber(14)
  void clearCredentialRef() => $_clearField(14);

  @$pb.TagNumber(15)
  $pb.PbMap<$core.String, $core.String> get options => $_getMap(14);
}

class ProfileRequest extends $pb.GeneratedMessage {
  factory ProfileRequest({
    Context? context,
    ProfileAction? action,
    Profile? profile,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (action != null) result.action = action;
    if (profile != null) result.profile = profile;
    return result;
  }

  ProfileRequest._();

  factory ProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aE<ProfileAction>(2, _omitFieldNames ? '' : 'action',
        enumValues: ProfileAction.values)
    ..aOM<Profile>(3, _omitFieldNames ? '' : 'profile',
        subBuilder: Profile.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileRequest copyWith(void Function(ProfileRequest) updates) =>
      super.copyWith((message) => updates(message as ProfileRequest))
          as ProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileRequest create() => ProfileRequest._();
  @$core.override
  ProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProfileRequest>(create);
  static ProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  ProfileAction get action => $_getN(1);
  @$pb.TagNumber(2)
  set action(ProfileAction value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAction() => $_has(1);
  @$pb.TagNumber(2)
  void clearAction() => $_clearField(2);

  @$pb.TagNumber(3)
  Profile get profile => $_getN(2);
  @$pb.TagNumber(3)
  set profile(Profile value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasProfile() => $_has(2);
  @$pb.TagNumber(3)
  void clearProfile() => $_clearField(3);
  @$pb.TagNumber(3)
  Profile ensureProfile() => $_ensure(2);
}

class ProfileList extends $pb.GeneratedMessage {
  factory ProfileList({
    $core.Iterable<Profile>? profiles,
  }) {
    final result = create();
    if (profiles != null) result.profiles.addAll(profiles);
    return result;
  }

  ProfileList._();

  factory ProfileList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProfileList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProfileList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<Profile>(1, _omitFieldNames ? '' : 'profiles',
        subBuilder: Profile.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileList copyWith(void Function(ProfileList) updates) =>
      super.copyWith((message) => updates(message as ProfileList))
          as ProfileList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileList create() => ProfileList._();
  @$core.override
  ProfileList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProfileList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProfileList>(create);
  static ProfileList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Profile> get profiles => $_getList(0);
}

class OpenRequest extends $pb.GeneratedMessage {
  factory OpenRequest({
    Context? context,
    Profile? profile,
    $core.String? password,
    $core.String? sshPassword,
    $core.String? keyPassphrase,
    $core.String? catalog,
    $core.String? schema,
    $core.String? tlsKeyPassword,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (profile != null) result.profile = profile;
    if (password != null) result.password = password;
    if (sshPassword != null) result.sshPassword = sshPassword;
    if (keyPassphrase != null) result.keyPassphrase = keyPassphrase;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (tlsKeyPassword != null) result.tlsKeyPassword = tlsKeyPassword;
    return result;
  }

  OpenRequest._();

  factory OpenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OpenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOM<Profile>(2, _omitFieldNames ? '' : 'profile',
        subBuilder: Profile.create)
    ..aOS(3, _omitFieldNames ? '' : 'password')
    ..aOS(4, _omitFieldNames ? '' : 'sshPassword')
    ..aOS(5, _omitFieldNames ? '' : 'keyPassphrase')
    ..aOS(6, _omitFieldNames ? '' : 'catalog')
    ..aOS(7, _omitFieldNames ? '' : 'schema')
    ..aOS(8, _omitFieldNames ? '' : 'tlsKeyPassword')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenRequest copyWith(void Function(OpenRequest) updates) =>
      super.copyWith((message) => updates(message as OpenRequest))
          as OpenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OpenRequest create() => OpenRequest._();
  @$core.override
  OpenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OpenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenRequest>(create);
  static OpenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  Profile get profile => $_getN(1);
  @$pb.TagNumber(2)
  set profile(Profile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfile() => $_clearField(2);
  @$pb.TagNumber(2)
  Profile ensureProfile() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get password => $_getSZ(2);
  @$pb.TagNumber(3)
  set password($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearPassword() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sshPassword => $_getSZ(3);
  @$pb.TagNumber(4)
  set sshPassword($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSshPassword() => $_has(3);
  @$pb.TagNumber(4)
  void clearSshPassword() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get keyPassphrase => $_getSZ(4);
  @$pb.TagNumber(5)
  set keyPassphrase($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKeyPassphrase() => $_has(4);
  @$pb.TagNumber(5)
  void clearKeyPassphrase() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get catalog => $_getSZ(5);
  @$pb.TagNumber(6)
  set catalog($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCatalog() => $_has(5);
  @$pb.TagNumber(6)
  void clearCatalog() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get schema => $_getSZ(6);
  @$pb.TagNumber(7)
  set schema($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSchema() => $_has(6);
  @$pb.TagNumber(7)
  void clearSchema() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get tlsKeyPassword => $_getSZ(7);
  @$pb.TagNumber(8)
  set tlsKeyPassword($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTlsKeyPassword() => $_has(7);
  @$pb.TagNumber(8)
  void clearTlsKeyPassword() => $_clearField(8);
}

class ConnectionDescription extends $pb.GeneratedMessage {
  factory ConnectionDescription({
    $core.String? jdbcUrl,
    $core.String? initialDatabase,
    $core.String? driverClass,
    $core.String? driverVersion,
  }) {
    final result = create();
    if (jdbcUrl != null) result.jdbcUrl = jdbcUrl;
    if (initialDatabase != null) result.initialDatabase = initialDatabase;
    if (driverClass != null) result.driverClass = driverClass;
    if (driverVersion != null) result.driverVersion = driverVersion;
    return result;
  }

  ConnectionDescription._();

  factory ConnectionDescription.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionDescription.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionDescription',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'jdbcUrl')
    ..aOS(2, _omitFieldNames ? '' : 'initialDatabase')
    ..aOS(3, _omitFieldNames ? '' : 'driverClass')
    ..aOS(4, _omitFieldNames ? '' : 'driverVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionDescription clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionDescription copyWith(
          void Function(ConnectionDescription) updates) =>
      super.copyWith((message) => updates(message as ConnectionDescription))
          as ConnectionDescription;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionDescription create() => ConnectionDescription._();
  @$core.override
  ConnectionDescription createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionDescription getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionDescription>(create);
  static ConnectionDescription? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get jdbcUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set jdbcUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJdbcUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearJdbcUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get initialDatabase => $_getSZ(1);
  @$pb.TagNumber(2)
  set initialDatabase($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInitialDatabase() => $_has(1);
  @$pb.TagNumber(2)
  void clearInitialDatabase() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get driverClass => $_getSZ(2);
  @$pb.TagNumber(3)
  set driverClass($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDriverClass() => $_has(2);
  @$pb.TagNumber(3)
  void clearDriverClass() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get driverVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set driverVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDriverVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearDriverVersion() => $_clearField(4);
}

class ConnectionInfo extends $pb.GeneratedMessage {
  factory ConnectionInfo({
    $core.String? product,
    $core.String? version,
    $core.String? host,
    $core.int? port,
    $core.String? database,
    $core.String? schema,
    $core.String? tlsCipher,
    $core.bool? tlsObserved,
  }) {
    final result = create();
    if (product != null) result.product = product;
    if (version != null) result.version = version;
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (database != null) result.database = database;
    if (schema != null) result.schema = schema;
    if (tlsCipher != null) result.tlsCipher = tlsCipher;
    if (tlsObserved != null) result.tlsObserved = tlsObserved;
    return result;
  }

  ConnectionInfo._();

  factory ConnectionInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'product')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..aOS(4, _omitFieldNames ? '' : 'host')
    ..aI(5, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'database')
    ..aOS(7, _omitFieldNames ? '' : 'schema')
    ..aOS(8, _omitFieldNames ? '' : 'tlsCipher')
    ..aOB(9, _omitFieldNames ? '' : 'tlsObserved')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionInfo copyWith(void Function(ConnectionInfo) updates) =>
      super.copyWith((message) => updates(message as ConnectionInfo))
          as ConnectionInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionInfo create() => ConnectionInfo._();
  @$core.override
  ConnectionInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionInfo>(create);
  static ConnectionInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get product => $_getSZ(0);
  @$pb.TagNumber(1)
  set product($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProduct() => $_has(0);
  @$pb.TagNumber(1)
  void clearProduct() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(4)
  $core.String get host => $_getSZ(2);
  @$pb.TagNumber(4)
  set host($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasHost() => $_has(2);
  @$pb.TagNumber(4)
  void clearHost() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get port => $_getIZ(3);
  @$pb.TagNumber(5)
  set port($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasPort() => $_has(3);
  @$pb.TagNumber(5)
  void clearPort() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get database => $_getSZ(4);
  @$pb.TagNumber(6)
  set database($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasDatabase() => $_has(4);
  @$pb.TagNumber(6)
  void clearDatabase() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get schema => $_getSZ(5);
  @$pb.TagNumber(7)
  set schema($core.String value) => $_setString(5, value);
  @$pb.TagNumber(7)
  $core.bool hasSchema() => $_has(5);
  @$pb.TagNumber(7)
  void clearSchema() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get tlsCipher => $_getSZ(6);
  @$pb.TagNumber(8)
  set tlsCipher($core.String value) => $_setString(6, value);
  @$pb.TagNumber(8)
  $core.bool hasTlsCipher() => $_has(6);
  @$pb.TagNumber(8)
  void clearTlsCipher() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get tlsObserved => $_getBF(7);
  @$pb.TagNumber(9)
  set tlsObserved($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(9)
  $core.bool hasTlsObserved() => $_has(7);
  @$pb.TagNumber(9)
  void clearTlsObserved() => $_clearField(9);
}

class CapabilityRequest extends $pb.GeneratedMessage {
  factory CapabilityRequest({
    Context? context,
    $core.String? sessionId,
    $fixnum.Int64? contextRevision,
    $fixnum.Int64? sessionRevision,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    return result;
  }

  CapabilityRequest._();

  factory CapabilityRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CapabilityRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CapabilityRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityRequest copyWith(void Function(CapabilityRequest) updates) =>
      super.copyWith((message) => updates(message as CapabilityRequest))
          as CapabilityRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CapabilityRequest create() => CapabilityRequest._();
  @$core.override
  CapabilityRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CapabilityRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CapabilityRequest>(create);
  static CapabilityRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get contextRevision => $_getI64(2);
  @$pb.TagNumber(3)
  set contextRevision($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContextRevision() => $_has(2);
  @$pb.TagNumber(3)
  void clearContextRevision() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sessionRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionRevision() => $_clearField(4);
}

/// Availability is scoped to a fresh read probe or a documented engine feature,
/// never a grant or approval. Empty inspected data differs from denied access.
class Capability extends $pb.GeneratedMessage {
  factory Capability({
    $core.String? id,
    $core.String? label,
    CapabilityState? state,
    $core.String? detail,
    $core.bool? dataChecked,
    $core.bool? empty,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (state != null) result.state = state;
    if (detail != null) result.detail = detail;
    if (dataChecked != null) result.dataChecked = dataChecked;
    if (empty != null) result.empty = empty;
    return result;
  }

  Capability._();

  factory Capability.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Capability.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Capability',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aE<CapabilityState>(3, _omitFieldNames ? '' : 'state',
        enumValues: CapabilityState.values)
    ..aOS(4, _omitFieldNames ? '' : 'detail')
    ..aOB(5, _omitFieldNames ? '' : 'dataChecked')
    ..aOB(6, _omitFieldNames ? '' : 'empty')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Capability clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Capability copyWith(void Function(Capability) updates) =>
      super.copyWith((message) => updates(message as Capability)) as Capability;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Capability create() => Capability._();
  @$core.override
  Capability createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Capability getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Capability>(create);
  static Capability? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  CapabilityState get state => $_getN(2);
  @$pb.TagNumber(3)
  set state(CapabilityState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get detail => $_getSZ(3);
  @$pb.TagNumber(4)
  set detail($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDetail() => $_has(3);
  @$pb.TagNumber(4)
  void clearDetail() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get dataChecked => $_getBF(4);
  @$pb.TagNumber(5)
  set dataChecked($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDataChecked() => $_has(4);
  @$pb.TagNumber(5)
  void clearDataChecked() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get empty => $_getBF(5);
  @$pb.TagNumber(6)
  set empty($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEmpty() => $_has(5);
  @$pb.TagNumber(6)
  void clearEmpty() => $_clearField(6);
}

class CapabilityList extends $pb.GeneratedMessage {
  factory CapabilityList({
    $core.String? backendInstance,
    $core.String? sessionId,
    $fixnum.Int64? contextRevision,
    $fixnum.Int64? sessionRevision,
    $core.String? product,
    $core.String? version,
    $core.int? majorVersion,
    $core.int? minorVersion,
    $core.Iterable<Capability>? entries,
    $core.String? availability,
  }) {
    final result = create();
    if (backendInstance != null) result.backendInstance = backendInstance;
    if (sessionId != null) result.sessionId = sessionId;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (product != null) result.product = product;
    if (version != null) result.version = version;
    if (majorVersion != null) result.majorVersion = majorVersion;
    if (minorVersion != null) result.minorVersion = minorVersion;
    if (entries != null) result.entries.addAll(entries);
    if (availability != null) result.availability = availability;
    return result;
  }

  CapabilityList._();

  factory CapabilityList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CapabilityList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CapabilityList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'backendInstance')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(5, _omitFieldNames ? '' : 'product')
    ..aOS(6, _omitFieldNames ? '' : 'version')
    ..aI(7, _omitFieldNames ? '' : 'majorVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'minorVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<Capability>(9, _omitFieldNames ? '' : 'entries',
        subBuilder: Capability.create)
    ..aOS(10, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityList copyWith(void Function(CapabilityList) updates) =>
      super.copyWith((message) => updates(message as CapabilityList))
          as CapabilityList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CapabilityList create() => CapabilityList._();
  @$core.override
  CapabilityList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CapabilityList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CapabilityList>(create);
  static CapabilityList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backendInstance => $_getSZ(0);
  @$pb.TagNumber(1)
  set backendInstance($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackendInstance() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackendInstance() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get contextRevision => $_getI64(2);
  @$pb.TagNumber(3)
  set contextRevision($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContextRevision() => $_has(2);
  @$pb.TagNumber(3)
  void clearContextRevision() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sessionRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionRevision() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get product => $_getSZ(4);
  @$pb.TagNumber(5)
  set product($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasProduct() => $_has(4);
  @$pb.TagNumber(5)
  void clearProduct() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get version => $_getSZ(5);
  @$pb.TagNumber(6)
  set version($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearVersion() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get majorVersion => $_getIZ(6);
  @$pb.TagNumber(7)
  set majorVersion($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMajorVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearMajorVersion() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get minorVersion => $_getIZ(7);
  @$pb.TagNumber(8)
  set minorVersion($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMinorVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearMinorVersion() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<Capability> get entries => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get availability => $_getSZ(9);
  @$pb.TagNumber(10)
  set availability($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAvailability() => $_has(9);
  @$pb.TagNumber(10)
  void clearAvailability() => $_clearField(10);
}

class SessionRequest extends $pb.GeneratedMessage {
  factory SessionRequest({
    Context? context,
    $core.String? sessionId,
    SessionAction? action,
    $core.bool? force,
    $core.String? approvalToken,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (action != null) result.action = action;
    if (force != null) result.force = force;
    if (approvalToken != null) result.approvalToken = approvalToken;
    return result;
  }

  SessionRequest._();

  factory SessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aE<SessionAction>(3, _omitFieldNames ? '' : 'action',
        enumValues: SessionAction.values)
    ..aOB(4, _omitFieldNames ? '' : 'force')
    ..aOS(5, _omitFieldNames ? '' : 'approvalToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionRequest copyWith(void Function(SessionRequest) updates) =>
      super.copyWith((message) => updates(message as SessionRequest))
          as SessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionRequest create() => SessionRequest._();
  @$core.override
  SessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionRequest>(create);
  static SessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  SessionAction get action => $_getN(2);
  @$pb.TagNumber(3)
  set action(SessionAction value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAction() => $_has(2);
  @$pb.TagNumber(3)
  void clearAction() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get force => $_getBF(3);
  @$pb.TagNumber(4)
  set force($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasForce() => $_has(3);
  @$pb.TagNumber(4)
  void clearForce() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get approvalToken => $_getSZ(4);
  @$pb.TagNumber(5)
  set approvalToken($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasApprovalToken() => $_has(4);
  @$pb.TagNumber(5)
  void clearApprovalToken() => $_clearField(5);
}

class SessionInfo extends $pb.GeneratedMessage {
  factory SessionInfo({
    $core.String? sessionId,
    Profile? profile,
    $core.bool? autoCommit,
    TransactionState? transaction,
    ConnectionInfo? database,
    $fixnum.Int64? contextRevision,
    $core.String? currentCatalog,
    $core.String? currentSchema,
    $core.Iterable<$core.String>? searchPath,
    $core.String? sqlMode,
    $core.bool? standardConformingStrings,
    $core.bool? commandAcknowledged,
    $core.String? commandWarning,
    SessionAction? acknowledgedAction,
    $fixnum.Int64? sessionRevision,
    $core.String? metadataSourceIdentity,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (profile != null) result.profile = profile;
    if (autoCommit != null) result.autoCommit = autoCommit;
    if (transaction != null) result.transaction = transaction;
    if (database != null) result.database = database;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (currentCatalog != null) result.currentCatalog = currentCatalog;
    if (currentSchema != null) result.currentSchema = currentSchema;
    if (searchPath != null) result.searchPath.addAll(searchPath);
    if (sqlMode != null) result.sqlMode = sqlMode;
    if (standardConformingStrings != null)
      result.standardConformingStrings = standardConformingStrings;
    if (commandAcknowledged != null)
      result.commandAcknowledged = commandAcknowledged;
    if (commandWarning != null) result.commandWarning = commandWarning;
    if (acknowledgedAction != null)
      result.acknowledgedAction = acknowledgedAction;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (metadataSourceIdentity != null)
      result.metadataSourceIdentity = metadataSourceIdentity;
    return result;
  }

  SessionInfo._();

  factory SessionInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOM<Profile>(2, _omitFieldNames ? '' : 'profile',
        subBuilder: Profile.create)
    ..aOB(3, _omitFieldNames ? '' : 'autoCommit')
    ..aE<TransactionState>(4, _omitFieldNames ? '' : 'transaction',
        enumValues: TransactionState.values)
    ..aOM<ConnectionInfo>(5, _omitFieldNames ? '' : 'database',
        subBuilder: ConnectionInfo.create)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(7, _omitFieldNames ? '' : 'currentCatalog')
    ..aOS(8, _omitFieldNames ? '' : 'currentSchema')
    ..pPS(9, _omitFieldNames ? '' : 'searchPath')
    ..aOS(10, _omitFieldNames ? '' : 'sqlMode')
    ..aOB(11, _omitFieldNames ? '' : 'standardConformingStrings')
    ..aOB(12, _omitFieldNames ? '' : 'commandAcknowledged')
    ..aOS(13, _omitFieldNames ? '' : 'commandWarning')
    ..aE<SessionAction>(14, _omitFieldNames ? '' : 'acknowledgedAction',
        enumValues: SessionAction.values)
    ..a<$fixnum.Int64>(
        15, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(16, _omitFieldNames ? '' : 'metadataSourceIdentity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInfo copyWith(void Function(SessionInfo) updates) =>
      super.copyWith((message) => updates(message as SessionInfo))
          as SessionInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionInfo create() => SessionInfo._();
  @$core.override
  SessionInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionInfo>(create);
  static SessionInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  Profile get profile => $_getN(1);
  @$pb.TagNumber(2)
  set profile(Profile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfile() => $_clearField(2);
  @$pb.TagNumber(2)
  Profile ensureProfile() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.bool get autoCommit => $_getBF(2);
  @$pb.TagNumber(3)
  set autoCommit($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAutoCommit() => $_has(2);
  @$pb.TagNumber(3)
  void clearAutoCommit() => $_clearField(3);

  @$pb.TagNumber(4)
  TransactionState get transaction => $_getN(3);
  @$pb.TagNumber(4)
  set transaction(TransactionState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTransaction() => $_has(3);
  @$pb.TagNumber(4)
  void clearTransaction() => $_clearField(4);

  @$pb.TagNumber(5)
  ConnectionInfo get database => $_getN(4);
  @$pb.TagNumber(5)
  set database(ConnectionInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDatabase() => $_has(4);
  @$pb.TagNumber(5)
  void clearDatabase() => $_clearField(5);
  @$pb.TagNumber(5)
  ConnectionInfo ensureDatabase() => $_ensure(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get contextRevision => $_getI64(5);
  @$pb.TagNumber(6)
  set contextRevision($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasContextRevision() => $_has(5);
  @$pb.TagNumber(6)
  void clearContextRevision() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get currentCatalog => $_getSZ(6);
  @$pb.TagNumber(7)
  set currentCatalog($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCurrentCatalog() => $_has(6);
  @$pb.TagNumber(7)
  void clearCurrentCatalog() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get currentSchema => $_getSZ(7);
  @$pb.TagNumber(8)
  set currentSchema($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCurrentSchema() => $_has(7);
  @$pb.TagNumber(8)
  void clearCurrentSchema() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get searchPath => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get sqlMode => $_getSZ(9);
  @$pb.TagNumber(10)
  set sqlMode($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSqlMode() => $_has(9);
  @$pb.TagNumber(10)
  void clearSqlMode() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get standardConformingStrings => $_getBF(10);
  @$pb.TagNumber(11)
  set standardConformingStrings($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStandardConformingStrings() => $_has(10);
  @$pb.TagNumber(11)
  void clearStandardConformingStrings() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get commandAcknowledged => $_getBF(11);
  @$pb.TagNumber(12)
  set commandAcknowledged($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCommandAcknowledged() => $_has(11);
  @$pb.TagNumber(12)
  void clearCommandAcknowledged() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get commandWarning => $_getSZ(12);
  @$pb.TagNumber(13)
  set commandWarning($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCommandWarning() => $_has(12);
  @$pb.TagNumber(13)
  void clearCommandWarning() => $_clearField(13);

  @$pb.TagNumber(14)
  SessionAction get acknowledgedAction => $_getN(13);
  @$pb.TagNumber(14)
  set acknowledgedAction(SessionAction value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasAcknowledgedAction() => $_has(13);
  @$pb.TagNumber(14)
  void clearAcknowledgedAction() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get sessionRevision => $_getI64(14);
  @$pb.TagNumber(15)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasSessionRevision() => $_has(14);
  @$pb.TagNumber(15)
  void clearSessionRevision() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get metadataSourceIdentity => $_getSZ(15);
  @$pb.TagNumber(16)
  set metadataSourceIdentity($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasMetadataSourceIdentity() => $_has(15);
  @$pb.TagNumber(16)
  void clearMetadataSourceIdentity() => $_clearField(16);
}

class ExecuteRequest extends $pb.GeneratedMessage {
  factory ExecuteRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? executionId,
    $core.String? sql,
    $core.String? documentId,
    $fixnum.Int64? documentVersion,
    ExecutionMode? mode,
    $core.int? caretUtf16,
    ErrorPolicy? errorPolicy,
    $fixnum.Int64? rowLimit,
    $core.bool? streamingRead,
    $core.String? approvalToken,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (executionId != null) result.executionId = executionId;
    if (sql != null) result.sql = sql;
    if (documentId != null) result.documentId = documentId;
    if (documentVersion != null) result.documentVersion = documentVersion;
    if (mode != null) result.mode = mode;
    if (caretUtf16 != null) result.caretUtf16 = caretUtf16;
    if (errorPolicy != null) result.errorPolicy = errorPolicy;
    if (rowLimit != null) result.rowLimit = rowLimit;
    if (streamingRead != null) result.streamingRead = streamingRead;
    if (approvalToken != null) result.approvalToken = approvalToken;
    return result;
  }

  ExecuteRequest._();

  factory ExecuteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExecuteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExecuteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aOS(4, _omitFieldNames ? '' : 'sql')
    ..aOS(5, _omitFieldNames ? '' : 'documentId')
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'documentVersion', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<ExecutionMode>(7, _omitFieldNames ? '' : 'mode',
        enumValues: ExecutionMode.values)
    ..aI(8, _omitFieldNames ? '' : 'caretUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aE<ErrorPolicy>(9, _omitFieldNames ? '' : 'errorPolicy',
        enumValues: ErrorPolicy.values)
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'rowLimit', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(11, _omitFieldNames ? '' : 'streamingRead')
    ..aOS(12, _omitFieldNames ? '' : 'approvalToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecuteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecuteRequest copyWith(void Function(ExecuteRequest) updates) =>
      super.copyWith((message) => updates(message as ExecuteRequest))
          as ExecuteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExecuteRequest create() => ExecuteRequest._();
  @$core.override
  ExecuteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExecuteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExecuteRequest>(create);
  static ExecuteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sql => $_getSZ(3);
  @$pb.TagNumber(4)
  set sql($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSql() => $_has(3);
  @$pb.TagNumber(4)
  void clearSql() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get documentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set documentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDocumentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearDocumentId() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get documentVersion => $_getI64(5);
  @$pb.TagNumber(6)
  set documentVersion($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDocumentVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearDocumentVersion() => $_clearField(6);

  @$pb.TagNumber(7)
  ExecutionMode get mode => $_getN(6);
  @$pb.TagNumber(7)
  set mode(ExecutionMode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearMode() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get caretUtf16 => $_getIZ(7);
  @$pb.TagNumber(8)
  set caretUtf16($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCaretUtf16() => $_has(7);
  @$pb.TagNumber(8)
  void clearCaretUtf16() => $_clearField(8);

  @$pb.TagNumber(9)
  ErrorPolicy get errorPolicy => $_getN(8);
  @$pb.TagNumber(9)
  set errorPolicy(ErrorPolicy value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasErrorPolicy() => $_has(8);
  @$pb.TagNumber(9)
  void clearErrorPolicy() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get rowLimit => $_getI64(9);
  @$pb.TagNumber(10)
  set rowLimit($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasRowLimit() => $_has(9);
  @$pb.TagNumber(10)
  void clearRowLimit() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get streamingRead => $_getBF(10);
  @$pb.TagNumber(11)
  set streamingRead($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStreamingRead() => $_has(10);
  @$pb.TagNumber(11)
  void clearStreamingRead() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get approvalToken => $_getSZ(11);
  @$pb.TagNumber(12)
  set approvalToken($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasApprovalToken() => $_has(11);
  @$pb.TagNumber(12)
  void clearApprovalToken() => $_clearField(12);
}

class RowCondition extends $pb.GeneratedMessage {
  factory RowCondition({
    $core.String? column,
    ValuePredicate? predicate,
    Value? value,
  }) {
    final result = create();
    if (column != null) result.column = column;
    if (predicate != null) result.predicate = predicate;
    if (value != null) result.value = value;
    return result;
  }

  RowCondition._();

  factory RowCondition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RowCondition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RowCondition',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'column')
    ..aE<ValuePredicate>(2, _omitFieldNames ? '' : 'predicate',
        enumValues: ValuePredicate.values)
    ..aOM<Value>(3, _omitFieldNames ? '' : 'value', subBuilder: Value.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowCondition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowCondition copyWith(void Function(RowCondition) updates) =>
      super.copyWith((message) => updates(message as RowCondition))
          as RowCondition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RowCondition create() => RowCondition._();
  @$core.override
  RowCondition createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RowCondition getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RowCondition>(create);
  static RowCondition? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get column => $_getSZ(0);
  @$pb.TagNumber(1)
  set column($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasColumn() => $_has(0);
  @$pb.TagNumber(1)
  void clearColumn() => $_clearField(1);

  @$pb.TagNumber(2)
  ValuePredicate get predicate => $_getN(1);
  @$pb.TagNumber(2)
  set predicate(ValuePredicate value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPredicate() => $_has(1);
  @$pb.TagNumber(2)
  void clearPredicate() => $_clearField(2);

  @$pb.TagNumber(3)
  Value get value => $_getN(2);
  @$pb.TagNumber(3)
  set value(Value value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
  @$pb.TagNumber(3)
  Value ensureValue() => $_ensure(2);
}

class RowOrder extends $pb.GeneratedMessage {
  factory RowOrder({
    $core.String? column,
    $core.bool? descending,
  }) {
    final result = create();
    if (column != null) result.column = column;
    if (descending != null) result.descending = descending;
    return result;
  }

  RowOrder._();

  factory RowOrder.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RowOrder.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RowOrder',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'column')
    ..aOB(2, _omitFieldNames ? '' : 'descending')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowOrder clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowOrder copyWith(void Function(RowOrder) updates) =>
      super.copyWith((message) => updates(message as RowOrder)) as RowOrder;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RowOrder create() => RowOrder._();
  @$core.override
  RowOrder createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RowOrder getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RowOrder>(create);
  static RowOrder? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get column => $_getSZ(0);
  @$pb.TagNumber(1)
  set column($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasColumn() => $_has(0);
  @$pb.TagNumber(1)
  void clearColumn() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get descending => $_getBF(1);
  @$pb.TagNumber(2)
  set descending($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescending() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescending() => $_clearField(2);
}

/// Only Java constructs the table query. Column identities are verified from metadata.
class BrowseRequest extends $pb.GeneratedMessage {
  factory BrowseRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? executionId,
    $core.String? documentId,
    $core.String? catalog,
    $core.String? schema,
    $core.String? table,
    $fixnum.Int64? rowLimit,
    $core.Iterable<RowCondition>? conditions,
    $core.Iterable<RowOrder>? order,
    $core.String? approvalToken,
    $fixnum.Int64? metadataSnapshotRevision,
    $core.String? metadataObjectIdentity,
    $core.String? originRelationshipIdentity,
    $core.String? originResultId,
    $fixnum.Int64? originSourceRow,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (executionId != null) result.executionId = executionId;
    if (documentId != null) result.documentId = documentId;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (rowLimit != null) result.rowLimit = rowLimit;
    if (conditions != null) result.conditions.addAll(conditions);
    if (order != null) result.order.addAll(order);
    if (approvalToken != null) result.approvalToken = approvalToken;
    if (metadataSnapshotRevision != null)
      result.metadataSnapshotRevision = metadataSnapshotRevision;
    if (metadataObjectIdentity != null)
      result.metadataObjectIdentity = metadataObjectIdentity;
    if (originRelationshipIdentity != null)
      result.originRelationshipIdentity = originRelationshipIdentity;
    if (originResultId != null) result.originResultId = originResultId;
    if (originSourceRow != null) result.originSourceRow = originSourceRow;
    return result;
  }

  BrowseRequest._();

  factory BrowseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BrowseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BrowseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aOS(4, _omitFieldNames ? '' : 'documentId')
    ..aOS(5, _omitFieldNames ? '' : 'catalog')
    ..aOS(6, _omitFieldNames ? '' : 'schema')
    ..aOS(7, _omitFieldNames ? '' : 'table')
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'rowLimit', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<RowCondition>(9, _omitFieldNames ? '' : 'conditions',
        subBuilder: RowCondition.create)
    ..pPM<RowOrder>(10, _omitFieldNames ? '' : 'order',
        subBuilder: RowOrder.create)
    ..aOS(11, _omitFieldNames ? '' : 'approvalToken')
    ..a<$fixnum.Int64>(12, _omitFieldNames ? '' : 'metadataSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(13, _omitFieldNames ? '' : 'metadataObjectIdentity')
    ..aOS(14, _omitFieldNames ? '' : 'originRelationshipIdentity')
    ..aOS(15, _omitFieldNames ? '' : 'originResultId')
    ..a<$fixnum.Int64>(
        16, _omitFieldNames ? '' : 'originSourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseRequest copyWith(void Function(BrowseRequest) updates) =>
      super.copyWith((message) => updates(message as BrowseRequest))
          as BrowseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BrowseRequest create() => BrowseRequest._();
  @$core.override
  BrowseRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BrowseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BrowseRequest>(create);
  static BrowseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get documentId => $_getSZ(3);
  @$pb.TagNumber(4)
  set documentId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDocumentId() => $_has(3);
  @$pb.TagNumber(4)
  void clearDocumentId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get catalog => $_getSZ(4);
  @$pb.TagNumber(5)
  set catalog($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCatalog() => $_has(4);
  @$pb.TagNumber(5)
  void clearCatalog() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get schema => $_getSZ(5);
  @$pb.TagNumber(6)
  set schema($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSchema() => $_has(5);
  @$pb.TagNumber(6)
  void clearSchema() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get table => $_getSZ(6);
  @$pb.TagNumber(7)
  set table($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTable() => $_has(6);
  @$pb.TagNumber(7)
  void clearTable() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get rowLimit => $_getI64(7);
  @$pb.TagNumber(8)
  set rowLimit($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRowLimit() => $_has(7);
  @$pb.TagNumber(8)
  void clearRowLimit() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<RowCondition> get conditions => $_getList(8);

  @$pb.TagNumber(10)
  $pb.PbList<RowOrder> get order => $_getList(9);

  @$pb.TagNumber(11)
  $core.String get approvalToken => $_getSZ(10);
  @$pb.TagNumber(11)
  set approvalToken($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasApprovalToken() => $_has(10);
  @$pb.TagNumber(11)
  void clearApprovalToken() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get metadataSnapshotRevision => $_getI64(11);
  @$pb.TagNumber(12)
  set metadataSnapshotRevision($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasMetadataSnapshotRevision() => $_has(11);
  @$pb.TagNumber(12)
  void clearMetadataSnapshotRevision() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get metadataObjectIdentity => $_getSZ(12);
  @$pb.TagNumber(13)
  set metadataObjectIdentity($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasMetadataObjectIdentity() => $_has(12);
  @$pb.TagNumber(13)
  void clearMetadataObjectIdentity() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get originRelationshipIdentity => $_getSZ(13);
  @$pb.TagNumber(14)
  set originRelationshipIdentity($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasOriginRelationshipIdentity() => $_has(13);
  @$pb.TagNumber(14)
  void clearOriginRelationshipIdentity() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get originResultId => $_getSZ(14);
  @$pb.TagNumber(15)
  set originResultId($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasOriginResultId() => $_has(14);
  @$pb.TagNumber(15)
  void clearOriginResultId() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get originSourceRow => $_getI64(15);
  @$pb.TagNumber(16)
  set originSourceRow($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasOriginSourceRow() => $_has(15);
  @$pb.TagNumber(16)
  void clearOriginSourceRow() => $_clearField(16);
}

class Approval extends $pb.GeneratedMessage {
  factory Approval({
    $core.String? token,
    $core.Iterable<$core.String>? statements,
    $core.Iterable<$core.String>? risks,
    $fixnum.Int64? expiresUnixMs,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (statements != null) result.statements.addAll(statements);
    if (risks != null) result.risks.addAll(risks);
    if (expiresUnixMs != null) result.expiresUnixMs = expiresUnixMs;
    return result;
  }

  Approval._();

  factory Approval.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Approval.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Approval',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..pPS(2, _omitFieldNames ? '' : 'statements')
    ..pPS(3, _omitFieldNames ? '' : 'risks')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'expiresUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Approval clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Approval copyWith(void Function(Approval) updates) =>
      super.copyWith((message) => updates(message as Approval)) as Approval;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Approval create() => Approval._();
  @$core.override
  Approval createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Approval getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Approval>(create);
  static Approval? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get statements => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get risks => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get expiresUnixMs => $_getI64(3);
  @$pb.TagNumber(4)
  set expiresUnixMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresUnixMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresUnixMs() => $_clearField(4);
}

class JobRequest extends $pb.GeneratedMessage {
  factory JobRequest({
    Context? context,
    $core.String? jobId,
    $core.String? sessionId,
    $core.int? offset,
    $core.int? limit,
    $fixnum.Int64? catalogRevision,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (jobId != null) result.jobId = jobId;
    if (sessionId != null) result.sessionId = sessionId;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    if (catalogRevision != null) result.catalogRevision = catalogRevision;
    return result;
  }

  JobRequest._();

  factory JobRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JobRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JobRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'jobId')
    ..aOS(3, _omitFieldNames ? '' : 'sessionId')
    ..aI(4, _omitFieldNames ? '' : 'offset', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'catalogRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JobRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JobRequest copyWith(void Function(JobRequest) updates) =>
      super.copyWith((message) => updates(message as JobRequest)) as JobRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JobRequest create() => JobRequest._();
  @$core.override
  JobRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JobRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JobRequest>(create);
  static JobRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get jobId => $_getSZ(1);
  @$pb.TagNumber(2)
  set jobId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJobId() => $_has(1);
  @$pb.TagNumber(2)
  void clearJobId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sessionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get offset => $_getIZ(3);
  @$pb.TagNumber(4)
  set offset($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOffset() => $_has(3);
  @$pb.TagNumber(4)
  void clearOffset() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get limit => $_getIZ(4);
  @$pb.TagNumber(5)
  set limit($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearLimit() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get catalogRevision => $_getI64(5);
  @$pb.TagNumber(6)
  set catalogRevision($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCatalogRevision() => $_has(5);
  @$pb.TagNumber(6)
  void clearCatalogRevision() => $_clearField(6);
}

class JobList extends $pb.GeneratedMessage {
  factory JobList({
    $core.Iterable<JobInfo>? jobs,
    $core.int? nextOffset,
    $core.bool? complete,
    $fixnum.Int64? catalogRevision,
  }) {
    final result = create();
    if (jobs != null) result.jobs.addAll(jobs);
    if (nextOffset != null) result.nextOffset = nextOffset;
    if (complete != null) result.complete = complete;
    if (catalogRevision != null) result.catalogRevision = catalogRevision;
    return result;
  }

  JobList._();

  factory JobList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JobList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JobList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<JobInfo>(1, _omitFieldNames ? '' : 'jobs', subBuilder: JobInfo.create)
    ..aI(2, _omitFieldNames ? '' : 'nextOffset', fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'complete')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'catalogRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JobList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JobList copyWith(void Function(JobList) updates) =>
      super.copyWith((message) => updates(message as JobList)) as JobList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JobList create() => JobList._();
  @$core.override
  JobList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JobList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JobList>(create);
  static JobList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JobInfo> get jobs => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get nextOffset => $_getIZ(1);
  @$pb.TagNumber(2)
  set nextOffset($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get complete => $_getBF(2);
  @$pb.TagNumber(3)
  set complete($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasComplete() => $_has(2);
  @$pb.TagNumber(3)
  void clearComplete() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get catalogRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set catalogRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCatalogRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearCatalogRevision() => $_clearField(4);
}

class RetainedRequest extends $pb.GeneratedMessage {
  factory RetainedRequest({
    Context? context,
    $core.int? offset,
    $core.int? limit,
    $fixnum.Int64? catalogRevision,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    if (catalogRevision != null) result.catalogRevision = catalogRevision;
    return result;
  }

  RetainedRequest._();

  factory RetainedRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RetainedRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RetainedRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aI(2, _omitFieldNames ? '' : 'offset', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'catalogRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RetainedRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RetainedRequest copyWith(void Function(RetainedRequest) updates) =>
      super.copyWith((message) => updates(message as RetainedRequest))
          as RetainedRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RetainedRequest create() => RetainedRequest._();
  @$core.override
  RetainedRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RetainedRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RetainedRequest>(create);
  static RetainedRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get catalogRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set catalogRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCatalogRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearCatalogRevision() => $_clearField(4);
}

/// SQL provenance uses the same bounded preview/private value spool as cells.
/// It is never written to history or portable workspace presentation state.
class RetainedResult extends $pb.GeneratedMessage {
  factory RetainedResult({
    StatementResult? result,
    $core.String? jobId,
    $core.String? executionId,
    $core.String? documentId,
    $core.String? sessionId,
    $fixnum.Int64? createdUnixMs,
    $core.bool? disposalPending,
    $core.int? leases,
    $core.String? availability,
    JobState? state,
    Profile? target,
    Value? sqlProvenance,
    $core.String? sourceSchema,
  }) {
    final result$ = create();
    if (result != null) result$.result = result;
    if (jobId != null) result$.jobId = jobId;
    if (executionId != null) result$.executionId = executionId;
    if (documentId != null) result$.documentId = documentId;
    if (sessionId != null) result$.sessionId = sessionId;
    if (createdUnixMs != null) result$.createdUnixMs = createdUnixMs;
    if (disposalPending != null) result$.disposalPending = disposalPending;
    if (leases != null) result$.leases = leases;
    if (availability != null) result$.availability = availability;
    if (state != null) result$.state = state;
    if (target != null) result$.target = target;
    if (sqlProvenance != null) result$.sqlProvenance = sqlProvenance;
    if (sourceSchema != null) result$.sourceSchema = sourceSchema;
    return result$;
  }

  RetainedResult._();

  factory RetainedResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RetainedResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RetainedResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<StatementResult>(1, _omitFieldNames ? '' : 'result',
        subBuilder: StatementResult.create)
    ..aOS(2, _omitFieldNames ? '' : 'jobId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aOS(4, _omitFieldNames ? '' : 'documentId')
    ..aOS(5, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'createdUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(7, _omitFieldNames ? '' : 'disposalPending')
    ..aI(8, _omitFieldNames ? '' : 'leases', fieldType: $pb.PbFieldType.OU3)
    ..aOS(9, _omitFieldNames ? '' : 'availability')
    ..aE<JobState>(10, _omitFieldNames ? '' : 'state',
        enumValues: JobState.values)
    ..aOM<Profile>(11, _omitFieldNames ? '' : 'target',
        subBuilder: Profile.create)
    ..aOM<Value>(12, _omitFieldNames ? '' : 'sqlProvenance',
        subBuilder: Value.create)
    ..aOS(13, _omitFieldNames ? '' : 'sourceSchema')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RetainedResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RetainedResult copyWith(void Function(RetainedResult) updates) =>
      super.copyWith((message) => updates(message as RetainedResult))
          as RetainedResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RetainedResult create() => RetainedResult._();
  @$core.override
  RetainedResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RetainedResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RetainedResult>(create);
  static RetainedResult? _defaultInstance;

  @$pb.TagNumber(1)
  StatementResult get result => $_getN(0);
  @$pb.TagNumber(1)
  set result(StatementResult value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => $_clearField(1);
  @$pb.TagNumber(1)
  StatementResult ensureResult() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get jobId => $_getSZ(1);
  @$pb.TagNumber(2)
  set jobId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJobId() => $_has(1);
  @$pb.TagNumber(2)
  void clearJobId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get documentId => $_getSZ(3);
  @$pb.TagNumber(4)
  set documentId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDocumentId() => $_has(3);
  @$pb.TagNumber(4)
  void clearDocumentId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sessionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set sessionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionId() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdUnixMs => $_getI64(5);
  @$pb.TagNumber(6)
  set createdUnixMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedUnixMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedUnixMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get disposalPending => $_getBF(6);
  @$pb.TagNumber(7)
  set disposalPending($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDisposalPending() => $_has(6);
  @$pb.TagNumber(7)
  void clearDisposalPending() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get leases => $_getIZ(7);
  @$pb.TagNumber(8)
  set leases($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLeases() => $_has(7);
  @$pb.TagNumber(8)
  void clearLeases() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get availability => $_getSZ(8);
  @$pb.TagNumber(9)
  set availability($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAvailability() => $_has(8);
  @$pb.TagNumber(9)
  void clearAvailability() => $_clearField(9);

  @$pb.TagNumber(10)
  JobState get state => $_getN(9);
  @$pb.TagNumber(10)
  set state(JobState value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasState() => $_has(9);
  @$pb.TagNumber(10)
  void clearState() => $_clearField(10);

  @$pb.TagNumber(11)
  Profile get target => $_getN(10);
  @$pb.TagNumber(11)
  set target(Profile value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasTarget() => $_has(10);
  @$pb.TagNumber(11)
  void clearTarget() => $_clearField(11);
  @$pb.TagNumber(11)
  Profile ensureTarget() => $_ensure(10);

  @$pb.TagNumber(12)
  Value get sqlProvenance => $_getN(11);
  @$pb.TagNumber(12)
  set sqlProvenance(Value value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSqlProvenance() => $_has(11);
  @$pb.TagNumber(12)
  void clearSqlProvenance() => $_clearField(12);
  @$pb.TagNumber(12)
  Value ensureSqlProvenance() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.String get sourceSchema => $_getSZ(12);
  @$pb.TagNumber(13)
  set sourceSchema($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasSourceSchema() => $_has(12);
  @$pb.TagNumber(13)
  void clearSourceSchema() => $_clearField(13);
}

class RetainedList extends $pb.GeneratedMessage {
  factory RetainedList({
    $core.Iterable<RetainedResult>? results,
    $core.int? nextOffset,
    $core.bool? complete,
    $fixnum.Int64? catalogRevision,
  }) {
    final result = create();
    if (results != null) result.results.addAll(results);
    if (nextOffset != null) result.nextOffset = nextOffset;
    if (complete != null) result.complete = complete;
    if (catalogRevision != null) result.catalogRevision = catalogRevision;
    return result;
  }

  RetainedList._();

  factory RetainedList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RetainedList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RetainedList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<RetainedResult>(1, _omitFieldNames ? '' : 'results',
        subBuilder: RetainedResult.create)
    ..aI(2, _omitFieldNames ? '' : 'nextOffset', fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'complete')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'catalogRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RetainedList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RetainedList copyWith(void Function(RetainedList) updates) =>
      super.copyWith((message) => updates(message as RetainedList))
          as RetainedList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RetainedList create() => RetainedList._();
  @$core.override
  RetainedList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RetainedList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RetainedList>(create);
  static RetainedList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RetainedResult> get results => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get nextOffset => $_getIZ(1);
  @$pb.TagNumber(2)
  set nextOffset($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get complete => $_getBF(2);
  @$pb.TagNumber(3)
  set complete($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasComplete() => $_has(2);
  @$pb.TagNumber(3)
  void clearComplete() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get catalogRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set catalogRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCatalogRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearCatalogRevision() => $_clearField(4);
}

/// target is the captured execution endpoint, stripped of credential/file bindings.
/// source_schema is execution context, separate from column base-table provenance.
class JobInfo extends $pb.GeneratedMessage {
  factory JobInfo({
    $core.String? jobId,
    $core.String? sessionId,
    $core.String? executionId,
    JobState? state,
    $core.Iterable<StatementResult>? results,
    $core.Iterable<$core.String>? messages,
    $fixnum.Int64? durationMs,
    $core.String? errorCode,
    $fixnum.Int64? progressRows,
    $fixnum.Int64? committedRows,
    $fixnum.Int64? rejectedRows,
    Profile? target,
    ToolKind? toolKind,
    $core.String? sourceSchema,
  }) {
    final result = create();
    if (jobId != null) result.jobId = jobId;
    if (sessionId != null) result.sessionId = sessionId;
    if (executionId != null) result.executionId = executionId;
    if (state != null) result.state = state;
    if (results != null) result.results.addAll(results);
    if (messages != null) result.messages.addAll(messages);
    if (durationMs != null) result.durationMs = durationMs;
    if (errorCode != null) result.errorCode = errorCode;
    if (progressRows != null) result.progressRows = progressRows;
    if (committedRows != null) result.committedRows = committedRows;
    if (rejectedRows != null) result.rejectedRows = rejectedRows;
    if (target != null) result.target = target;
    if (toolKind != null) result.toolKind = toolKind;
    if (sourceSchema != null) result.sourceSchema = sourceSchema;
    return result;
  }

  JobInfo._();

  factory JobInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JobInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JobInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'jobId')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aE<JobState>(4, _omitFieldNames ? '' : 'state',
        enumValues: JobState.values)
    ..pPM<StatementResult>(5, _omitFieldNames ? '' : 'results',
        subBuilder: StatementResult.create)
    ..pPS(6, _omitFieldNames ? '' : 'messages')
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'durationMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(8, _omitFieldNames ? '' : 'errorCode')
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'progressRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'committedRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'rejectedRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<Profile>(12, _omitFieldNames ? '' : 'target',
        subBuilder: Profile.create)
    ..aE<ToolKind>(13, _omitFieldNames ? '' : 'toolKind',
        enumValues: ToolKind.values)
    ..aOS(14, _omitFieldNames ? '' : 'sourceSchema')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JobInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JobInfo copyWith(void Function(JobInfo) updates) =>
      super.copyWith((message) => updates(message as JobInfo)) as JobInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JobInfo create() => JobInfo._();
  @$core.override
  JobInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JobInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JobInfo>(create);
  static JobInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get jobId => $_getSZ(0);
  @$pb.TagNumber(1)
  set jobId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJobId() => $_has(0);
  @$pb.TagNumber(1)
  void clearJobId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  JobState get state => $_getN(3);
  @$pb.TagNumber(4)
  set state(JobState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<StatementResult> get results => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get messages => $_getList(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get durationMs => $_getI64(6);
  @$pb.TagNumber(7)
  set durationMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDurationMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearDurationMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get errorCode => $_getSZ(7);
  @$pb.TagNumber(8)
  set errorCode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasErrorCode() => $_has(7);
  @$pb.TagNumber(8)
  void clearErrorCode() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get progressRows => $_getI64(8);
  @$pb.TagNumber(9)
  set progressRows($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasProgressRows() => $_has(8);
  @$pb.TagNumber(9)
  void clearProgressRows() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get committedRows => $_getI64(9);
  @$pb.TagNumber(10)
  set committedRows($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCommittedRows() => $_has(9);
  @$pb.TagNumber(10)
  void clearCommittedRows() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get rejectedRows => $_getI64(10);
  @$pb.TagNumber(11)
  set rejectedRows($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasRejectedRows() => $_has(10);
  @$pb.TagNumber(11)
  void clearRejectedRows() => $_clearField(11);

  @$pb.TagNumber(12)
  Profile get target => $_getN(11);
  @$pb.TagNumber(12)
  set target(Profile value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasTarget() => $_has(11);
  @$pb.TagNumber(12)
  void clearTarget() => $_clearField(12);
  @$pb.TagNumber(12)
  Profile ensureTarget() => $_ensure(11);

  @$pb.TagNumber(13)
  ToolKind get toolKind => $_getN(12);
  @$pb.TagNumber(13)
  set toolKind(ToolKind value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasToolKind() => $_has(12);
  @$pb.TagNumber(13)
  void clearToolKind() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get sourceSchema => $_getSZ(13);
  @$pb.TagNumber(14)
  set sourceSchema($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSourceSchema() => $_has(13);
  @$pb.TagNumber(14)
  void clearSourceSchema() => $_clearField(14);
}

class StatementResult extends $pb.GeneratedMessage {
  factory StatementResult({
    $core.int? statementIndex,
    $core.String? resultId,
    $core.Iterable<Column>? columns,
    $fixnum.Int64? updateCount,
    $fixnum.Int64? fetchedRows,
    $core.bool? complete,
    $core.bool? limited,
    $core.bool? plan,
  }) {
    final result = create();
    if (statementIndex != null) result.statementIndex = statementIndex;
    if (resultId != null) result.resultId = resultId;
    if (columns != null) result.columns.addAll(columns);
    if (updateCount != null) result.updateCount = updateCount;
    if (fetchedRows != null) result.fetchedRows = fetchedRows;
    if (complete != null) result.complete = complete;
    if (limited != null) result.limited = limited;
    if (plan != null) result.plan = plan;
    return result;
  }

  StatementResult._();

  factory StatementResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StatementResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StatementResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'statementIndex',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..pPM<Column>(3, _omitFieldNames ? '' : 'columns',
        subBuilder: Column.create)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'updateCount', $pb.PbFieldType.OS6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'fetchedRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(6, _omitFieldNames ? '' : 'complete')
    ..aOB(7, _omitFieldNames ? '' : 'limited')
    ..aOB(8, _omitFieldNames ? '' : 'plan')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatementResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatementResult copyWith(void Function(StatementResult) updates) =>
      super.copyWith((message) => updates(message as StatementResult))
          as StatementResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StatementResult create() => StatementResult._();
  @$core.override
  StatementResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StatementResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StatementResult>(create);
  static StatementResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get statementIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set statementIndex($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatementIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatementIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<Column> get columns => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get updateCount => $_getI64(3);
  @$pb.TagNumber(4)
  set updateCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdateCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdateCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get fetchedRows => $_getI64(4);
  @$pb.TagNumber(5)
  set fetchedRows($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFetchedRows() => $_has(4);
  @$pb.TagNumber(5)
  void clearFetchedRows() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get complete => $_getBF(5);
  @$pb.TagNumber(6)
  set complete($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasComplete() => $_has(5);
  @$pb.TagNumber(6)
  void clearComplete() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get limited => $_getBF(6);
  @$pb.TagNumber(7)
  set limited($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLimited() => $_has(6);
  @$pb.TagNumber(7)
  void clearLimited() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get plan => $_getBF(7);
  @$pb.TagNumber(8)
  set plan($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPlan() => $_has(7);
  @$pb.TagNumber(8)
  void clearPlan() => $_clearField(8);
}

/// name is a display label. ordinal is one-based; only verified base identity is
/// usable for editing. Unknown provenance never falls back to the display label.
class Column extends $pb.GeneratedMessage {
  factory Column({
    $core.String? name,
    $core.String? typeName,
    $core.int? jdbcType,
    $core.int? precision,
    $core.int? scale,
    $core.bool? nullable,
    $core.bool? signed,
    $core.String? catalog,
    $core.String? schema,
    $core.String? table,
    $core.bool? readOnly,
    $core.String? baseColumn,
    $core.int? ordinal,
    $core.bool? provenanceKnown,
    $core.String? metadataIdentity,
    $fixnum.Int64? metadataSnapshotRevision,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (typeName != null) result.typeName = typeName;
    if (jdbcType != null) result.jdbcType = jdbcType;
    if (precision != null) result.precision = precision;
    if (scale != null) result.scale = scale;
    if (nullable != null) result.nullable = nullable;
    if (signed != null) result.signed = signed;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (readOnly != null) result.readOnly = readOnly;
    if (baseColumn != null) result.baseColumn = baseColumn;
    if (ordinal != null) result.ordinal = ordinal;
    if (provenanceKnown != null) result.provenanceKnown = provenanceKnown;
    if (metadataIdentity != null) result.metadataIdentity = metadataIdentity;
    if (metadataSnapshotRevision != null)
      result.metadataSnapshotRevision = metadataSnapshotRevision;
    return result;
  }

  Column._();

  factory Column.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Column.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Column',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'typeName')
    ..aI(3, _omitFieldNames ? '' : 'jdbcType')
    ..aI(4, _omitFieldNames ? '' : 'precision', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'scale', fieldType: $pb.PbFieldType.OS3)
    ..aOB(6, _omitFieldNames ? '' : 'nullable')
    ..aOB(7, _omitFieldNames ? '' : 'signed')
    ..aOS(8, _omitFieldNames ? '' : 'catalog')
    ..aOS(9, _omitFieldNames ? '' : 'schema')
    ..aOS(10, _omitFieldNames ? '' : 'table')
    ..aOB(11, _omitFieldNames ? '' : 'readOnly')
    ..aOS(12, _omitFieldNames ? '' : 'baseColumn')
    ..aI(13, _omitFieldNames ? '' : 'ordinal', fieldType: $pb.PbFieldType.OU3)
    ..aOB(14, _omitFieldNames ? '' : 'provenanceKnown')
    ..aOS(15, _omitFieldNames ? '' : 'metadataIdentity')
    ..a<$fixnum.Int64>(16, _omitFieldNames ? '' : 'metadataSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Column clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Column copyWith(void Function(Column) updates) =>
      super.copyWith((message) => updates(message as Column)) as Column;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Column create() => Column._();
  @$core.override
  Column createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Column getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Column>(create);
  static Column? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get typeName => $_getSZ(1);
  @$pb.TagNumber(2)
  set typeName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTypeName() => $_has(1);
  @$pb.TagNumber(2)
  void clearTypeName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get jdbcType => $_getIZ(2);
  @$pb.TagNumber(3)
  set jdbcType($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasJdbcType() => $_has(2);
  @$pb.TagNumber(3)
  void clearJdbcType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get precision => $_getIZ(3);
  @$pb.TagNumber(4)
  set precision($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPrecision() => $_has(3);
  @$pb.TagNumber(4)
  void clearPrecision() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get scale => $_getIZ(4);
  @$pb.TagNumber(5)
  set scale($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScale() => $_has(4);
  @$pb.TagNumber(5)
  void clearScale() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get nullable => $_getBF(5);
  @$pb.TagNumber(6)
  set nullable($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNullable() => $_has(5);
  @$pb.TagNumber(6)
  void clearNullable() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get signed => $_getBF(6);
  @$pb.TagNumber(7)
  set signed($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSigned() => $_has(6);
  @$pb.TagNumber(7)
  void clearSigned() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get catalog => $_getSZ(7);
  @$pb.TagNumber(8)
  set catalog($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCatalog() => $_has(7);
  @$pb.TagNumber(8)
  void clearCatalog() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get schema => $_getSZ(8);
  @$pb.TagNumber(9)
  set schema($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSchema() => $_has(8);
  @$pb.TagNumber(9)
  void clearSchema() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get table => $_getSZ(9);
  @$pb.TagNumber(10)
  set table($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTable() => $_has(9);
  @$pb.TagNumber(10)
  void clearTable() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get readOnly => $_getBF(10);
  @$pb.TagNumber(11)
  set readOnly($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasReadOnly() => $_has(10);
  @$pb.TagNumber(11)
  void clearReadOnly() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get baseColumn => $_getSZ(11);
  @$pb.TagNumber(12)
  set baseColumn($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasBaseColumn() => $_has(11);
  @$pb.TagNumber(12)
  void clearBaseColumn() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get ordinal => $_getIZ(12);
  @$pb.TagNumber(13)
  set ordinal($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasOrdinal() => $_has(12);
  @$pb.TagNumber(13)
  void clearOrdinal() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get provenanceKnown => $_getBF(13);
  @$pb.TagNumber(14)
  set provenanceKnown($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasProvenanceKnown() => $_has(13);
  @$pb.TagNumber(14)
  void clearProvenanceKnown() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get metadataIdentity => $_getSZ(14);
  @$pb.TagNumber(15)
  set metadataIdentity($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasMetadataIdentity() => $_has(14);
  @$pb.TagNumber(15)
  void clearMetadataIdentity() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get metadataSnapshotRevision => $_getI64(15);
  @$pb.TagNumber(16)
  set metadataSnapshotRevision($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasMetadataSnapshotRevision() => $_has(15);
  @$pb.TagNumber(16)
  void clearMetadataSnapshotRevision() => $_clearField(16);
}

class Null extends $pb.GeneratedMessage {
  factory Null() => create();

  Null._();

  factory Null.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Null.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Null',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Null clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Null copyWith(void Function(Null) updates) =>
      super.copyWith((message) => updates(message as Null)) as Null;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Null create() => Null._();
  @$core.override
  Null createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Null getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Null>(create);
  static Null? _defaultInstance;
}

class Temporal extends $pb.GeneratedMessage {
  factory Temporal({
    $core.String? iso,
    $core.String? kind,
    $core.String? zone,
  }) {
    final result = create();
    if (iso != null) result.iso = iso;
    if (kind != null) result.kind = kind;
    if (zone != null) result.zone = zone;
    return result;
  }

  Temporal._();

  factory Temporal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Temporal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Temporal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'iso')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..aOS(3, _omitFieldNames ? '' : 'zone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Temporal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Temporal copyWith(void Function(Temporal) updates) =>
      super.copyWith((message) => updates(message as Temporal)) as Temporal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Temporal create() => Temporal._();
  @$core.override
  Temporal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Temporal getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Temporal>(create);
  static Temporal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get iso => $_getSZ(0);
  @$pb.TagNumber(1)
  set iso($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIso() => $_has(0);
  @$pb.TagNumber(1)
  void clearIso() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get zone => $_getSZ(2);
  @$pb.TagNumber(3)
  set zone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasZone() => $_has(2);
  @$pb.TagNumber(3)
  void clearZone() => $_clearField(3);
}

class EngineValue extends $pb.GeneratedMessage {
  factory EngineValue({
    $core.String? typeName,
    $core.String? text,
  }) {
    final result = create();
    if (typeName != null) result.typeName = typeName;
    if (text != null) result.text = text;
    return result;
  }

  EngineValue._();

  factory EngineValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EngineValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EngineValue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'typeName')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EngineValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EngineValue copyWith(void Function(EngineValue) updates) =>
      super.copyWith((message) => updates(message as EngineValue))
          as EngineValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EngineValue create() => EngineValue._();
  @$core.override
  EngineValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EngineValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EngineValue>(create);
  static EngineValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get typeName => $_getSZ(0);
  @$pb.TagNumber(1)
  set typeName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTypeName() => $_has(0);
  @$pb.TagNumber(1)
  void clearTypeName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class ArrayValue extends $pb.GeneratedMessage {
  factory ArrayValue({
    $core.Iterable<Value>? values,
    $core.String? nativeLiteral,
    $core.String? elementNativeType,
    $core.List<$core.int>? nativeBinary,
  }) {
    final result = create();
    if (values != null) result.values.addAll(values);
    if (nativeLiteral != null) result.nativeLiteral = nativeLiteral;
    if (elementNativeType != null) result.elementNativeType = elementNativeType;
    if (nativeBinary != null) result.nativeBinary = nativeBinary;
    return result;
  }

  ArrayValue._();

  factory ArrayValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArrayValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArrayValue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<Value>(1, _omitFieldNames ? '' : 'values', subBuilder: Value.create)
    ..aOS(2, _omitFieldNames ? '' : 'nativeLiteral')
    ..aOS(3, _omitFieldNames ? '' : 'elementNativeType')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'nativeBinary', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrayValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrayValue copyWith(void Function(ArrayValue) updates) =>
      super.copyWith((message) => updates(message as ArrayValue)) as ArrayValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArrayValue create() => ArrayValue._();
  @$core.override
  ArrayValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArrayValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArrayValue>(create);
  static ArrayValue? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Value> get values => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nativeLiteral => $_getSZ(1);
  @$pb.TagNumber(2)
  set nativeLiteral($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNativeLiteral() => $_has(1);
  @$pb.TagNumber(2)
  void clearNativeLiteral() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get elementNativeType => $_getSZ(2);
  @$pb.TagNumber(3)
  set elementNativeType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasElementNativeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearElementNativeType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get nativeBinary => $_getN(3);
  @$pb.TagNumber(4)
  set nativeBinary($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNativeBinary() => $_has(3);
  @$pb.TagNumber(4)
  void clearNativeBinary() => $_clearField(4);
}

enum Value_Data {
  nullValue,
  boolean,
  signedInteger,
  unsignedInteger,
  decimal,
  text,
  binary,
  temporal,
  json,
  array,
  engineValue,
  real,
  notSet
}

class Value extends $pb.GeneratedMessage {
  factory Value({
    Null? nullValue,
    $core.bool? boolean,
    $core.String? signedInteger,
    $core.String? unsignedInteger,
    $core.String? decimal,
    $core.String? text,
    $core.List<$core.int>? binary,
    Temporal? temporal,
    $core.String? json,
    ArrayValue? array,
    EngineValue? engineValue,
    $core.double? real,
    $core.bool? truncated,
    $fixnum.Int64? originalBytes,
    $core.String? valueId,
  }) {
    final result = create();
    if (nullValue != null) result.nullValue = nullValue;
    if (boolean != null) result.boolean = boolean;
    if (signedInteger != null) result.signedInteger = signedInteger;
    if (unsignedInteger != null) result.unsignedInteger = unsignedInteger;
    if (decimal != null) result.decimal = decimal;
    if (text != null) result.text = text;
    if (binary != null) result.binary = binary;
    if (temporal != null) result.temporal = temporal;
    if (json != null) result.json = json;
    if (array != null) result.array = array;
    if (engineValue != null) result.engineValue = engineValue;
    if (real != null) result.real = real;
    if (truncated != null) result.truncated = truncated;
    if (originalBytes != null) result.originalBytes = originalBytes;
    if (valueId != null) result.valueId = valueId;
    return result;
  }

  Value._();

  factory Value.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Value.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Value_Data> _Value_DataByTag = {
    1: Value_Data.nullValue,
    2: Value_Data.boolean,
    3: Value_Data.signedInteger,
    4: Value_Data.unsignedInteger,
    5: Value_Data.decimal,
    6: Value_Data.text,
    7: Value_Data.binary,
    8: Value_Data.temporal,
    9: Value_Data.json,
    10: Value_Data.array,
    11: Value_Data.engineValue,
    12: Value_Data.real,
    0: Value_Data.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Value',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    ..aOM<Null>(1, _omitFieldNames ? '' : 'nullValue', subBuilder: Null.create)
    ..aOB(2, _omitFieldNames ? '' : 'boolean')
    ..aOS(3, _omitFieldNames ? '' : 'signedInteger')
    ..aOS(4, _omitFieldNames ? '' : 'unsignedInteger')
    ..aOS(5, _omitFieldNames ? '' : 'decimal')
    ..aOS(6, _omitFieldNames ? '' : 'text')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'binary', $pb.PbFieldType.OY)
    ..aOM<Temporal>(8, _omitFieldNames ? '' : 'temporal',
        subBuilder: Temporal.create)
    ..aOS(9, _omitFieldNames ? '' : 'json')
    ..aOM<ArrayValue>(10, _omitFieldNames ? '' : 'array',
        subBuilder: ArrayValue.create)
    ..aOM<EngineValue>(11, _omitFieldNames ? '' : 'engineValue',
        subBuilder: EngineValue.create)
    ..aD(12, _omitFieldNames ? '' : 'real')
    ..aOB(20, _omitFieldNames ? '' : 'truncated')
    ..a<$fixnum.Int64>(
        21, _omitFieldNames ? '' : 'originalBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(22, _omitFieldNames ? '' : 'valueId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Value clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Value copyWith(void Function(Value) updates) =>
      super.copyWith((message) => updates(message as Value)) as Value;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Value create() => Value._();
  @$core.override
  Value createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Value getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Value>(create);
  static Value? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  Value_Data whichData() => _Value_DataByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  void clearData() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Null get nullValue => $_getN(0);
  @$pb.TagNumber(1)
  set nullValue(Null value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNullValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearNullValue() => $_clearField(1);
  @$pb.TagNumber(1)
  Null ensureNullValue() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get boolean => $_getBF(1);
  @$pb.TagNumber(2)
  set boolean($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBoolean() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoolean() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get signedInteger => $_getSZ(2);
  @$pb.TagNumber(3)
  set signedInteger($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignedInteger() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignedInteger() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get unsignedInteger => $_getSZ(3);
  @$pb.TagNumber(4)
  set unsignedInteger($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUnsignedInteger() => $_has(3);
  @$pb.TagNumber(4)
  void clearUnsignedInteger() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get decimal => $_getSZ(4);
  @$pb.TagNumber(5)
  set decimal($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDecimal() => $_has(4);
  @$pb.TagNumber(5)
  void clearDecimal() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get text => $_getSZ(5);
  @$pb.TagNumber(6)
  set text($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasText() => $_has(5);
  @$pb.TagNumber(6)
  void clearText() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get binary => $_getN(6);
  @$pb.TagNumber(7)
  set binary($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBinary() => $_has(6);
  @$pb.TagNumber(7)
  void clearBinary() => $_clearField(7);

  @$pb.TagNumber(8)
  Temporal get temporal => $_getN(7);
  @$pb.TagNumber(8)
  set temporal(Temporal value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTemporal() => $_has(7);
  @$pb.TagNumber(8)
  void clearTemporal() => $_clearField(8);
  @$pb.TagNumber(8)
  Temporal ensureTemporal() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get json => $_getSZ(8);
  @$pb.TagNumber(9)
  set json($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasJson() => $_has(8);
  @$pb.TagNumber(9)
  void clearJson() => $_clearField(9);

  @$pb.TagNumber(10)
  ArrayValue get array => $_getN(9);
  @$pb.TagNumber(10)
  set array(ArrayValue value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasArray() => $_has(9);
  @$pb.TagNumber(10)
  void clearArray() => $_clearField(10);
  @$pb.TagNumber(10)
  ArrayValue ensureArray() => $_ensure(9);

  @$pb.TagNumber(11)
  EngineValue get engineValue => $_getN(10);
  @$pb.TagNumber(11)
  set engineValue(EngineValue value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasEngineValue() => $_has(10);
  @$pb.TagNumber(11)
  void clearEngineValue() => $_clearField(11);
  @$pb.TagNumber(11)
  EngineValue ensureEngineValue() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.double get real => $_getN(11);
  @$pb.TagNumber(12)
  set real($core.double value) => $_setDouble(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReal() => $_has(11);
  @$pb.TagNumber(12)
  void clearReal() => $_clearField(12);

  @$pb.TagNumber(20)
  $core.bool get truncated => $_getBF(12);
  @$pb.TagNumber(20)
  set truncated($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(20)
  $core.bool hasTruncated() => $_has(12);
  @$pb.TagNumber(20)
  void clearTruncated() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get originalBytes => $_getI64(13);
  @$pb.TagNumber(21)
  set originalBytes($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(21)
  $core.bool hasOriginalBytes() => $_has(13);
  @$pb.TagNumber(21)
  void clearOriginalBytes() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get valueId => $_getSZ(14);
  @$pb.TagNumber(22)
  set valueId($core.String value) => $_setString(14, value);
  @$pb.TagNumber(22)
  $core.bool hasValueId() => $_has(14);
  @$pb.TagNumber(22)
  void clearValueId() => $_clearField(22);
}

class ValueRequest extends $pb.GeneratedMessage {
  factory ValueRequest({
    Context? context,
    $core.String? resultId,
    $core.String? valueId,
    $fixnum.Int64? offset,
    $core.int? maxBytes,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (resultId != null) result.resultId = resultId;
    if (valueId != null) result.valueId = valueId;
    if (offset != null) result.offset = offset;
    if (maxBytes != null) result.maxBytes = maxBytes;
    return result;
  }

  ValueRequest._();

  factory ValueRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ValueRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..aOS(3, _omitFieldNames ? '' : 'valueId')
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(5, _omitFieldNames ? '' : 'maxBytes', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValueRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValueRequest copyWith(void Function(ValueRequest) updates) =>
      super.copyWith((message) => updates(message as ValueRequest))
          as ValueRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ValueRequest create() => ValueRequest._();
  @$core.override
  ValueRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ValueRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValueRequest>(create);
  static ValueRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get valueId => $_getSZ(2);
  @$pb.TagNumber(3)
  set valueId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValueId() => $_has(2);
  @$pb.TagNumber(3)
  void clearValueId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get offset => $_getI64(3);
  @$pb.TagNumber(4)
  set offset($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOffset() => $_has(3);
  @$pb.TagNumber(4)
  void clearOffset() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get maxBytes => $_getIZ(4);
  @$pb.TagNumber(5)
  set maxBytes($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMaxBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearMaxBytes() => $_clearField(5);
}

class ValueChunk extends $pb.GeneratedMessage {
  factory ValueChunk({
    $core.List<$core.int>? data,
    $fixnum.Int64? totalBytes,
    $core.bool? complete,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (complete != null) result.complete = complete;
    return result;
  }

  ValueChunk._();

  factory ValueChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ValueChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValueChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'totalBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(3, _omitFieldNames ? '' : 'complete')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValueChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValueChunk copyWith(void Function(ValueChunk) updates) =>
      super.copyWith((message) => updates(message as ValueChunk)) as ValueChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ValueChunk create() => ValueChunk._();
  @$core.override
  ValueChunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ValueChunk getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValueChunk>(create);
  static ValueChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set totalBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get complete => $_getBF(2);
  @$pb.TagNumber(3)
  set complete($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasComplete() => $_has(2);
  @$pb.TagNumber(3)
  void clearComplete() => $_clearField(3);
}

class Row extends $pb.GeneratedMessage {
  factory Row({
    $core.Iterable<Value>? values,
  }) {
    final result = create();
    if (values != null) result.values.addAll(values);
    return result;
  }

  Row._();

  factory Row.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Row.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Row',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<Value>(1, _omitFieldNames ? '' : 'values', subBuilder: Value.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Row clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Row copyWith(void Function(Row) updates) =>
      super.copyWith((message) => updates(message as Row)) as Row;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Row create() => Row._();
  @$core.override
  Row createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Row getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Row>(create);
  static Row? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Value> get values => $_getList(0);
}

class PageRequest extends $pb.GeneratedMessage {
  factory PageRequest({
    Context? context,
    $core.String? resultId,
    $fixnum.Int64? offset,
    $core.int? limit,
    $core.int? maxBytes,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (resultId != null) result.resultId = resultId;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    if (maxBytes != null) result.maxBytes = maxBytes;
    return result;
  }

  PageRequest._();

  factory PageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'maxBytes', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageRequest copyWith(void Function(PageRequest) updates) =>
      super.copyWith((message) => updates(message as PageRequest))
          as PageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PageRequest create() => PageRequest._();
  @$core.override
  PageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PageRequest>(create);
  static PageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get offset => $_getI64(2);
  @$pb.TagNumber(3)
  set offset($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffset() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get limit => $_getIZ(3);
  @$pb.TagNumber(4)
  set limit($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get maxBytes => $_getIZ(4);
  @$pb.TagNumber(5)
  set maxBytes($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMaxBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearMaxBytes() => $_clearField(5);
}

class CopySqlRequest extends $pb.GeneratedMessage {
  factory CopySqlRequest({
    Context? context,
    $core.String? resultId,
    $fixnum.Int64? firstRow,
    $core.int? rowCount,
    $core.int? firstColumn,
    $core.int? columnCount,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (resultId != null) result.resultId = resultId;
    if (firstRow != null) result.firstRow = firstRow;
    if (rowCount != null) result.rowCount = rowCount;
    if (firstColumn != null) result.firstColumn = firstColumn;
    if (columnCount != null) result.columnCount = columnCount;
    return result;
  }

  CopySqlRequest._();

  factory CopySqlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CopySqlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CopySqlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'firstRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'rowCount', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'firstColumn',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'columnCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopySqlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopySqlRequest copyWith(void Function(CopySqlRequest) updates) =>
      super.copyWith((message) => updates(message as CopySqlRequest))
          as CopySqlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CopySqlRequest create() => CopySqlRequest._();
  @$core.override
  CopySqlRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CopySqlRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CopySqlRequest>(create);
  static CopySqlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get firstRow => $_getI64(2);
  @$pb.TagNumber(3)
  set firstRow($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rowCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set rowCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRowCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRowCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get firstColumn => $_getIZ(4);
  @$pb.TagNumber(5)
  set firstColumn($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFirstColumn() => $_has(4);
  @$pb.TagNumber(5)
  void clearFirstColumn() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get columnCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set columnCount($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasColumnCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearColumnCount() => $_clearField(6);
}

class CopySqlReply extends $pb.GeneratedMessage {
  factory CopySqlReply({
    $core.String? text,
  }) {
    final result = create();
    if (text != null) result.text = text;
    return result;
  }

  CopySqlReply._();

  factory CopySqlReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CopySqlReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CopySqlReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopySqlReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopySqlReply copyWith(void Function(CopySqlReply) updates) =>
      super.copyWith((message) => updates(message as CopySqlReply))
          as CopySqlReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CopySqlReply create() => CopySqlReply._();
  @$core.override
  CopySqlReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CopySqlReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CopySqlReply>(create);
  static CopySqlReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

class Page extends $pb.GeneratedMessage {
  factory Page({
    $core.Iterable<Column>? columns,
    $core.Iterable<Row>? rows,
    $fixnum.Int64? fetchedRows,
    $core.bool? complete,
    $core.bool? limited,
    $fixnum.Int64? firstOffset,
    $fixnum.Int64? nextOffset,
    PageState? state,
    $core.String? availability,
    $core.Iterable<$fixnum.Int64>? sourceRows,
  }) {
    final result = create();
    if (columns != null) result.columns.addAll(columns);
    if (rows != null) result.rows.addAll(rows);
    if (fetchedRows != null) result.fetchedRows = fetchedRows;
    if (complete != null) result.complete = complete;
    if (limited != null) result.limited = limited;
    if (firstOffset != null) result.firstOffset = firstOffset;
    if (nextOffset != null) result.nextOffset = nextOffset;
    if (state != null) result.state = state;
    if (availability != null) result.availability = availability;
    if (sourceRows != null) result.sourceRows.addAll(sourceRows);
    return result;
  }

  Page._();

  factory Page.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Page.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Page',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<Column>(1, _omitFieldNames ? '' : 'columns',
        subBuilder: Column.create)
    ..pPM<Row>(2, _omitFieldNames ? '' : 'rows', subBuilder: Row.create)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'fetchedRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(4, _omitFieldNames ? '' : 'complete')
    ..aOB(5, _omitFieldNames ? '' : 'limited')
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'firstOffset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'nextOffset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<PageState>(8, _omitFieldNames ? '' : 'state',
        enumValues: PageState.values)
    ..aOS(9, _omitFieldNames ? '' : 'availability')
    ..p<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'sourceRows', $pb.PbFieldType.KU6)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page copyWith(void Function(Page) updates) =>
      super.copyWith((message) => updates(message as Page)) as Page;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Page create() => Page._();
  @$core.override
  Page createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Page getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Page>(create);
  static Page? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Column> get columns => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<Row> get rows => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get fetchedRows => $_getI64(2);
  @$pb.TagNumber(3)
  set fetchedRows($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFetchedRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearFetchedRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get complete => $_getBF(3);
  @$pb.TagNumber(4)
  set complete($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasComplete() => $_has(3);
  @$pb.TagNumber(4)
  void clearComplete() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get limited => $_getBF(4);
  @$pb.TagNumber(5)
  set limited($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLimited() => $_has(4);
  @$pb.TagNumber(5)
  void clearLimited() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get firstOffset => $_getI64(5);
  @$pb.TagNumber(6)
  set firstOffset($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFirstOffset() => $_has(5);
  @$pb.TagNumber(6)
  void clearFirstOffset() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get nextOffset => $_getI64(6);
  @$pb.TagNumber(7)
  set nextOffset($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNextOffset() => $_has(6);
  @$pb.TagNumber(7)
  void clearNextOffset() => $_clearField(7);

  @$pb.TagNumber(8)
  PageState get state => $_getN(7);
  @$pb.TagNumber(8)
  set state(PageState value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasState() => $_has(7);
  @$pb.TagNumber(8)
  void clearState() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get availability => $_getSZ(8);
  @$pb.TagNumber(9)
  set availability($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAvailability() => $_has(8);
  @$pb.TagNumber(9)
  void clearAvailability() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$fixnum.Int64> get sourceRows => $_getList(9);
}

class ResultViewRequest extends $pb.GeneratedMessage {
  factory ResultViewRequest({
    Context? context,
    $core.String? resultId,
    $core.String? viewId,
    $core.Iterable<RowCondition>? conditions,
    $core.Iterable<RowOrder>? order,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (resultId != null) result.resultId = resultId;
    if (viewId != null) result.viewId = viewId;
    if (conditions != null) result.conditions.addAll(conditions);
    if (order != null) result.order.addAll(order);
    return result;
  }

  ResultViewRequest._();

  factory ResultViewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResultViewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResultViewRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..aOS(3, _omitFieldNames ? '' : 'viewId')
    ..pPM<RowCondition>(4, _omitFieldNames ? '' : 'conditions',
        subBuilder: RowCondition.create)
    ..pPM<RowOrder>(5, _omitFieldNames ? '' : 'order',
        subBuilder: RowOrder.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultViewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultViewRequest copyWith(void Function(ResultViewRequest) updates) =>
      super.copyWith((message) => updates(message as ResultViewRequest))
          as ResultViewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResultViewRequest create() => ResultViewRequest._();
  @$core.override
  ResultViewRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResultViewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResultViewRequest>(create);
  static ResultViewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get viewId => $_getSZ(2);
  @$pb.TagNumber(3)
  set viewId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasViewId() => $_has(2);
  @$pb.TagNumber(3)
  void clearViewId() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RowCondition> get conditions => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<RowOrder> get order => $_getList(4);
}

class ResultViewInfo extends $pb.GeneratedMessage {
  factory ResultViewInfo({
    $core.String? viewId,
    $core.String? resultId,
    $fixnum.Int64? sourceRows,
    $fixnum.Int64? visibleRows,
    $core.bool? partial,
    $core.String? availability,
  }) {
    final result = create();
    if (viewId != null) result.viewId = viewId;
    if (resultId != null) result.resultId = resultId;
    if (sourceRows != null) result.sourceRows = sourceRows;
    if (visibleRows != null) result.visibleRows = visibleRows;
    if (partial != null) result.partial = partial;
    if (availability != null) result.availability = availability;
    return result;
  }

  ResultViewInfo._();

  factory ResultViewInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResultViewInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResultViewInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'viewId')
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'sourceRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'visibleRows', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(5, _omitFieldNames ? '' : 'partial')
    ..aOS(6, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultViewInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultViewInfo copyWith(void Function(ResultViewInfo) updates) =>
      super.copyWith((message) => updates(message as ResultViewInfo))
          as ResultViewInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResultViewInfo create() => ResultViewInfo._();
  @$core.override
  ResultViewInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResultViewInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResultViewInfo>(create);
  static ResultViewInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get viewId => $_getSZ(0);
  @$pb.TagNumber(1)
  set viewId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasViewId() => $_has(0);
  @$pb.TagNumber(1)
  void clearViewId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sourceRows => $_getI64(2);
  @$pb.TagNumber(3)
  set sourceRows($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSourceRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearSourceRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get visibleRows => $_getI64(3);
  @$pb.TagNumber(4)
  set visibleRows($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVisibleRows() => $_has(3);
  @$pb.TagNumber(4)
  void clearVisibleRows() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get partial => $_getBF(4);
  @$pb.TagNumber(5)
  set partial($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPartial() => $_has(4);
  @$pb.TagNumber(5)
  void clearPartial() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get availability => $_getSZ(5);
  @$pb.TagNumber(6)
  set availability($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAvailability() => $_has(5);
  @$pb.TagNumber(6)
  void clearAvailability() => $_clearField(6);
}

class InspectionSetting extends $pb.GeneratedMessage {
  factory InspectionSetting({
    $core.String? code,
    $core.bool? enabled,
    $core.String? severity,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (enabled != null) result.enabled = enabled;
    if (severity != null) result.severity = severity;
    return result;
  }

  InspectionSetting._();

  factory InspectionSetting.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InspectionSetting.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InspectionSetting',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOB(2, _omitFieldNames ? '' : 'enabled')
    ..aOS(3, _omitFieldNames ? '' : 'severity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InspectionSetting clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InspectionSetting copyWith(void Function(InspectionSetting) updates) =>
      super.copyWith((message) => updates(message as InspectionSetting))
          as InspectionSetting;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InspectionSetting create() => InspectionSetting._();
  @$core.override
  InspectionSetting createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InspectionSetting getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InspectionSetting>(create);
  static InspectionSetting? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get enabled => $_getBF(1);
  @$pb.TagNumber(2)
  set enabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get severity => $_getSZ(2);
  @$pb.TagNumber(3)
  set severity($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSeverity() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeverity() => $_clearField(3);
}

class FormatSettings extends $pb.GeneratedMessage {
  factory FormatSettings({
    $core.String? keywordCase,
    $core.int? indentationWidth,
    $core.int? continuationIndent,
    $core.bool? clauseLineBreaks,
    $core.String? joinLayout,
    $core.String? commaPlacement,
    $core.String? logicalOperatorPlacement,
    $core.bool? wrapLists,
    $core.bool? wrapArguments,
    $core.bool? indentSubqueries,
    $core.bool? cteLineBreaks,
    $core.bool? parenthesisSpacing,
    $core.bool? operatorSpacing,
    $core.bool? alignment,
    $core.int? maxLineLength,
    $core.bool? preserveBlankLines,
    $core.int? startUtf16,
    $core.int? endUtf16,
  }) {
    final result = create();
    if (keywordCase != null) result.keywordCase = keywordCase;
    if (indentationWidth != null) result.indentationWidth = indentationWidth;
    if (continuationIndent != null)
      result.continuationIndent = continuationIndent;
    if (clauseLineBreaks != null) result.clauseLineBreaks = clauseLineBreaks;
    if (joinLayout != null) result.joinLayout = joinLayout;
    if (commaPlacement != null) result.commaPlacement = commaPlacement;
    if (logicalOperatorPlacement != null)
      result.logicalOperatorPlacement = logicalOperatorPlacement;
    if (wrapLists != null) result.wrapLists = wrapLists;
    if (wrapArguments != null) result.wrapArguments = wrapArguments;
    if (indentSubqueries != null) result.indentSubqueries = indentSubqueries;
    if (cteLineBreaks != null) result.cteLineBreaks = cteLineBreaks;
    if (parenthesisSpacing != null)
      result.parenthesisSpacing = parenthesisSpacing;
    if (operatorSpacing != null) result.operatorSpacing = operatorSpacing;
    if (alignment != null) result.alignment = alignment;
    if (maxLineLength != null) result.maxLineLength = maxLineLength;
    if (preserveBlankLines != null)
      result.preserveBlankLines = preserveBlankLines;
    if (startUtf16 != null) result.startUtf16 = startUtf16;
    if (endUtf16 != null) result.endUtf16 = endUtf16;
    return result;
  }

  FormatSettings._();

  factory FormatSettings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FormatSettings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatSettings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'keywordCase')
    ..aI(2, _omitFieldNames ? '' : 'indentationWidth',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'continuationIndent',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'clauseLineBreaks')
    ..aOS(5, _omitFieldNames ? '' : 'joinLayout')
    ..aOS(6, _omitFieldNames ? '' : 'commaPlacement')
    ..aOS(7, _omitFieldNames ? '' : 'logicalOperatorPlacement')
    ..aOB(8, _omitFieldNames ? '' : 'wrapLists')
    ..aOB(9, _omitFieldNames ? '' : 'wrapArguments')
    ..aOB(10, _omitFieldNames ? '' : 'indentSubqueries')
    ..aOB(11, _omitFieldNames ? '' : 'cteLineBreaks')
    ..aOB(12, _omitFieldNames ? '' : 'parenthesisSpacing')
    ..aOB(13, _omitFieldNames ? '' : 'operatorSpacing')
    ..aOB(14, _omitFieldNames ? '' : 'alignment')
    ..aI(15, _omitFieldNames ? '' : 'maxLineLength',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(16, _omitFieldNames ? '' : 'preserveBlankLines')
    ..aI(17, _omitFieldNames ? '' : 'startUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(18, _omitFieldNames ? '' : 'endUtf16', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatSettings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatSettings copyWith(void Function(FormatSettings) updates) =>
      super.copyWith((message) => updates(message as FormatSettings))
          as FormatSettings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FormatSettings create() => FormatSettings._();
  @$core.override
  FormatSettings createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FormatSettings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FormatSettings>(create);
  static FormatSettings? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get keywordCase => $_getSZ(0);
  @$pb.TagNumber(1)
  set keywordCase($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeywordCase() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeywordCase() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get indentationWidth => $_getIZ(1);
  @$pb.TagNumber(2)
  set indentationWidth($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIndentationWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearIndentationWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get continuationIndent => $_getIZ(2);
  @$pb.TagNumber(3)
  set continuationIndent($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContinuationIndent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContinuationIndent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get clauseLineBreaks => $_getBF(3);
  @$pb.TagNumber(4)
  set clauseLineBreaks($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasClauseLineBreaks() => $_has(3);
  @$pb.TagNumber(4)
  void clearClauseLineBreaks() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get joinLayout => $_getSZ(4);
  @$pb.TagNumber(5)
  set joinLayout($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasJoinLayout() => $_has(4);
  @$pb.TagNumber(5)
  void clearJoinLayout() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get commaPlacement => $_getSZ(5);
  @$pb.TagNumber(6)
  set commaPlacement($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCommaPlacement() => $_has(5);
  @$pb.TagNumber(6)
  void clearCommaPlacement() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get logicalOperatorPlacement => $_getSZ(6);
  @$pb.TagNumber(7)
  set logicalOperatorPlacement($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLogicalOperatorPlacement() => $_has(6);
  @$pb.TagNumber(7)
  void clearLogicalOperatorPlacement() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get wrapLists => $_getBF(7);
  @$pb.TagNumber(8)
  set wrapLists($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWrapLists() => $_has(7);
  @$pb.TagNumber(8)
  void clearWrapLists() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get wrapArguments => $_getBF(8);
  @$pb.TagNumber(9)
  set wrapArguments($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasWrapArguments() => $_has(8);
  @$pb.TagNumber(9)
  void clearWrapArguments() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get indentSubqueries => $_getBF(9);
  @$pb.TagNumber(10)
  set indentSubqueries($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIndentSubqueries() => $_has(9);
  @$pb.TagNumber(10)
  void clearIndentSubqueries() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get cteLineBreaks => $_getBF(10);
  @$pb.TagNumber(11)
  set cteLineBreaks($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCteLineBreaks() => $_has(10);
  @$pb.TagNumber(11)
  void clearCteLineBreaks() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get parenthesisSpacing => $_getBF(11);
  @$pb.TagNumber(12)
  set parenthesisSpacing($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasParenthesisSpacing() => $_has(11);
  @$pb.TagNumber(12)
  void clearParenthesisSpacing() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get operatorSpacing => $_getBF(12);
  @$pb.TagNumber(13)
  set operatorSpacing($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasOperatorSpacing() => $_has(12);
  @$pb.TagNumber(13)
  void clearOperatorSpacing() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get alignment => $_getBF(13);
  @$pb.TagNumber(14)
  set alignment($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasAlignment() => $_has(13);
  @$pb.TagNumber(14)
  void clearAlignment() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get maxLineLength => $_getIZ(14);
  @$pb.TagNumber(15)
  set maxLineLength($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasMaxLineLength() => $_has(14);
  @$pb.TagNumber(15)
  void clearMaxLineLength() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get preserveBlankLines => $_getBF(15);
  @$pb.TagNumber(16)
  set preserveBlankLines($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasPreserveBlankLines() => $_has(15);
  @$pb.TagNumber(16)
  void clearPreserveBlankLines() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get startUtf16 => $_getIZ(16);
  @$pb.TagNumber(17)
  set startUtf16($core.int value) => $_setUnsignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasStartUtf16() => $_has(16);
  @$pb.TagNumber(17)
  void clearStartUtf16() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get endUtf16 => $_getIZ(17);
  @$pb.TagNumber(18)
  set endUtf16($core.int value) => $_setUnsignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasEndUtf16() => $_has(17);
  @$pb.TagNumber(18)
  void clearEndUtf16() => $_clearField(18);
}

class AnalysisRequest extends $pb.GeneratedMessage {
  factory AnalysisRequest({
    Context? context,
    $core.String? documentId,
    $fixnum.Int64? documentVersion,
    $core.String? sql,
    $core.int? caretUtf16,
    $core.String? sessionId,
    Engine? engine,
    $fixnum.Int64? contextRevision,
    $fixnum.Int64? sessionRevision,
    AnalysisOperation? operation,
    $fixnum.Int64? metadataSnapshotRevision,
    $fixnum.Int64? metadataConfigurationRevision,
    FormatSettings? formatSettings,
    $core.Iterable<InspectionSetting>? inspections,
    $core.bool? formatCurrentStatement,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? snippets,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (documentId != null) result.documentId = documentId;
    if (documentVersion != null) result.documentVersion = documentVersion;
    if (sql != null) result.sql = sql;
    if (caretUtf16 != null) result.caretUtf16 = caretUtf16;
    if (sessionId != null) result.sessionId = sessionId;
    if (engine != null) result.engine = engine;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (operation != null) result.operation = operation;
    if (metadataSnapshotRevision != null)
      result.metadataSnapshotRevision = metadataSnapshotRevision;
    if (metadataConfigurationRevision != null)
      result.metadataConfigurationRevision = metadataConfigurationRevision;
    if (formatSettings != null) result.formatSettings = formatSettings;
    if (inspections != null) result.inspections.addAll(inspections);
    if (formatCurrentStatement != null)
      result.formatCurrentStatement = formatCurrentStatement;
    if (snippets != null) result.snippets.addEntries(snippets);
    return result;
  }

  AnalysisRequest._();

  factory AnalysisRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnalysisRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnalysisRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'documentId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'documentVersion', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'sql')
    ..aI(5, _omitFieldNames ? '' : 'caretUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'sessionId')
    ..aE<Engine>(7, _omitFieldNames ? '' : 'engine', enumValues: Engine.values)
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<AnalysisOperation>(11, _omitFieldNames ? '' : 'operation',
        enumValues: AnalysisOperation.values)
    ..a<$fixnum.Int64>(12, _omitFieldNames ? '' : 'metadataSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        13,
        _omitFieldNames ? '' : 'metadataConfigurationRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<FormatSettings>(14, _omitFieldNames ? '' : 'formatSettings',
        subBuilder: FormatSettings.create)
    ..pPM<InspectionSetting>(15, _omitFieldNames ? '' : 'inspections',
        subBuilder: InspectionSetting.create)
    ..aOB(16, _omitFieldNames ? '' : 'formatCurrentStatement')
    ..m<$core.String, $core.String>(17, _omitFieldNames ? '' : 'snippets',
        entryClassName: 'AnalysisRequest.SnippetsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('busydata.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalysisRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalysisRequest copyWith(void Function(AnalysisRequest) updates) =>
      super.copyWith((message) => updates(message as AnalysisRequest))
          as AnalysisRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnalysisRequest create() => AnalysisRequest._();
  @$core.override
  AnalysisRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnalysisRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnalysisRequest>(create);
  static AnalysisRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get documentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set documentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDocumentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDocumentId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get documentVersion => $_getI64(2);
  @$pb.TagNumber(3)
  set documentVersion($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDocumentVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearDocumentVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sql => $_getSZ(3);
  @$pb.TagNumber(4)
  set sql($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSql() => $_has(3);
  @$pb.TagNumber(4)
  void clearSql() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get caretUtf16 => $_getIZ(4);
  @$pb.TagNumber(5)
  set caretUtf16($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCaretUtf16() => $_has(4);
  @$pb.TagNumber(5)
  void clearCaretUtf16() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get sessionId => $_getSZ(5);
  @$pb.TagNumber(6)
  set sessionId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSessionId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSessionId() => $_clearField(6);

  @$pb.TagNumber(7)
  Engine get engine => $_getN(6);
  @$pb.TagNumber(7)
  set engine(Engine value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasEngine() => $_has(6);
  @$pb.TagNumber(7)
  void clearEngine() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get contextRevision => $_getI64(7);
  @$pb.TagNumber(8)
  set contextRevision($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasContextRevision() => $_has(7);
  @$pb.TagNumber(8)
  void clearContextRevision() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get sessionRevision => $_getI64(8);
  @$pb.TagNumber(9)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionRevision() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionRevision() => $_clearField(9);

  @$pb.TagNumber(11)
  AnalysisOperation get operation => $_getN(9);
  @$pb.TagNumber(11)
  set operation(AnalysisOperation value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasOperation() => $_has(9);
  @$pb.TagNumber(11)
  void clearOperation() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get metadataSnapshotRevision => $_getI64(10);
  @$pb.TagNumber(12)
  set metadataSnapshotRevision($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(12)
  $core.bool hasMetadataSnapshotRevision() => $_has(10);
  @$pb.TagNumber(12)
  void clearMetadataSnapshotRevision() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get metadataConfigurationRevision => $_getI64(11);
  @$pb.TagNumber(13)
  set metadataConfigurationRevision($fixnum.Int64 value) =>
      $_setInt64(11, value);
  @$pb.TagNumber(13)
  $core.bool hasMetadataConfigurationRevision() => $_has(11);
  @$pb.TagNumber(13)
  void clearMetadataConfigurationRevision() => $_clearField(13);

  @$pb.TagNumber(14)
  FormatSettings get formatSettings => $_getN(12);
  @$pb.TagNumber(14)
  set formatSettings(FormatSettings value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasFormatSettings() => $_has(12);
  @$pb.TagNumber(14)
  void clearFormatSettings() => $_clearField(14);
  @$pb.TagNumber(14)
  FormatSettings ensureFormatSettings() => $_ensure(12);

  @$pb.TagNumber(15)
  $pb.PbList<InspectionSetting> get inspections => $_getList(13);

  @$pb.TagNumber(16)
  $core.bool get formatCurrentStatement => $_getBF(14);
  @$pb.TagNumber(16)
  set formatCurrentStatement($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(16)
  $core.bool hasFormatCurrentStatement() => $_has(14);
  @$pb.TagNumber(16)
  void clearFormatCurrentStatement() => $_clearField(16);

  @$pb.TagNumber(17)
  $pb.PbMap<$core.String, $core.String> get snippets => $_getMap(15);
}

class Span extends $pb.GeneratedMessage {
  factory Span({
    $core.int? startUtf16,
    $core.int? endUtf16,
    $core.String? text,
    $core.bool? supported,
  }) {
    final result = create();
    if (startUtf16 != null) result.startUtf16 = startUtf16;
    if (endUtf16 != null) result.endUtf16 = endUtf16;
    if (text != null) result.text = text;
    if (supported != null) result.supported = supported;
    return result;
  }

  Span._();

  factory Span.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Span.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Span',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'startUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'endUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOB(4, _omitFieldNames ? '' : 'supported')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Span clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Span copyWith(void Function(Span) updates) =>
      super.copyWith((message) => updates(message as Span)) as Span;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Span create() => Span._();
  @$core.override
  Span createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Span getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Span>(create);
  static Span? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get startUtf16 => $_getIZ(0);
  @$pb.TagNumber(1)
  set startUtf16($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartUtf16() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartUtf16() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get endUtf16 => $_getIZ(1);
  @$pb.TagNumber(2)
  set endUtf16($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndUtf16() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndUtf16() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get supported => $_getBF(3);
  @$pb.TagNumber(4)
  set supported($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSupported() => $_has(3);
  @$pb.TagNumber(4)
  void clearSupported() => $_clearField(4);
}

class Diagnostic extends $pb.GeneratedMessage {
  factory Diagnostic({
    $core.int? startUtf16,
    $core.int? endUtf16,
    $core.String? message,
    $core.String? severity,
    $core.String? code,
    $core.String? source,
    $core.bool? incomplete,
    $core.Iterable<Span>? related,
    $core.Iterable<QuickFix>? fixes,
    Engine? engine,
  }) {
    final result = create();
    if (startUtf16 != null) result.startUtf16 = startUtf16;
    if (endUtf16 != null) result.endUtf16 = endUtf16;
    if (message != null) result.message = message;
    if (severity != null) result.severity = severity;
    if (code != null) result.code = code;
    if (source != null) result.source = source;
    if (incomplete != null) result.incomplete = incomplete;
    if (related != null) result.related.addAll(related);
    if (fixes != null) result.fixes.addAll(fixes);
    if (engine != null) result.engine = engine;
    return result;
  }

  Diagnostic._();

  factory Diagnostic.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Diagnostic.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Diagnostic',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'startUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'endUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..aOS(4, _omitFieldNames ? '' : 'severity')
    ..aOS(5, _omitFieldNames ? '' : 'code')
    ..aOS(6, _omitFieldNames ? '' : 'source')
    ..aOB(7, _omitFieldNames ? '' : 'incomplete')
    ..pPM<Span>(8, _omitFieldNames ? '' : 'related', subBuilder: Span.create)
    ..pPM<QuickFix>(9, _omitFieldNames ? '' : 'fixes',
        subBuilder: QuickFix.create)
    ..aE<Engine>(10, _omitFieldNames ? '' : 'engine', enumValues: Engine.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Diagnostic clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Diagnostic copyWith(void Function(Diagnostic) updates) =>
      super.copyWith((message) => updates(message as Diagnostic)) as Diagnostic;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Diagnostic create() => Diagnostic._();
  @$core.override
  Diagnostic createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Diagnostic getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Diagnostic>(create);
  static Diagnostic? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get startUtf16 => $_getIZ(0);
  @$pb.TagNumber(1)
  set startUtf16($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartUtf16() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartUtf16() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get endUtf16 => $_getIZ(1);
  @$pb.TagNumber(2)
  set endUtf16($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndUtf16() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndUtf16() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get severity => $_getSZ(3);
  @$pb.TagNumber(4)
  set severity($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSeverity() => $_has(3);
  @$pb.TagNumber(4)
  void clearSeverity() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get code => $_getSZ(4);
  @$pb.TagNumber(5)
  set code($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get source => $_getSZ(5);
  @$pb.TagNumber(6)
  set source($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSource() => $_has(5);
  @$pb.TagNumber(6)
  void clearSource() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get incomplete => $_getBF(6);
  @$pb.TagNumber(7)
  set incomplete($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIncomplete() => $_has(6);
  @$pb.TagNumber(7)
  void clearIncomplete() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<Span> get related => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<QuickFix> get fixes => $_getList(8);

  @$pb.TagNumber(10)
  Engine get engine => $_getN(9);
  @$pb.TagNumber(10)
  set engine(Engine value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasEngine() => $_has(9);
  @$pb.TagNumber(10)
  void clearEngine() => $_clearField(10);
}

class QuickFix extends $pb.GeneratedMessage {
  factory QuickFix({
    $core.String? label,
    $core.int? startUtf16,
    $core.int? endUtf16,
    $core.String? replacement,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (startUtf16 != null) result.startUtf16 = startUtf16;
    if (endUtf16 != null) result.endUtf16 = endUtf16;
    if (replacement != null) result.replacement = replacement;
    return result;
  }

  QuickFix._();

  factory QuickFix.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuickFix.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuickFix',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aI(2, _omitFieldNames ? '' : 'startUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'endUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'replacement')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuickFix clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuickFix copyWith(void Function(QuickFix) updates) =>
      super.copyWith((message) => updates(message as QuickFix)) as QuickFix;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuickFix create() => QuickFix._();
  @$core.override
  QuickFix createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuickFix getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QuickFix>(create);
  static QuickFix? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get startUtf16 => $_getIZ(1);
  @$pb.TagNumber(2)
  set startUtf16($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartUtf16() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartUtf16() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get endUtf16 => $_getIZ(2);
  @$pb.TagNumber(3)
  set endUtf16($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEndUtf16() => $_has(2);
  @$pb.TagNumber(3)
  void clearEndUtf16() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get replacement => $_getSZ(3);
  @$pb.TagNumber(4)
  set replacement($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReplacement() => $_has(3);
  @$pb.TagNumber(4)
  void clearReplacement() => $_clearField(4);
}

class Completion extends $pb.GeneratedMessage {
  factory Completion({
    $core.String? label,
    $core.String? insertText,
    $core.String? kind,
    $core.int? startUtf16,
    $core.int? endUtf16,
    $core.String? detail,
    $core.String? targetIdentity,
    $core.int? rank,
    $core.bool? qualificationRequired,
    $core.bool? quoted,
    $core.String? documentation,
    $core.Iterable<$core.String>? commitCharacters,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (insertText != null) result.insertText = insertText;
    if (kind != null) result.kind = kind;
    if (startUtf16 != null) result.startUtf16 = startUtf16;
    if (endUtf16 != null) result.endUtf16 = endUtf16;
    if (detail != null) result.detail = detail;
    if (targetIdentity != null) result.targetIdentity = targetIdentity;
    if (rank != null) result.rank = rank;
    if (qualificationRequired != null)
      result.qualificationRequired = qualificationRequired;
    if (quoted != null) result.quoted = quoted;
    if (documentation != null) result.documentation = documentation;
    if (commitCharacters != null)
      result.commitCharacters.addAll(commitCharacters);
    return result;
  }

  Completion._();

  factory Completion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Completion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Completion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aOS(2, _omitFieldNames ? '' : 'insertText')
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..aI(4, _omitFieldNames ? '' : 'startUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'endUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'detail')
    ..aOS(7, _omitFieldNames ? '' : 'targetIdentity')
    ..aI(8, _omitFieldNames ? '' : 'rank', fieldType: $pb.PbFieldType.OS3)
    ..aOB(9, _omitFieldNames ? '' : 'qualificationRequired')
    ..aOB(10, _omitFieldNames ? '' : 'quoted')
    ..aOS(11, _omitFieldNames ? '' : 'documentation')
    ..pPS(12, _omitFieldNames ? '' : 'commitCharacters')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Completion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Completion copyWith(void Function(Completion) updates) =>
      super.copyWith((message) => updates(message as Completion)) as Completion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Completion create() => Completion._();
  @$core.override
  Completion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Completion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Completion>(create);
  static Completion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get insertText => $_getSZ(1);
  @$pb.TagNumber(2)
  set insertText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInsertText() => $_has(1);
  @$pb.TagNumber(2)
  void clearInsertText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get startUtf16 => $_getIZ(3);
  @$pb.TagNumber(4)
  set startUtf16($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStartUtf16() => $_has(3);
  @$pb.TagNumber(4)
  void clearStartUtf16() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get endUtf16 => $_getIZ(4);
  @$pb.TagNumber(5)
  set endUtf16($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEndUtf16() => $_has(4);
  @$pb.TagNumber(5)
  void clearEndUtf16() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get detail => $_getSZ(5);
  @$pb.TagNumber(6)
  set detail($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDetail() => $_has(5);
  @$pb.TagNumber(6)
  void clearDetail() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get targetIdentity => $_getSZ(6);
  @$pb.TagNumber(7)
  set targetIdentity($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTargetIdentity() => $_has(6);
  @$pb.TagNumber(7)
  void clearTargetIdentity() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get rank => $_getIZ(7);
  @$pb.TagNumber(8)
  set rank($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRank() => $_has(7);
  @$pb.TagNumber(8)
  void clearRank() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get qualificationRequired => $_getBF(8);
  @$pb.TagNumber(9)
  set qualificationRequired($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasQualificationRequired() => $_has(8);
  @$pb.TagNumber(9)
  void clearQualificationRequired() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get quoted => $_getBF(9);
  @$pb.TagNumber(10)
  set quoted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasQuoted() => $_has(9);
  @$pb.TagNumber(10)
  void clearQuoted() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get documentation => $_getSZ(10);
  @$pb.TagNumber(11)
  set documentation($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasDocumentation() => $_has(10);
  @$pb.TagNumber(11)
  void clearDocumentation() => $_clearField(11);

  @$pb.TagNumber(12)
  $pb.PbList<$core.String> get commitCharacters => $_getList(11);
}

/// Token-preserving formatting maps full-document UTF-16 positions, including
/// literal/comment whitespace. Gaps map to the next token without changing SQL.
class FormatToken extends $pb.GeneratedMessage {
  factory FormatToken({
    $core.int? sourceStartUtf16,
    $core.int? sourceEndUtf16,
    $core.int? formattedStartUtf16,
  }) {
    final result = create();
    if (sourceStartUtf16 != null) result.sourceStartUtf16 = sourceStartUtf16;
    if (sourceEndUtf16 != null) result.sourceEndUtf16 = sourceEndUtf16;
    if (formattedStartUtf16 != null)
      result.formattedStartUtf16 = formattedStartUtf16;
    return result;
  }

  FormatToken._();

  factory FormatToken.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FormatToken.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatToken',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'sourceStartUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'sourceEndUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'formattedStartUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatToken clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatToken copyWith(void Function(FormatToken) updates) =>
      super.copyWith((message) => updates(message as FormatToken))
          as FormatToken;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FormatToken create() => FormatToken._();
  @$core.override
  FormatToken createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FormatToken getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FormatToken>(create);
  static FormatToken? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sourceStartUtf16 => $_getIZ(0);
  @$pb.TagNumber(1)
  set sourceStartUtf16($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceStartUtf16() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceStartUtf16() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sourceEndUtf16 => $_getIZ(1);
  @$pb.TagNumber(2)
  set sourceEndUtf16($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceEndUtf16() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceEndUtf16() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get formattedStartUtf16 => $_getIZ(2);
  @$pb.TagNumber(3)
  set formattedStartUtf16($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFormattedStartUtf16() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormattedStartUtf16() => $_clearField(3);
}

class ResolvedSymbol extends $pb.GeneratedMessage {
  factory ResolvedSymbol({
    Span? span,
    $core.Iterable<SchemaObject>? candidates,
    $core.bool? complete,
    $core.String? availability,
    $core.String? catalog,
    $core.String? schema,
    $core.String? profileId,
  }) {
    final result = create();
    if (span != null) result.span = span;
    if (candidates != null) result.candidates.addAll(candidates);
    if (complete != null) result.complete = complete;
    if (availability != null) result.availability = availability;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (profileId != null) result.profileId = profileId;
    return result;
  }

  ResolvedSymbol._();

  factory ResolvedSymbol.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolvedSymbol.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolvedSymbol',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Span>(1, _omitFieldNames ? '' : 'span', subBuilder: Span.create)
    ..pPM<SchemaObject>(2, _omitFieldNames ? '' : 'candidates',
        subBuilder: SchemaObject.create)
    ..aOB(3, _omitFieldNames ? '' : 'complete')
    ..aOS(4, _omitFieldNames ? '' : 'availability')
    ..aOS(5, _omitFieldNames ? '' : 'catalog')
    ..aOS(6, _omitFieldNames ? '' : 'schema')
    ..aOS(7, _omitFieldNames ? '' : 'profileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolvedSymbol clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolvedSymbol copyWith(void Function(ResolvedSymbol) updates) =>
      super.copyWith((message) => updates(message as ResolvedSymbol))
          as ResolvedSymbol;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResolvedSymbol create() => ResolvedSymbol._();
  @$core.override
  ResolvedSymbol createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolvedSymbol getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolvedSymbol>(create);
  static ResolvedSymbol? _defaultInstance;

  @$pb.TagNumber(1)
  Span get span => $_getN(0);
  @$pb.TagNumber(1)
  set span(Span value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSpan() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpan() => $_clearField(1);
  @$pb.TagNumber(1)
  Span ensureSpan() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<SchemaObject> get candidates => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get complete => $_getBF(2);
  @$pb.TagNumber(3)
  set complete($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasComplete() => $_has(2);
  @$pb.TagNumber(3)
  void clearComplete() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get availability => $_getSZ(3);
  @$pb.TagNumber(4)
  set availability($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvailability() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvailability() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get catalog => $_getSZ(4);
  @$pb.TagNumber(5)
  set catalog($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCatalog() => $_has(4);
  @$pb.TagNumber(5)
  void clearCatalog() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get schema => $_getSZ(5);
  @$pb.TagNumber(6)
  set schema($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSchema() => $_has(5);
  @$pb.TagNumber(6)
  void clearSchema() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get profileId => $_getSZ(6);
  @$pb.TagNumber(7)
  set profileId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProfileId() => $_has(6);
  @$pb.TagNumber(7)
  void clearProfileId() => $_clearField(7);
}

class Analysis extends $pb.GeneratedMessage {
  factory Analysis({
    $core.String? documentId,
    $fixnum.Int64? documentVersion,
    $core.Iterable<Span>? statements,
    $core.Iterable<Diagnostic>? diagnostics,
    $core.Iterable<Completion>? completions,
    $core.String? formattedSql,
    $core.String? backendInstance,
    $core.String? sessionId,
    $fixnum.Int64? contextRevision,
    $core.int? caretUtf16,
    $fixnum.Int64? sessionRevision,
    $core.Iterable<FormatToken>? formatTokens,
    ResolvedSymbol? symbol,
    AnalysisOperation? operation,
    $fixnum.Int64? metadataSnapshotRevision,
    $fixnum.Int64? metadataConfigurationRevision,
    ParameterInformation? parameterInformation,
    $core.Iterable<DdlEffect>? ddlEffects,
    $core.String? availability,
    $core.bool? completionLimited,
    $core.String? metadataSourceIdentity,
  }) {
    final result = create();
    if (documentId != null) result.documentId = documentId;
    if (documentVersion != null) result.documentVersion = documentVersion;
    if (statements != null) result.statements.addAll(statements);
    if (diagnostics != null) result.diagnostics.addAll(diagnostics);
    if (completions != null) result.completions.addAll(completions);
    if (formattedSql != null) result.formattedSql = formattedSql;
    if (backendInstance != null) result.backendInstance = backendInstance;
    if (sessionId != null) result.sessionId = sessionId;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (caretUtf16 != null) result.caretUtf16 = caretUtf16;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (formatTokens != null) result.formatTokens.addAll(formatTokens);
    if (symbol != null) result.symbol = symbol;
    if (operation != null) result.operation = operation;
    if (metadataSnapshotRevision != null)
      result.metadataSnapshotRevision = metadataSnapshotRevision;
    if (metadataConfigurationRevision != null)
      result.metadataConfigurationRevision = metadataConfigurationRevision;
    if (parameterInformation != null)
      result.parameterInformation = parameterInformation;
    if (ddlEffects != null) result.ddlEffects.addAll(ddlEffects);
    if (availability != null) result.availability = availability;
    if (completionLimited != null) result.completionLimited = completionLimited;
    if (metadataSourceIdentity != null)
      result.metadataSourceIdentity = metadataSourceIdentity;
    return result;
  }

  Analysis._();

  factory Analysis.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Analysis.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Analysis',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'documentId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'documentVersion', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<Span>(3, _omitFieldNames ? '' : 'statements', subBuilder: Span.create)
    ..pPM<Diagnostic>(4, _omitFieldNames ? '' : 'diagnostics',
        subBuilder: Diagnostic.create)
    ..pPM<Completion>(5, _omitFieldNames ? '' : 'completions',
        subBuilder: Completion.create)
    ..aOS(6, _omitFieldNames ? '' : 'formattedSql')
    ..aOS(7, _omitFieldNames ? '' : 'backendInstance')
    ..aOS(8, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(10, _omitFieldNames ? '' : 'caretUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<FormatToken>(12, _omitFieldNames ? '' : 'formatTokens',
        subBuilder: FormatToken.create)
    ..aOM<ResolvedSymbol>(13, _omitFieldNames ? '' : 'symbol',
        subBuilder: ResolvedSymbol.create)
    ..aE<AnalysisOperation>(14, _omitFieldNames ? '' : 'operation',
        enumValues: AnalysisOperation.values)
    ..a<$fixnum.Int64>(15, _omitFieldNames ? '' : 'metadataSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        16,
        _omitFieldNames ? '' : 'metadataConfigurationRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<ParameterInformation>(
        17, _omitFieldNames ? '' : 'parameterInformation',
        subBuilder: ParameterInformation.create)
    ..pPM<DdlEffect>(18, _omitFieldNames ? '' : 'ddlEffects',
        subBuilder: DdlEffect.create)
    ..aOS(19, _omitFieldNames ? '' : 'availability')
    ..aOB(20, _omitFieldNames ? '' : 'completionLimited')
    ..aOS(21, _omitFieldNames ? '' : 'metadataSourceIdentity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Analysis clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Analysis copyWith(void Function(Analysis) updates) =>
      super.copyWith((message) => updates(message as Analysis)) as Analysis;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Analysis create() => Analysis._();
  @$core.override
  Analysis createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Analysis getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Analysis>(create);
  static Analysis? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get documentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set documentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDocumentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocumentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get documentVersion => $_getI64(1);
  @$pb.TagNumber(2)
  set documentVersion($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDocumentVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearDocumentVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<Span> get statements => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<Diagnostic> get diagnostics => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<Completion> get completions => $_getList(4);

  @$pb.TagNumber(6)
  $core.String get formattedSql => $_getSZ(5);
  @$pb.TagNumber(6)
  set formattedSql($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFormattedSql() => $_has(5);
  @$pb.TagNumber(6)
  void clearFormattedSql() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get backendInstance => $_getSZ(6);
  @$pb.TagNumber(7)
  set backendInstance($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBackendInstance() => $_has(6);
  @$pb.TagNumber(7)
  void clearBackendInstance() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sessionId => $_getSZ(7);
  @$pb.TagNumber(8)
  set sessionId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSessionId() => $_has(7);
  @$pb.TagNumber(8)
  void clearSessionId() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get contextRevision => $_getI64(8);
  @$pb.TagNumber(9)
  set contextRevision($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasContextRevision() => $_has(8);
  @$pb.TagNumber(9)
  void clearContextRevision() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get caretUtf16 => $_getIZ(9);
  @$pb.TagNumber(10)
  set caretUtf16($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCaretUtf16() => $_has(9);
  @$pb.TagNumber(10)
  void clearCaretUtf16() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get sessionRevision => $_getI64(10);
  @$pb.TagNumber(11)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSessionRevision() => $_has(10);
  @$pb.TagNumber(11)
  void clearSessionRevision() => $_clearField(11);

  @$pb.TagNumber(12)
  $pb.PbList<FormatToken> get formatTokens => $_getList(11);

  @$pb.TagNumber(13)
  ResolvedSymbol get symbol => $_getN(12);
  @$pb.TagNumber(13)
  set symbol(ResolvedSymbol value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasSymbol() => $_has(12);
  @$pb.TagNumber(13)
  void clearSymbol() => $_clearField(13);
  @$pb.TagNumber(13)
  ResolvedSymbol ensureSymbol() => $_ensure(12);

  @$pb.TagNumber(14)
  AnalysisOperation get operation => $_getN(13);
  @$pb.TagNumber(14)
  set operation(AnalysisOperation value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasOperation() => $_has(13);
  @$pb.TagNumber(14)
  void clearOperation() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get metadataSnapshotRevision => $_getI64(14);
  @$pb.TagNumber(15)
  set metadataSnapshotRevision($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasMetadataSnapshotRevision() => $_has(14);
  @$pb.TagNumber(15)
  void clearMetadataSnapshotRevision() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get metadataConfigurationRevision => $_getI64(15);
  @$pb.TagNumber(16)
  set metadataConfigurationRevision($fixnum.Int64 value) =>
      $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasMetadataConfigurationRevision() => $_has(15);
  @$pb.TagNumber(16)
  void clearMetadataConfigurationRevision() => $_clearField(16);

  @$pb.TagNumber(17)
  ParameterInformation get parameterInformation => $_getN(16);
  @$pb.TagNumber(17)
  set parameterInformation(ParameterInformation value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasParameterInformation() => $_has(16);
  @$pb.TagNumber(17)
  void clearParameterInformation() => $_clearField(17);
  @$pb.TagNumber(17)
  ParameterInformation ensureParameterInformation() => $_ensure(16);

  @$pb.TagNumber(18)
  $pb.PbList<DdlEffect> get ddlEffects => $_getList(17);

  @$pb.TagNumber(19)
  $core.String get availability => $_getSZ(18);
  @$pb.TagNumber(19)
  set availability($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasAvailability() => $_has(18);
  @$pb.TagNumber(19)
  void clearAvailability() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.bool get completionLimited => $_getBF(19);
  @$pb.TagNumber(20)
  set completionLimited($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(20)
  $core.bool hasCompletionLimited() => $_has(19);
  @$pb.TagNumber(20)
  void clearCompletionLimited() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get metadataSourceIdentity => $_getSZ(20);
  @$pb.TagNumber(21)
  set metadataSourceIdentity($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasMetadataSourceIdentity() => $_has(20);
  @$pb.TagNumber(21)
  void clearMetadataSourceIdentity() => $_clearField(21);
}

class RoutineParameter extends $pb.GeneratedMessage {
  factory RoutineParameter({
    $core.String? name,
    $core.String? mode,
    $core.String? nativeType,
    $core.bool? optional,
    $core.bool? variadic,
    $core.String? defaultExpression,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (mode != null) result.mode = mode;
    if (nativeType != null) result.nativeType = nativeType;
    if (optional != null) result.optional = optional;
    if (variadic != null) result.variadic = variadic;
    if (defaultExpression != null) result.defaultExpression = defaultExpression;
    return result;
  }

  RoutineParameter._();

  factory RoutineParameter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoutineParameter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoutineParameter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'mode')
    ..aOS(3, _omitFieldNames ? '' : 'nativeType')
    ..aOB(4, _omitFieldNames ? '' : 'optional')
    ..aOB(5, _omitFieldNames ? '' : 'variadic')
    ..aOS(6, _omitFieldNames ? '' : 'defaultExpression')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutineParameter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutineParameter copyWith(void Function(RoutineParameter) updates) =>
      super.copyWith((message) => updates(message as RoutineParameter))
          as RoutineParameter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoutineParameter create() => RoutineParameter._();
  @$core.override
  RoutineParameter createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoutineParameter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoutineParameter>(create);
  static RoutineParameter? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mode => $_getSZ(1);
  @$pb.TagNumber(2)
  set mode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearMode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get nativeType => $_getSZ(2);
  @$pb.TagNumber(3)
  set nativeType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNativeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearNativeType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get optional => $_getBF(3);
  @$pb.TagNumber(4)
  set optional($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOptional() => $_has(3);
  @$pb.TagNumber(4)
  void clearOptional() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get variadic => $_getBF(4);
  @$pb.TagNumber(5)
  set variadic($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVariadic() => $_has(4);
  @$pb.TagNumber(5)
  void clearVariadic() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get defaultExpression => $_getSZ(5);
  @$pb.TagNumber(6)
  set defaultExpression($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDefaultExpression() => $_has(5);
  @$pb.TagNumber(6)
  void clearDefaultExpression() => $_clearField(6);
}

class RoutineSignature extends $pb.GeneratedMessage {
  factory RoutineSignature({
    $core.String? identity,
    $core.String? name,
    $core.String? signature,
    $core.Iterable<RoutineParameter>? parameters,
    $core.String? returnType,
  }) {
    final result = create();
    if (identity != null) result.identity = identity;
    if (name != null) result.name = name;
    if (signature != null) result.signature = signature;
    if (parameters != null) result.parameters.addAll(parameters);
    if (returnType != null) result.returnType = returnType;
    return result;
  }

  RoutineSignature._();

  factory RoutineSignature.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoutineSignature.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoutineSignature',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'identity')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'signature')
    ..pPM<RoutineParameter>(4, _omitFieldNames ? '' : 'parameters',
        subBuilder: RoutineParameter.create)
    ..aOS(5, _omitFieldNames ? '' : 'returnType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutineSignature clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutineSignature copyWith(void Function(RoutineSignature) updates) =>
      super.copyWith((message) => updates(message as RoutineSignature))
          as RoutineSignature;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoutineSignature create() => RoutineSignature._();
  @$core.override
  RoutineSignature createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoutineSignature getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoutineSignature>(create);
  static RoutineSignature? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get identity => $_getSZ(0);
  @$pb.TagNumber(1)
  set identity($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIdentity() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdentity() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get signature => $_getSZ(2);
  @$pb.TagNumber(3)
  set signature($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RoutineParameter> get parameters => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get returnType => $_getSZ(4);
  @$pb.TagNumber(5)
  set returnType($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReturnType() => $_has(4);
  @$pb.TagNumber(5)
  void clearReturnType() => $_clearField(5);
}

class ParameterInformation extends $pb.GeneratedMessage {
  factory ParameterInformation({
    $core.int? startUtf16,
    $core.int? endUtf16,
    $core.int? activeArgument,
    $core.Iterable<RoutineSignature>? overloads,
    $core.String? availability,
  }) {
    final result = create();
    if (startUtf16 != null) result.startUtf16 = startUtf16;
    if (endUtf16 != null) result.endUtf16 = endUtf16;
    if (activeArgument != null) result.activeArgument = activeArgument;
    if (overloads != null) result.overloads.addAll(overloads);
    if (availability != null) result.availability = availability;
    return result;
  }

  ParameterInformation._();

  factory ParameterInformation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ParameterInformation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParameterInformation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'startUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'endUtf16', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'activeArgument',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<RoutineSignature>(4, _omitFieldNames ? '' : 'overloads',
        subBuilder: RoutineSignature.create)
    ..aOS(5, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParameterInformation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParameterInformation copyWith(void Function(ParameterInformation) updates) =>
      super.copyWith((message) => updates(message as ParameterInformation))
          as ParameterInformation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParameterInformation create() => ParameterInformation._();
  @$core.override
  ParameterInformation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ParameterInformation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ParameterInformation>(create);
  static ParameterInformation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get startUtf16 => $_getIZ(0);
  @$pb.TagNumber(1)
  set startUtf16($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartUtf16() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartUtf16() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get endUtf16 => $_getIZ(1);
  @$pb.TagNumber(2)
  set endUtf16($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndUtf16() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndUtf16() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get activeArgument => $_getIZ(2);
  @$pb.TagNumber(3)
  set activeArgument($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveArgument() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveArgument() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RoutineSignature> get overloads => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get availability => $_getSZ(4);
  @$pb.TagNumber(5)
  set availability($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvailability() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvailability() => $_clearField(5);
}

class DdlEffect extends $pb.GeneratedMessage {
  factory DdlEffect({
    $core.String? operation,
    $core.String? catalog,
    $core.String? schema,
    $core.String? name,
    ObjectKind? kind,
    $core.bool? temporary,
    $core.bool? conservative,
  }) {
    final result = create();
    if (operation != null) result.operation = operation;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    if (temporary != null) result.temporary = temporary;
    if (conservative != null) result.conservative = conservative;
    return result;
  }

  DdlEffect._();

  factory DdlEffect.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DdlEffect.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DdlEffect',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'operation')
    ..aOS(2, _omitFieldNames ? '' : 'catalog')
    ..aOS(3, _omitFieldNames ? '' : 'schema')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aE<ObjectKind>(5, _omitFieldNames ? '' : 'kind',
        enumValues: ObjectKind.values)
    ..aOB(6, _omitFieldNames ? '' : 'temporary')
    ..aOB(7, _omitFieldNames ? '' : 'conservative')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DdlEffect clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DdlEffect copyWith(void Function(DdlEffect) updates) =>
      super.copyWith((message) => updates(message as DdlEffect)) as DdlEffect;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DdlEffect create() => DdlEffect._();
  @$core.override
  DdlEffect createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DdlEffect getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DdlEffect>(create);
  static DdlEffect? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get operation => $_getSZ(0);
  @$pb.TagNumber(1)
  set operation($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOperation() => $_has(0);
  @$pb.TagNumber(1)
  void clearOperation() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get catalog => $_getSZ(1);
  @$pb.TagNumber(2)
  set catalog($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCatalog() => $_has(1);
  @$pb.TagNumber(2)
  void clearCatalog() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get schema => $_getSZ(2);
  @$pb.TagNumber(3)
  set schema($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchema() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchema() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  ObjectKind get kind => $_getN(4);
  @$pb.TagNumber(5)
  set kind(ObjectKind value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearKind() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get temporary => $_getBF(5);
  @$pb.TagNumber(6)
  set temporary($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTemporary() => $_has(5);
  @$pb.TagNumber(6)
  void clearTemporary() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get conservative => $_getBF(6);
  @$pb.TagNumber(7)
  set conservative($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasConservative() => $_has(6);
  @$pb.TagNumber(7)
  void clearConservative() => $_clearField(7);
}

class ExploreRequest extends $pb.GeneratedMessage {
  factory ExploreRequest({
    Context? context,
    $core.String? sessionId,
    ObjectKind? kind,
    $core.String? catalog,
    $core.String? schema,
    $core.String? table,
    $core.String? search,
    $core.bool? refresh,
    $core.bool? globalSearch,
    $core.String? continuation,
    $core.int? limit,
    $fixnum.Int64? expectedSessionRevision,
    $fixnum.Int64? expectedContextRevision,
    $core.bool? exactName,
    $core.String? identifier,
    ObjectSubtype? subtype,
    $core.bool? independentMetadata,
    $core.int? introspectionLevel,
    $core.String? refreshMode,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (kind != null) result.kind = kind;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (search != null) result.search = search;
    if (refresh != null) result.refresh = refresh;
    if (globalSearch != null) result.globalSearch = globalSearch;
    if (continuation != null) result.continuation = continuation;
    if (limit != null) result.limit = limit;
    if (expectedSessionRevision != null)
      result.expectedSessionRevision = expectedSessionRevision;
    if (expectedContextRevision != null)
      result.expectedContextRevision = expectedContextRevision;
    if (exactName != null) result.exactName = exactName;
    if (identifier != null) result.identifier = identifier;
    if (subtype != null) result.subtype = subtype;
    if (independentMetadata != null)
      result.independentMetadata = independentMetadata;
    if (introspectionLevel != null)
      result.introspectionLevel = introspectionLevel;
    if (refreshMode != null) result.refreshMode = refreshMode;
    return result;
  }

  ExploreRequest._();

  factory ExploreRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExploreRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExploreRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aE<ObjectKind>(3, _omitFieldNames ? '' : 'kind',
        enumValues: ObjectKind.values)
    ..aOS(4, _omitFieldNames ? '' : 'catalog')
    ..aOS(5, _omitFieldNames ? '' : 'schema')
    ..aOS(6, _omitFieldNames ? '' : 'table')
    ..aOS(7, _omitFieldNames ? '' : 'search')
    ..aOB(8, _omitFieldNames ? '' : 'refresh')
    ..aOB(9, _omitFieldNames ? '' : 'globalSearch')
    ..aOS(10, _omitFieldNames ? '' : 'continuation')
    ..aI(11, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(12, _omitFieldNames ? '' : 'expectedSessionRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(13, _omitFieldNames ? '' : 'expectedContextRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(14, _omitFieldNames ? '' : 'exactName')
    ..aOS(15, _omitFieldNames ? '' : 'identifier')
    ..aE<ObjectSubtype>(16, _omitFieldNames ? '' : 'subtype',
        enumValues: ObjectSubtype.values)
    ..aOB(17, _omitFieldNames ? '' : 'independentMetadata')
    ..aI(18, _omitFieldNames ? '' : 'introspectionLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(19, _omitFieldNames ? '' : 'refreshMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExploreRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExploreRequest copyWith(void Function(ExploreRequest) updates) =>
      super.copyWith((message) => updates(message as ExploreRequest))
          as ExploreRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExploreRequest create() => ExploreRequest._();
  @$core.override
  ExploreRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExploreRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExploreRequest>(create);
  static ExploreRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  ObjectKind get kind => $_getN(2);
  @$pb.TagNumber(3)
  set kind(ObjectKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get catalog => $_getSZ(3);
  @$pb.TagNumber(4)
  set catalog($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCatalog() => $_has(3);
  @$pb.TagNumber(4)
  void clearCatalog() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get schema => $_getSZ(4);
  @$pb.TagNumber(5)
  set schema($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSchema() => $_has(4);
  @$pb.TagNumber(5)
  void clearSchema() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get table => $_getSZ(5);
  @$pb.TagNumber(6)
  set table($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTable() => $_has(5);
  @$pb.TagNumber(6)
  void clearTable() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get search => $_getSZ(6);
  @$pb.TagNumber(7)
  set search($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSearch() => $_has(6);
  @$pb.TagNumber(7)
  void clearSearch() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get refresh => $_getBF(7);
  @$pb.TagNumber(8)
  set refresh($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRefresh() => $_has(7);
  @$pb.TagNumber(8)
  void clearRefresh() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get globalSearch => $_getBF(8);
  @$pb.TagNumber(9)
  set globalSearch($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasGlobalSearch() => $_has(8);
  @$pb.TagNumber(9)
  void clearGlobalSearch() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get continuation => $_getSZ(9);
  @$pb.TagNumber(10)
  set continuation($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasContinuation() => $_has(9);
  @$pb.TagNumber(10)
  void clearContinuation() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get limit => $_getIZ(10);
  @$pb.TagNumber(11)
  set limit($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLimit() => $_has(10);
  @$pb.TagNumber(11)
  void clearLimit() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get expectedSessionRevision => $_getI64(11);
  @$pb.TagNumber(12)
  set expectedSessionRevision($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasExpectedSessionRevision() => $_has(11);
  @$pb.TagNumber(12)
  void clearExpectedSessionRevision() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get expectedContextRevision => $_getI64(12);
  @$pb.TagNumber(13)
  set expectedContextRevision($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasExpectedContextRevision() => $_has(12);
  @$pb.TagNumber(13)
  void clearExpectedContextRevision() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get exactName => $_getBF(13);
  @$pb.TagNumber(14)
  set exactName($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasExactName() => $_has(13);
  @$pb.TagNumber(14)
  void clearExactName() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get identifier => $_getSZ(14);
  @$pb.TagNumber(15)
  set identifier($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasIdentifier() => $_has(14);
  @$pb.TagNumber(15)
  void clearIdentifier() => $_clearField(15);

  @$pb.TagNumber(16)
  ObjectSubtype get subtype => $_getN(15);
  @$pb.TagNumber(16)
  set subtype(ObjectSubtype value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasSubtype() => $_has(15);
  @$pb.TagNumber(16)
  void clearSubtype() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get independentMetadata => $_getBF(16);
  @$pb.TagNumber(17)
  set independentMetadata($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(17)
  $core.bool hasIndependentMetadata() => $_has(16);
  @$pb.TagNumber(17)
  void clearIndependentMetadata() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get introspectionLevel => $_getIZ(17);
  @$pb.TagNumber(18)
  set introspectionLevel($core.int value) => $_setUnsignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasIntrospectionLevel() => $_has(17);
  @$pb.TagNumber(18)
  void clearIntrospectionLevel() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get refreshMode => $_getSZ(18);
  @$pb.TagNumber(19)
  set refreshMode($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasRefreshMode() => $_has(18);
  @$pb.TagNumber(19)
  void clearRefreshMode() => $_clearField(19);
}

/// identifier is the exact native snapshot/dependency identity for routines.
/// A display name cannot distinguish overloads. Maximum UTF-8 size: 8KiB.
class SchemaObject extends $pb.GeneratedMessage {
  factory SchemaObject({
    $core.String? name,
    ObjectKind? kind,
    $core.String? catalog,
    $core.String? schema,
    $core.String? table,
    $core.String? definition,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? properties,
    $core.String? identifier,
    ObjectSubtype? subtype,
    $core.String? stableIdentity,
    $core.String? quotedIdentifier,
    $core.String? normalizedIdentifier,
    $core.String? parentIdentity,
    $fixnum.Int64? metadataSnapshotRevision,
    $core.int? introspectionLevel,
    $core.String? metadataState,
    $core.String? sourceRevision,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (definition != null) result.definition = definition;
    if (properties != null) result.properties.addEntries(properties);
    if (identifier != null) result.identifier = identifier;
    if (subtype != null) result.subtype = subtype;
    if (stableIdentity != null) result.stableIdentity = stableIdentity;
    if (quotedIdentifier != null) result.quotedIdentifier = quotedIdentifier;
    if (normalizedIdentifier != null)
      result.normalizedIdentifier = normalizedIdentifier;
    if (parentIdentity != null) result.parentIdentity = parentIdentity;
    if (metadataSnapshotRevision != null)
      result.metadataSnapshotRevision = metadataSnapshotRevision;
    if (introspectionLevel != null)
      result.introspectionLevel = introspectionLevel;
    if (metadataState != null) result.metadataState = metadataState;
    if (sourceRevision != null) result.sourceRevision = sourceRevision;
    return result;
  }

  SchemaObject._();

  factory SchemaObject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchemaObject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchemaObject',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<ObjectKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: ObjectKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'catalog')
    ..aOS(4, _omitFieldNames ? '' : 'schema')
    ..aOS(5, _omitFieldNames ? '' : 'table')
    ..aOS(6, _omitFieldNames ? '' : 'definition')
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'properties',
        entryClassName: 'SchemaObject.PropertiesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('busydata.v1'))
    ..aOS(8, _omitFieldNames ? '' : 'identifier')
    ..aE<ObjectSubtype>(9, _omitFieldNames ? '' : 'subtype',
        enumValues: ObjectSubtype.values)
    ..aOS(10, _omitFieldNames ? '' : 'stableIdentity')
    ..aOS(11, _omitFieldNames ? '' : 'quotedIdentifier')
    ..aOS(12, _omitFieldNames ? '' : 'normalizedIdentifier')
    ..aOS(13, _omitFieldNames ? '' : 'parentIdentity')
    ..a<$fixnum.Int64>(14, _omitFieldNames ? '' : 'metadataSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(15, _omitFieldNames ? '' : 'introspectionLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(16, _omitFieldNames ? '' : 'metadataState')
    ..aOS(17, _omitFieldNames ? '' : 'sourceRevision')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaObject clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaObject copyWith(void Function(SchemaObject) updates) =>
      super.copyWith((message) => updates(message as SchemaObject))
          as SchemaObject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchemaObject create() => SchemaObject._();
  @$core.override
  SchemaObject createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchemaObject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchemaObject>(create);
  static SchemaObject? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  ObjectKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(ObjectKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get catalog => $_getSZ(2);
  @$pb.TagNumber(3)
  set catalog($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCatalog() => $_has(2);
  @$pb.TagNumber(3)
  void clearCatalog() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get schema => $_getSZ(3);
  @$pb.TagNumber(4)
  set schema($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchema() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchema() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get table => $_getSZ(4);
  @$pb.TagNumber(5)
  set table($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTable() => $_has(4);
  @$pb.TagNumber(5)
  void clearTable() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get definition => $_getSZ(5);
  @$pb.TagNumber(6)
  set definition($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDefinition() => $_has(5);
  @$pb.TagNumber(6)
  void clearDefinition() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, $core.String> get properties => $_getMap(6);

  @$pb.TagNumber(8)
  $core.String get identifier => $_getSZ(7);
  @$pb.TagNumber(8)
  set identifier($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIdentifier() => $_has(7);
  @$pb.TagNumber(8)
  void clearIdentifier() => $_clearField(8);

  @$pb.TagNumber(9)
  ObjectSubtype get subtype => $_getN(8);
  @$pb.TagNumber(9)
  set subtype(ObjectSubtype value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSubtype() => $_has(8);
  @$pb.TagNumber(9)
  void clearSubtype() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get stableIdentity => $_getSZ(9);
  @$pb.TagNumber(10)
  set stableIdentity($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStableIdentity() => $_has(9);
  @$pb.TagNumber(10)
  void clearStableIdentity() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get quotedIdentifier => $_getSZ(10);
  @$pb.TagNumber(11)
  set quotedIdentifier($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasQuotedIdentifier() => $_has(10);
  @$pb.TagNumber(11)
  void clearQuotedIdentifier() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get normalizedIdentifier => $_getSZ(11);
  @$pb.TagNumber(12)
  set normalizedIdentifier($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasNormalizedIdentifier() => $_has(11);
  @$pb.TagNumber(12)
  void clearNormalizedIdentifier() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get parentIdentity => $_getSZ(12);
  @$pb.TagNumber(13)
  set parentIdentity($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasParentIdentity() => $_has(12);
  @$pb.TagNumber(13)
  void clearParentIdentity() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get metadataSnapshotRevision => $_getI64(13);
  @$pb.TagNumber(14)
  set metadataSnapshotRevision($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasMetadataSnapshotRevision() => $_has(13);
  @$pb.TagNumber(14)
  void clearMetadataSnapshotRevision() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get introspectionLevel => $_getIZ(14);
  @$pb.TagNumber(15)
  set introspectionLevel($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasIntrospectionLevel() => $_has(14);
  @$pb.TagNumber(15)
  void clearIntrospectionLevel() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get metadataState => $_getSZ(15);
  @$pb.TagNumber(16)
  set metadataState($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasMetadataState() => $_has(15);
  @$pb.TagNumber(16)
  void clearMetadataState() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get sourceRevision => $_getSZ(16);
  @$pb.TagNumber(17)
  set sourceRevision($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasSourceRevision() => $_has(16);
  @$pb.TagNumber(17)
  void clearSourceRevision() => $_clearField(17);
}

/// Ordinary tree counts describe the full requested name/kind scope, independent
/// of its returned page. Missing totals are never implicitly zero. Continuations
/// are opaque, backend-owned and bound to owner, revision and exact scope.
class SchemaObjects extends $pb.GeneratedMessage {
  factory SchemaObjects({
    $core.Iterable<SchemaObject>? objects,
    $core.String? availability,
    $core.String? continuation,
    $core.bool? complete,
    $fixnum.Int64? contextRevision,
    $fixnum.Int64? sessionRevision,
    $core.String? profileId,
    $core.String? sessionId,
    $core.String? instanceId,
    $core.String? catalog,
    $core.String? schema,
    $core.String? parent,
    ObjectKind? kind,
    MetadataCount? countAvailability,
    $fixnum.Int64? totalCount,
    $core.String? defaultNamespace,
    ObjectSubtype? subtype,
    $fixnum.Int64? metadataSnapshotRevision,
    $fixnum.Int64? metadataConfigurationRevision,
    $core.int? introspectionLevel,
    $core.String? metadataState,
    $core.String? metadataSourceIdentity,
  }) {
    final result = create();
    if (objects != null) result.objects.addAll(objects);
    if (availability != null) result.availability = availability;
    if (continuation != null) result.continuation = continuation;
    if (complete != null) result.complete = complete;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (profileId != null) result.profileId = profileId;
    if (sessionId != null) result.sessionId = sessionId;
    if (instanceId != null) result.instanceId = instanceId;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (parent != null) result.parent = parent;
    if (kind != null) result.kind = kind;
    if (countAvailability != null) result.countAvailability = countAvailability;
    if (totalCount != null) result.totalCount = totalCount;
    if (defaultNamespace != null) result.defaultNamespace = defaultNamespace;
    if (subtype != null) result.subtype = subtype;
    if (metadataSnapshotRevision != null)
      result.metadataSnapshotRevision = metadataSnapshotRevision;
    if (metadataConfigurationRevision != null)
      result.metadataConfigurationRevision = metadataConfigurationRevision;
    if (introspectionLevel != null)
      result.introspectionLevel = introspectionLevel;
    if (metadataState != null) result.metadataState = metadataState;
    if (metadataSourceIdentity != null)
      result.metadataSourceIdentity = metadataSourceIdentity;
    return result;
  }

  SchemaObjects._();

  factory SchemaObjects.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchemaObjects.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchemaObjects',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<SchemaObject>(1, _omitFieldNames ? '' : 'objects',
        subBuilder: SchemaObject.create)
    ..aOS(2, _omitFieldNames ? '' : 'availability')
    ..aOS(3, _omitFieldNames ? '' : 'continuation')
    ..aOB(4, _omitFieldNames ? '' : 'complete')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(7, _omitFieldNames ? '' : 'profileId')
    ..aOS(8, _omitFieldNames ? '' : 'sessionId')
    ..aOS(9, _omitFieldNames ? '' : 'instanceId')
    ..aOS(10, _omitFieldNames ? '' : 'catalog')
    ..aOS(11, _omitFieldNames ? '' : 'schema')
    ..aOS(12, _omitFieldNames ? '' : 'parent')
    ..aE<ObjectKind>(13, _omitFieldNames ? '' : 'kind',
        enumValues: ObjectKind.values)
    ..aE<MetadataCount>(14, _omitFieldNames ? '' : 'countAvailability',
        enumValues: MetadataCount.values)
    ..a<$fixnum.Int64>(
        15, _omitFieldNames ? '' : 'totalCount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(16, _omitFieldNames ? '' : 'defaultNamespace')
    ..aE<ObjectSubtype>(17, _omitFieldNames ? '' : 'subtype',
        enumValues: ObjectSubtype.values)
    ..a<$fixnum.Int64>(18, _omitFieldNames ? '' : 'metadataSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        19,
        _omitFieldNames ? '' : 'metadataConfigurationRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(20, _omitFieldNames ? '' : 'introspectionLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(21, _omitFieldNames ? '' : 'metadataState')
    ..aOS(22, _omitFieldNames ? '' : 'metadataSourceIdentity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaObjects clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaObjects copyWith(void Function(SchemaObjects) updates) =>
      super.copyWith((message) => updates(message as SchemaObjects))
          as SchemaObjects;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchemaObjects create() => SchemaObjects._();
  @$core.override
  SchemaObjects createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchemaObjects getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchemaObjects>(create);
  static SchemaObjects? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SchemaObject> get objects => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get availability => $_getSZ(1);
  @$pb.TagNumber(2)
  set availability($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAvailability() => $_has(1);
  @$pb.TagNumber(2)
  void clearAvailability() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get continuation => $_getSZ(2);
  @$pb.TagNumber(3)
  set continuation($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContinuation() => $_has(2);
  @$pb.TagNumber(3)
  void clearContinuation() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get complete => $_getBF(3);
  @$pb.TagNumber(4)
  set complete($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasComplete() => $_has(3);
  @$pb.TagNumber(4)
  void clearComplete() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get contextRevision => $_getI64(4);
  @$pb.TagNumber(5)
  set contextRevision($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasContextRevision() => $_has(4);
  @$pb.TagNumber(5)
  void clearContextRevision() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get sessionRevision => $_getI64(5);
  @$pb.TagNumber(6)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSessionRevision() => $_has(5);
  @$pb.TagNumber(6)
  void clearSessionRevision() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get profileId => $_getSZ(6);
  @$pb.TagNumber(7)
  set profileId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProfileId() => $_has(6);
  @$pb.TagNumber(7)
  void clearProfileId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sessionId => $_getSZ(7);
  @$pb.TagNumber(8)
  set sessionId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSessionId() => $_has(7);
  @$pb.TagNumber(8)
  void clearSessionId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get instanceId => $_getSZ(8);
  @$pb.TagNumber(9)
  set instanceId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasInstanceId() => $_has(8);
  @$pb.TagNumber(9)
  void clearInstanceId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get catalog => $_getSZ(9);
  @$pb.TagNumber(10)
  set catalog($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCatalog() => $_has(9);
  @$pb.TagNumber(10)
  void clearCatalog() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get schema => $_getSZ(10);
  @$pb.TagNumber(11)
  set schema($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSchema() => $_has(10);
  @$pb.TagNumber(11)
  void clearSchema() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get parent => $_getSZ(11);
  @$pb.TagNumber(12)
  set parent($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasParent() => $_has(11);
  @$pb.TagNumber(12)
  void clearParent() => $_clearField(12);

  @$pb.TagNumber(13)
  ObjectKind get kind => $_getN(12);
  @$pb.TagNumber(13)
  set kind(ObjectKind value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasKind() => $_has(12);
  @$pb.TagNumber(13)
  void clearKind() => $_clearField(13);

  @$pb.TagNumber(14)
  MetadataCount get countAvailability => $_getN(13);
  @$pb.TagNumber(14)
  set countAvailability(MetadataCount value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCountAvailability() => $_has(13);
  @$pb.TagNumber(14)
  void clearCountAvailability() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get totalCount => $_getI64(14);
  @$pb.TagNumber(15)
  set totalCount($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasTotalCount() => $_has(14);
  @$pb.TagNumber(15)
  void clearTotalCount() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get defaultNamespace => $_getSZ(15);
  @$pb.TagNumber(16)
  set defaultNamespace($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasDefaultNamespace() => $_has(15);
  @$pb.TagNumber(16)
  void clearDefaultNamespace() => $_clearField(16);

  @$pb.TagNumber(17)
  ObjectSubtype get subtype => $_getN(16);
  @$pb.TagNumber(17)
  set subtype(ObjectSubtype value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasSubtype() => $_has(16);
  @$pb.TagNumber(17)
  void clearSubtype() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get metadataSnapshotRevision => $_getI64(17);
  @$pb.TagNumber(18)
  set metadataSnapshotRevision($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasMetadataSnapshotRevision() => $_has(17);
  @$pb.TagNumber(18)
  void clearMetadataSnapshotRevision() => $_clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get metadataConfigurationRevision => $_getI64(18);
  @$pb.TagNumber(19)
  set metadataConfigurationRevision($fixnum.Int64 value) =>
      $_setInt64(18, value);
  @$pb.TagNumber(19)
  $core.bool hasMetadataConfigurationRevision() => $_has(18);
  @$pb.TagNumber(19)
  void clearMetadataConfigurationRevision() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.int get introspectionLevel => $_getIZ(19);
  @$pb.TagNumber(20)
  set introspectionLevel($core.int value) => $_setUnsignedInt32(19, value);
  @$pb.TagNumber(20)
  $core.bool hasIntrospectionLevel() => $_has(19);
  @$pb.TagNumber(20)
  void clearIntrospectionLevel() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get metadataState => $_getSZ(20);
  @$pb.TagNumber(21)
  set metadataState($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasMetadataState() => $_has(20);
  @$pb.TagNumber(21)
  void clearMetadataState() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get metadataSourceIdentity => $_getSZ(21);
  @$pb.TagNumber(22)
  set metadataSourceIdentity($core.String value) => $_setString(21, value);
  @$pb.TagNumber(22)
  $core.bool hasMetadataSourceIdentity() => $_has(21);
  @$pb.TagNumber(22)
  void clearMetadataSourceIdentity() => $_clearField(22);
}

class SchemaToolRequest extends $pb.GeneratedMessage {
  factory SchemaToolRequest({
    Context? context,
    $core.String? sessionId,
    SchemaToolAction? action,
    $core.String? schema,
    $core.String? table,
    $core.String? sourceSnapshot,
    $core.String? targetSnapshot,
    $core.String? column,
    $core.String? type,
    $core.bool? nullable,
    $core.String? operation,
    $core.String? property,
    $core.String? value,
    $core.String? objectName,
    $core.Iterable<$core.String>? objectColumns,
    $core.bool? unique,
    $core.String? referenceSchema,
    $core.String? referenceTable,
    $core.Iterable<$core.String>? referenceColumns,
    $core.String? expression,
    $core.String? definition,
    $core.String? objectKind,
    $core.Iterable<DesignedColumn>? designedColumns,
    $core.String? onDelete,
    $core.String? onUpdate,
    $core.bool? deferrable,
    $core.bool? initiallyDeferred,
    $core.String? catalog,
    ObjectKind? kind,
    $core.String? identifier,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (action != null) result.action = action;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (sourceSnapshot != null) result.sourceSnapshot = sourceSnapshot;
    if (targetSnapshot != null) result.targetSnapshot = targetSnapshot;
    if (column != null) result.column = column;
    if (type != null) result.type = type;
    if (nullable != null) result.nullable = nullable;
    if (operation != null) result.operation = operation;
    if (property != null) result.property = property;
    if (value != null) result.value = value;
    if (objectName != null) result.objectName = objectName;
    if (objectColumns != null) result.objectColumns.addAll(objectColumns);
    if (unique != null) result.unique = unique;
    if (referenceSchema != null) result.referenceSchema = referenceSchema;
    if (referenceTable != null) result.referenceTable = referenceTable;
    if (referenceColumns != null)
      result.referenceColumns.addAll(referenceColumns);
    if (expression != null) result.expression = expression;
    if (definition != null) result.definition = definition;
    if (objectKind != null) result.objectKind = objectKind;
    if (designedColumns != null) result.designedColumns.addAll(designedColumns);
    if (onDelete != null) result.onDelete = onDelete;
    if (onUpdate != null) result.onUpdate = onUpdate;
    if (deferrable != null) result.deferrable = deferrable;
    if (initiallyDeferred != null) result.initiallyDeferred = initiallyDeferred;
    if (catalog != null) result.catalog = catalog;
    if (kind != null) result.kind = kind;
    if (identifier != null) result.identifier = identifier;
    return result;
  }

  SchemaToolRequest._();

  factory SchemaToolRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchemaToolRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchemaToolRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aE<SchemaToolAction>(3, _omitFieldNames ? '' : 'action',
        enumValues: SchemaToolAction.values)
    ..aOS(4, _omitFieldNames ? '' : 'schema')
    ..aOS(5, _omitFieldNames ? '' : 'table')
    ..aOS(6, _omitFieldNames ? '' : 'sourceSnapshot')
    ..aOS(7, _omitFieldNames ? '' : 'targetSnapshot')
    ..aOS(8, _omitFieldNames ? '' : 'column')
    ..aOS(9, _omitFieldNames ? '' : 'type')
    ..aOB(10, _omitFieldNames ? '' : 'nullable')
    ..aOS(11, _omitFieldNames ? '' : 'operation')
    ..aOS(12, _omitFieldNames ? '' : 'property')
    ..aOS(13, _omitFieldNames ? '' : 'value')
    ..aOS(14, _omitFieldNames ? '' : 'objectName')
    ..pPS(15, _omitFieldNames ? '' : 'objectColumns')
    ..aOB(16, _omitFieldNames ? '' : 'unique')
    ..aOS(17, _omitFieldNames ? '' : 'referenceSchema')
    ..aOS(18, _omitFieldNames ? '' : 'referenceTable')
    ..pPS(19, _omitFieldNames ? '' : 'referenceColumns')
    ..aOS(20, _omitFieldNames ? '' : 'expression')
    ..aOS(21, _omitFieldNames ? '' : 'definition')
    ..aOS(22, _omitFieldNames ? '' : 'objectKind')
    ..pPM<DesignedColumn>(23, _omitFieldNames ? '' : 'designedColumns',
        subBuilder: DesignedColumn.create)
    ..aOS(24, _omitFieldNames ? '' : 'onDelete')
    ..aOS(25, _omitFieldNames ? '' : 'onUpdate')
    ..aOB(26, _omitFieldNames ? '' : 'deferrable')
    ..aOB(27, _omitFieldNames ? '' : 'initiallyDeferred')
    ..aOS(28, _omitFieldNames ? '' : 'catalog')
    ..aE<ObjectKind>(29, _omitFieldNames ? '' : 'kind',
        enumValues: ObjectKind.values)
    ..aOS(30, _omitFieldNames ? '' : 'identifier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaToolRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaToolRequest copyWith(void Function(SchemaToolRequest) updates) =>
      super.copyWith((message) => updates(message as SchemaToolRequest))
          as SchemaToolRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchemaToolRequest create() => SchemaToolRequest._();
  @$core.override
  SchemaToolRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchemaToolRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchemaToolRequest>(create);
  static SchemaToolRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  SchemaToolAction get action => $_getN(2);
  @$pb.TagNumber(3)
  set action(SchemaToolAction value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAction() => $_has(2);
  @$pb.TagNumber(3)
  void clearAction() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get schema => $_getSZ(3);
  @$pb.TagNumber(4)
  set schema($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchema() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchema() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get table => $_getSZ(4);
  @$pb.TagNumber(5)
  set table($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTable() => $_has(4);
  @$pb.TagNumber(5)
  void clearTable() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get sourceSnapshot => $_getSZ(5);
  @$pb.TagNumber(6)
  set sourceSnapshot($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSourceSnapshot() => $_has(5);
  @$pb.TagNumber(6)
  void clearSourceSnapshot() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get targetSnapshot => $_getSZ(6);
  @$pb.TagNumber(7)
  set targetSnapshot($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTargetSnapshot() => $_has(6);
  @$pb.TagNumber(7)
  void clearTargetSnapshot() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get column => $_getSZ(7);
  @$pb.TagNumber(8)
  set column($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasColumn() => $_has(7);
  @$pb.TagNumber(8)
  void clearColumn() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get type => $_getSZ(8);
  @$pb.TagNumber(9)
  set type($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasType() => $_has(8);
  @$pb.TagNumber(9)
  void clearType() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get nullable => $_getBF(9);
  @$pb.TagNumber(10)
  set nullable($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNullable() => $_has(9);
  @$pb.TagNumber(10)
  void clearNullable() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get operation => $_getSZ(10);
  @$pb.TagNumber(11)
  set operation($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasOperation() => $_has(10);
  @$pb.TagNumber(11)
  void clearOperation() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get property => $_getSZ(11);
  @$pb.TagNumber(12)
  set property($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasProperty() => $_has(11);
  @$pb.TagNumber(12)
  void clearProperty() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get value => $_getSZ(12);
  @$pb.TagNumber(13)
  set value($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasValue() => $_has(12);
  @$pb.TagNumber(13)
  void clearValue() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get objectName => $_getSZ(13);
  @$pb.TagNumber(14)
  set objectName($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasObjectName() => $_has(13);
  @$pb.TagNumber(14)
  void clearObjectName() => $_clearField(14);

  @$pb.TagNumber(15)
  $pb.PbList<$core.String> get objectColumns => $_getList(14);

  @$pb.TagNumber(16)
  $core.bool get unique => $_getBF(15);
  @$pb.TagNumber(16)
  set unique($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasUnique() => $_has(15);
  @$pb.TagNumber(16)
  void clearUnique() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get referenceSchema => $_getSZ(16);
  @$pb.TagNumber(17)
  set referenceSchema($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasReferenceSchema() => $_has(16);
  @$pb.TagNumber(17)
  void clearReferenceSchema() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.String get referenceTable => $_getSZ(17);
  @$pb.TagNumber(18)
  set referenceTable($core.String value) => $_setString(17, value);
  @$pb.TagNumber(18)
  $core.bool hasReferenceTable() => $_has(17);
  @$pb.TagNumber(18)
  void clearReferenceTable() => $_clearField(18);

  @$pb.TagNumber(19)
  $pb.PbList<$core.String> get referenceColumns => $_getList(18);

  @$pb.TagNumber(20)
  $core.String get expression => $_getSZ(19);
  @$pb.TagNumber(20)
  set expression($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasExpression() => $_has(19);
  @$pb.TagNumber(20)
  void clearExpression() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get definition => $_getSZ(20);
  @$pb.TagNumber(21)
  set definition($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasDefinition() => $_has(20);
  @$pb.TagNumber(21)
  void clearDefinition() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get objectKind => $_getSZ(21);
  @$pb.TagNumber(22)
  set objectKind($core.String value) => $_setString(21, value);
  @$pb.TagNumber(22)
  $core.bool hasObjectKind() => $_has(21);
  @$pb.TagNumber(22)
  void clearObjectKind() => $_clearField(22);

  @$pb.TagNumber(23)
  $pb.PbList<DesignedColumn> get designedColumns => $_getList(22);

  @$pb.TagNumber(24)
  $core.String get onDelete => $_getSZ(23);
  @$pb.TagNumber(24)
  set onDelete($core.String value) => $_setString(23, value);
  @$pb.TagNumber(24)
  $core.bool hasOnDelete() => $_has(23);
  @$pb.TagNumber(24)
  void clearOnDelete() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.String get onUpdate => $_getSZ(24);
  @$pb.TagNumber(25)
  set onUpdate($core.String value) => $_setString(24, value);
  @$pb.TagNumber(25)
  $core.bool hasOnUpdate() => $_has(24);
  @$pb.TagNumber(25)
  void clearOnUpdate() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.bool get deferrable => $_getBF(25);
  @$pb.TagNumber(26)
  set deferrable($core.bool value) => $_setBool(25, value);
  @$pb.TagNumber(26)
  $core.bool hasDeferrable() => $_has(25);
  @$pb.TagNumber(26)
  void clearDeferrable() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.bool get initiallyDeferred => $_getBF(26);
  @$pb.TagNumber(27)
  set initiallyDeferred($core.bool value) => $_setBool(26, value);
  @$pb.TagNumber(27)
  $core.bool hasInitiallyDeferred() => $_has(26);
  @$pb.TagNumber(27)
  void clearInitiallyDeferred() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.String get catalog => $_getSZ(27);
  @$pb.TagNumber(28)
  set catalog($core.String value) => $_setString(27, value);
  @$pb.TagNumber(28)
  $core.bool hasCatalog() => $_has(27);
  @$pb.TagNumber(28)
  void clearCatalog() => $_clearField(28);

  @$pb.TagNumber(29)
  ObjectKind get kind => $_getN(28);
  @$pb.TagNumber(29)
  set kind(ObjectKind value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasKind() => $_has(28);
  @$pb.TagNumber(29)
  void clearKind() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.String get identifier => $_getSZ(29);
  @$pb.TagNumber(30)
  set identifier($core.String value) => $_setString(29, value);
  @$pb.TagNumber(30)
  $core.bool hasIdentifier() => $_has(29);
  @$pb.TagNumber(30)
  void clearIdentifier() => $_clearField(30);
}

class DesignedColumn extends $pb.GeneratedMessage {
  factory DesignedColumn({
    $core.String? name,
    $core.String? type,
    $core.bool? nullable,
    $core.String? defaultExpression,
    $core.String? identity,
    $core.String? generatedExpression,
    $core.String? comment,
    $core.String? collation,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (nullable != null) result.nullable = nullable;
    if (defaultExpression != null) result.defaultExpression = defaultExpression;
    if (identity != null) result.identity = identity;
    if (generatedExpression != null)
      result.generatedExpression = generatedExpression;
    if (comment != null) result.comment = comment;
    if (collation != null) result.collation = collation;
    return result;
  }

  DesignedColumn._();

  factory DesignedColumn.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DesignedColumn.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DesignedColumn',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'type')
    ..aOB(3, _omitFieldNames ? '' : 'nullable')
    ..aOS(4, _omitFieldNames ? '' : 'defaultExpression')
    ..aOS(5, _omitFieldNames ? '' : 'identity')
    ..aOS(6, _omitFieldNames ? '' : 'generatedExpression')
    ..aOS(7, _omitFieldNames ? '' : 'comment')
    ..aOS(8, _omitFieldNames ? '' : 'collation')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DesignedColumn clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DesignedColumn copyWith(void Function(DesignedColumn) updates) =>
      super.copyWith((message) => updates(message as DesignedColumn))
          as DesignedColumn;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DesignedColumn create() => DesignedColumn._();
  @$core.override
  DesignedColumn createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DesignedColumn getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DesignedColumn>(create);
  static DesignedColumn? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get nullable => $_getBF(2);
  @$pb.TagNumber(3)
  set nullable($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNullable() => $_has(2);
  @$pb.TagNumber(3)
  void clearNullable() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get defaultExpression => $_getSZ(3);
  @$pb.TagNumber(4)
  set defaultExpression($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDefaultExpression() => $_has(3);
  @$pb.TagNumber(4)
  void clearDefaultExpression() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get identity => $_getSZ(4);
  @$pb.TagNumber(5)
  set identity($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdentity() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdentity() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get generatedExpression => $_getSZ(5);
  @$pb.TagNumber(6)
  set generatedExpression($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGeneratedExpression() => $_has(5);
  @$pb.TagNumber(6)
  void clearGeneratedExpression() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get comment => $_getSZ(6);
  @$pb.TagNumber(7)
  set comment($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasComment() => $_has(6);
  @$pb.TagNumber(7)
  void clearComment() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get collation => $_getSZ(7);
  @$pb.TagNumber(8)
  set collation($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCollation() => $_has(7);
  @$pb.TagNumber(8)
  void clearCollation() => $_clearField(8);
}

/// Differences describe the versioned snapshots. SQL remains one dependency-ordered
/// batch; individual differences do not authorize arbitrary statement subsets.
class SchemaDifference extends $pb.GeneratedMessage {
  factory SchemaDifference({
    $core.String? kind,
    $core.String? name,
    $core.String? state,
    $core.String? beforeDefinition,
    $core.String? afterDefinition,
    $core.bool? presentationLimited,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (state != null) result.state = state;
    if (beforeDefinition != null) result.beforeDefinition = beforeDefinition;
    if (afterDefinition != null) result.afterDefinition = afterDefinition;
    if (presentationLimited != null)
      result.presentationLimited = presentationLimited;
    return result;
  }

  SchemaDifference._();

  factory SchemaDifference.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchemaDifference.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchemaDifference',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kind')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'state')
    ..aOS(4, _omitFieldNames ? '' : 'beforeDefinition')
    ..aOS(5, _omitFieldNames ? '' : 'afterDefinition')
    ..aOB(6, _omitFieldNames ? '' : 'presentationLimited')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaDifference clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaDifference copyWith(void Function(SchemaDifference) updates) =>
      super.copyWith((message) => updates(message as SchemaDifference))
          as SchemaDifference;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchemaDifference create() => SchemaDifference._();
  @$core.override
  SchemaDifference createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchemaDifference getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchemaDifference>(create);
  static SchemaDifference? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get state => $_getSZ(2);
  @$pb.TagNumber(3)
  set state($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get beforeDefinition => $_getSZ(3);
  @$pb.TagNumber(4)
  set beforeDefinition($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBeforeDefinition() => $_has(3);
  @$pb.TagNumber(4)
  void clearBeforeDefinition() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get afterDefinition => $_getSZ(4);
  @$pb.TagNumber(5)
  set afterDefinition($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAfterDefinition() => $_has(4);
  @$pb.TagNumber(5)
  void clearAfterDefinition() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get presentationLimited => $_getBF(5);
  @$pb.TagNumber(6)
  set presentationLimited($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPresentationLimited() => $_has(5);
  @$pb.TagNumber(6)
  void clearPresentationLimited() => $_clearField(6);
}

class SchemaToolResult extends $pb.GeneratedMessage {
  factory SchemaToolResult({
    $core.String? snapshot,
    $core.Iterable<$core.String>? sql,
    $core.Iterable<$core.String>? risks,
    $core.Iterable<$core.String>? unsupported,
    $core.String? definition,
    $core.bool? complete,
    $core.bool? equivalent,
    $core.Iterable<$core.String>? dependencies,
    $core.Iterable<SchemaDifference>? differences,
    $core.bool? differencesLimited,
    SchemaObject? inspectedObject,
    $core.String? provenance,
  }) {
    final result = create();
    if (snapshot != null) result.snapshot = snapshot;
    if (sql != null) result.sql.addAll(sql);
    if (risks != null) result.risks.addAll(risks);
    if (unsupported != null) result.unsupported.addAll(unsupported);
    if (definition != null) result.definition = definition;
    if (complete != null) result.complete = complete;
    if (equivalent != null) result.equivalent = equivalent;
    if (dependencies != null) result.dependencies.addAll(dependencies);
    if (differences != null) result.differences.addAll(differences);
    if (differencesLimited != null)
      result.differencesLimited = differencesLimited;
    if (inspectedObject != null) result.inspectedObject = inspectedObject;
    if (provenance != null) result.provenance = provenance;
    return result;
  }

  SchemaToolResult._();

  factory SchemaToolResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchemaToolResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchemaToolResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'snapshot')
    ..pPS(2, _omitFieldNames ? '' : 'sql')
    ..pPS(3, _omitFieldNames ? '' : 'risks')
    ..pPS(4, _omitFieldNames ? '' : 'unsupported')
    ..aOS(5, _omitFieldNames ? '' : 'definition')
    ..aOB(6, _omitFieldNames ? '' : 'complete')
    ..aOB(7, _omitFieldNames ? '' : 'equivalent')
    ..pPS(8, _omitFieldNames ? '' : 'dependencies')
    ..pPM<SchemaDifference>(9, _omitFieldNames ? '' : 'differences',
        subBuilder: SchemaDifference.create)
    ..aOB(10, _omitFieldNames ? '' : 'differencesLimited')
    ..aOM<SchemaObject>(11, _omitFieldNames ? '' : 'inspectedObject',
        subBuilder: SchemaObject.create)
    ..aOS(12, _omitFieldNames ? '' : 'provenance')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaToolResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaToolResult copyWith(void Function(SchemaToolResult) updates) =>
      super.copyWith((message) => updates(message as SchemaToolResult))
          as SchemaToolResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchemaToolResult create() => SchemaToolResult._();
  @$core.override
  SchemaToolResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchemaToolResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchemaToolResult>(create);
  static SchemaToolResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get snapshot => $_getSZ(0);
  @$pb.TagNumber(1)
  set snapshot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSnapshot() => $_has(0);
  @$pb.TagNumber(1)
  void clearSnapshot() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get sql => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get risks => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get unsupported => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get definition => $_getSZ(4);
  @$pb.TagNumber(5)
  set definition($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDefinition() => $_has(4);
  @$pb.TagNumber(5)
  void clearDefinition() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get complete => $_getBF(5);
  @$pb.TagNumber(6)
  set complete($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasComplete() => $_has(5);
  @$pb.TagNumber(6)
  void clearComplete() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get equivalent => $_getBF(6);
  @$pb.TagNumber(7)
  set equivalent($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEquivalent() => $_has(6);
  @$pb.TagNumber(7)
  void clearEquivalent() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get dependencies => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<SchemaDifference> get differences => $_getList(8);

  @$pb.TagNumber(10)
  $core.bool get differencesLimited => $_getBF(9);
  @$pb.TagNumber(10)
  set differencesLimited($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDifferencesLimited() => $_has(9);
  @$pb.TagNumber(10)
  void clearDifferencesLimited() => $_clearField(10);

  @$pb.TagNumber(11)
  SchemaObject get inspectedObject => $_getN(10);
  @$pb.TagNumber(11)
  set inspectedObject(SchemaObject value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasInspectedObject() => $_has(10);
  @$pb.TagNumber(11)
  void clearInspectedObject() => $_clearField(11);
  @$pb.TagNumber(11)
  SchemaObject ensureInspectedObject() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.String get provenance => $_getSZ(11);
  @$pb.TagNumber(12)
  set provenance($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasProvenance() => $_has(11);
  @$pb.TagNumber(12)
  void clearProvenance() => $_clearField(12);
}

class AuthenticationRequest extends $pb.GeneratedMessage {
  factory AuthenticationRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? executionId,
    AuthenticationAction? action,
    Principal? principal,
    $core.String? password,
    $core.String? approvalToken,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (executionId != null) result.executionId = executionId;
    if (action != null) result.action = action;
    if (principal != null) result.principal = principal;
    if (password != null) result.password = password;
    if (approvalToken != null) result.approvalToken = approvalToken;
    return result;
  }

  AuthenticationRequest._();

  factory AuthenticationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuthenticationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthenticationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aE<AuthenticationAction>(4, _omitFieldNames ? '' : 'action',
        enumValues: AuthenticationAction.values)
    ..aOM<Principal>(5, _omitFieldNames ? '' : 'principal',
        subBuilder: Principal.create)
    ..aOS(6, _omitFieldNames ? '' : 'password')
    ..aOS(7, _omitFieldNames ? '' : 'approvalToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthenticationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthenticationRequest copyWith(
          void Function(AuthenticationRequest) updates) =>
      super.copyWith((message) => updates(message as AuthenticationRequest))
          as AuthenticationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuthenticationRequest create() => AuthenticationRequest._();
  @$core.override
  AuthenticationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuthenticationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthenticationRequest>(create);
  static AuthenticationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  AuthenticationAction get action => $_getN(3);
  @$pb.TagNumber(4)
  set action(AuthenticationAction value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);

  @$pb.TagNumber(5)
  Principal get principal => $_getN(4);
  @$pb.TagNumber(5)
  set principal(Principal value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPrincipal() => $_has(4);
  @$pb.TagNumber(5)
  void clearPrincipal() => $_clearField(5);
  @$pb.TagNumber(5)
  Principal ensurePrincipal() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get password => $_getSZ(5);
  @$pb.TagNumber(6)
  set password($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPassword() => $_has(5);
  @$pb.TagNumber(6)
  void clearPassword() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get approvalToken => $_getSZ(6);
  @$pb.TagNumber(7)
  set approvalToken($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasApprovalToken() => $_has(6);
  @$pb.TagNumber(7)
  void clearApprovalToken() => $_clearField(7);
}

class Principal extends $pb.GeneratedMessage {
  factory Principal({
    $core.String? name,
    $core.String? host,
    $core.String? kind,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (host != null) result.host = host;
    if (kind != null) result.kind = kind;
    return result;
  }

  Principal._();

  factory Principal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Principal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Principal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'host')
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Principal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Principal copyWith(void Function(Principal) updates) =>
      super.copyWith((message) => updates(message as Principal)) as Principal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Principal create() => Principal._();
  @$core.override
  Principal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Principal getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Principal>(create);
  static Principal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get host => $_getSZ(1);
  @$pb.TagNumber(2)
  set host($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHost() => $_has(1);
  @$pb.TagNumber(2)
  void clearHost() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);
}

class PrivilegeRequest extends $pb.GeneratedMessage {
  factory PrivilegeRequest({
    Context? context,
    $core.String? sessionId,
    PrivilegeAction? action,
    Principal? grantee,
    PrivilegeScope? scope,
    $core.String? schema,
    $core.String? table,
    $core.Iterable<$core.String>? privileges,
    $core.bool? revoke,
    $core.bool? delegation,
    Principal? role,
    $core.String? search,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (action != null) result.action = action;
    if (grantee != null) result.grantee = grantee;
    if (scope != null) result.scope = scope;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (privileges != null) result.privileges.addAll(privileges);
    if (revoke != null) result.revoke = revoke;
    if (delegation != null) result.delegation = delegation;
    if (role != null) result.role = role;
    if (search != null) result.search = search;
    return result;
  }

  PrivilegeRequest._();

  factory PrivilegeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PrivilegeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PrivilegeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aE<PrivilegeAction>(3, _omitFieldNames ? '' : 'action',
        enumValues: PrivilegeAction.values)
    ..aOM<Principal>(4, _omitFieldNames ? '' : 'grantee',
        subBuilder: Principal.create)
    ..aE<PrivilegeScope>(5, _omitFieldNames ? '' : 'scope',
        enumValues: PrivilegeScope.values)
    ..aOS(6, _omitFieldNames ? '' : 'schema')
    ..aOS(7, _omitFieldNames ? '' : 'table')
    ..pPS(8, _omitFieldNames ? '' : 'privileges')
    ..aOB(9, _omitFieldNames ? '' : 'revoke')
    ..aOB(10, _omitFieldNames ? '' : 'delegation')
    ..aOM<Principal>(11, _omitFieldNames ? '' : 'role',
        subBuilder: Principal.create)
    ..aOS(12, _omitFieldNames ? '' : 'search')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrivilegeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrivilegeRequest copyWith(void Function(PrivilegeRequest) updates) =>
      super.copyWith((message) => updates(message as PrivilegeRequest))
          as PrivilegeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PrivilegeRequest create() => PrivilegeRequest._();
  @$core.override
  PrivilegeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PrivilegeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PrivilegeRequest>(create);
  static PrivilegeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  PrivilegeAction get action => $_getN(2);
  @$pb.TagNumber(3)
  set action(PrivilegeAction value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAction() => $_has(2);
  @$pb.TagNumber(3)
  void clearAction() => $_clearField(3);

  @$pb.TagNumber(4)
  Principal get grantee => $_getN(3);
  @$pb.TagNumber(4)
  set grantee(Principal value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGrantee() => $_has(3);
  @$pb.TagNumber(4)
  void clearGrantee() => $_clearField(4);
  @$pb.TagNumber(4)
  Principal ensureGrantee() => $_ensure(3);

  @$pb.TagNumber(5)
  PrivilegeScope get scope => $_getN(4);
  @$pb.TagNumber(5)
  set scope(PrivilegeScope value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasScope() => $_has(4);
  @$pb.TagNumber(5)
  void clearScope() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get schema => $_getSZ(5);
  @$pb.TagNumber(6)
  set schema($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSchema() => $_has(5);
  @$pb.TagNumber(6)
  void clearSchema() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get table => $_getSZ(6);
  @$pb.TagNumber(7)
  set table($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTable() => $_has(6);
  @$pb.TagNumber(7)
  void clearTable() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get privileges => $_getList(7);

  @$pb.TagNumber(9)
  $core.bool get revoke => $_getBF(8);
  @$pb.TagNumber(9)
  set revoke($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRevoke() => $_has(8);
  @$pb.TagNumber(9)
  void clearRevoke() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get delegation => $_getBF(9);
  @$pb.TagNumber(10)
  set delegation($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDelegation() => $_has(9);
  @$pb.TagNumber(10)
  void clearDelegation() => $_clearField(10);

  @$pb.TagNumber(11)
  Principal get role => $_getN(10);
  @$pb.TagNumber(11)
  set role(Principal value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRole() => $_has(10);
  @$pb.TagNumber(11)
  void clearRole() => $_clearField(11);
  @$pb.TagNumber(11)
  Principal ensureRole() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.String get search => $_getSZ(11);
  @$pb.TagNumber(12)
  set search($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSearch() => $_has(11);
  @$pb.TagNumber(12)
  void clearSearch() => $_clearField(12);
}

class PrivilegeReply extends $pb.GeneratedMessage {
  factory PrivilegeReply({
    $core.Iterable<Principal>? principals,
    $core.String? definition,
    $core.Iterable<$core.String>? sql,
    $core.Iterable<$core.String>? risks,
    $core.bool? limited,
  }) {
    final result = create();
    if (principals != null) result.principals.addAll(principals);
    if (definition != null) result.definition = definition;
    if (sql != null) result.sql.addAll(sql);
    if (risks != null) result.risks.addAll(risks);
    if (limited != null) result.limited = limited;
    return result;
  }

  PrivilegeReply._();

  factory PrivilegeReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PrivilegeReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PrivilegeReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<Principal>(1, _omitFieldNames ? '' : 'principals',
        subBuilder: Principal.create)
    ..aOS(2, _omitFieldNames ? '' : 'definition')
    ..pPS(3, _omitFieldNames ? '' : 'sql')
    ..pPS(4, _omitFieldNames ? '' : 'risks')
    ..aOB(5, _omitFieldNames ? '' : 'limited')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrivilegeReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrivilegeReply copyWith(void Function(PrivilegeReply) updates) =>
      super.copyWith((message) => updates(message as PrivilegeReply))
          as PrivilegeReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PrivilegeReply create() => PrivilegeReply._();
  @$core.override
  PrivilegeReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PrivilegeReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PrivilegeReply>(create);
  static PrivilegeReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Principal> get principals => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get definition => $_getSZ(1);
  @$pb.TagNumber(2)
  set definition($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefinition() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefinition() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get sql => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get risks => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get limited => $_getBF(4);
  @$pb.TagNumber(5)
  set limited($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLimited() => $_has(4);
  @$pb.TagNumber(5)
  void clearLimited() => $_clearField(5);
}

/// Values are addressed by the result's one-based ordinals. Original values and
/// row identity come exclusively from server-retained rows, never client labels.
class DefaultValue extends $pb.GeneratedMessage {
  factory DefaultValue() => create();

  DefaultValue._();

  factory DefaultValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DefaultValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DefaultValue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefaultValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefaultValue copyWith(void Function(DefaultValue) updates) =>
      super.copyWith((message) => updates(message as DefaultValue))
          as DefaultValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DefaultValue create() => DefaultValue._();
  @$core.override
  DefaultValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DefaultValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DefaultValue>(create);
  static DefaultValue? _defaultInstance;
}

enum ValueAssignment_Assignment { value, nullValue, defaultValue, notSet }

/// No assignment case means unset; explicit NULL and DEFAULT are not text values.
class ValueAssignment extends $pb.GeneratedMessage {
  factory ValueAssignment({
    Value? value,
    Null? nullValue,
    DefaultValue? defaultValue,
  }) {
    final result = create();
    if (value != null) result.value = value;
    if (nullValue != null) result.nullValue = nullValue;
    if (defaultValue != null) result.defaultValue = defaultValue;
    return result;
  }

  ValueAssignment._();

  factory ValueAssignment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ValueAssignment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ValueAssignment_Assignment>
      _ValueAssignment_AssignmentByTag = {
    1: ValueAssignment_Assignment.value,
    2: ValueAssignment_Assignment.nullValue,
    3: ValueAssignment_Assignment.defaultValue,
    0: ValueAssignment_Assignment.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValueAssignment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<Value>(1, _omitFieldNames ? '' : 'value', subBuilder: Value.create)
    ..aOM<Null>(2, _omitFieldNames ? '' : 'nullValue', subBuilder: Null.create)
    ..aOM<DefaultValue>(3, _omitFieldNames ? '' : 'defaultValue',
        subBuilder: DefaultValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValueAssignment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValueAssignment copyWith(void Function(ValueAssignment) updates) =>
      super.copyWith((message) => updates(message as ValueAssignment))
          as ValueAssignment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ValueAssignment create() => ValueAssignment._();
  @$core.override
  ValueAssignment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ValueAssignment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValueAssignment>(create);
  static ValueAssignment? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  ValueAssignment_Assignment whichAssignment() =>
      _ValueAssignment_AssignmentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearAssignment() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Value get value => $_getN(0);
  @$pb.TagNumber(1)
  set value(Value value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
  @$pb.TagNumber(1)
  Value ensureValue() => $_ensure(0);

  @$pb.TagNumber(2)
  Null get nullValue => $_getN(1);
  @$pb.TagNumber(2)
  set nullValue(Null value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNullValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearNullValue() => $_clearField(2);
  @$pb.TagNumber(2)
  Null ensureNullValue() => $_ensure(1);

  @$pb.TagNumber(3)
  DefaultValue get defaultValue => $_getN(2);
  @$pb.TagNumber(3)
  set defaultValue(DefaultValue value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDefaultValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearDefaultValue() => $_clearField(3);
  @$pb.TagNumber(3)
  DefaultValue ensureDefaultValue() => $_ensure(2);
}

class StagedChange extends $pb.GeneratedMessage {
  factory StagedChange({
    ChangeKind? kind,
    $fixnum.Int64? sourceRow,
    $core.Iterable<$core.MapEntry<$core.int, ValueAssignment>>? values,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (sourceRow != null) result.sourceRow = sourceRow;
    if (values != null) result.values.addEntries(values);
    return result;
  }

  StagedChange._();

  factory StagedChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StagedChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StagedChange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aE<ChangeKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: ChangeKind.values)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..m<$core.int, ValueAssignment>(5, _omitFieldNames ? '' : 'values',
        entryClassName: 'StagedChange.ValuesEntry',
        keyFieldType: $pb.PbFieldType.OU3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ValueAssignment.create,
        valueDefaultOrMaker: ValueAssignment.getDefault,
        packageName: const $pb.PackageName('busydata.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StagedChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StagedChange copyWith(void Function(StagedChange) updates) =>
      super.copyWith((message) => updates(message as StagedChange))
          as StagedChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StagedChange create() => StagedChange._();
  @$core.override
  StagedChange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StagedChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StagedChange>(create);
  static StagedChange? _defaultInstance;

  @$pb.TagNumber(1)
  ChangeKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(ChangeKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sourceRow => $_getI64(1);
  @$pb.TagNumber(4)
  set sourceRow($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceRow() => $_has(1);
  @$pb.TagNumber(4)
  void clearSourceRow() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.int, ValueAssignment> get values => $_getMap(2);
}

class ChangeRequest extends $pb.GeneratedMessage {
  factory ChangeRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? catalog,
    $core.String? schema,
    $core.String? table,
    $core.Iterable<StagedChange>? changes,
    $core.String? resultId,
    $core.String? recoveryId,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (changes != null) result.changes.addAll(changes);
    if (resultId != null) result.resultId = resultId;
    if (recoveryId != null) result.recoveryId = recoveryId;
    return result;
  }

  ChangeRequest._();

  factory ChangeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChangeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChangeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'catalog')
    ..aOS(4, _omitFieldNames ? '' : 'schema')
    ..aOS(5, _omitFieldNames ? '' : 'table')
    ..pPM<StagedChange>(6, _omitFieldNames ? '' : 'changes',
        subBuilder: StagedChange.create)
    ..aOS(7, _omitFieldNames ? '' : 'resultId')
    ..aOS(8, _omitFieldNames ? '' : 'recoveryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangeRequest copyWith(void Function(ChangeRequest) updates) =>
      super.copyWith((message) => updates(message as ChangeRequest))
          as ChangeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChangeRequest create() => ChangeRequest._();
  @$core.override
  ChangeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChangeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChangeRequest>(create);
  static ChangeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get catalog => $_getSZ(2);
  @$pb.TagNumber(3)
  set catalog($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCatalog() => $_has(2);
  @$pb.TagNumber(3)
  void clearCatalog() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get schema => $_getSZ(3);
  @$pb.TagNumber(4)
  set schema($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchema() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchema() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get table => $_getSZ(4);
  @$pb.TagNumber(5)
  set table($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTable() => $_has(4);
  @$pb.TagNumber(5)
  void clearTable() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<StagedChange> get changes => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get resultId => $_getSZ(6);
  @$pb.TagNumber(7)
  set resultId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasResultId() => $_has(6);
  @$pb.TagNumber(7)
  void clearResultId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get recoveryId => $_getSZ(7);
  @$pb.TagNumber(8)
  set recoveryId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRecoveryId() => $_has(7);
  @$pb.TagNumber(8)
  void clearRecoveryId() => $_clearField(8);
}

class ReviewedChange extends $pb.GeneratedMessage {
  factory ReviewedChange({
    ChangeKind? kind,
    $core.Iterable<$core.MapEntry<$core.String, ValueAssignment>>? values,
    $core.Iterable<$core.MapEntry<$core.String, Value>>? original,
    $fixnum.Int64? sourceRow,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (values != null) result.values.addEntries(values);
    if (original != null) result.original.addEntries(original);
    if (sourceRow != null) result.sourceRow = sourceRow;
    return result;
  }

  ReviewedChange._();

  factory ReviewedChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReviewedChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReviewedChange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aE<ChangeKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: ChangeKind.values)
    ..m<$core.String, ValueAssignment>(2, _omitFieldNames ? '' : 'values',
        entryClassName: 'ReviewedChange.ValuesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ValueAssignment.create,
        valueDefaultOrMaker: ValueAssignment.getDefault,
        packageName: const $pb.PackageName('busydata.v1'))
    ..m<$core.String, Value>(3, _omitFieldNames ? '' : 'original',
        entryClassName: 'ReviewedChange.OriginalEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Value.create,
        valueDefaultOrMaker: Value.getDefault,
        packageName: const $pb.PackageName('busydata.v1'))
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReviewedChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReviewedChange copyWith(void Function(ReviewedChange) updates) =>
      super.copyWith((message) => updates(message as ReviewedChange))
          as ReviewedChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReviewedChange create() => ReviewedChange._();
  @$core.override
  ReviewedChange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReviewedChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReviewedChange>(create);
  static ReviewedChange? _defaultInstance;

  @$pb.TagNumber(1)
  ChangeKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(ChangeKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, ValueAssignment> get values => $_getMap(1);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, Value> get original => $_getMap(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sourceRow => $_getI64(3);
  @$pb.TagNumber(4)
  set sourceRow($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceRow() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceRow() => $_clearField(4);
}

class ChangePlan extends $pb.GeneratedMessage {
  factory ChangePlan({
    $core.String? planId,
    $core.Iterable<$core.String>? sql,
    $core.Iterable<$core.String>? risks,
    $fixnum.Int64? expiresUnixMs,
    $core.Iterable<ReviewedChange>? changes,
    Profile? target,
  }) {
    final result = create();
    if (planId != null) result.planId = planId;
    if (sql != null) result.sql.addAll(sql);
    if (risks != null) result.risks.addAll(risks);
    if (expiresUnixMs != null) result.expiresUnixMs = expiresUnixMs;
    if (changes != null) result.changes.addAll(changes);
    if (target != null) result.target = target;
    return result;
  }

  ChangePlan._();

  factory ChangePlan.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChangePlan.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChangePlan',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'planId')
    ..pPS(2, _omitFieldNames ? '' : 'sql')
    ..pPS(3, _omitFieldNames ? '' : 'risks')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'expiresUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<ReviewedChange>(5, _omitFieldNames ? '' : 'changes',
        subBuilder: ReviewedChange.create)
    ..aOM<Profile>(6, _omitFieldNames ? '' : 'target',
        subBuilder: Profile.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangePlan clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangePlan copyWith(void Function(ChangePlan) updates) =>
      super.copyWith((message) => updates(message as ChangePlan)) as ChangePlan;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChangePlan create() => ChangePlan._();
  @$core.override
  ChangePlan createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChangePlan getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChangePlan>(create);
  static ChangePlan? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get planId => $_getSZ(0);
  @$pb.TagNumber(1)
  set planId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlanId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get sql => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get risks => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get expiresUnixMs => $_getI64(3);
  @$pb.TagNumber(4)
  set expiresUnixMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresUnixMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresUnixMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<ReviewedChange> get changes => $_getList(4);

  @$pb.TagNumber(6)
  Profile get target => $_getN(5);
  @$pb.TagNumber(6)
  set target(Profile value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTarget() => $_has(5);
  @$pb.TagNumber(6)
  void clearTarget() => $_clearField(6);
  @$pb.TagNumber(6)
  Profile ensureTarget() => $_ensure(5);
}

class Editability extends $pb.GeneratedMessage {
  factory Editability({
    $core.bool? editable,
    $core.String? reason,
    $core.Iterable<$core.int>? editableColumns,
    $core.String? reasonCode,
  }) {
    final result = create();
    if (editable != null) result.editable = editable;
    if (reason != null) result.reason = reason;
    if (editableColumns != null) result.editableColumns.addAll(editableColumns);
    if (reasonCode != null) result.reasonCode = reasonCode;
    return result;
  }

  Editability._();

  factory Editability.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Editability.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Editability',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'editable')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..p<$core.int>(
        3, _omitFieldNames ? '' : 'editableColumns', $pb.PbFieldType.KU3)
    ..aOS(4, _omitFieldNames ? '' : 'reasonCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Editability clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Editability copyWith(void Function(Editability) updates) =>
      super.copyWith((message) => updates(message as Editability))
          as Editability;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Editability create() => Editability._();
  @$core.override
  Editability createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Editability getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Editability>(create);
  static Editability? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get editable => $_getBF(0);
  @$pb.TagNumber(1)
  set editable($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEditable() => $_has(0);
  @$pb.TagNumber(1)
  void clearEditable() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get editableColumns => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get reasonCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set reasonCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReasonCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearReasonCode() => $_clearField(4);
}

class ApplyRequest extends $pb.GeneratedMessage {
  factory ApplyRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? executionId,
    $core.String? planId,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (executionId != null) result.executionId = executionId;
    if (planId != null) result.planId = planId;
    return result;
  }

  ApplyRequest._();

  factory ApplyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApplyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApplyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aOS(4, _omitFieldNames ? '' : 'planId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyRequest copyWith(void Function(ApplyRequest) updates) =>
      super.copyWith((message) => updates(message as ApplyRequest))
          as ApplyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApplyRequest create() => ApplyRequest._();
  @$core.override
  ApplyRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApplyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApplyRequest>(create);
  static ApplyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get planId => $_getSZ(3);
  @$pb.TagNumber(4)
  set planId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlanId() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlanId() => $_clearField(4);
}

class ToolRequest extends $pb.GeneratedMessage {
  factory ToolRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? executionId,
    ToolKind? kind,
    $core.String? sql,
    $core.String? schema,
    $core.String? table,
    $core.String? path,
    $core.String? format,
    $core.String? resultId,
    $core.String? approvalToken,
    $core.bool? overwrite,
    $core.Iterable<$core.String>? columns,
    $core.String? nullMarker,
    $core.String? encoding,
    $core.String? nativeToolPath,
    $core.String? valueId,
    $fixnum.Int64? targetId,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? columnMapping,
    $core.String? sourceSha256,
    $core.String? delimiter,
    ImportPolicy? importPolicy,
    $core.int? batchRows,
    $core.int? errorLimit,
    $fixnum.Int64? outputLimitBytes,
    $core.String? activityFingerprint,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (executionId != null) result.executionId = executionId;
    if (kind != null) result.kind = kind;
    if (sql != null) result.sql = sql;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (path != null) result.path = path;
    if (format != null) result.format = format;
    if (resultId != null) result.resultId = resultId;
    if (approvalToken != null) result.approvalToken = approvalToken;
    if (overwrite != null) result.overwrite = overwrite;
    if (columns != null) result.columns.addAll(columns);
    if (nullMarker != null) result.nullMarker = nullMarker;
    if (encoding != null) result.encoding = encoding;
    if (nativeToolPath != null) result.nativeToolPath = nativeToolPath;
    if (valueId != null) result.valueId = valueId;
    if (targetId != null) result.targetId = targetId;
    if (columnMapping != null) result.columnMapping.addEntries(columnMapping);
    if (sourceSha256 != null) result.sourceSha256 = sourceSha256;
    if (delimiter != null) result.delimiter = delimiter;
    if (importPolicy != null) result.importPolicy = importPolicy;
    if (batchRows != null) result.batchRows = batchRows;
    if (errorLimit != null) result.errorLimit = errorLimit;
    if (outputLimitBytes != null) result.outputLimitBytes = outputLimitBytes;
    if (activityFingerprint != null)
      result.activityFingerprint = activityFingerprint;
    return result;
  }

  ToolRequest._();

  factory ToolRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ToolRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToolRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'executionId')
    ..aE<ToolKind>(4, _omitFieldNames ? '' : 'kind',
        enumValues: ToolKind.values)
    ..aOS(5, _omitFieldNames ? '' : 'sql')
    ..aOS(6, _omitFieldNames ? '' : 'schema')
    ..aOS(7, _omitFieldNames ? '' : 'table')
    ..aOS(8, _omitFieldNames ? '' : 'path')
    ..aOS(9, _omitFieldNames ? '' : 'format')
    ..aOS(10, _omitFieldNames ? '' : 'resultId')
    ..aOS(11, _omitFieldNames ? '' : 'approvalToken')
    ..aOB(12, _omitFieldNames ? '' : 'overwrite')
    ..pPS(13, _omitFieldNames ? '' : 'columns')
    ..aOS(14, _omitFieldNames ? '' : 'nullMarker')
    ..aOS(15, _omitFieldNames ? '' : 'encoding')
    ..aOS(16, _omitFieldNames ? '' : 'nativeToolPath')
    ..aOS(17, _omitFieldNames ? '' : 'valueId')
    ..a<$fixnum.Int64>(
        18, _omitFieldNames ? '' : 'targetId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..m<$core.String, $core.String>(19, _omitFieldNames ? '' : 'columnMapping',
        entryClassName: 'ToolRequest.ColumnMappingEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('busydata.v1'))
    ..aOS(20, _omitFieldNames ? '' : 'sourceSha256')
    ..aOS(21, _omitFieldNames ? '' : 'delimiter')
    ..aE<ImportPolicy>(22, _omitFieldNames ? '' : 'importPolicy',
        enumValues: ImportPolicy.values)
    ..aI(23, _omitFieldNames ? '' : 'batchRows', fieldType: $pb.PbFieldType.OU3)
    ..aI(24, _omitFieldNames ? '' : 'errorLimit',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        25, _omitFieldNames ? '' : 'outputLimitBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(26, _omitFieldNames ? '' : 'activityFingerprint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolRequest copyWith(void Function(ToolRequest) updates) =>
      super.copyWith((message) => updates(message as ToolRequest))
          as ToolRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ToolRequest create() => ToolRequest._();
  @$core.override
  ToolRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ToolRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ToolRequest>(create);
  static ToolRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get executionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set executionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionId() => $_clearField(3);

  @$pb.TagNumber(4)
  ToolKind get kind => $_getN(3);
  @$pb.TagNumber(4)
  set kind(ToolKind value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sql => $_getSZ(4);
  @$pb.TagNumber(5)
  set sql($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSql() => $_has(4);
  @$pb.TagNumber(5)
  void clearSql() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get schema => $_getSZ(5);
  @$pb.TagNumber(6)
  set schema($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSchema() => $_has(5);
  @$pb.TagNumber(6)
  void clearSchema() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get table => $_getSZ(6);
  @$pb.TagNumber(7)
  set table($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTable() => $_has(6);
  @$pb.TagNumber(7)
  void clearTable() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get path => $_getSZ(7);
  @$pb.TagNumber(8)
  set path($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPath() => $_has(7);
  @$pb.TagNumber(8)
  void clearPath() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get format => $_getSZ(8);
  @$pb.TagNumber(9)
  set format($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFormat() => $_has(8);
  @$pb.TagNumber(9)
  void clearFormat() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get resultId => $_getSZ(9);
  @$pb.TagNumber(10)
  set resultId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasResultId() => $_has(9);
  @$pb.TagNumber(10)
  void clearResultId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get approvalToken => $_getSZ(10);
  @$pb.TagNumber(11)
  set approvalToken($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasApprovalToken() => $_has(10);
  @$pb.TagNumber(11)
  void clearApprovalToken() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get overwrite => $_getBF(11);
  @$pb.TagNumber(12)
  set overwrite($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasOverwrite() => $_has(11);
  @$pb.TagNumber(12)
  void clearOverwrite() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<$core.String> get columns => $_getList(12);

  @$pb.TagNumber(14)
  $core.String get nullMarker => $_getSZ(13);
  @$pb.TagNumber(14)
  set nullMarker($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasNullMarker() => $_has(13);
  @$pb.TagNumber(14)
  void clearNullMarker() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get encoding => $_getSZ(14);
  @$pb.TagNumber(15)
  set encoding($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasEncoding() => $_has(14);
  @$pb.TagNumber(15)
  void clearEncoding() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get nativeToolPath => $_getSZ(15);
  @$pb.TagNumber(16)
  set nativeToolPath($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasNativeToolPath() => $_has(15);
  @$pb.TagNumber(16)
  void clearNativeToolPath() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get valueId => $_getSZ(16);
  @$pb.TagNumber(17)
  set valueId($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasValueId() => $_has(16);
  @$pb.TagNumber(17)
  void clearValueId() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get targetId => $_getI64(17);
  @$pb.TagNumber(18)
  set targetId($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasTargetId() => $_has(17);
  @$pb.TagNumber(18)
  void clearTargetId() => $_clearField(18);

  @$pb.TagNumber(19)
  $pb.PbMap<$core.String, $core.String> get columnMapping => $_getMap(18);

  @$pb.TagNumber(20)
  $core.String get sourceSha256 => $_getSZ(19);
  @$pb.TagNumber(20)
  set sourceSha256($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasSourceSha256() => $_has(19);
  @$pb.TagNumber(20)
  void clearSourceSha256() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get delimiter => $_getSZ(20);
  @$pb.TagNumber(21)
  set delimiter($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasDelimiter() => $_has(20);
  @$pb.TagNumber(21)
  void clearDelimiter() => $_clearField(21);

  @$pb.TagNumber(22)
  ImportPolicy get importPolicy => $_getN(21);
  @$pb.TagNumber(22)
  set importPolicy(ImportPolicy value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasImportPolicy() => $_has(21);
  @$pb.TagNumber(22)
  void clearImportPolicy() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.int get batchRows => $_getIZ(22);
  @$pb.TagNumber(23)
  set batchRows($core.int value) => $_setUnsignedInt32(22, value);
  @$pb.TagNumber(23)
  $core.bool hasBatchRows() => $_has(22);
  @$pb.TagNumber(23)
  void clearBatchRows() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.int get errorLimit => $_getIZ(23);
  @$pb.TagNumber(24)
  set errorLimit($core.int value) => $_setUnsignedInt32(23, value);
  @$pb.TagNumber(24)
  $core.bool hasErrorLimit() => $_has(23);
  @$pb.TagNumber(24)
  void clearErrorLimit() => $_clearField(24);

  @$pb.TagNumber(25)
  $fixnum.Int64 get outputLimitBytes => $_getI64(24);
  @$pb.TagNumber(25)
  set outputLimitBytes($fixnum.Int64 value) => $_setInt64(24, value);
  @$pb.TagNumber(25)
  $core.bool hasOutputLimitBytes() => $_has(24);
  @$pb.TagNumber(25)
  void clearOutputLimitBytes() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.String get activityFingerprint => $_getSZ(25);
  @$pb.TagNumber(26)
  set activityFingerprint($core.String value) => $_setString(25, value);
  @$pb.TagNumber(26)
  $core.bool hasActivityFingerprint() => $_has(25);
  @$pb.TagNumber(26)
  void clearActivityFingerprint() => $_clearField(26);
}

class ActivityRequest extends $pb.GeneratedMessage {
  factory ActivityRequest({
    Context? context,
    $core.String? sessionId,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  ActivityRequest._();

  factory ActivityRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityRequest copyWith(void Function(ActivityRequest) updates) =>
      super.copyWith((message) => updates(message as ActivityRequest))
          as ActivityRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityRequest create() => ActivityRequest._();
  @$core.override
  ActivityRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityRequest>(create);
  static ActivityRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);
}

class Activity extends $pb.GeneratedMessage {
  factory Activity({
    $fixnum.Int64? id,
    $core.String? principal,
    $core.String? database,
    $core.String? state,
    $core.String? queryPreview,
    $core.String? fingerprint,
    $core.Iterable<$fixnum.Int64>? blockers,
    $core.String? wait,
    $core.bool? cancellable,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (principal != null) result.principal = principal;
    if (database != null) result.database = database;
    if (state != null) result.state = state;
    if (queryPreview != null) result.queryPreview = queryPreview;
    if (fingerprint != null) result.fingerprint = fingerprint;
    if (blockers != null) result.blockers.addAll(blockers);
    if (wait != null) result.wait = wait;
    if (cancellable != null) result.cancellable = cancellable;
    return result;
  }

  Activity._();

  factory Activity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Activity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Activity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'principal')
    ..aOS(3, _omitFieldNames ? '' : 'database')
    ..aOS(4, _omitFieldNames ? '' : 'state')
    ..aOS(5, _omitFieldNames ? '' : 'queryPreview')
    ..aOS(6, _omitFieldNames ? '' : 'fingerprint')
    ..p<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'blockers', $pb.PbFieldType.KU6)
    ..aOS(8, _omitFieldNames ? '' : 'wait')
    ..aOB(9, _omitFieldNames ? '' : 'cancellable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Activity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Activity copyWith(void Function(Activity) updates) =>
      super.copyWith((message) => updates(message as Activity)) as Activity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Activity create() => Activity._();
  @$core.override
  Activity createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Activity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Activity>(create);
  static Activity? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get principal => $_getSZ(1);
  @$pb.TagNumber(2)
  set principal($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPrincipal() => $_has(1);
  @$pb.TagNumber(2)
  void clearPrincipal() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get database => $_getSZ(2);
  @$pb.TagNumber(3)
  set database($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDatabase() => $_has(2);
  @$pb.TagNumber(3)
  void clearDatabase() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get state => $_getSZ(3);
  @$pb.TagNumber(4)
  set state($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get queryPreview => $_getSZ(4);
  @$pb.TagNumber(5)
  set queryPreview($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQueryPreview() => $_has(4);
  @$pb.TagNumber(5)
  void clearQueryPreview() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get fingerprint => $_getSZ(5);
  @$pb.TagNumber(6)
  set fingerprint($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFingerprint() => $_has(5);
  @$pb.TagNumber(6)
  void clearFingerprint() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$fixnum.Int64> get blockers => $_getList(6);

  @$pb.TagNumber(8)
  $core.String get wait => $_getSZ(7);
  @$pb.TagNumber(8)
  set wait($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWait() => $_has(7);
  @$pb.TagNumber(8)
  void clearWait() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get cancellable => $_getBF(8);
  @$pb.TagNumber(9)
  set cancellable($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCancellable() => $_has(8);
  @$pb.TagNumber(9)
  void clearCancellable() => $_clearField(9);
}

class ActivityList extends $pb.GeneratedMessage {
  factory ActivityList({
    $core.Iterable<Activity>? entries,
    $core.bool? limited,
    $core.String? availability,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    if (limited != null) result.limited = limited;
    if (availability != null) result.availability = availability;
    return result;
  }

  ActivityList._();

  factory ActivityList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<Activity>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: Activity.create)
    ..aOB(2, _omitFieldNames ? '' : 'limited')
    ..aOS(3, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityList copyWith(void Function(ActivityList) updates) =>
      super.copyWith((message) => updates(message as ActivityList))
          as ActivityList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityList create() => ActivityList._();
  @$core.override
  ActivityList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityList>(create);
  static ActivityList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Activity> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get limited => $_getBF(1);
  @$pb.TagNumber(2)
  set limited($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimited() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimited() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get availability => $_getSZ(2);
  @$pb.TagNumber(3)
  set availability($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvailability() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvailability() => $_clearField(3);
}

class ImportPreview extends $pb.GeneratedMessage {
  factory ImportPreview({
    $core.Iterable<$core.String>? sourceColumns,
    $core.Iterable<Row>? rows,
    $core.bool? limited,
    $core.String? encoding,
    $core.String? nullMarker,
    $core.Iterable<$core.String>? warnings,
    $core.String? sourceSha256,
  }) {
    final result = create();
    if (sourceColumns != null) result.sourceColumns.addAll(sourceColumns);
    if (rows != null) result.rows.addAll(rows);
    if (limited != null) result.limited = limited;
    if (encoding != null) result.encoding = encoding;
    if (nullMarker != null) result.nullMarker = nullMarker;
    if (warnings != null) result.warnings.addAll(warnings);
    if (sourceSha256 != null) result.sourceSha256 = sourceSha256;
    return result;
  }

  ImportPreview._();

  factory ImportPreview.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImportPreview.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportPreview',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'sourceColumns')
    ..pPM<Row>(2, _omitFieldNames ? '' : 'rows', subBuilder: Row.create)
    ..aOB(3, _omitFieldNames ? '' : 'limited')
    ..aOS(4, _omitFieldNames ? '' : 'encoding')
    ..aOS(5, _omitFieldNames ? '' : 'nullMarker')
    ..pPS(6, _omitFieldNames ? '' : 'warnings')
    ..aOS(7, _omitFieldNames ? '' : 'sourceSha256')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportPreview clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportPreview copyWith(void Function(ImportPreview) updates) =>
      super.copyWith((message) => updates(message as ImportPreview))
          as ImportPreview;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImportPreview create() => ImportPreview._();
  @$core.override
  ImportPreview createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImportPreview getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportPreview>(create);
  static ImportPreview? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get sourceColumns => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<Row> get rows => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get limited => $_getBF(2);
  @$pb.TagNumber(3)
  set limited($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimited() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimited() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get encoding => $_getSZ(3);
  @$pb.TagNumber(4)
  set encoding($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEncoding() => $_has(3);
  @$pb.TagNumber(4)
  void clearEncoding() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get nullMarker => $_getSZ(4);
  @$pb.TagNumber(5)
  set nullMarker($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNullMarker() => $_has(4);
  @$pb.TagNumber(5)
  void clearNullMarker() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get warnings => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get sourceSha256 => $_getSZ(6);
  @$pb.TagNumber(7)
  set sourceSha256($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceSha256() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceSha256() => $_clearField(7);
}

class HistoryRequest extends $pb.GeneratedMessage {
  factory HistoryRequest({
    Context? context,
    HistoryAction? action,
    $core.String? search,
    $core.bool? retainSql,
    $core.int? retentionDays,
    $core.String? entryId,
    $core.int? offset,
    $core.int? limit,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (action != null) result.action = action;
    if (search != null) result.search = search;
    if (retainSql != null) result.retainSql = retainSql;
    if (retentionDays != null) result.retentionDays = retentionDays;
    if (entryId != null) result.entryId = entryId;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    return result;
  }

  HistoryRequest._();

  factory HistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aE<HistoryAction>(2, _omitFieldNames ? '' : 'action',
        enumValues: HistoryAction.values)
    ..aOS(3, _omitFieldNames ? '' : 'search')
    ..aOB(4, _omitFieldNames ? '' : 'retainSql')
    ..aI(5, _omitFieldNames ? '' : 'retentionDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'entryId')
    ..aI(7, _omitFieldNames ? '' : 'offset', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryRequest copyWith(void Function(HistoryRequest) updates) =>
      super.copyWith((message) => updates(message as HistoryRequest))
          as HistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistoryRequest create() => HistoryRequest._();
  @$core.override
  HistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistoryRequest>(create);
  static HistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  HistoryAction get action => $_getN(1);
  @$pb.TagNumber(2)
  set action(HistoryAction value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAction() => $_has(1);
  @$pb.TagNumber(2)
  void clearAction() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get search => $_getSZ(2);
  @$pb.TagNumber(3)
  set search($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSearch() => $_has(2);
  @$pb.TagNumber(3)
  void clearSearch() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get retainSql => $_getBF(3);
  @$pb.TagNumber(4)
  set retainSql($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRetainSql() => $_has(3);
  @$pb.TagNumber(4)
  void clearRetainSql() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get retentionDays => $_getIZ(4);
  @$pb.TagNumber(5)
  set retentionDays($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRetentionDays() => $_has(4);
  @$pb.TagNumber(5)
  void clearRetentionDays() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get entryId => $_getSZ(5);
  @$pb.TagNumber(6)
  set entryId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEntryId() => $_has(5);
  @$pb.TagNumber(6)
  void clearEntryId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get offset => $_getIZ(6);
  @$pb.TagNumber(7)
  set offset($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOffset() => $_has(6);
  @$pb.TagNumber(7)
  void clearOffset() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get limit => $_getIZ(7);
  @$pb.TagNumber(8)
  set limit($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLimit() => $_has(7);
  @$pb.TagNumber(8)
  void clearLimit() => $_clearField(8);
}

class HistoryEntry extends $pb.GeneratedMessage {
  factory HistoryEntry({
    $core.String? id,
    $core.String? target,
    $core.String? sql,
    JobState? state,
    $fixnum.Int64? durationMs,
    $fixnum.Int64? startedUnixMs,
    $core.bool? sqlTruncated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (target != null) result.target = target;
    if (sql != null) result.sql = sql;
    if (state != null) result.state = state;
    if (durationMs != null) result.durationMs = durationMs;
    if (startedUnixMs != null) result.startedUnixMs = startedUnixMs;
    if (sqlTruncated != null) result.sqlTruncated = sqlTruncated;
    return result;
  }

  HistoryEntry._();

  factory HistoryEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistoryEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoryEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'target')
    ..aOS(3, _omitFieldNames ? '' : 'sql')
    ..aE<JobState>(4, _omitFieldNames ? '' : 'state',
        enumValues: JobState.values)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'durationMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'startedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(7, _omitFieldNames ? '' : 'sqlTruncated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryEntry copyWith(void Function(HistoryEntry) updates) =>
      super.copyWith((message) => updates(message as HistoryEntry))
          as HistoryEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistoryEntry create() => HistoryEntry._();
  @$core.override
  HistoryEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistoryEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistoryEntry>(create);
  static HistoryEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get target => $_getSZ(1);
  @$pb.TagNumber(2)
  set target($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTarget() => $_has(1);
  @$pb.TagNumber(2)
  void clearTarget() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sql => $_getSZ(2);
  @$pb.TagNumber(3)
  set sql($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSql() => $_has(2);
  @$pb.TagNumber(3)
  void clearSql() => $_clearField(3);

  @$pb.TagNumber(4)
  JobState get state => $_getN(3);
  @$pb.TagNumber(4)
  set state(JobState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get startedUnixMs => $_getI64(5);
  @$pb.TagNumber(6)
  set startedUnixMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartedUnixMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartedUnixMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get sqlTruncated => $_getBF(6);
  @$pb.TagNumber(7)
  set sqlTruncated($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSqlTruncated() => $_has(6);
  @$pb.TagNumber(7)
  void clearSqlTruncated() => $_clearField(7);
}

class HistoryList extends $pb.GeneratedMessage {
  factory HistoryList({
    $core.Iterable<HistoryEntry>? entries,
    $core.bool? retainSql,
    $core.int? retentionDays,
    $core.bool? limited,
    $core.int? nextOffset,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    if (retainSql != null) result.retainSql = retainSql;
    if (retentionDays != null) result.retentionDays = retentionDays;
    if (limited != null) result.limited = limited;
    if (nextOffset != null) result.nextOffset = nextOffset;
    return result;
  }

  HistoryList._();

  factory HistoryList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistoryList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoryList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<HistoryEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: HistoryEntry.create)
    ..aOB(2, _omitFieldNames ? '' : 'retainSql')
    ..aI(3, _omitFieldNames ? '' : 'retentionDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'limited')
    ..aI(5, _omitFieldNames ? '' : 'nextOffset', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryList copyWith(void Function(HistoryList) updates) =>
      super.copyWith((message) => updates(message as HistoryList))
          as HistoryList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistoryList create() => HistoryList._();
  @$core.override
  HistoryList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistoryList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistoryList>(create);
  static HistoryList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<HistoryEntry> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get retainSql => $_getBF(1);
  @$pb.TagNumber(2)
  set retainSql($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRetainSql() => $_has(1);
  @$pb.TagNumber(2)
  void clearRetainSql() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get retentionDays => $_getIZ(2);
  @$pb.TagNumber(3)
  set retentionDays($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRetentionDays() => $_has(2);
  @$pb.TagNumber(3)
  void clearRetentionDays() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get limited => $_getBF(3);
  @$pb.TagNumber(4)
  set limited($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLimited() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimited() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get nextOffset => $_getIZ(4);
  @$pb.TagNumber(5)
  set nextOffset($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNextOffset() => $_has(4);
  @$pb.TagNumber(5)
  void clearNextOffset() => $_clearField(5);
}

class HistorySqlRequest extends $pb.GeneratedMessage {
  factory HistorySqlRequest({
    Context? context,
    $core.String? entryId,
    $core.int? offsetUtf16,
    $core.int? maxUnits,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (entryId != null) result.entryId = entryId;
    if (offsetUtf16 != null) result.offsetUtf16 = offsetUtf16;
    if (maxUnits != null) result.maxUnits = maxUnits;
    return result;
  }

  HistorySqlRequest._();

  factory HistorySqlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistorySqlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistorySqlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'entryId')
    ..aI(3, _omitFieldNames ? '' : 'offsetUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'maxUnits', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistorySqlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistorySqlRequest copyWith(void Function(HistorySqlRequest) updates) =>
      super.copyWith((message) => updates(message as HistorySqlRequest))
          as HistorySqlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistorySqlRequest create() => HistorySqlRequest._();
  @$core.override
  HistorySqlRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistorySqlRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistorySqlRequest>(create);
  static HistorySqlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get entryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set entryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEntryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntryId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get offsetUtf16 => $_getIZ(2);
  @$pb.TagNumber(3)
  set offsetUtf16($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOffsetUtf16() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffsetUtf16() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get maxUnits => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxUnits($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxUnits() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxUnits() => $_clearField(4);
}

class HistorySqlChunk extends $pb.GeneratedMessage {
  factory HistorySqlChunk({
    $core.String? text,
    $core.int? totalUnits,
    $core.int? nextOffsetUtf16,
    $core.bool? complete,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (totalUnits != null) result.totalUnits = totalUnits;
    if (nextOffsetUtf16 != null) result.nextOffsetUtf16 = nextOffsetUtf16;
    if (complete != null) result.complete = complete;
    return result;
  }

  HistorySqlChunk._();

  factory HistorySqlChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistorySqlChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistorySqlChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aI(2, _omitFieldNames ? '' : 'totalUnits', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'nextOffsetUtf16',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'complete')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistorySqlChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistorySqlChunk copyWith(void Function(HistorySqlChunk) updates) =>
      super.copyWith((message) => updates(message as HistorySqlChunk))
          as HistorySqlChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistorySqlChunk create() => HistorySqlChunk._();
  @$core.override
  HistorySqlChunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistorySqlChunk getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistorySqlChunk>(create);
  static HistorySqlChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalUnits => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalUnits($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalUnits() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalUnits() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get nextOffsetUtf16 => $_getIZ(2);
  @$pb.TagNumber(3)
  set nextOffsetUtf16($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNextOffsetUtf16() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextOffsetUtf16() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get complete => $_getBF(3);
  @$pb.TagNumber(4)
  set complete($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasComplete() => $_has(3);
  @$pb.TagNumber(4)
  void clearComplete() => $_clearField(4);
}

class EditDraftRequest extends $pb.GeneratedMessage {
  factory EditDraftRequest({
    Context? context,
    EditDraftAction? action,
    $core.String? draftId,
    $core.String? sessionId,
    $core.String? documentId,
    ChangeRequest? changes,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (action != null) result.action = action;
    if (draftId != null) result.draftId = draftId;
    if (sessionId != null) result.sessionId = sessionId;
    if (documentId != null) result.documentId = documentId;
    if (changes != null) result.changes = changes;
    return result;
  }

  EditDraftRequest._();

  factory EditDraftRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditDraftRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditDraftRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aE<EditDraftAction>(2, _omitFieldNames ? '' : 'action',
        enumValues: EditDraftAction.values)
    ..aOS(3, _omitFieldNames ? '' : 'draftId')
    ..aOS(4, _omitFieldNames ? '' : 'sessionId')
    ..aOS(5, _omitFieldNames ? '' : 'documentId')
    ..aOM<ChangeRequest>(6, _omitFieldNames ? '' : 'changes',
        subBuilder: ChangeRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftRequest copyWith(void Function(EditDraftRequest) updates) =>
      super.copyWith((message) => updates(message as EditDraftRequest))
          as EditDraftRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditDraftRequest create() => EditDraftRequest._();
  @$core.override
  EditDraftRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditDraftRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditDraftRequest>(create);
  static EditDraftRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  EditDraftAction get action => $_getN(1);
  @$pb.TagNumber(2)
  set action(EditDraftAction value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAction() => $_has(1);
  @$pb.TagNumber(2)
  void clearAction() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get draftId => $_getSZ(2);
  @$pb.TagNumber(3)
  set draftId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDraftId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDraftId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sessionId => $_getSZ(3);
  @$pb.TagNumber(4)
  set sessionId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get documentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set documentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDocumentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearDocumentId() => $_clearField(5);

  @$pb.TagNumber(6)
  ChangeRequest get changes => $_getN(5);
  @$pb.TagNumber(6)
  set changes(ChangeRequest value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasChanges() => $_has(5);
  @$pb.TagNumber(6)
  void clearChanges() => $_clearField(6);
  @$pb.TagNumber(6)
  ChangeRequest ensureChanges() => $_ensure(5);
}

class EditDraftInfo extends $pb.GeneratedMessage {
  factory EditDraftInfo({
    $core.String? draftId,
    $core.String? documentId,
    Profile? target,
    $core.String? schema,
    $core.String? table,
    $core.int? changes,
    $core.String? state,
    $fixnum.Int64? createdUnixMs,
  }) {
    final result = create();
    if (draftId != null) result.draftId = draftId;
    if (documentId != null) result.documentId = documentId;
    if (target != null) result.target = target;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    if (changes != null) result.changes = changes;
    if (state != null) result.state = state;
    if (createdUnixMs != null) result.createdUnixMs = createdUnixMs;
    return result;
  }

  EditDraftInfo._();

  factory EditDraftInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditDraftInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditDraftInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'draftId')
    ..aOS(2, _omitFieldNames ? '' : 'documentId')
    ..aOM<Profile>(3, _omitFieldNames ? '' : 'target',
        subBuilder: Profile.create)
    ..aOS(4, _omitFieldNames ? '' : 'schema')
    ..aOS(5, _omitFieldNames ? '' : 'table')
    ..aI(6, _omitFieldNames ? '' : 'changes', fieldType: $pb.PbFieldType.OU3)
    ..aOS(7, _omitFieldNames ? '' : 'state')
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'createdUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftInfo copyWith(void Function(EditDraftInfo) updates) =>
      super.copyWith((message) => updates(message as EditDraftInfo))
          as EditDraftInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditDraftInfo create() => EditDraftInfo._();
  @$core.override
  EditDraftInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditDraftInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditDraftInfo>(create);
  static EditDraftInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get draftId => $_getSZ(0);
  @$pb.TagNumber(1)
  set draftId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDraftId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDraftId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get documentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set documentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDocumentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDocumentId() => $_clearField(2);

  @$pb.TagNumber(3)
  Profile get target => $_getN(2);
  @$pb.TagNumber(3)
  set target(Profile value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTarget() => $_has(2);
  @$pb.TagNumber(3)
  void clearTarget() => $_clearField(3);
  @$pb.TagNumber(3)
  Profile ensureTarget() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get schema => $_getSZ(3);
  @$pb.TagNumber(4)
  set schema($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchema() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchema() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get table => $_getSZ(4);
  @$pb.TagNumber(5)
  set table($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTable() => $_has(4);
  @$pb.TagNumber(5)
  void clearTable() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get changes => $_getIZ(5);
  @$pb.TagNumber(6)
  set changes($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasChanges() => $_has(5);
  @$pb.TagNumber(6)
  void clearChanges() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get state => $_getSZ(6);
  @$pb.TagNumber(7)
  set state($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasState() => $_has(6);
  @$pb.TagNumber(7)
  void clearState() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdUnixMs => $_getI64(7);
  @$pb.TagNumber(8)
  set createdUnixMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedUnixMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedUnixMs() => $_clearField(8);
}

class EditDraftReply extends $pb.GeneratedMessage {
  factory EditDraftReply({
    $core.Iterable<EditDraftInfo>? drafts,
    ChangeRequest? changes,
    RetainedResult? result,
  }) {
    final result$ = create();
    if (drafts != null) result$.drafts.addAll(drafts);
    if (changes != null) result$.changes = changes;
    if (result != null) result$.result = result;
    return result$;
  }

  EditDraftReply._();

  factory EditDraftReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditDraftReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditDraftReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPM<EditDraftInfo>(1, _omitFieldNames ? '' : 'drafts',
        subBuilder: EditDraftInfo.create)
    ..aOM<ChangeRequest>(2, _omitFieldNames ? '' : 'changes',
        subBuilder: ChangeRequest.create)
    ..aOM<RetainedResult>(3, _omitFieldNames ? '' : 'result',
        subBuilder: RetainedResult.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftReply copyWith(void Function(EditDraftReply) updates) =>
      super.copyWith((message) => updates(message as EditDraftReply))
          as EditDraftReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditDraftReply create() => EditDraftReply._();
  @$core.override
  EditDraftReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditDraftReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditDraftReply>(create);
  static EditDraftReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<EditDraftInfo> get drafts => $_getList(0);

  @$pb.TagNumber(2)
  ChangeRequest get changes => $_getN(1);
  @$pb.TagNumber(2)
  set changes(ChangeRequest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasChanges() => $_has(1);
  @$pb.TagNumber(2)
  void clearChanges() => $_clearField(2);
  @$pb.TagNumber(2)
  ChangeRequest ensureChanges() => $_ensure(1);

  @$pb.TagNumber(3)
  RetainedResult get result => $_getN(2);
  @$pb.TagNumber(3)
  set result(RetainedResult value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasResult() => $_has(2);
  @$pb.TagNumber(3)
  void clearResult() => $_clearField(3);
  @$pb.TagNumber(3)
  RetainedResult ensureResult() => $_ensure(2);
}

/// Stored by Java, never accepted from Flutter as proof of row identity.
class EditDraftRow extends $pb.GeneratedMessage {
  factory EditDraftRow({
    $fixnum.Int64? sourceRow,
    Row? row,
  }) {
    final result = create();
    if (sourceRow != null) result.sourceRow = sourceRow;
    if (row != null) result.row = row;
    return result;
  }

  EditDraftRow._();

  factory EditDraftRow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditDraftRow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditDraftRow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'sourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<Row>(2, _omitFieldNames ? '' : 'row', subBuilder: Row.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftRow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditDraftRow copyWith(void Function(EditDraftRow) updates) =>
      super.copyWith((message) => updates(message as EditDraftRow))
          as EditDraftRow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditDraftRow create() => EditDraftRow._();
  @$core.override
  EditDraftRow createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditDraftRow getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditDraftRow>(create);
  static EditDraftRow? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sourceRow => $_getI64(0);
  @$pb.TagNumber(1)
  set sourceRow($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceRow() => $_clearField(1);

  @$pb.TagNumber(2)
  Row get row => $_getN(1);
  @$pb.TagNumber(2)
  set row(Row value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);
  @$pb.TagNumber(2)
  Row ensureRow() => $_ensure(1);
}

class StoredEditDraft extends $pb.GeneratedMessage {
  factory StoredEditDraft({
    ChangeRequest? changes,
    $core.Iterable<Column>? columns,
    $core.Iterable<EditDraftRow>? rows,
    $core.String? sourceSql,
    Profile? target,
    $core.String? schemaSignature,
    $core.String? documentId,
    $core.String? sourceSqlMode,
    $core.bool? standardConformingStrings,
    $core.String? sourceTimeZone,
    $core.String? sourceSystemTimeZone,
  }) {
    final result = create();
    if (changes != null) result.changes = changes;
    if (columns != null) result.columns.addAll(columns);
    if (rows != null) result.rows.addAll(rows);
    if (sourceSql != null) result.sourceSql = sourceSql;
    if (target != null) result.target = target;
    if (schemaSignature != null) result.schemaSignature = schemaSignature;
    if (documentId != null) result.documentId = documentId;
    if (sourceSqlMode != null) result.sourceSqlMode = sourceSqlMode;
    if (standardConformingStrings != null)
      result.standardConformingStrings = standardConformingStrings;
    if (sourceTimeZone != null) result.sourceTimeZone = sourceTimeZone;
    if (sourceSystemTimeZone != null)
      result.sourceSystemTimeZone = sourceSystemTimeZone;
    return result;
  }

  StoredEditDraft._();

  factory StoredEditDraft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoredEditDraft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoredEditDraft',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<ChangeRequest>(1, _omitFieldNames ? '' : 'changes',
        subBuilder: ChangeRequest.create)
    ..pPM<Column>(2, _omitFieldNames ? '' : 'columns',
        subBuilder: Column.create)
    ..pPM<EditDraftRow>(3, _omitFieldNames ? '' : 'rows',
        subBuilder: EditDraftRow.create)
    ..aOS(4, _omitFieldNames ? '' : 'sourceSql')
    ..aOM<Profile>(5, _omitFieldNames ? '' : 'target',
        subBuilder: Profile.create)
    ..aOS(6, _omitFieldNames ? '' : 'schemaSignature')
    ..aOS(7, _omitFieldNames ? '' : 'documentId')
    ..aOS(8, _omitFieldNames ? '' : 'sourceSqlMode')
    ..aOB(9, _omitFieldNames ? '' : 'standardConformingStrings')
    ..aOS(10, _omitFieldNames ? '' : 'sourceTimeZone')
    ..aOS(11, _omitFieldNames ? '' : 'sourceSystemTimeZone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoredEditDraft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoredEditDraft copyWith(void Function(StoredEditDraft) updates) =>
      super.copyWith((message) => updates(message as StoredEditDraft))
          as StoredEditDraft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoredEditDraft create() => StoredEditDraft._();
  @$core.override
  StoredEditDraft createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StoredEditDraft getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StoredEditDraft>(create);
  static StoredEditDraft? _defaultInstance;

  @$pb.TagNumber(1)
  ChangeRequest get changes => $_getN(0);
  @$pb.TagNumber(1)
  set changes(ChangeRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChanges() => $_has(0);
  @$pb.TagNumber(1)
  void clearChanges() => $_clearField(1);
  @$pb.TagNumber(1)
  ChangeRequest ensureChanges() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<Column> get columns => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<EditDraftRow> get rows => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get sourceSql => $_getSZ(3);
  @$pb.TagNumber(4)
  set sourceSql($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceSql() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceSql() => $_clearField(4);

  @$pb.TagNumber(5)
  Profile get target => $_getN(4);
  @$pb.TagNumber(5)
  set target(Profile value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTarget() => $_has(4);
  @$pb.TagNumber(5)
  void clearTarget() => $_clearField(5);
  @$pb.TagNumber(5)
  Profile ensureTarget() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get schemaSignature => $_getSZ(5);
  @$pb.TagNumber(6)
  set schemaSignature($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSchemaSignature() => $_has(5);
  @$pb.TagNumber(6)
  void clearSchemaSignature() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get documentId => $_getSZ(6);
  @$pb.TagNumber(7)
  set documentId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDocumentId() => $_has(6);
  @$pb.TagNumber(7)
  void clearDocumentId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sourceSqlMode => $_getSZ(7);
  @$pb.TagNumber(8)
  set sourceSqlMode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSourceSqlMode() => $_has(7);
  @$pb.TagNumber(8)
  void clearSourceSqlMode() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get standardConformingStrings => $_getBF(8);
  @$pb.TagNumber(9)
  set standardConformingStrings($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStandardConformingStrings() => $_has(8);
  @$pb.TagNumber(9)
  void clearStandardConformingStrings() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get sourceTimeZone => $_getSZ(9);
  @$pb.TagNumber(10)
  set sourceTimeZone($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSourceTimeZone() => $_has(9);
  @$pb.TagNumber(10)
  void clearSourceTimeZone() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get sourceSystemTimeZone => $_getSZ(10);
  @$pb.TagNumber(11)
  set sourceSystemTimeZone($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSourceSystemTimeZone() => $_has(10);
  @$pb.TagNumber(11)
  void clearSourceSystemTimeZone() => $_clearField(11);
}

/// Bounded exact calculations over an explicit retained result/view selection.
class ResultAggregateRequest extends $pb.GeneratedMessage {
  factory ResultAggregateRequest({
    Context? context,
    $core.String? resultId,
    $fixnum.Int64? firstRow,
    $core.int? rowCount,
    $core.Iterable<$core.int>? ordinals,
    $core.String? viewId,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (resultId != null) result.resultId = resultId;
    if (firstRow != null) result.firstRow = firstRow;
    if (rowCount != null) result.rowCount = rowCount;
    if (ordinals != null) result.ordinals.addAll(ordinals);
    if (viewId != null) result.viewId = viewId;
    return result;
  }

  ResultAggregateRequest._();

  factory ResultAggregateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResultAggregateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResultAggregateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'firstRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'rowCount', fieldType: $pb.PbFieldType.OU3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'ordinals', $pb.PbFieldType.KU3)
    ..aOS(6, _omitFieldNames ? '' : 'viewId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultAggregateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultAggregateRequest copyWith(
          void Function(ResultAggregateRequest) updates) =>
      super.copyWith((message) => updates(message as ResultAggregateRequest))
          as ResultAggregateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResultAggregateRequest create() => ResultAggregateRequest._();
  @$core.override
  ResultAggregateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResultAggregateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResultAggregateRequest>(create);
  static ResultAggregateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get resultId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resultId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get firstRow => $_getI64(2);
  @$pb.TagNumber(3)
  set firstRow($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rowCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set rowCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRowCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRowCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get ordinals => $_getList(4);

  @$pb.TagNumber(6)
  $core.String get viewId => $_getSZ(5);
  @$pb.TagNumber(6)
  set viewId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasViewId() => $_has(5);
  @$pb.TagNumber(6)
  void clearViewId() => $_clearField(6);
}

class ColumnAggregate extends $pb.GeneratedMessage {
  factory ColumnAggregate({
    $core.int? ordinal,
    $fixnum.Int64? selectedCount,
    $fixnum.Int64? nonNullCount,
    $fixnum.Int64? nullCount,
    $fixnum.Int64? distinctCount,
    $core.String? sum,
    $core.String? average,
    Value? minimum,
    Value? maximum,
    $core.String? availability,
  }) {
    final result = create();
    if (ordinal != null) result.ordinal = ordinal;
    if (selectedCount != null) result.selectedCount = selectedCount;
    if (nonNullCount != null) result.nonNullCount = nonNullCount;
    if (nullCount != null) result.nullCount = nullCount;
    if (distinctCount != null) result.distinctCount = distinctCount;
    if (sum != null) result.sum = sum;
    if (average != null) result.average = average;
    if (minimum != null) result.minimum = minimum;
    if (maximum != null) result.maximum = maximum;
    if (availability != null) result.availability = availability;
    return result;
  }

  ColumnAggregate._();

  factory ColumnAggregate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ColumnAggregate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ColumnAggregate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ordinal', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'selectedCount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'nonNullCount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'nullCount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'distinctCount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'sum')
    ..aOS(7, _omitFieldNames ? '' : 'average')
    ..aOM<Value>(8, _omitFieldNames ? '' : 'minimum', subBuilder: Value.create)
    ..aOM<Value>(9, _omitFieldNames ? '' : 'maximum', subBuilder: Value.create)
    ..aOS(10, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColumnAggregate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColumnAggregate copyWith(void Function(ColumnAggregate) updates) =>
      super.copyWith((message) => updates(message as ColumnAggregate))
          as ColumnAggregate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ColumnAggregate create() => ColumnAggregate._();
  @$core.override
  ColumnAggregate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ColumnAggregate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ColumnAggregate>(create);
  static ColumnAggregate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get ordinal => $_getIZ(0);
  @$pb.TagNumber(1)
  set ordinal($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrdinal() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrdinal() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get selectedCount => $_getI64(1);
  @$pb.TagNumber(2)
  set selectedCount($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSelectedCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearSelectedCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get nonNullCount => $_getI64(2);
  @$pb.TagNumber(3)
  set nonNullCount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNonNullCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearNonNullCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get nullCount => $_getI64(3);
  @$pb.TagNumber(4)
  set nullCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNullCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearNullCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get distinctCount => $_getI64(4);
  @$pb.TagNumber(5)
  set distinctCount($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDistinctCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearDistinctCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get sum => $_getSZ(5);
  @$pb.TagNumber(6)
  set sum($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSum() => $_has(5);
  @$pb.TagNumber(6)
  void clearSum() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get average => $_getSZ(6);
  @$pb.TagNumber(7)
  set average($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAverage() => $_has(6);
  @$pb.TagNumber(7)
  void clearAverage() => $_clearField(7);

  @$pb.TagNumber(8)
  Value get minimum => $_getN(7);
  @$pb.TagNumber(8)
  set minimum(Value value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasMinimum() => $_has(7);
  @$pb.TagNumber(8)
  void clearMinimum() => $_clearField(8);
  @$pb.TagNumber(8)
  Value ensureMinimum() => $_ensure(7);

  @$pb.TagNumber(9)
  Value get maximum => $_getN(8);
  @$pb.TagNumber(9)
  set maximum(Value value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasMaximum() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaximum() => $_clearField(9);
  @$pb.TagNumber(9)
  Value ensureMaximum() => $_ensure(8);

  @$pb.TagNumber(10)
  $core.String get availability => $_getSZ(9);
  @$pb.TagNumber(10)
  set availability($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAvailability() => $_has(9);
  @$pb.TagNumber(10)
  void clearAvailability() => $_clearField(10);
}

class ResultAggregateReply extends $pb.GeneratedMessage {
  factory ResultAggregateReply({
    $core.String? resultId,
    $core.String? viewId,
    $core.String? scope,
    $core.bool? partial,
    $core.Iterable<ColumnAggregate>? columns,
  }) {
    final result = create();
    if (resultId != null) result.resultId = resultId;
    if (viewId != null) result.viewId = viewId;
    if (scope != null) result.scope = scope;
    if (partial != null) result.partial = partial;
    if (columns != null) result.columns.addAll(columns);
    return result;
  }

  ResultAggregateReply._();

  factory ResultAggregateReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResultAggregateReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResultAggregateReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resultId')
    ..aOS(2, _omitFieldNames ? '' : 'viewId')
    ..aOS(3, _omitFieldNames ? '' : 'scope')
    ..aOB(4, _omitFieldNames ? '' : 'partial')
    ..pPM<ColumnAggregate>(5, _omitFieldNames ? '' : 'columns',
        subBuilder: ColumnAggregate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultAggregateReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultAggregateReply copyWith(void Function(ResultAggregateReply) updates) =>
      super.copyWith((message) => updates(message as ResultAggregateReply))
          as ResultAggregateReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResultAggregateReply create() => ResultAggregateReply._();
  @$core.override
  ResultAggregateReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResultAggregateReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResultAggregateReply>(create);
  static ResultAggregateReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resultId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resultId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResultId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResultId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get viewId => $_getSZ(1);
  @$pb.TagNumber(2)
  set viewId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasViewId() => $_has(1);
  @$pb.TagNumber(2)
  void clearViewId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get scope => $_getSZ(2);
  @$pb.TagNumber(3)
  set scope($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScope() => $_has(2);
  @$pb.TagNumber(3)
  void clearScope() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get partial => $_getBF(3);
  @$pb.TagNumber(4)
  set partial($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPartial() => $_has(3);
  @$pb.TagNumber(4)
  void clearPartial() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<ColumnAggregate> get columns => $_getList(4);
}

class RelatedRowsRequest extends $pb.GeneratedMessage {
  factory RelatedRowsRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? resultId,
    $fixnum.Int64? sourceRow,
    $fixnum.Int64? snapshotRevision,
    $core.String? documentId,
    $fixnum.Int64? expectedSessionRevision,
    $fixnum.Int64? expectedContextRevision,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (resultId != null) result.resultId = resultId;
    if (sourceRow != null) result.sourceRow = sourceRow;
    if (snapshotRevision != null) result.snapshotRevision = snapshotRevision;
    if (documentId != null) result.documentId = documentId;
    if (expectedSessionRevision != null)
      result.expectedSessionRevision = expectedSessionRevision;
    if (expectedContextRevision != null)
      result.expectedContextRevision = expectedContextRevision;
    return result;
  }

  RelatedRowsRequest._();

  factory RelatedRowsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelatedRowsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelatedRowsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'snapshotRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'documentId')
    ..a<$fixnum.Int64>(7, _omitFieldNames ? '' : 'expectedSessionRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(8, _omitFieldNames ? '' : 'expectedContextRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatedRowsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatedRowsRequest copyWith(void Function(RelatedRowsRequest) updates) =>
      super.copyWith((message) => updates(message as RelatedRowsRequest))
          as RelatedRowsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelatedRowsRequest create() => RelatedRowsRequest._();
  @$core.override
  RelatedRowsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelatedRowsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelatedRowsRequest>(create);
  static RelatedRowsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get resultId => $_getSZ(2);
  @$pb.TagNumber(3)
  set resultId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResultId() => $_has(2);
  @$pb.TagNumber(3)
  void clearResultId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sourceRow => $_getI64(3);
  @$pb.TagNumber(4)
  set sourceRow($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceRow() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceRow() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get snapshotRevision => $_getI64(4);
  @$pb.TagNumber(5)
  set snapshotRevision($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSnapshotRevision() => $_has(4);
  @$pb.TagNumber(5)
  void clearSnapshotRevision() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get documentId => $_getSZ(5);
  @$pb.TagNumber(6)
  set documentId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDocumentId() => $_has(5);
  @$pb.TagNumber(6)
  void clearDocumentId() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get expectedSessionRevision => $_getI64(6);
  @$pb.TagNumber(7)
  set expectedSessionRevision($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExpectedSessionRevision() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpectedSessionRevision() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get expectedContextRevision => $_getI64(7);
  @$pb.TagNumber(8)
  set expectedContextRevision($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExpectedContextRevision() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpectedContextRevision() => $_clearField(8);
}

class RelatedRelationship extends $pb.GeneratedMessage {
  factory RelatedRelationship({
    $core.String? identity,
    $core.String? name,
    $core.bool? incoming,
    BrowseRequest? browse,
    $core.String? availability,
  }) {
    final result = create();
    if (identity != null) result.identity = identity;
    if (name != null) result.name = name;
    if (incoming != null) result.incoming = incoming;
    if (browse != null) result.browse = browse;
    if (availability != null) result.availability = availability;
    return result;
  }

  RelatedRelationship._();

  factory RelatedRelationship.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelatedRelationship.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelatedRelationship',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'identity')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOB(3, _omitFieldNames ? '' : 'incoming')
    ..aOM<BrowseRequest>(4, _omitFieldNames ? '' : 'browse',
        subBuilder: BrowseRequest.create)
    ..aOS(5, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatedRelationship clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatedRelationship copyWith(void Function(RelatedRelationship) updates) =>
      super.copyWith((message) => updates(message as RelatedRelationship))
          as RelatedRelationship;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelatedRelationship create() => RelatedRelationship._();
  @$core.override
  RelatedRelationship createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelatedRelationship getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelatedRelationship>(create);
  static RelatedRelationship? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get identity => $_getSZ(0);
  @$pb.TagNumber(1)
  set identity($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIdentity() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdentity() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get incoming => $_getBF(2);
  @$pb.TagNumber(3)
  set incoming($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIncoming() => $_has(2);
  @$pb.TagNumber(3)
  void clearIncoming() => $_clearField(3);

  @$pb.TagNumber(4)
  BrowseRequest get browse => $_getN(3);
  @$pb.TagNumber(4)
  set browse(BrowseRequest value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasBrowse() => $_has(3);
  @$pb.TagNumber(4)
  void clearBrowse() => $_clearField(4);
  @$pb.TagNumber(4)
  BrowseRequest ensureBrowse() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get availability => $_getSZ(4);
  @$pb.TagNumber(5)
  set availability($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvailability() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvailability() => $_clearField(5);
}

class RelatedRowsReply extends $pb.GeneratedMessage {
  factory RelatedRowsReply({
    $core.String? resultId,
    $fixnum.Int64? sourceRow,
    $fixnum.Int64? snapshotRevision,
    $core.Iterable<RelatedRelationship>? relationships,
    $core.String? availability,
    $core.String? backendInstance,
    $core.String? profileId,
    $core.String? metadataSourceIdentity,
    $core.String? sessionId,
    $fixnum.Int64? sessionRevision,
    $fixnum.Int64? contextRevision,
    $fixnum.Int64? metadataConfigurationRevision,
  }) {
    final result = create();
    if (resultId != null) result.resultId = resultId;
    if (sourceRow != null) result.sourceRow = sourceRow;
    if (snapshotRevision != null) result.snapshotRevision = snapshotRevision;
    if (relationships != null) result.relationships.addAll(relationships);
    if (availability != null) result.availability = availability;
    if (backendInstance != null) result.backendInstance = backendInstance;
    if (profileId != null) result.profileId = profileId;
    if (metadataSourceIdentity != null)
      result.metadataSourceIdentity = metadataSourceIdentity;
    if (sessionId != null) result.sessionId = sessionId;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (metadataConfigurationRevision != null)
      result.metadataConfigurationRevision = metadataConfigurationRevision;
    return result;
  }

  RelatedRowsReply._();

  factory RelatedRowsReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelatedRowsReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelatedRowsReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'sourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'snapshotRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<RelatedRelationship>(4, _omitFieldNames ? '' : 'relationships',
        subBuilder: RelatedRelationship.create)
    ..aOS(5, _omitFieldNames ? '' : 'availability')
    ..aOS(6, _omitFieldNames ? '' : 'backendInstance')
    ..aOS(7, _omitFieldNames ? '' : 'profileId')
    ..aOS(8, _omitFieldNames ? '' : 'metadataSourceIdentity')
    ..aOS(9, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        12,
        _omitFieldNames ? '' : 'metadataConfigurationRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatedRowsReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatedRowsReply copyWith(void Function(RelatedRowsReply) updates) =>
      super.copyWith((message) => updates(message as RelatedRowsReply))
          as RelatedRowsReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelatedRowsReply create() => RelatedRowsReply._();
  @$core.override
  RelatedRowsReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelatedRowsReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelatedRowsReply>(create);
  static RelatedRowsReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resultId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resultId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResultId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResultId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sourceRow => $_getI64(1);
  @$pb.TagNumber(2)
  set sourceRow($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get snapshotRevision => $_getI64(2);
  @$pb.TagNumber(3)
  set snapshotRevision($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSnapshotRevision() => $_has(2);
  @$pb.TagNumber(3)
  void clearSnapshotRevision() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RelatedRelationship> get relationships => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get availability => $_getSZ(4);
  @$pb.TagNumber(5)
  set availability($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvailability() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvailability() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get backendInstance => $_getSZ(5);
  @$pb.TagNumber(6)
  set backendInstance($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBackendInstance() => $_has(5);
  @$pb.TagNumber(6)
  void clearBackendInstance() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get profileId => $_getSZ(6);
  @$pb.TagNumber(7)
  set profileId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProfileId() => $_has(6);
  @$pb.TagNumber(7)
  void clearProfileId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get metadataSourceIdentity => $_getSZ(7);
  @$pb.TagNumber(8)
  set metadataSourceIdentity($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMetadataSourceIdentity() => $_has(7);
  @$pb.TagNumber(8)
  void clearMetadataSourceIdentity() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get sessionId => $_getSZ(8);
  @$pb.TagNumber(9)
  set sessionId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionId() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionId() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get sessionRevision => $_getI64(9);
  @$pb.TagNumber(10)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSessionRevision() => $_has(9);
  @$pb.TagNumber(10)
  void clearSessionRevision() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get contextRevision => $_getI64(10);
  @$pb.TagNumber(11)
  set contextRevision($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasContextRevision() => $_has(10);
  @$pb.TagNumber(11)
  void clearContextRevision() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get metadataConfigurationRevision => $_getI64(11);
  @$pb.TagNumber(12)
  set metadataConfigurationRevision($fixnum.Int64 value) =>
      $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasMetadataConfigurationRevision() => $_has(11);
  @$pb.TagNumber(12)
  void clearMetadataConfigurationRevision() => $_clearField(12);
}

class CloneRowRequest extends $pb.GeneratedMessage {
  factory CloneRowRequest({
    Context? context,
    $core.String? sessionId,
    $core.String? resultId,
    $fixnum.Int64? sourceRow,
    $core.String? catalog,
    $core.String? schema,
    $core.String? table,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (resultId != null) result.resultId = resultId;
    if (sourceRow != null) result.sourceRow = sourceRow;
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (table != null) result.table = table;
    return result;
  }

  CloneRowRequest._();

  factory CloneRowRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CloneRowRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloneRowRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'resultId')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sourceRow', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(5, _omitFieldNames ? '' : 'catalog')
    ..aOS(6, _omitFieldNames ? '' : 'schema')
    ..aOS(7, _omitFieldNames ? '' : 'table')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloneRowRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloneRowRequest copyWith(void Function(CloneRowRequest) updates) =>
      super.copyWith((message) => updates(message as CloneRowRequest))
          as CloneRowRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CloneRowRequest create() => CloneRowRequest._();
  @$core.override
  CloneRowRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CloneRowRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloneRowRequest>(create);
  static CloneRowRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get resultId => $_getSZ(2);
  @$pb.TagNumber(3)
  set resultId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResultId() => $_has(2);
  @$pb.TagNumber(3)
  void clearResultId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sourceRow => $_getI64(3);
  @$pb.TagNumber(4)
  set sourceRow($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceRow() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceRow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get catalog => $_getSZ(4);
  @$pb.TagNumber(5)
  set catalog($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCatalog() => $_has(4);
  @$pb.TagNumber(5)
  void clearCatalog() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get schema => $_getSZ(5);
  @$pb.TagNumber(6)
  set schema($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSchema() => $_has(5);
  @$pb.TagNumber(6)
  void clearSchema() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get table => $_getSZ(6);
  @$pb.TagNumber(7)
  set table($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTable() => $_has(6);
  @$pb.TagNumber(7)
  void clearTable() => $_clearField(7);
}

class MetadataScopeLevel extends $pb.GeneratedMessage {
  factory MetadataScopeLevel({
    $core.String? catalog,
    $core.String? schema,
    $core.int? level,
  }) {
    final result = create();
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (level != null) result.level = level;
    return result;
  }

  MetadataScopeLevel._();

  factory MetadataScopeLevel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MetadataScopeLevel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MetadataScopeLevel',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'catalog')
    ..aOS(2, _omitFieldNames ? '' : 'schema')
    ..aI(3, _omitFieldNames ? '' : 'level', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataScopeLevel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataScopeLevel copyWith(void Function(MetadataScopeLevel) updates) =>
      super.copyWith((message) => updates(message as MetadataScopeLevel))
          as MetadataScopeLevel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetadataScopeLevel create() => MetadataScopeLevel._();
  @$core.override
  MetadataScopeLevel createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MetadataScopeLevel getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MetadataScopeLevel>(create);
  static MetadataScopeLevel? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get catalog => $_getSZ(0);
  @$pb.TagNumber(1)
  set catalog($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCatalog() => $_has(0);
  @$pb.TagNumber(1)
  void clearCatalog() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get schema => $_getSZ(1);
  @$pb.TagNumber(2)
  set schema($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchema() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchema() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get level => $_getIZ(2);
  @$pb.TagNumber(3)
  set level($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLevel() => $_has(2);
  @$pb.TagNumber(3)
  void clearLevel() => $_clearField(3);
}

class MetadataIntrospectionConfiguration extends $pb.GeneratedMessage {
  factory MetadataIntrospectionConfiguration({
    $core.Iterable<$core.String>? includedCatalogs,
    $core.Iterable<$core.String>? excludedCatalogs,
    $core.Iterable<$core.String>? includedSchemas,
    $core.Iterable<$core.String>? excludedSchemas,
    $core.bool? systemObjects,
    $core.Iterable<ObjectKind>? kinds,
    $core.Iterable<$core.String>? includePatterns,
    $core.Iterable<$core.String>? excludePatterns,
    $core.int? defaultLevel,
    $core.Iterable<MetadataScopeLevel>? scopeLevels,
  }) {
    final result = create();
    if (includedCatalogs != null)
      result.includedCatalogs.addAll(includedCatalogs);
    if (excludedCatalogs != null)
      result.excludedCatalogs.addAll(excludedCatalogs);
    if (includedSchemas != null) result.includedSchemas.addAll(includedSchemas);
    if (excludedSchemas != null) result.excludedSchemas.addAll(excludedSchemas);
    if (systemObjects != null) result.systemObjects = systemObjects;
    if (kinds != null) result.kinds.addAll(kinds);
    if (includePatterns != null) result.includePatterns.addAll(includePatterns);
    if (excludePatterns != null) result.excludePatterns.addAll(excludePatterns);
    if (defaultLevel != null) result.defaultLevel = defaultLevel;
    if (scopeLevels != null) result.scopeLevels.addAll(scopeLevels);
    return result;
  }

  MetadataIntrospectionConfiguration._();

  factory MetadataIntrospectionConfiguration.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MetadataIntrospectionConfiguration.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MetadataIntrospectionConfiguration',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'includedCatalogs')
    ..pPS(2, _omitFieldNames ? '' : 'excludedCatalogs')
    ..pPS(3, _omitFieldNames ? '' : 'includedSchemas')
    ..pPS(4, _omitFieldNames ? '' : 'excludedSchemas')
    ..aOB(5, _omitFieldNames ? '' : 'systemObjects')
    ..pc<ObjectKind>(6, _omitFieldNames ? '' : 'kinds', $pb.PbFieldType.KE,
        valueOf: ObjectKind.valueOf,
        enumValues: ObjectKind.values,
        defaultEnumValue: ObjectKind.CATALOG)
    ..pPS(7, _omitFieldNames ? '' : 'includePatterns')
    ..pPS(8, _omitFieldNames ? '' : 'excludePatterns')
    ..aI(9, _omitFieldNames ? '' : 'defaultLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<MetadataScopeLevel>(10, _omitFieldNames ? '' : 'scopeLevels',
        subBuilder: MetadataScopeLevel.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataIntrospectionConfiguration clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataIntrospectionConfiguration copyWith(
          void Function(MetadataIntrospectionConfiguration) updates) =>
      super.copyWith((message) =>
              updates(message as MetadataIntrospectionConfiguration))
          as MetadataIntrospectionConfiguration;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetadataIntrospectionConfiguration create() =>
      MetadataIntrospectionConfiguration._();
  @$core.override
  MetadataIntrospectionConfiguration createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MetadataIntrospectionConfiguration getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MetadataIntrospectionConfiguration>(
          create);
  static MetadataIntrospectionConfiguration? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get includedCatalogs => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get excludedCatalogs => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get includedSchemas => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get excludedSchemas => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get systemObjects => $_getBF(4);
  @$pb.TagNumber(5)
  set systemObjects($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSystemObjects() => $_has(4);
  @$pb.TagNumber(5)
  void clearSystemObjects() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<ObjectKind> get kinds => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get includePatterns => $_getList(6);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get excludePatterns => $_getList(7);

  @$pb.TagNumber(9)
  $core.int get defaultLevel => $_getIZ(8);
  @$pb.TagNumber(9)
  set defaultLevel($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDefaultLevel() => $_has(8);
  @$pb.TagNumber(9)
  void clearDefaultLevel() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<MetadataScopeLevel> get scopeLevels => $_getList(9);
}

class MetadataSettingsRequest extends $pb.GeneratedMessage {
  factory MetadataSettingsRequest({
    Context? context,
    $core.String? sessionId,
    $fixnum.Int64? sessionRevision,
    $fixnum.Int64? contextRevision,
    MetadataSettingsAction? action,
    $fixnum.Int64? expectedConfigurationRevision,
    MetadataIntrospectionConfiguration? configuration,
    $core.int? offset,
    $core.int? limit,
    $fixnum.Int64? expectedSnapshotRevision,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (sessionId != null) result.sessionId = sessionId;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (action != null) result.action = action;
    if (expectedConfigurationRevision != null)
      result.expectedConfigurationRevision = expectedConfigurationRevision;
    if (configuration != null) result.configuration = configuration;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    if (expectedSnapshotRevision != null)
      result.expectedSnapshotRevision = expectedSnapshotRevision;
    return result;
  }

  MetadataSettingsRequest._();

  factory MetadataSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MetadataSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MetadataSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOM<Context>(1, _omitFieldNames ? '' : 'context',
        subBuilder: Context.create)
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<MetadataSettingsAction>(5, _omitFieldNames ? '' : 'action',
        enumValues: MetadataSettingsAction.values)
    ..a<$fixnum.Int64>(
        6,
        _omitFieldNames ? '' : 'expectedConfigurationRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<MetadataIntrospectionConfiguration>(
        7, _omitFieldNames ? '' : 'configuration',
        subBuilder: MetadataIntrospectionConfiguration.create)
    ..aI(8, _omitFieldNames ? '' : 'offset', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(10, _omitFieldNames ? '' : 'expectedSnapshotRevision',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataSettingsRequest copyWith(
          void Function(MetadataSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as MetadataSettingsRequest))
          as MetadataSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetadataSettingsRequest create() => MetadataSettingsRequest._();
  @$core.override
  MetadataSettingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MetadataSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MetadataSettingsRequest>(create);
  static MetadataSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
  @$pb.TagNumber(1)
  Context ensureContext() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sessionRevision => $_getI64(2);
  @$pb.TagNumber(3)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionRevision() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionRevision() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get contextRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set contextRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContextRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearContextRevision() => $_clearField(4);

  @$pb.TagNumber(5)
  MetadataSettingsAction get action => $_getN(4);
  @$pb.TagNumber(5)
  set action(MetadataSettingsAction value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAction() => $_has(4);
  @$pb.TagNumber(5)
  void clearAction() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get expectedConfigurationRevision => $_getI64(5);
  @$pb.TagNumber(6)
  set expectedConfigurationRevision($fixnum.Int64 value) =>
      $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExpectedConfigurationRevision() => $_has(5);
  @$pb.TagNumber(6)
  void clearExpectedConfigurationRevision() => $_clearField(6);

  @$pb.TagNumber(7)
  MetadataIntrospectionConfiguration get configuration => $_getN(6);
  @$pb.TagNumber(7)
  set configuration(MetadataIntrospectionConfiguration value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasConfiguration() => $_has(6);
  @$pb.TagNumber(7)
  void clearConfiguration() => $_clearField(7);
  @$pb.TagNumber(7)
  MetadataIntrospectionConfiguration ensureConfiguration() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.int get offset => $_getIZ(7);
  @$pb.TagNumber(8)
  set offset($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOffset() => $_has(7);
  @$pb.TagNumber(8)
  void clearOffset() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get limit => $_getIZ(8);
  @$pb.TagNumber(9)
  set limit($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLimit() => $_has(8);
  @$pb.TagNumber(9)
  void clearLimit() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get expectedSnapshotRevision => $_getI64(9);
  @$pb.TagNumber(10)
  set expectedSnapshotRevision($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExpectedSnapshotRevision() => $_has(9);
  @$pb.TagNumber(10)
  void clearExpectedSnapshotRevision() => $_clearField(10);
}

class MetadataScopeStatus extends $pb.GeneratedMessage {
  factory MetadataScopeStatus({
    $core.String? catalog,
    $core.String? schema,
    $core.String? parent,
    ObjectKind? kind,
    $core.int? level,
    $core.String? state,
    $core.bool? complete,
    $fixnum.Int64? lastSuccessfulRefreshUnixMs,
    $core.String? limitation,
    $fixnum.Int64? objectCount,
  }) {
    final result = create();
    if (catalog != null) result.catalog = catalog;
    if (schema != null) result.schema = schema;
    if (parent != null) result.parent = parent;
    if (kind != null) result.kind = kind;
    if (level != null) result.level = level;
    if (state != null) result.state = state;
    if (complete != null) result.complete = complete;
    if (lastSuccessfulRefreshUnixMs != null)
      result.lastSuccessfulRefreshUnixMs = lastSuccessfulRefreshUnixMs;
    if (limitation != null) result.limitation = limitation;
    if (objectCount != null) result.objectCount = objectCount;
    return result;
  }

  MetadataScopeStatus._();

  factory MetadataScopeStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MetadataScopeStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MetadataScopeStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'catalog')
    ..aOS(2, _omitFieldNames ? '' : 'schema')
    ..aOS(3, _omitFieldNames ? '' : 'parent')
    ..aE<ObjectKind>(4, _omitFieldNames ? '' : 'kind',
        enumValues: ObjectKind.values)
    ..aI(5, _omitFieldNames ? '' : 'level', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'state')
    ..aOB(7, _omitFieldNames ? '' : 'complete')
    ..a<$fixnum.Int64>(8, _omitFieldNames ? '' : 'lastSuccessfulRefreshUnixMs',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(9, _omitFieldNames ? '' : 'limitation')
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'objectCount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataScopeStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataScopeStatus copyWith(void Function(MetadataScopeStatus) updates) =>
      super.copyWith((message) => updates(message as MetadataScopeStatus))
          as MetadataScopeStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetadataScopeStatus create() => MetadataScopeStatus._();
  @$core.override
  MetadataScopeStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MetadataScopeStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MetadataScopeStatus>(create);
  static MetadataScopeStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get catalog => $_getSZ(0);
  @$pb.TagNumber(1)
  set catalog($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCatalog() => $_has(0);
  @$pb.TagNumber(1)
  void clearCatalog() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get schema => $_getSZ(1);
  @$pb.TagNumber(2)
  set schema($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchema() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchema() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get parent => $_getSZ(2);
  @$pb.TagNumber(3)
  set parent($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParent() => $_has(2);
  @$pb.TagNumber(3)
  void clearParent() => $_clearField(3);

  @$pb.TagNumber(4)
  ObjectKind get kind => $_getN(3);
  @$pb.TagNumber(4)
  set kind(ObjectKind value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get level => $_getIZ(4);
  @$pb.TagNumber(5)
  set level($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLevel() => $_has(4);
  @$pb.TagNumber(5)
  void clearLevel() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get state => $_getSZ(5);
  @$pb.TagNumber(6)
  set state($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasState() => $_has(5);
  @$pb.TagNumber(6)
  void clearState() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get complete => $_getBF(6);
  @$pb.TagNumber(7)
  set complete($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasComplete() => $_has(6);
  @$pb.TagNumber(7)
  void clearComplete() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get lastSuccessfulRefreshUnixMs => $_getI64(7);
  @$pb.TagNumber(8)
  set lastSuccessfulRefreshUnixMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastSuccessfulRefreshUnixMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastSuccessfulRefreshUnixMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get limitation => $_getSZ(8);
  @$pb.TagNumber(9)
  set limitation($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLimitation() => $_has(8);
  @$pb.TagNumber(9)
  void clearLimitation() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get objectCount => $_getI64(9);
  @$pb.TagNumber(10)
  set objectCount($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasObjectCount() => $_has(9);
  @$pb.TagNumber(10)
  void clearObjectCount() => $_clearField(10);
}

class MetadataSettingsReply extends $pb.GeneratedMessage {
  factory MetadataSettingsReply({
    $core.String? backendInstance,
    $core.String? profileId,
    $core.String? sessionId,
    $fixnum.Int64? sessionRevision,
    $fixnum.Int64? contextRevision,
    $fixnum.Int64? configurationRevision,
    $fixnum.Int64? snapshotRevision,
    MetadataIntrospectionConfiguration? configuration,
    $core.Iterable<MetadataScopeStatus>? scopes,
    $core.int? nextOffset,
    $core.bool? complete,
    $core.String? cacheState,
    $core.String? refreshStrategy,
    $fixnum.Int64? scannedScopes,
    $fixnum.Int64? fetchedScopes,
    $fixnum.Int64? fetchedObjects,
    $fixnum.Int64? refreshDurationMs,
    $core.String? metadataSourceIdentity,
  }) {
    final result = create();
    if (backendInstance != null) result.backendInstance = backendInstance;
    if (profileId != null) result.profileId = profileId;
    if (sessionId != null) result.sessionId = sessionId;
    if (sessionRevision != null) result.sessionRevision = sessionRevision;
    if (contextRevision != null) result.contextRevision = contextRevision;
    if (configurationRevision != null)
      result.configurationRevision = configurationRevision;
    if (snapshotRevision != null) result.snapshotRevision = snapshotRevision;
    if (configuration != null) result.configuration = configuration;
    if (scopes != null) result.scopes.addAll(scopes);
    if (nextOffset != null) result.nextOffset = nextOffset;
    if (complete != null) result.complete = complete;
    if (cacheState != null) result.cacheState = cacheState;
    if (refreshStrategy != null) result.refreshStrategy = refreshStrategy;
    if (scannedScopes != null) result.scannedScopes = scannedScopes;
    if (fetchedScopes != null) result.fetchedScopes = fetchedScopes;
    if (fetchedObjects != null) result.fetchedObjects = fetchedObjects;
    if (refreshDurationMs != null) result.refreshDurationMs = refreshDurationMs;
    if (metadataSourceIdentity != null)
      result.metadataSourceIdentity = metadataSourceIdentity;
    return result;
  }

  MetadataSettingsReply._();

  factory MetadataSettingsReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MetadataSettingsReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MetadataSettingsReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'busydata.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'backendInstance')
    ..aOS(2, _omitFieldNames ? '' : 'profileId')
    ..aOS(3, _omitFieldNames ? '' : 'sessionId')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sessionRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'contextRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'configurationRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'snapshotRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<MetadataIntrospectionConfiguration>(
        8, _omitFieldNames ? '' : 'configuration',
        subBuilder: MetadataIntrospectionConfiguration.create)
    ..pPM<MetadataScopeStatus>(9, _omitFieldNames ? '' : 'scopes',
        subBuilder: MetadataScopeStatus.create)
    ..aI(10, _omitFieldNames ? '' : 'nextOffset',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(11, _omitFieldNames ? '' : 'complete')
    ..aOS(12, _omitFieldNames ? '' : 'cacheState')
    ..aOS(13, _omitFieldNames ? '' : 'refreshStrategy')
    ..a<$fixnum.Int64>(
        14, _omitFieldNames ? '' : 'scannedScopes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        15, _omitFieldNames ? '' : 'fetchedScopes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        16, _omitFieldNames ? '' : 'fetchedObjects', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        17, _omitFieldNames ? '' : 'refreshDurationMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(18, _omitFieldNames ? '' : 'metadataSourceIdentity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataSettingsReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MetadataSettingsReply copyWith(
          void Function(MetadataSettingsReply) updates) =>
      super.copyWith((message) => updates(message as MetadataSettingsReply))
          as MetadataSettingsReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetadataSettingsReply create() => MetadataSettingsReply._();
  @$core.override
  MetadataSettingsReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MetadataSettingsReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MetadataSettingsReply>(create);
  static MetadataSettingsReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backendInstance => $_getSZ(0);
  @$pb.TagNumber(1)
  set backendInstance($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackendInstance() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackendInstance() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get profileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set profileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProfileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfileId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sessionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sessionRevision => $_getI64(3);
  @$pb.TagNumber(4)
  set sessionRevision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionRevision() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get contextRevision => $_getI64(4);
  @$pb.TagNumber(5)
  set contextRevision($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasContextRevision() => $_has(4);
  @$pb.TagNumber(5)
  void clearContextRevision() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get configurationRevision => $_getI64(5);
  @$pb.TagNumber(6)
  set configurationRevision($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasConfigurationRevision() => $_has(5);
  @$pb.TagNumber(6)
  void clearConfigurationRevision() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get snapshotRevision => $_getI64(6);
  @$pb.TagNumber(7)
  set snapshotRevision($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSnapshotRevision() => $_has(6);
  @$pb.TagNumber(7)
  void clearSnapshotRevision() => $_clearField(7);

  @$pb.TagNumber(8)
  MetadataIntrospectionConfiguration get configuration => $_getN(7);
  @$pb.TagNumber(8)
  set configuration(MetadataIntrospectionConfiguration value) =>
      $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasConfiguration() => $_has(7);
  @$pb.TagNumber(8)
  void clearConfiguration() => $_clearField(8);
  @$pb.TagNumber(8)
  MetadataIntrospectionConfiguration ensureConfiguration() => $_ensure(7);

  @$pb.TagNumber(9)
  $pb.PbList<MetadataScopeStatus> get scopes => $_getList(8);

  @$pb.TagNumber(10)
  $core.int get nextOffset => $_getIZ(9);
  @$pb.TagNumber(10)
  set nextOffset($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNextOffset() => $_has(9);
  @$pb.TagNumber(10)
  void clearNextOffset() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get complete => $_getBF(10);
  @$pb.TagNumber(11)
  set complete($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasComplete() => $_has(10);
  @$pb.TagNumber(11)
  void clearComplete() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get cacheState => $_getSZ(11);
  @$pb.TagNumber(12)
  set cacheState($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCacheState() => $_has(11);
  @$pb.TagNumber(12)
  void clearCacheState() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get refreshStrategy => $_getSZ(12);
  @$pb.TagNumber(13)
  set refreshStrategy($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRefreshStrategy() => $_has(12);
  @$pb.TagNumber(13)
  void clearRefreshStrategy() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get scannedScopes => $_getI64(13);
  @$pb.TagNumber(14)
  set scannedScopes($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasScannedScopes() => $_has(13);
  @$pb.TagNumber(14)
  void clearScannedScopes() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get fetchedScopes => $_getI64(14);
  @$pb.TagNumber(15)
  set fetchedScopes($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasFetchedScopes() => $_has(14);
  @$pb.TagNumber(15)
  void clearFetchedScopes() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get fetchedObjects => $_getI64(15);
  @$pb.TagNumber(16)
  set fetchedObjects($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasFetchedObjects() => $_has(15);
  @$pb.TagNumber(16)
  void clearFetchedObjects() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get refreshDurationMs => $_getI64(16);
  @$pb.TagNumber(17)
  set refreshDurationMs($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasRefreshDurationMs() => $_has(16);
  @$pb.TagNumber(17)
  void clearRefreshDurationMs() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.String get metadataSourceIdentity => $_getSZ(17);
  @$pb.TagNumber(18)
  set metadataSourceIdentity($core.String value) => $_setString(17, value);
  @$pb.TagNumber(18)
  $core.bool hasMetadataSourceIdentity() => $_has(17);
  @$pb.TagNumber(18)
  void clearMetadataSourceIdentity() => $_clearField(18);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
