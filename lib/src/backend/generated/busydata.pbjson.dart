// This is a generated file - do not edit.
//
// Generated from busydata.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use protocolVersionDescriptor instead')
const ProtocolVersion$json = {
  '1': 'ProtocolVersion',
  '2': [
    {'1': 'PROTOCOL_VERSION_UNSPECIFIED', '2': 0},
    {'1': 'BUSYDATA_PROTOCOL_VERSION', '2': 15},
  ],
};

/// Descriptor for `ProtocolVersion`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List protocolVersionDescriptor = $convert.base64Decode(
    'Cg9Qcm90b2NvbFZlcnNpb24SIAocUFJPVE9DT0xfVkVSU0lPTl9VTlNQRUNJRklFRBAAEh0KGU'
    'JVU1lEQVRBX1BST1RPQ09MX1ZFUlNJT04QDw==');

@$core.Deprecated('Use engineDescriptor instead')
const Engine$json = {
  '1': 'Engine',
  '2': [
    {'1': 'ENGINE_UNSPECIFIED', '2': 0},
    {'1': 'POSTGRESQL', '2': 1},
    {'1': 'MYSQL', '2': 2},
    {'1': 'MARIADB', '2': 3},
  ],
};

/// Descriptor for `Engine`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List engineDescriptor = $convert.base64Decode(
    'CgZFbmdpbmUSFgoSRU5HSU5FX1VOU1BFQ0lGSUVEEAASDgoKUE9TVEdSRVNRTBABEgkKBU1ZU1'
    'FMEAISCwoHTUFSSUFEQhAD');

@$core.Deprecated('Use environmentDescriptor instead')
const Environment$json = {
  '1': 'Environment',
  '2': [
    {'1': 'DEVELOPMENT', '2': 0},
    {'1': 'STAGING', '2': 1},
    {'1': 'PRODUCTION', '2': 2},
  ],
};

/// Descriptor for `Environment`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List environmentDescriptor = $convert.base64Decode(
    'CgtFbnZpcm9ubWVudBIPCgtERVZFTE9QTUVOVBAAEgsKB1NUQUdJTkcQARIOCgpQUk9EVUNUSU'
    '9OEAI=');

@$core.Deprecated('Use tlsModeDescriptor instead')
const TlsMode$json = {
  '1': 'TlsMode',
  '2': [
    {'1': 'VERIFY_FULL', '2': 0},
    {'1': 'INSECURE', '2': 1},
    {'1': 'DISABLED', '2': 2},
    {'1': 'VERIFY_CA', '2': 3},
    {'1': 'DRIVER_DEFAULT', '2': 4},
  ],
};

/// Descriptor for `TlsMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tlsModeDescriptor = $convert.base64Decode(
    'CgdUbHNNb2RlEg8KC1ZFUklGWV9GVUxMEAASDAoISU5TRUNVUkUQARIMCghESVNBQkxFRBACEg'
    '0KCVZFUklGWV9DQRADEhIKDkRSSVZFUl9ERUZBVUxUEAQ=');

@$core.Deprecated('Use profileActionDescriptor instead')
const ProfileAction$json = {
  '1': 'ProfileAction',
  '2': [
    {'1': 'LIST_PROFILES', '2': 0},
    {'1': 'SAVE_PROFILE', '2': 1},
    {'1': 'DELETE_PROFILE', '2': 2},
  ],
};

/// Descriptor for `ProfileAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List profileActionDescriptor = $convert.base64Decode(
    'Cg1Qcm9maWxlQWN0aW9uEhEKDUxJU1RfUFJPRklMRVMQABIQCgxTQVZFX1BST0ZJTEUQARISCg'
    '5ERUxFVEVfUFJPRklMRRAC');

@$core.Deprecated('Use capabilityStateDescriptor instead')
const CapabilityState$json = {
  '1': 'CapabilityState',
  '2': [
    {'1': 'CAPABILITY_UNKNOWN', '2': 0},
    {'1': 'CAPABILITY_AVAILABLE', '2': 1},
    {'1': 'CAPABILITY_LIMITED', '2': 2},
    {'1': 'CAPABILITY_DENIED', '2': 3},
    {'1': 'CAPABILITY_UNSUPPORTED', '2': 4},
    {'1': 'CAPABILITY_UNAVAILABLE', '2': 5},
    {'1': 'CAPABILITY_DISABLED', '2': 6},
  ],
};

/// Descriptor for `CapabilityState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List capabilityStateDescriptor = $convert.base64Decode(
    'Cg9DYXBhYmlsaXR5U3RhdGUSFgoSQ0FQQUJJTElUWV9VTktOT1dOEAASGAoUQ0FQQUJJTElUWV'
    '9BVkFJTEFCTEUQARIWChJDQVBBQklMSVRZX0xJTUlURUQQAhIVChFDQVBBQklMSVRZX0RFTklF'
    'RBADEhoKFkNBUEFCSUxJVFlfVU5TVVBQT1JURUQQBBIaChZDQVBBQklMSVRZX1VOQVZBSUxBQk'
    'xFEAUSFwoTQ0FQQUJJTElUWV9ESVNBQkxFRBAG');

@$core.Deprecated('Use sessionActionDescriptor instead')
const SessionAction$json = {
  '1': 'SessionAction',
  '2': [
    {'1': 'SESSION_STATUS', '2': 0},
    {'1': 'BEGIN', '2': 1},
    {'1': 'COMMIT', '2': 2},
    {'1': 'ROLLBACK', '2': 3},
    {'1': 'AUTO_COMMIT_ON', '2': 4},
    {'1': 'AUTO_COMMIT_OFF', '2': 5},
    {'1': 'DISCONNECT', '2': 6},
    {'1': 'ADOPT_SESSION', '2': 7},
  ],
};

/// Descriptor for `SessionAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionActionDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uQWN0aW9uEhIKDlNFU1NJT05fU1RBVFVTEAASCQoFQkVHSU4QARIKCgZDT01NSV'
    'QQAhIMCghST0xMQkFDSxADEhIKDkFVVE9fQ09NTUlUX09OEAQSEwoPQVVUT19DT01NSVRfT0ZG'
    'EAUSDgoKRElTQ09OTkVDVBAGEhEKDUFET1BUX1NFU1NJT04QBw==');

@$core.Deprecated('Use transactionStateDescriptor instead')
const TransactionState$json = {
  '1': 'TransactionState',
  '2': [
    {'1': 'IDLE', '2': 0},
    {'1': 'ACTIVE', '2': 1},
    {'1': 'FAILED_TRANSACTION', '2': 2},
    {'1': 'UNKNOWN_TRANSACTION', '2': 3},
    {'1': 'DISCONNECTED', '2': 4},
  ],
};

/// Descriptor for `TransactionState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List transactionStateDescriptor = $convert.base64Decode(
    'ChBUcmFuc2FjdGlvblN0YXRlEggKBElETEUQABIKCgZBQ1RJVkUQARIWChJGQUlMRURfVFJBTl'
    'NBQ1RJT04QAhIXChNVTktOT1dOX1RSQU5TQUNUSU9OEAMSEAoMRElTQ09OTkVDVEVEEAQ=');

@$core.Deprecated('Use executionModeDescriptor instead')
const ExecutionMode$json = {
  '1': 'ExecutionMode',
  '2': [
    {'1': 'SCRIPT', '2': 0},
    {'1': 'CURRENT_STATEMENT', '2': 1},
    {'1': 'SELECTION', '2': 2},
  ],
};

/// Descriptor for `ExecutionMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List executionModeDescriptor = $convert.base64Decode(
    'Cg1FeGVjdXRpb25Nb2RlEgoKBlNDUklQVBAAEhUKEUNVUlJFTlRfU1RBVEVNRU5UEAESDQoJU0'
    'VMRUNUSU9OEAI=');

@$core.Deprecated('Use errorPolicyDescriptor instead')
const ErrorPolicy$json = {
  '1': 'ErrorPolicy',
  '2': [
    {'1': 'STOP_ON_ERROR', '2': 0},
    {'1': 'CONTINUE_ON_ERROR', '2': 1},
  ],
};

/// Descriptor for `ErrorPolicy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List errorPolicyDescriptor = $convert.base64Decode(
    'CgtFcnJvclBvbGljeRIRCg1TVE9QX09OX0VSUk9SEAASFQoRQ09OVElOVUVfT05fRVJST1IQAQ'
    '==');

@$core.Deprecated('Use valuePredicateDescriptor instead')
const ValuePredicate$json = {
  '1': 'ValuePredicate',
  '2': [
    {'1': 'EQUAL', '2': 0},
    {'1': 'NOT_EQUAL', '2': 1},
    {'1': 'LESS', '2': 2},
    {'1': 'GREATER', '2': 3},
    {'1': 'IS_NULL', '2': 4},
    {'1': 'IS_NOT_NULL', '2': 5},
  ],
};

/// Descriptor for `ValuePredicate`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List valuePredicateDescriptor = $convert.base64Decode(
    'Cg5WYWx1ZVByZWRpY2F0ZRIJCgVFUVVBTBAAEg0KCU5PVF9FUVVBTBABEggKBExFU1MQAhILCg'
    'dHUkVBVEVSEAMSCwoHSVNfTlVMTBAEEg8KC0lTX05PVF9OVUxMEAU=');

@$core.Deprecated('Use jobStateDescriptor instead')
const JobState$json = {
  '1': 'JobState',
  '2': [
    {'1': 'QUEUED', '2': 0},
    {'1': 'EXECUTING', '2': 1},
    {'1': 'FETCHING', '2': 2},
    {'1': 'CANCELLING', '2': 3},
    {'1': 'COMPLETED', '2': 4},
    {'1': 'FAILED', '2': 5},
    {'1': 'CANCELLED', '2': 6},
    {'1': 'INTERRUPTED', '2': 7},
    {'1': 'UNKNOWN_OUTCOME', '2': 8},
  ],
};

/// Descriptor for `JobState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List jobStateDescriptor = $convert.base64Decode(
    'CghKb2JTdGF0ZRIKCgZRVUVVRUQQABINCglFWEVDVVRJTkcQARIMCghGRVRDSElORxACEg4KCk'
    'NBTkNFTExJTkcQAxINCglDT01QTEVURUQQBBIKCgZGQUlMRUQQBRINCglDQU5DRUxMRUQQBhIP'
    'CgtJTlRFUlJVUFRFRBAHEhMKD1VOS05PV05fT1VUQ09NRRAI');

@$core.Deprecated('Use pageStateDescriptor instead')
const PageState$json = {
  '1': 'PageState',
  '2': [
    {'1': 'PAGE_DATA', '2': 0},
    {'1': 'PAGE_BYTE_LIMIT', '2': 1},
    {'1': 'PAGE_WAITING', '2': 2},
    {'1': 'PAGE_END', '2': 3},
    {'1': 'PAGE_METADATA_TOO_LARGE', '2': 4},
    {'1': 'PAGE_ROW_TOO_LARGE', '2': 5},
    {'1': 'PAGE_DISPOSED', '2': 6},
    {'1': 'PAGE_FAILED', '2': 7},
  ],
};

/// Descriptor for `PageState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pageStateDescriptor = $convert.base64Decode(
    'CglQYWdlU3RhdGUSDQoJUEFHRV9EQVRBEAASEwoPUEFHRV9CWVRFX0xJTUlUEAESEAoMUEFHRV'
    '9XQUlUSU5HEAISDAoIUEFHRV9FTkQQAxIbChdQQUdFX01FVEFEQVRBX1RPT19MQVJHRRAEEhYK'
    'ElBBR0VfUk9XX1RPT19MQVJHRRAFEhEKDVBBR0VfRElTUE9TRUQQBhIPCgtQQUdFX0ZBSUxFRB'
    'AH');

@$core.Deprecated('Use analysisOperationDescriptor instead')
const AnalysisOperation$json = {
  '1': 'AnalysisOperation',
  '2': [
    {'1': 'COMPLETION', '2': 0},
    {'1': 'DIAGNOSTICS', '2': 1},
    {'1': 'PARAMETER_INFORMATION', '2': 2},
    {'1': 'FORMAT', '2': 3},
    {'1': 'SYMBOL_RESOLUTION', '2': 4},
    {'1': 'DDL_IMPACT', '2': 5},
  ],
};

/// Descriptor for `AnalysisOperation`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List analysisOperationDescriptor = $convert.base64Decode(
    'ChFBbmFseXNpc09wZXJhdGlvbhIOCgpDT01QTEVUSU9OEAASDwoLRElBR05PU1RJQ1MQARIZCh'
    'VQQVJBTUVURVJfSU5GT1JNQVRJT04QAhIKCgZGT1JNQVQQAxIVChFTWU1CT0xfUkVTT0xVVElP'
    'ThAEEg4KCkRETF9JTVBBQ1QQBQ==');

@$core.Deprecated('Use objectKindDescriptor instead')
const ObjectKind$json = {
  '1': 'ObjectKind',
  '2': [
    {'1': 'CATALOG', '2': 0},
    {'1': 'SCHEMA', '2': 1},
    {'1': 'TABLE', '2': 2},
    {'1': 'VIEW', '2': 3},
    {'1': 'COLUMN', '2': 4},
    {'1': 'INDEX', '2': 5},
    {'1': 'CONSTRAINT', '2': 6},
    {'1': 'ROUTINE', '2': 7},
    {'1': 'TRIGGER', '2': 8},
    {'1': 'FOREIGN_KEY', '2': 9},
    {'1': 'SEQUENCE', '2': 10},
    {'1': 'TYPE', '2': 11},
  ],
};

/// Descriptor for `ObjectKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List objectKindDescriptor = $convert.base64Decode(
    'CgpPYmplY3RLaW5kEgsKB0NBVEFMT0cQABIKCgZTQ0hFTUEQARIJCgVUQUJMRRACEggKBFZJRV'
    'cQAxIKCgZDT0xVTU4QBBIJCgVJTkRFWBAFEg4KCkNPTlNUUkFJTlQQBhILCgdST1VUSU5FEAcS'
    'CwoHVFJJR0dFUhAIEg8KC0ZPUkVJR05fS0VZEAkSDAoIU0VRVUVOQ0UQChIICgRUWVBFEAs=');

@$core.Deprecated('Use objectSubtypeDescriptor instead')
const ObjectSubtype$json = {
  '1': 'ObjectSubtype',
  '2': [
    {'1': 'OBJECT_SUBTYPE_UNSPECIFIED', '2': 0},
    {'1': 'ORDINARY_TABLE', '2': 1},
    {'1': 'PARTITIONED_TABLE', '2': 2},
    {'1': 'FOREIGN_TABLE', '2': 3},
    {'1': 'REGULAR_VIEW', '2': 4},
    {'1': 'MATERIALIZED_VIEW', '2': 5},
    {'1': 'NATIVE_SEQUENCE', '2': 6},
    {'1': 'FUNCTION', '2': 7},
    {'1': 'PROCEDURE', '2': 8},
  ],
};

/// Descriptor for `ObjectSubtype`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List objectSubtypeDescriptor = $convert.base64Decode(
    'Cg1PYmplY3RTdWJ0eXBlEh4KGk9CSkVDVF9TVUJUWVBFX1VOU1BFQ0lGSUVEEAASEgoOT1JESU'
    '5BUllfVEFCTEUQARIVChFQQVJUSVRJT05FRF9UQUJMRRACEhEKDUZPUkVJR05fVEFCTEUQAxIQ'
    'CgxSRUdVTEFSX1ZJRVcQBBIVChFNQVRFUklBTElaRURfVklFVxAFEhMKD05BVElWRV9TRVFVRU'
    '5DRRAGEgwKCEZVTkNUSU9OEAcSDQoJUFJPQ0VEVVJFEAg=');

@$core.Deprecated('Use metadataCountDescriptor instead')
const MetadataCount$json = {
  '1': 'MetadataCount',
  '2': [
    {'1': 'COUNT_UNAVAILABLE', '2': 0},
    {'1': 'AUTHORITATIVE_TOTAL', '2': 1},
    {'1': 'COMPLETE_ENUMERATION', '2': 2},
    {'1': 'PARTIAL_ENUMERATION', '2': 3},
  ],
};

/// Descriptor for `MetadataCount`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List metadataCountDescriptor = $convert.base64Decode(
    'Cg1NZXRhZGF0YUNvdW50EhUKEUNPVU5UX1VOQVZBSUxBQkxFEAASFwoTQVVUSE9SSVRBVElWRV'
    '9UT1RBTBABEhgKFENPTVBMRVRFX0VOVU1FUkFUSU9OEAISFwoTUEFSVElBTF9FTlVNRVJBVElP'
    'ThAD');

@$core.Deprecated('Use schemaToolActionDescriptor instead')
const SchemaToolAction$json = {
  '1': 'SchemaToolAction',
  '2': [
    {'1': 'CAPTURE_SCHEMA', '2': 0},
    {'1': 'COMPARE_SCHEMA', '2': 1},
    {'1': 'INSPECT_OBJECT', '2': 2},
    {'1': 'DESIGN_COLUMN', '2': 3},
    {'1': 'OBJECT_DEFINITION', '2': 4},
  ],
};

/// Descriptor for `SchemaToolAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List schemaToolActionDescriptor = $convert.base64Decode(
    'ChBTY2hlbWFUb29sQWN0aW9uEhIKDkNBUFRVUkVfU0NIRU1BEAASEgoOQ09NUEFSRV9TQ0hFTU'
    'EQARISCg5JTlNQRUNUX09CSkVDVBACEhEKDURFU0lHTl9DT0xVTU4QAxIVChFPQkpFQ1RfREVG'
    'SU5JVElPThAE');

@$core.Deprecated('Use privilegeActionDescriptor instead')
const PrivilegeAction$json = {
  '1': 'PrivilegeAction',
  '2': [
    {'1': 'INSPECT_PRIVILEGES', '2': 0},
    {'1': 'DESIGN_PRIVILEGE', '2': 1},
  ],
};

/// Descriptor for `PrivilegeAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List privilegeActionDescriptor = $convert.base64Decode(
    'Cg9Qcml2aWxlZ2VBY3Rpb24SFgoSSU5TUEVDVF9QUklWSUxFR0VTEAASFAoQREVTSUdOX1BSSV'
    'ZJTEVHRRAB');

@$core.Deprecated('Use authenticationActionDescriptor instead')
const AuthenticationAction$json = {
  '1': 'AuthenticationAction',
  '2': [
    {'1': 'CREATE_LOGIN', '2': 0},
    {'1': 'CREATE_ROLE', '2': 1},
    {'1': 'SET_PASSWORD', '2': 2},
    {'1': 'LOCK_LOGIN', '2': 3},
    {'1': 'UNLOCK_LOGIN', '2': 4},
    {'1': 'DROP_PRINCIPAL', '2': 5},
  ],
};

/// Descriptor for `AuthenticationAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List authenticationActionDescriptor = $convert.base64Decode(
    'ChRBdXRoZW50aWNhdGlvbkFjdGlvbhIQCgxDUkVBVEVfTE9HSU4QABIPCgtDUkVBVEVfUk9MRR'
    'ABEhAKDFNFVF9QQVNTV09SRBACEg4KCkxPQ0tfTE9HSU4QAxIQCgxVTkxPQ0tfTE9HSU4QBBIS'
    'Cg5EUk9QX1BSSU5DSVBBTBAF');

@$core.Deprecated('Use privilegeScopeDescriptor instead')
const PrivilegeScope$json = {
  '1': 'PrivilegeScope',
  '2': [
    {'1': 'TABLE_PRIVILEGE', '2': 0},
    {'1': 'SCHEMA_PRIVILEGE', '2': 1},
    {'1': 'DATABASE_PRIVILEGE', '2': 2},
    {'1': 'ROLE_MEMBERSHIP', '2': 3},
    {'1': 'DEFAULT_ROLE', '2': 4},
  ],
};

/// Descriptor for `PrivilegeScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List privilegeScopeDescriptor = $convert.base64Decode(
    'Cg5Qcml2aWxlZ2VTY29wZRITCg9UQUJMRV9QUklWSUxFR0UQABIUChBTQ0hFTUFfUFJJVklMRU'
    'dFEAESFgoSREFUQUJBU0VfUFJJVklMRUdFEAISEwoPUk9MRV9NRU1CRVJTSElQEAMSEAoMREVG'
    'QVVMVF9ST0xFEAQ=');

@$core.Deprecated('Use changeKindDescriptor instead')
const ChangeKind$json = {
  '1': 'ChangeKind',
  '2': [
    {'1': 'INSERT', '2': 0},
    {'1': 'UPDATE', '2': 1},
    {'1': 'DELETE', '2': 2},
  ],
};

/// Descriptor for `ChangeKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List changeKindDescriptor = $convert.base64Decode(
    'CgpDaGFuZ2VLaW5kEgoKBklOU0VSVBAAEgoKBlVQREFURRABEgoKBkRFTEVURRAC');

@$core.Deprecated('Use toolKindDescriptor instead')
const ToolKind$json = {
  '1': 'ToolKind',
  '2': [
    {'1': 'EXPLAIN', '2': 0},
    {'1': 'EXPLAIN_ANALYZE', '2': 1},
    {'1': 'ACTIVITY', '2': 2},
    {'1': 'LOCKS', '2': 3},
    {'1': 'STATISTICS', '2': 4},
    {'1': 'ROLES', '2': 5},
    {'1': 'GRANTS', '2': 6},
    {'1': 'DEFINITION', '2': 7},
    {'1': 'SNAPSHOT', '2': 8},
    {'1': 'EXPORT_RESULT', '2': 9},
    {'1': 'IMPORT_CSV', '2': 10},
    {'1': 'IMPORT_JSON', '2': 11},
    {'1': 'DUMP', '2': 12},
    {'1': 'RESTORE', '2': 13},
    {'1': 'CANCEL_ACTIVITY', '2': 14},
    {'1': 'TERMINATE_ACTIVITY', '2': 15},
    {'1': 'EXPORT_QUERY', '2': 16},
    {'1': 'QUERY_STATISTICS', '2': 17},
    {'1': 'INDEX_DIAGNOSTICS', '2': 18},
  ],
};

/// Descriptor for `ToolKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List toolKindDescriptor = $convert.base64Decode(
    'CghUb29sS2luZBILCgdFWFBMQUlOEAASEwoPRVhQTEFJTl9BTkFMWVpFEAESDAoIQUNUSVZJVF'
    'kQAhIJCgVMT0NLUxADEg4KClNUQVRJU1RJQ1MQBBIJCgVST0xFUxAFEgoKBkdSQU5UUxAGEg4K'
    'CkRFRklOSVRJT04QBxIMCghTTkFQU0hPVBAIEhEKDUVYUE9SVF9SRVNVTFQQCRIOCgpJTVBPUl'
    'RfQ1NWEAoSDwoLSU1QT1JUX0pTT04QCxIICgREVU1QEAwSCwoHUkVTVE9SRRANEhMKD0NBTkNF'
    'TF9BQ1RJVklUWRAOEhYKElRFUk1JTkFURV9BQ1RJVklUWRAPEhAKDEVYUE9SVF9RVUVSWRAQEh'
    'QKEFFVRVJZX1NUQVRJU1RJQ1MQERIVChFJTkRFWF9ESUFHTk9TVElDUxAS');

@$core.Deprecated('Use importPolicyDescriptor instead')
const ImportPolicy$json = {
  '1': 'ImportPolicy',
  '2': [
    {'1': 'ATOMIC_IMPORT', '2': 0},
    {'1': 'COMMIT_BATCHES', '2': 1},
    {'1': 'SKIP_INVALID_ROWS', '2': 2},
  ],
};

/// Descriptor for `ImportPolicy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List importPolicyDescriptor = $convert.base64Decode(
    'CgxJbXBvcnRQb2xpY3kSEQoNQVRPTUlDX0lNUE9SVBAAEhIKDkNPTU1JVF9CQVRDSEVTEAESFQ'
    'oRU0tJUF9JTlZBTElEX1JPV1MQAg==');

@$core.Deprecated('Use historyActionDescriptor instead')
const HistoryAction$json = {
  '1': 'HistoryAction',
  '2': [
    {'1': 'SEARCH_HISTORY', '2': 0},
    {'1': 'CLEAR_HISTORY', '2': 1},
    {'1': 'SET_PRIVACY', '2': 2},
    {'1': 'DELETE_HISTORY_ENTRY', '2': 3},
  ],
};

/// Descriptor for `HistoryAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List historyActionDescriptor = $convert.base64Decode(
    'Cg1IaXN0b3J5QWN0aW9uEhIKDlNFQVJDSF9ISVNUT1JZEAASEQoNQ0xFQVJfSElTVE9SWRABEg'
    '8KC1NFVF9QUklWQUNZEAISGAoUREVMRVRFX0hJU1RPUllfRU5UUlkQAw==');

@$core.Deprecated('Use editDraftActionDescriptor instead')
const EditDraftAction$json = {
  '1': 'EditDraftAction',
  '2': [
    {'1': 'LIST_EDIT_DRAFTS', '2': 0},
    {'1': 'SAVE_EDIT_DRAFT', '2': 1},
    {'1': 'REBIND_EDIT_DRAFT', '2': 2},
    {'1': 'DELETE_EDIT_DRAFT', '2': 3},
  ],
};

/// Descriptor for `EditDraftAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List editDraftActionDescriptor = $convert.base64Decode(
    'Cg9FZGl0RHJhZnRBY3Rpb24SFAoQTElTVF9FRElUX0RSQUZUUxAAEhMKD1NBVkVfRURJVF9EUk'
    'FGVBABEhUKEVJFQklORF9FRElUX0RSQUZUEAISFQoRREVMRVRFX0VESVRfRFJBRlQQAw==');

@$core.Deprecated('Use metadataSettingsActionDescriptor instead')
const MetadataSettingsAction$json = {
  '1': 'MetadataSettingsAction',
  '2': [
    {'1': 'READ_METADATA_SETTINGS', '2': 0},
    {'1': 'SAVE_METADATA_SETTINGS', '2': 1},
    {'1': 'FULL_METADATA_REFRESH', '2': 2},
    {'1': 'INCREMENTAL_METADATA_REFRESH', '2': 3},
  ],
};

/// Descriptor for `MetadataSettingsAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List metadataSettingsActionDescriptor = $convert.base64Decode(
    'ChZNZXRhZGF0YVNldHRpbmdzQWN0aW9uEhoKFlJFQURfTUVUQURBVEFfU0VUVElOR1MQABIaCh'
    'ZTQVZFX01FVEFEQVRBX1NFVFRJTkdTEAESGQoVRlVMTF9NRVRBREFUQV9SRUZSRVNIEAISIAoc'
    'SU5DUkVNRU5UQUxfTUVUQURBVEFfUkVGUkVTSBAD');

@$core.Deprecated('Use runtimeStatsReplyDescriptor instead')
const RuntimeStatsReply$json = {
  '1': 'RuntimeStatsReply',
  '2': [
    {'1': 'instance_id', '3': 1, '4': 1, '5': 9, '10': 'instanceId'},
    {'1': 'java_version', '3': 2, '4': 1, '5': 9, '10': 'javaVersion'},
    {'1': 'heap_used_bytes', '3': 3, '4': 1, '5': 4, '10': 'heapUsedBytes'},
    {
      '1': 'heap_committed_bytes',
      '3': 4,
      '4': 1,
      '5': 4,
      '10': 'heapCommittedBytes'
    },
    {
      '1': 'direct_buffer_bytes',
      '3': 5,
      '4': 1,
      '5': 4,
      '10': 'directBufferBytes'
    },
    {
      '1': 'mapped_buffer_bytes',
      '3': 6,
      '4': 1,
      '5': 4,
      '10': 'mappedBufferBytes'
    },
    {'1': 'retained_bytes', '3': 7, '4': 1, '5': 4, '10': 'retainedBytes'},
    {
      '1': 'transfer_snapshot_bytes',
      '3': 8,
      '4': 1,
      '5': 4,
      '10': 'transferSnapshotBytes'
    },
    {
      '1': 'physical_sessions',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'physicalSessions'
    },
    {'1': 'active_jobs', '3': 10, '4': 1, '5': 13, '10': 'activeJobs'},
    {
      '1': 'garbage_collectors',
      '3': 11,
      '4': 3,
      '5': 9,
      '10': 'garbageCollectors'
    },
  ],
};

/// Descriptor for `RuntimeStatsReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List runtimeStatsReplyDescriptor = $convert.base64Decode(
    'ChFSdW50aW1lU3RhdHNSZXBseRIfCgtpbnN0YW5jZV9pZBgBIAEoCVIKaW5zdGFuY2VJZBIhCg'
    'xqYXZhX3ZlcnNpb24YAiABKAlSC2phdmFWZXJzaW9uEiYKD2hlYXBfdXNlZF9ieXRlcxgDIAEo'
    'BFINaGVhcFVzZWRCeXRlcxIwChRoZWFwX2NvbW1pdHRlZF9ieXRlcxgEIAEoBFISaGVhcENvbW'
    '1pdHRlZEJ5dGVzEi4KE2RpcmVjdF9idWZmZXJfYnl0ZXMYBSABKARSEWRpcmVjdEJ1ZmZlckJ5'
    'dGVzEi4KE21hcHBlZF9idWZmZXJfYnl0ZXMYBiABKARSEW1hcHBlZEJ1ZmZlckJ5dGVzEiUKDn'
    'JldGFpbmVkX2J5dGVzGAcgASgEUg1yZXRhaW5lZEJ5dGVzEjYKF3RyYW5zZmVyX3NuYXBzaG90'
    'X2J5dGVzGAggASgEUhV0cmFuc2ZlclNuYXBzaG90Qnl0ZXMSKwoRcGh5c2ljYWxfc2Vzc2lvbn'
    'MYCSABKA1SEHBoeXNpY2FsU2Vzc2lvbnMSHwoLYWN0aXZlX2pvYnMYCiABKA1SCmFjdGl2ZUpv'
    'YnMSLQoSZ2FyYmFnZV9jb2xsZWN0b3JzGAsgAygJUhFnYXJiYWdlQ29sbGVjdG9ycw==');

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use contextDescriptor instead')
const Context$json = {
  '1': 'Context',
  '2': [
    {'1': 'instance_id', '3': 1, '4': 1, '5': 9, '10': 'instanceId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'protocol_version', '3': 3, '4': 1, '5': 13, '10': 'protocolVersion'},
  ],
};

/// Descriptor for `Context`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contextDescriptor = $convert.base64Decode(
    'CgdDb250ZXh0Eh8KC2luc3RhbmNlX2lkGAEgASgJUgppbnN0YW5jZUlkEh0KCnJlcXVlc3RfaW'
    'QYAiABKAlSCXJlcXVlc3RJZBIpChBwcm90b2NvbF92ZXJzaW9uGAMgASgNUg9wcm90b2NvbFZl'
    'cnNpb24=');

@$core.Deprecated('Use backendInfoDescriptor instead')
const BackendInfo$json = {
  '1': 'BackendInfo',
  '2': [
    {'1': 'instance_id', '3': 1, '4': 1, '5': 9, '10': 'instanceId'},
    {'1': 'protocol_version', '3': 2, '4': 1, '5': 13, '10': 'protocolVersion'},
    {'1': 'version', '3': 3, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `BackendInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backendInfoDescriptor = $convert.base64Decode(
    'CgtCYWNrZW5kSW5mbxIfCgtpbnN0YW5jZV9pZBgBIAEoCVIKaW5zdGFuY2VJZBIpChBwcm90b2'
    'NvbF92ZXJzaW9uGAIgASgNUg9wcm90b2NvbFZlcnNpb24SGAoHdmVyc2lvbhgDIAEoCVIHdmVy'
    'c2lvbg==');

@$core.Deprecated('Use tlsDescriptor instead')
const Tls$json = {
  '1': 'Tls',
  '2': [
    {
      '1': 'mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.TlsMode',
      '10': 'mode'
    },
    {'1': 'ca_file', '3': 2, '4': 1, '5': 9, '10': 'caFile'},
    {'1': 'client_cert', '3': 3, '4': 1, '5': 9, '10': 'clientCert'},
    {'1': 'client_key', '3': 4, '4': 1, '5': 9, '10': 'clientKey'},
    {
      '1': 'java_trust',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'javaTrust',
      '17': true
    },
    {
      '1': 'system_trust',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'systemTrust',
      '17': true
    },
    {
      '1': 'key_credential_ref',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'keyCredentialRef'
    },
    {
      '1': 'configured_mode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.TlsMode',
      '9': 2,
      '10': 'configuredMode',
      '17': true
    },
  ],
  '8': [
    {'1': '_java_trust'},
    {'1': '_system_trust'},
    {'1': '_configured_mode'},
  ],
};

/// Descriptor for `Tls`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tlsDescriptor = $convert.base64Decode(
    'CgNUbHMSKAoEbW9kZRgBIAEoDjIULmJ1c3lkYXRhLnYxLlRsc01vZGVSBG1vZGUSFwoHY2FfZm'
    'lsZRgCIAEoCVIGY2FGaWxlEh8KC2NsaWVudF9jZXJ0GAMgASgJUgpjbGllbnRDZXJ0Eh0KCmNs'
    'aWVudF9rZXkYBCABKAlSCWNsaWVudEtleRIiCgpqYXZhX3RydXN0GAUgASgISABSCWphdmFUcn'
    'VzdIgBARImCgxzeXN0ZW1fdHJ1c3QYBiABKAhIAVILc3lzdGVtVHJ1c3SIAQESLAoSa2V5X2Ny'
    'ZWRlbnRpYWxfcmVmGAcgASgJUhBrZXlDcmVkZW50aWFsUmVmEkIKD2NvbmZpZ3VyZWRfbW9kZR'
    'gIIAEoDjIULmJ1c3lkYXRhLnYxLlRsc01vZGVIAlIOY29uZmlndXJlZE1vZGWIAQFCDQoLX2ph'
    'dmFfdHJ1c3RCDwoNX3N5c3RlbV90cnVzdEISChBfY29uZmlndXJlZF9tb2Rl');

@$core.Deprecated('Use sshDescriptor instead')
const Ssh$json = {
  '1': 'Ssh',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'host', '3': 2, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 3, '4': 1, '5': 13, '10': 'port'},
    {'1': 'user', '3': 4, '4': 1, '5': 9, '10': 'user'},
    {'1': 'known_hosts', '3': 5, '4': 1, '5': 9, '10': 'knownHosts'},
    {'1': 'private_key', '3': 6, '4': 1, '5': 9, '10': 'privateKey'},
    {'1': 'agent', '3': 7, '4': 1, '5': 8, '10': 'agent'},
    {'1': 'agent_socket', '3': 8, '4': 1, '5': 9, '10': 'agentSocket'},
    {
      '1': 'agent_key_fingerprint',
      '3': 9,
      '4': 1,
      '5': 9,
      '10': 'agentKeyFingerprint'
    },
    {'1': 'trust_ref', '3': 10, '4': 1, '5': 9, '10': 'trustRef'},
  ],
};

/// Descriptor for `Ssh`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sshDescriptor = $convert.base64Decode(
    'CgNTc2gSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBISCgRob3N0GAIgASgJUgRob3N0EhIKBH'
    'BvcnQYAyABKA1SBHBvcnQSEgoEdXNlchgEIAEoCVIEdXNlchIfCgtrbm93bl9ob3N0cxgFIAEo'
    'CVIKa25vd25Ib3N0cxIfCgtwcml2YXRlX2tleRgGIAEoCVIKcHJpdmF0ZUtleRIUCgVhZ2VudB'
    'gHIAEoCFIFYWdlbnQSIQoMYWdlbnRfc29ja2V0GAggASgJUgthZ2VudFNvY2tldBIyChVhZ2Vu'
    'dF9rZXlfZmluZ2VycHJpbnQYCSABKAlSE2FnZW50S2V5RmluZ2VycHJpbnQSGwoJdHJ1c3Rfcm'
    'VmGAogASgJUgh0cnVzdFJlZg==');

@$core.Deprecated('Use sshTestRequestDescriptor instead')
const SshTestRequest$json = {
  '1': 'SshTestRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'profile_id', '3': 2, '4': 1, '5': 9, '10': 'profileId'},
    {'1': 'ssh', '3': 3, '4': 1, '5': 11, '6': '.busydata.v1.Ssh', '10': 'ssh'},
    {'1': 'ssh_password', '3': 4, '4': 1, '5': 9, '10': 'sshPassword'},
    {'1': 'key_passphrase', '3': 5, '4': 1, '5': 9, '10': 'keyPassphrase'},
  ],
};

/// Descriptor for `SshTestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sshTestRequestDescriptor = $convert.base64Decode(
    'Cg5Tc2hUZXN0UmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIdCgpwcm9maWxlX2lkGAIgASgJUglwcm9maWxlSWQSIgoDc3NoGAMgASgLMhAu'
    'YnVzeWRhdGEudjEuU3NoUgNzc2gSIQoMc3NoX3Bhc3N3b3JkGAQgASgJUgtzc2hQYXNzd29yZB'
    'IlCg5rZXlfcGFzc3BocmFzZRgFIAEoCVINa2V5UGFzc3BocmFzZQ==');

@$core.Deprecated('Use sshTestReplyDescriptor instead')
const SshTestReply$json = {
  '1': 'SshTestReply',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'user', '3': 3, '4': 1, '5': 9, '10': 'user'},
    {'1': 'algorithm', '3': 4, '4': 1, '5': 9, '10': 'algorithm'},
    {'1': 'fingerprint', '3': 5, '4': 1, '5': 9, '10': 'fingerprint'},
  ],
};

/// Descriptor for `SshTestReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sshTestReplyDescriptor = $convert.base64Decode(
    'CgxTc2hUZXN0UmVwbHkSEgoEaG9zdBgBIAEoCVIEaG9zdBISCgRwb3J0GAIgASgNUgRwb3J0Eh'
    'IKBHVzZXIYAyABKAlSBHVzZXISHAoJYWxnb3JpdGhtGAQgASgJUglhbGdvcml0aG0SIAoLZmlu'
    'Z2VycHJpbnQYBSABKAlSC2ZpbmdlcnByaW50');

@$core.Deprecated('Use sshTrustRequestDescriptor instead')
const SshTrustRequest$json = {
  '1': 'SshTrustRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {
      '1': 'profile',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'profile'
    },
    {'1': 'approval_token', '3': 3, '4': 1, '5': 9, '10': 'approvalToken'},
    {'1': 'algorithm', '3': 4, '4': 1, '5': 9, '10': 'algorithm'},
    {'1': 'fingerprint', '3': 5, '4': 1, '5': 9, '10': 'fingerprint'},
    {
      '1': 'replace_changed_key',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'replaceChangedKey'
    },
  ],
};

/// Descriptor for `SshTrustRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sshTrustRequestDescriptor = $convert.base64Decode(
    'Cg9Tc2hUcnVzdFJlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleH'
    'RSB2NvbnRleHQSLgoHcHJvZmlsZRgCIAEoCzIULmJ1c3lkYXRhLnYxLlByb2ZpbGVSB3Byb2Zp'
    'bGUSJQoOYXBwcm92YWxfdG9rZW4YAyABKAlSDWFwcHJvdmFsVG9rZW4SHAoJYWxnb3JpdGhtGA'
    'QgASgJUglhbGdvcml0aG0SIAoLZmluZ2VycHJpbnQYBSABKAlSC2ZpbmdlcnByaW50Ei4KE3Jl'
    'cGxhY2VfY2hhbmdlZF9rZXkYBiABKAhSEXJlcGxhY2VDaGFuZ2VkS2V5');

@$core.Deprecated('Use sshTrustReplyDescriptor instead')
const SshTrustReply$json = {
  '1': 'SshTrustReply',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'algorithm', '3': 3, '4': 1, '5': 9, '10': 'algorithm'},
    {'1': 'fingerprint', '3': 4, '4': 1, '5': 9, '10': 'fingerprint'},
    {
      '1': 'previous_fingerprint',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'previousFingerprint'
    },
    {'1': 'known', '3': 6, '4': 1, '5': 8, '10': 'known'},
    {'1': 'changed', '3': 7, '4': 1, '5': 8, '10': 'changed'},
    {'1': 'approval_token', '3': 8, '4': 1, '5': 9, '10': 'approvalToken'},
    {'1': 'trust_ref', '3': 9, '4': 1, '5': 9, '10': 'trustRef'},
  ],
};

/// Descriptor for `SshTrustReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sshTrustReplyDescriptor = $convert.base64Decode(
    'Cg1Tc2hUcnVzdFJlcGx5EhIKBGhvc3QYASABKAlSBGhvc3QSEgoEcG9ydBgCIAEoDVIEcG9ydB'
    'IcCglhbGdvcml0aG0YAyABKAlSCWFsZ29yaXRobRIgCgtmaW5nZXJwcmludBgEIAEoCVILZmlu'
    'Z2VycHJpbnQSMQoUcHJldmlvdXNfZmluZ2VycHJpbnQYBSABKAlSE3ByZXZpb3VzRmluZ2VycH'
    'JpbnQSFAoFa25vd24YBiABKAhSBWtub3duEhgKB2NoYW5nZWQYByABKAhSB2NoYW5nZWQSJQoO'
    'YXBwcm92YWxfdG9rZW4YCCABKAlSDWFwcHJvdmFsVG9rZW4SGwoJdHJ1c3RfcmVmGAkgASgJUg'
    'h0cnVzdFJlZg==');

@$core.Deprecated('Use profileDescriptor instead')
const Profile$json = {
  '1': 'Profile',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'engine',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.Engine',
      '10': 'engine'
    },
    {'1': 'host', '3': 4, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 5, '4': 1, '5': 13, '10': 'port'},
    {'1': 'database', '3': 6, '4': 1, '5': 9, '10': 'database'},
    {'1': 'user', '3': 7, '4': 1, '5': 9, '10': 'user'},
    {
      '1': 'environment',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.Environment',
      '10': 'environment'
    },
    {'1': 'read_only', '3': 9, '4': 1, '5': 8, '10': 'readOnly'},
    {
      '1': 'connect_timeout_seconds',
      '3': 10,
      '4': 1,
      '5': 13,
      '10': 'connectTimeoutSeconds'
    },
    {
      '1': 'query_timeout_seconds',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'queryTimeoutSeconds'
    },
    {
      '1': 'tls',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Tls',
      '10': 'tls'
    },
    {
      '1': 'ssh',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Ssh',
      '10': 'ssh'
    },
    {'1': 'credential_ref', '3': 14, '4': 1, '5': 9, '10': 'credentialRef'},
    {
      '1': 'options',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Profile.OptionsEntry',
      '10': 'options'
    },
  ],
  '3': [Profile_OptionsEntry$json],
};

@$core.Deprecated('Use profileDescriptor instead')
const Profile_OptionsEntry$json = {
  '1': 'OptionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Profile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileDescriptor = $convert.base64Decode(
    'CgdQcm9maWxlEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEisKBmVuZ2luZR'
    'gDIAEoDjITLmJ1c3lkYXRhLnYxLkVuZ2luZVIGZW5naW5lEhIKBGhvc3QYBCABKAlSBGhvc3QS'
    'EgoEcG9ydBgFIAEoDVIEcG9ydBIaCghkYXRhYmFzZRgGIAEoCVIIZGF0YWJhc2USEgoEdXNlch'
    'gHIAEoCVIEdXNlchI6CgtlbnZpcm9ubWVudBgIIAEoDjIYLmJ1c3lkYXRhLnYxLkVudmlyb25t'
    'ZW50UgtlbnZpcm9ubWVudBIbCglyZWFkX29ubHkYCSABKAhSCHJlYWRPbmx5EjYKF2Nvbm5lY3'
    'RfdGltZW91dF9zZWNvbmRzGAogASgNUhVjb25uZWN0VGltZW91dFNlY29uZHMSMgoVcXVlcnlf'
    'dGltZW91dF9zZWNvbmRzGAsgASgNUhNxdWVyeVRpbWVvdXRTZWNvbmRzEiIKA3RscxgMIAEoCz'
    'IQLmJ1c3lkYXRhLnYxLlRsc1IDdGxzEiIKA3NzaBgNIAEoCzIQLmJ1c3lkYXRhLnYxLlNzaFID'
    'c3NoEiUKDmNyZWRlbnRpYWxfcmVmGA4gASgJUg1jcmVkZW50aWFsUmVmEjsKB29wdGlvbnMYDy'
    'ADKAsyIS5idXN5ZGF0YS52MS5Qcm9maWxlLk9wdGlvbnNFbnRyeVIHb3B0aW9ucxo6CgxPcHRp'
    'b25zRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use profileRequestDescriptor instead')
const ProfileRequest$json = {
  '1': 'ProfileRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {
      '1': 'action',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ProfileAction',
      '10': 'action'
    },
    {
      '1': 'profile',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'profile'
    },
  ],
};

/// Descriptor for `ProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileRequestDescriptor = $convert.base64Decode(
    'Cg5Qcm9maWxlUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIyCgZhY3Rpb24YAiABKA4yGi5idXN5ZGF0YS52MS5Qcm9maWxlQWN0aW9uUgZh'
    'Y3Rpb24SLgoHcHJvZmlsZRgDIAEoCzIULmJ1c3lkYXRhLnYxLlByb2ZpbGVSB3Byb2ZpbGU=');

@$core.Deprecated('Use profileListDescriptor instead')
const ProfileList$json = {
  '1': 'ProfileList',
  '2': [
    {
      '1': 'profiles',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'profiles'
    },
  ],
};

/// Descriptor for `ProfileList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileListDescriptor = $convert.base64Decode(
    'CgtQcm9maWxlTGlzdBIwCghwcm9maWxlcxgBIAMoCzIULmJ1c3lkYXRhLnYxLlByb2ZpbGVSCH'
    'Byb2ZpbGVz');

@$core.Deprecated('Use openRequestDescriptor instead')
const OpenRequest$json = {
  '1': 'OpenRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {
      '1': 'profile',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'profile'
    },
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'ssh_password', '3': 4, '4': 1, '5': 9, '10': 'sshPassword'},
    {'1': 'key_passphrase', '3': 5, '4': 1, '5': 9, '10': 'keyPassphrase'},
    {'1': 'catalog', '3': 6, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 7, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'tls_key_password', '3': 8, '4': 1, '5': 9, '10': 'tlsKeyPassword'},
  ],
};

/// Descriptor for `OpenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openRequestDescriptor = $convert.base64Decode(
    'CgtPcGVuUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dFIHY2'
    '9udGV4dBIuCgdwcm9maWxlGAIgASgLMhQuYnVzeWRhdGEudjEuUHJvZmlsZVIHcHJvZmlsZRIa'
    'CghwYXNzd29yZBgDIAEoCVIIcGFzc3dvcmQSIQoMc3NoX3Bhc3N3b3JkGAQgASgJUgtzc2hQYX'
    'Nzd29yZBIlCg5rZXlfcGFzc3BocmFzZRgFIAEoCVINa2V5UGFzc3BocmFzZRIYCgdjYXRhbG9n'
    'GAYgASgJUgdjYXRhbG9nEhYKBnNjaGVtYRgHIAEoCVIGc2NoZW1hEigKEHRsc19rZXlfcGFzc3'
    'dvcmQYCCABKAlSDnRsc0tleVBhc3N3b3Jk');

@$core.Deprecated('Use connectionDescriptionDescriptor instead')
const ConnectionDescription$json = {
  '1': 'ConnectionDescription',
  '2': [
    {'1': 'jdbc_url', '3': 1, '4': 1, '5': 9, '10': 'jdbcUrl'},
    {'1': 'initial_database', '3': 2, '4': 1, '5': 9, '10': 'initialDatabase'},
    {'1': 'driver_class', '3': 3, '4': 1, '5': 9, '10': 'driverClass'},
    {'1': 'driver_version', '3': 4, '4': 1, '5': 9, '10': 'driverVersion'},
  ],
};

/// Descriptor for `ConnectionDescription`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionDescriptionDescriptor = $convert.base64Decode(
    'ChVDb25uZWN0aW9uRGVzY3JpcHRpb24SGQoIamRiY191cmwYASABKAlSB2pkYmNVcmwSKQoQaW'
    '5pdGlhbF9kYXRhYmFzZRgCIAEoCVIPaW5pdGlhbERhdGFiYXNlEiEKDGRyaXZlcl9jbGFzcxgD'
    'IAEoCVILZHJpdmVyQ2xhc3MSJQoOZHJpdmVyX3ZlcnNpb24YBCABKAlSDWRyaXZlclZlcnNpb2'
    '4=');

@$core.Deprecated('Use connectionInfoDescriptor instead')
const ConnectionInfo$json = {
  '1': 'ConnectionInfo',
  '2': [
    {'1': 'product', '3': 1, '4': 1, '5': 9, '10': 'product'},
    {'1': 'version', '3': 2, '4': 1, '5': 9, '10': 'version'},
    {'1': 'host', '3': 4, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 5, '4': 1, '5': 13, '10': 'port'},
    {'1': 'database', '3': 6, '4': 1, '5': 9, '10': 'database'},
    {'1': 'schema', '3': 7, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'tls_cipher', '3': 8, '4': 1, '5': 9, '10': 'tlsCipher'},
    {'1': 'tls_observed', '3': 9, '4': 1, '5': 8, '10': 'tlsObserved'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
};

/// Descriptor for `ConnectionInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionInfoDescriptor = $convert.base64Decode(
    'Cg5Db25uZWN0aW9uSW5mbxIYCgdwcm9kdWN0GAEgASgJUgdwcm9kdWN0EhgKB3ZlcnNpb24YAi'
    'ABKAlSB3ZlcnNpb24SEgoEaG9zdBgEIAEoCVIEaG9zdBISCgRwb3J0GAUgASgNUgRwb3J0EhoK'
    'CGRhdGFiYXNlGAYgASgJUghkYXRhYmFzZRIWCgZzY2hlbWEYByABKAlSBnNjaGVtYRIdCgp0bH'
    'NfY2lwaGVyGAggASgJUgl0bHNDaXBoZXISIQoMdGxzX29ic2VydmVkGAkgASgIUgt0bHNPYnNl'
    'cnZlZEoECAMQBA==');

@$core.Deprecated('Use capabilityRequestDescriptor instead')
const CapabilityRequest$json = {
  '1': 'CapabilityRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'context_revision', '3': 3, '4': 1, '5': 4, '10': 'contextRevision'},
    {'1': 'session_revision', '3': 4, '4': 1, '5': 4, '10': 'sessionRevision'},
  ],
};

/// Descriptor for `CapabilityRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityRequestDescriptor = $convert.base64Decode(
    'ChFDYXBhYmlsaXR5UmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udG'
    'V4dFIHY29udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSKQoQY29udGV4dF9y'
    'ZXZpc2lvbhgDIAEoBFIPY29udGV4dFJldmlzaW9uEikKEHNlc3Npb25fcmV2aXNpb24YBCABKA'
    'RSD3Nlc3Npb25SZXZpc2lvbg==');

@$core.Deprecated('Use capabilityDescriptor instead')
const Capability$json = {
  '1': 'Capability',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {
      '1': 'state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.CapabilityState',
      '10': 'state'
    },
    {'1': 'detail', '3': 4, '4': 1, '5': 9, '10': 'detail'},
    {'1': 'data_checked', '3': 5, '4': 1, '5': 8, '10': 'dataChecked'},
    {'1': 'empty', '3': 6, '4': 1, '5': 8, '10': 'empty'},
  ],
};

/// Descriptor for `Capability`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityDescriptor = $convert.base64Decode(
    'CgpDYXBhYmlsaXR5Eg4KAmlkGAEgASgJUgJpZBIUCgVsYWJlbBgCIAEoCVIFbGFiZWwSMgoFc3'
    'RhdGUYAyABKA4yHC5idXN5ZGF0YS52MS5DYXBhYmlsaXR5U3RhdGVSBXN0YXRlEhYKBmRldGFp'
    'bBgEIAEoCVIGZGV0YWlsEiEKDGRhdGFfY2hlY2tlZBgFIAEoCFILZGF0YUNoZWNrZWQSFAoFZW'
    '1wdHkYBiABKAhSBWVtcHR5');

@$core.Deprecated('Use capabilityListDescriptor instead')
const CapabilityList$json = {
  '1': 'CapabilityList',
  '2': [
    {'1': 'backend_instance', '3': 1, '4': 1, '5': 9, '10': 'backendInstance'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'context_revision', '3': 3, '4': 1, '5': 4, '10': 'contextRevision'},
    {'1': 'session_revision', '3': 4, '4': 1, '5': 4, '10': 'sessionRevision'},
    {'1': 'product', '3': 5, '4': 1, '5': 9, '10': 'product'},
    {'1': 'version', '3': 6, '4': 1, '5': 9, '10': 'version'},
    {'1': 'major_version', '3': 7, '4': 1, '5': 13, '10': 'majorVersion'},
    {'1': 'minor_version', '3': 8, '4': 1, '5': 13, '10': 'minorVersion'},
    {
      '1': 'entries',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Capability',
      '10': 'entries'
    },
    {'1': 'availability', '3': 10, '4': 1, '5': 9, '10': 'availability'},
  ],
};

/// Descriptor for `CapabilityList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityListDescriptor = $convert.base64Decode(
    'Cg5DYXBhYmlsaXR5TGlzdBIpChBiYWNrZW5kX2luc3RhbmNlGAEgASgJUg9iYWNrZW5kSW5zdG'
    'FuY2USHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2lvbklkEikKEGNvbnRleHRfcmV2aXNpb24Y'
    'AyABKARSD2NvbnRleHRSZXZpc2lvbhIpChBzZXNzaW9uX3JldmlzaW9uGAQgASgEUg9zZXNzaW'
    '9uUmV2aXNpb24SGAoHcHJvZHVjdBgFIAEoCVIHcHJvZHVjdBIYCgd2ZXJzaW9uGAYgASgJUgd2'
    'ZXJzaW9uEiMKDW1ham9yX3ZlcnNpb24YByABKA1SDG1ham9yVmVyc2lvbhIjCg1taW5vcl92ZX'
    'JzaW9uGAggASgNUgxtaW5vclZlcnNpb24SMQoHZW50cmllcxgJIAMoCzIXLmJ1c3lkYXRhLnYx'
    'LkNhcGFiaWxpdHlSB2VudHJpZXMSIgoMYXZhaWxhYmlsaXR5GAogASgJUgxhdmFpbGFiaWxpdH'
    'k=');

@$core.Deprecated('Use sessionRequestDescriptor instead')
const SessionRequest$json = {
  '1': 'SessionRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'action',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.SessionAction',
      '10': 'action'
    },
    {'1': 'force', '3': 4, '4': 1, '5': 8, '10': 'force'},
    {'1': 'approval_token', '3': 5, '4': 1, '5': 9, '10': 'approvalToken'},
  ],
};

/// Descriptor for `SessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionRequestDescriptor = $convert.base64Decode(
    'Cg5TZXNzaW9uUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSMgoGYWN0aW9uGAMgASgO'
    'MhouYnVzeWRhdGEudjEuU2Vzc2lvbkFjdGlvblIGYWN0aW9uEhQKBWZvcmNlGAQgASgIUgVmb3'
    'JjZRIlCg5hcHByb3ZhbF90b2tlbhgFIAEoCVINYXBwcm92YWxUb2tlbg==');

@$core.Deprecated('Use sessionInfoDescriptor instead')
const SessionInfo$json = {
  '1': 'SessionInfo',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'profile',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'profile'
    },
    {'1': 'auto_commit', '3': 3, '4': 1, '5': 8, '10': 'autoCommit'},
    {
      '1': 'transaction',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.TransactionState',
      '10': 'transaction'
    },
    {
      '1': 'database',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ConnectionInfo',
      '10': 'database'
    },
    {'1': 'context_revision', '3': 6, '4': 1, '5': 4, '10': 'contextRevision'},
    {'1': 'current_catalog', '3': 7, '4': 1, '5': 9, '10': 'currentCatalog'},
    {'1': 'current_schema', '3': 8, '4': 1, '5': 9, '10': 'currentSchema'},
    {'1': 'search_path', '3': 9, '4': 3, '5': 9, '10': 'searchPath'},
    {'1': 'sql_mode', '3': 10, '4': 1, '5': 9, '10': 'sqlMode'},
    {
      '1': 'standard_conforming_strings',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'standardConformingStrings'
    },
    {
      '1': 'command_acknowledged',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'commandAcknowledged'
    },
    {'1': 'command_warning', '3': 13, '4': 1, '5': 9, '10': 'commandWarning'},
    {
      '1': 'acknowledged_action',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.SessionAction',
      '10': 'acknowledgedAction'
    },
    {'1': 'session_revision', '3': 15, '4': 1, '5': 4, '10': 'sessionRevision'},
    {
      '1': 'metadata_source_identity',
      '3': 16,
      '4': 1,
      '5': 9,
      '10': 'metadataSourceIdentity'
    },
  ],
};

/// Descriptor for `SessionInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionInfoDescriptor = $convert.base64Decode(
    'CgtTZXNzaW9uSW5mbxIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSLgoHcHJvZmlsZR'
    'gCIAEoCzIULmJ1c3lkYXRhLnYxLlByb2ZpbGVSB3Byb2ZpbGUSHwoLYXV0b19jb21taXQYAyAB'
    'KAhSCmF1dG9Db21taXQSPwoLdHJhbnNhY3Rpb24YBCABKA4yHS5idXN5ZGF0YS52MS5UcmFuc2'
    'FjdGlvblN0YXRlUgt0cmFuc2FjdGlvbhI3CghkYXRhYmFzZRgFIAEoCzIbLmJ1c3lkYXRhLnYx'
    'LkNvbm5lY3Rpb25JbmZvUghkYXRhYmFzZRIpChBjb250ZXh0X3JldmlzaW9uGAYgASgEUg9jb2'
    '50ZXh0UmV2aXNpb24SJwoPY3VycmVudF9jYXRhbG9nGAcgASgJUg5jdXJyZW50Q2F0YWxvZxIl'
    'Cg5jdXJyZW50X3NjaGVtYRgIIAEoCVINY3VycmVudFNjaGVtYRIfCgtzZWFyY2hfcGF0aBgJIA'
    'MoCVIKc2VhcmNoUGF0aBIZCghzcWxfbW9kZRgKIAEoCVIHc3FsTW9kZRI+ChtzdGFuZGFyZF9j'
    'b25mb3JtaW5nX3N0cmluZ3MYCyABKAhSGXN0YW5kYXJkQ29uZm9ybWluZ1N0cmluZ3MSMQoUY2'
    '9tbWFuZF9hY2tub3dsZWRnZWQYDCABKAhSE2NvbW1hbmRBY2tub3dsZWRnZWQSJwoPY29tbWFu'
    'ZF93YXJuaW5nGA0gASgJUg5jb21tYW5kV2FybmluZxJLChNhY2tub3dsZWRnZWRfYWN0aW9uGA'
    '4gASgOMhouYnVzeWRhdGEudjEuU2Vzc2lvbkFjdGlvblISYWNrbm93bGVkZ2VkQWN0aW9uEikK'
    'EHNlc3Npb25fcmV2aXNpb24YDyABKARSD3Nlc3Npb25SZXZpc2lvbhI4ChhtZXRhZGF0YV9zb3'
    'VyY2VfaWRlbnRpdHkYECABKAlSFm1ldGFkYXRhU291cmNlSWRlbnRpdHk=');

@$core.Deprecated('Use executeRequestDescriptor instead')
const ExecuteRequest$json = {
  '1': 'ExecuteRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {'1': 'sql', '3': 4, '4': 1, '5': 9, '10': 'sql'},
    {'1': 'document_id', '3': 5, '4': 1, '5': 9, '10': 'documentId'},
    {'1': 'document_version', '3': 6, '4': 1, '5': 4, '10': 'documentVersion'},
    {
      '1': 'mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ExecutionMode',
      '10': 'mode'
    },
    {'1': 'caret_utf16', '3': 8, '4': 1, '5': 13, '10': 'caretUtf16'},
    {
      '1': 'error_policy',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ErrorPolicy',
      '10': 'errorPolicy'
    },
    {'1': 'row_limit', '3': 10, '4': 1, '5': 4, '10': 'rowLimit'},
    {'1': 'streaming_read', '3': 11, '4': 1, '5': 8, '10': 'streamingRead'},
    {'1': 'approval_token', '3': 12, '4': 1, '5': 9, '10': 'approvalToken'},
  ],
};

/// Descriptor for `ExecuteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List executeRequestDescriptor = $convert.base64Decode(
    'Cg5FeGVjdXRlUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSIQoMZXhlY3V0aW9uX2lk'
    'GAMgASgJUgtleGVjdXRpb25JZBIQCgNzcWwYBCABKAlSA3NxbBIfCgtkb2N1bWVudF9pZBgFIA'
    'EoCVIKZG9jdW1lbnRJZBIpChBkb2N1bWVudF92ZXJzaW9uGAYgASgEUg9kb2N1bWVudFZlcnNp'
    'b24SLgoEbW9kZRgHIAEoDjIaLmJ1c3lkYXRhLnYxLkV4ZWN1dGlvbk1vZGVSBG1vZGUSHwoLY2'
    'FyZXRfdXRmMTYYCCABKA1SCmNhcmV0VXRmMTYSOwoMZXJyb3JfcG9saWN5GAkgASgOMhguYnVz'
    'eWRhdGEudjEuRXJyb3JQb2xpY3lSC2Vycm9yUG9saWN5EhsKCXJvd19saW1pdBgKIAEoBFIIcm'
    '93TGltaXQSJQoOc3RyZWFtaW5nX3JlYWQYCyABKAhSDXN0cmVhbWluZ1JlYWQSJQoOYXBwcm92'
    'YWxfdG9rZW4YDCABKAlSDWFwcHJvdmFsVG9rZW4=');

@$core.Deprecated('Use rowConditionDescriptor instead')
const RowCondition$json = {
  '1': 'RowCondition',
  '2': [
    {'1': 'column', '3': 1, '4': 1, '5': 9, '10': 'column'},
    {
      '1': 'predicate',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ValuePredicate',
      '10': 'predicate'
    },
    {
      '1': 'value',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'value'
    },
  ],
};

/// Descriptor for `RowCondition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowConditionDescriptor = $convert.base64Decode(
    'CgxSb3dDb25kaXRpb24SFgoGY29sdW1uGAEgASgJUgZjb2x1bW4SOQoJcHJlZGljYXRlGAIgAS'
    'gOMhsuYnVzeWRhdGEudjEuVmFsdWVQcmVkaWNhdGVSCXByZWRpY2F0ZRIoCgV2YWx1ZRgDIAEo'
    'CzISLmJ1c3lkYXRhLnYxLlZhbHVlUgV2YWx1ZQ==');

@$core.Deprecated('Use rowOrderDescriptor instead')
const RowOrder$json = {
  '1': 'RowOrder',
  '2': [
    {'1': 'column', '3': 1, '4': 1, '5': 9, '10': 'column'},
    {'1': 'descending', '3': 2, '4': 1, '5': 8, '10': 'descending'},
  ],
};

/// Descriptor for `RowOrder`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowOrderDescriptor = $convert.base64Decode(
    'CghSb3dPcmRlchIWCgZjb2x1bW4YASABKAlSBmNvbHVtbhIeCgpkZXNjZW5kaW5nGAIgASgIUg'
    'pkZXNjZW5kaW5n');

@$core.Deprecated('Use browseRequestDescriptor instead')
const BrowseRequest$json = {
  '1': 'BrowseRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {'1': 'document_id', '3': 4, '4': 1, '5': 9, '10': 'documentId'},
    {'1': 'catalog', '3': 5, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 6, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 7, '4': 1, '5': 9, '10': 'table'},
    {'1': 'row_limit', '3': 8, '4': 1, '5': 4, '10': 'rowLimit'},
    {
      '1': 'conditions',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RowCondition',
      '10': 'conditions'
    },
    {
      '1': 'order',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RowOrder',
      '10': 'order'
    },
    {'1': 'approval_token', '3': 11, '4': 1, '5': 9, '10': 'approvalToken'},
    {
      '1': 'metadata_snapshot_revision',
      '3': 12,
      '4': 1,
      '5': 4,
      '10': 'metadataSnapshotRevision'
    },
    {
      '1': 'metadata_object_identity',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'metadataObjectIdentity'
    },
    {
      '1': 'origin_relationship_identity',
      '3': 14,
      '4': 1,
      '5': 9,
      '10': 'originRelationshipIdentity'
    },
    {'1': 'origin_result_id', '3': 15, '4': 1, '5': 9, '10': 'originResultId'},
    {
      '1': 'origin_source_row',
      '3': 16,
      '4': 1,
      '5': 4,
      '10': 'originSourceRow'
    },
  ],
};

/// Descriptor for `BrowseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List browseRequestDescriptor = $convert.base64Decode(
    'Cg1Ccm93c2VSZXF1ZXN0Ei4KB2NvbnRleHQYASABKAsyFC5idXN5ZGF0YS52MS5Db250ZXh0Ug'
    'djb250ZXh0Eh0KCnNlc3Npb25faWQYAiABKAlSCXNlc3Npb25JZBIhCgxleGVjdXRpb25faWQY'
    'AyABKAlSC2V4ZWN1dGlvbklkEh8KC2RvY3VtZW50X2lkGAQgASgJUgpkb2N1bWVudElkEhgKB2'
    'NhdGFsb2cYBSABKAlSB2NhdGFsb2cSFgoGc2NoZW1hGAYgASgJUgZzY2hlbWESFAoFdGFibGUY'
    'ByABKAlSBXRhYmxlEhsKCXJvd19saW1pdBgIIAEoBFIIcm93TGltaXQSOQoKY29uZGl0aW9ucx'
    'gJIAMoCzIZLmJ1c3lkYXRhLnYxLlJvd0NvbmRpdGlvblIKY29uZGl0aW9ucxIrCgVvcmRlchgK'
    'IAMoCzIVLmJ1c3lkYXRhLnYxLlJvd09yZGVyUgVvcmRlchIlCg5hcHByb3ZhbF90b2tlbhgLIA'
    'EoCVINYXBwcm92YWxUb2tlbhI8ChptZXRhZGF0YV9zbmFwc2hvdF9yZXZpc2lvbhgMIAEoBFIY'
    'bWV0YWRhdGFTbmFwc2hvdFJldmlzaW9uEjgKGG1ldGFkYXRhX29iamVjdF9pZGVudGl0eRgNIA'
    'EoCVIWbWV0YWRhdGFPYmplY3RJZGVudGl0eRJAChxvcmlnaW5fcmVsYXRpb25zaGlwX2lkZW50'
    'aXR5GA4gASgJUhpvcmlnaW5SZWxhdGlvbnNoaXBJZGVudGl0eRIoChBvcmlnaW5fcmVzdWx0X2'
    'lkGA8gASgJUg5vcmlnaW5SZXN1bHRJZBIqChFvcmlnaW5fc291cmNlX3JvdxgQIAEoBFIPb3Jp'
    'Z2luU291cmNlUm93');

@$core.Deprecated('Use approvalDescriptor instead')
const Approval$json = {
  '1': 'Approval',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'statements', '3': 2, '4': 3, '5': 9, '10': 'statements'},
    {'1': 'risks', '3': 3, '4': 3, '5': 9, '10': 'risks'},
    {'1': 'expires_unix_ms', '3': 4, '4': 1, '5': 4, '10': 'expiresUnixMs'},
  ],
};

/// Descriptor for `Approval`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalDescriptor = $convert.base64Decode(
    'CghBcHByb3ZhbBIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SHgoKc3RhdGVtZW50cxgCIAMoCVIKc3'
    'RhdGVtZW50cxIUCgVyaXNrcxgDIAMoCVIFcmlza3MSJgoPZXhwaXJlc191bml4X21zGAQgASgE'
    'Ug1leHBpcmVzVW5peE1z');

@$core.Deprecated('Use jobRequestDescriptor instead')
const JobRequest$json = {
  '1': 'JobRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'job_id', '3': 2, '4': 1, '5': 9, '10': 'jobId'},
    {'1': 'session_id', '3': 3, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'offset', '3': 4, '4': 1, '5': 13, '10': 'offset'},
    {'1': 'limit', '3': 5, '4': 1, '5': 13, '10': 'limit'},
    {'1': 'catalog_revision', '3': 6, '4': 1, '5': 4, '10': 'catalogRevision'},
  ],
};

/// Descriptor for `JobRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jobRequestDescriptor = $convert.base64Decode(
    'CgpKb2JSZXF1ZXN0Ei4KB2NvbnRleHQYASABKAsyFC5idXN5ZGF0YS52MS5Db250ZXh0Ugdjb2'
    '50ZXh0EhUKBmpvYl9pZBgCIAEoCVIFam9iSWQSHQoKc2Vzc2lvbl9pZBgDIAEoCVIJc2Vzc2lv'
    'bklkEhYKBm9mZnNldBgEIAEoDVIGb2Zmc2V0EhQKBWxpbWl0GAUgASgNUgVsaW1pdBIpChBjYX'
    'RhbG9nX3JldmlzaW9uGAYgASgEUg9jYXRhbG9nUmV2aXNpb24=');

@$core.Deprecated('Use jobListDescriptor instead')
const JobList$json = {
  '1': 'JobList',
  '2': [
    {
      '1': 'jobs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.JobInfo',
      '10': 'jobs'
    },
    {'1': 'next_offset', '3': 2, '4': 1, '5': 13, '10': 'nextOffset'},
    {'1': 'complete', '3': 3, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'catalog_revision', '3': 4, '4': 1, '5': 4, '10': 'catalogRevision'},
  ],
};

/// Descriptor for `JobList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jobListDescriptor = $convert.base64Decode(
    'CgdKb2JMaXN0EigKBGpvYnMYASADKAsyFC5idXN5ZGF0YS52MS5Kb2JJbmZvUgRqb2JzEh8KC2'
    '5leHRfb2Zmc2V0GAIgASgNUgpuZXh0T2Zmc2V0EhoKCGNvbXBsZXRlGAMgASgIUghjb21wbGV0'
    'ZRIpChBjYXRhbG9nX3JldmlzaW9uGAQgASgEUg9jYXRhbG9nUmV2aXNpb24=');

@$core.Deprecated('Use retainedRequestDescriptor instead')
const RetainedRequest$json = {
  '1': 'RetainedRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'offset', '3': 2, '4': 1, '5': 13, '10': 'offset'},
    {'1': 'limit', '3': 3, '4': 1, '5': 13, '10': 'limit'},
    {'1': 'catalog_revision', '3': 4, '4': 1, '5': 4, '10': 'catalogRevision'},
  ],
};

/// Descriptor for `RetainedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List retainedRequestDescriptor = $convert.base64Decode(
    'Cg9SZXRhaW5lZFJlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleH'
    'RSB2NvbnRleHQSFgoGb2Zmc2V0GAIgASgNUgZvZmZzZXQSFAoFbGltaXQYAyABKA1SBWxpbWl0'
    'EikKEGNhdGFsb2dfcmV2aXNpb24YBCABKARSD2NhdGFsb2dSZXZpc2lvbg==');

@$core.Deprecated('Use retainedResultDescriptor instead')
const RetainedResult$json = {
  '1': 'RetainedResult',
  '2': [
    {
      '1': 'result',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.StatementResult',
      '10': 'result'
    },
    {'1': 'job_id', '3': 2, '4': 1, '5': 9, '10': 'jobId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {'1': 'document_id', '3': 4, '4': 1, '5': 9, '10': 'documentId'},
    {'1': 'session_id', '3': 5, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'created_unix_ms', '3': 6, '4': 1, '5': 4, '10': 'createdUnixMs'},
    {'1': 'disposal_pending', '3': 7, '4': 1, '5': 8, '10': 'disposalPending'},
    {'1': 'leases', '3': 8, '4': 1, '5': 13, '10': 'leases'},
    {'1': 'availability', '3': 9, '4': 1, '5': 9, '10': 'availability'},
    {
      '1': 'state',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.JobState',
      '10': 'state'
    },
    {
      '1': 'target',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'target'
    },
    {
      '1': 'sql_provenance',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'sqlProvenance'
    },
    {'1': 'source_schema', '3': 13, '4': 1, '5': 9, '10': 'sourceSchema'},
  ],
};

/// Descriptor for `RetainedResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List retainedResultDescriptor = $convert.base64Decode(
    'Cg5SZXRhaW5lZFJlc3VsdBI0CgZyZXN1bHQYASABKAsyHC5idXN5ZGF0YS52MS5TdGF0ZW1lbn'
    'RSZXN1bHRSBnJlc3VsdBIVCgZqb2JfaWQYAiABKAlSBWpvYklkEiEKDGV4ZWN1dGlvbl9pZBgD'
    'IAEoCVILZXhlY3V0aW9uSWQSHwoLZG9jdW1lbnRfaWQYBCABKAlSCmRvY3VtZW50SWQSHQoKc2'
    'Vzc2lvbl9pZBgFIAEoCVIJc2Vzc2lvbklkEiYKD2NyZWF0ZWRfdW5peF9tcxgGIAEoBFINY3Jl'
    'YXRlZFVuaXhNcxIpChBkaXNwb3NhbF9wZW5kaW5nGAcgASgIUg9kaXNwb3NhbFBlbmRpbmcSFg'
    'oGbGVhc2VzGAggASgNUgZsZWFzZXMSIgoMYXZhaWxhYmlsaXR5GAkgASgJUgxhdmFpbGFiaWxp'
    'dHkSKwoFc3RhdGUYCiABKA4yFS5idXN5ZGF0YS52MS5Kb2JTdGF0ZVIFc3RhdGUSLAoGdGFyZ2'
    'V0GAsgASgLMhQuYnVzeWRhdGEudjEuUHJvZmlsZVIGdGFyZ2V0EjkKDnNxbF9wcm92ZW5hbmNl'
    'GAwgASgLMhIuYnVzeWRhdGEudjEuVmFsdWVSDXNxbFByb3ZlbmFuY2USIwoNc291cmNlX3NjaG'
    'VtYRgNIAEoCVIMc291cmNlU2NoZW1h');

@$core.Deprecated('Use retainedListDescriptor instead')
const RetainedList$json = {
  '1': 'RetainedList',
  '2': [
    {
      '1': 'results',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RetainedResult',
      '10': 'results'
    },
    {'1': 'next_offset', '3': 2, '4': 1, '5': 13, '10': 'nextOffset'},
    {'1': 'complete', '3': 3, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'catalog_revision', '3': 4, '4': 1, '5': 4, '10': 'catalogRevision'},
  ],
};

/// Descriptor for `RetainedList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List retainedListDescriptor = $convert.base64Decode(
    'CgxSZXRhaW5lZExpc3QSNQoHcmVzdWx0cxgBIAMoCzIbLmJ1c3lkYXRhLnYxLlJldGFpbmVkUm'
    'VzdWx0UgdyZXN1bHRzEh8KC25leHRfb2Zmc2V0GAIgASgNUgpuZXh0T2Zmc2V0EhoKCGNvbXBs'
    'ZXRlGAMgASgIUghjb21wbGV0ZRIpChBjYXRhbG9nX3JldmlzaW9uGAQgASgEUg9jYXRhbG9nUm'
    'V2aXNpb24=');

@$core.Deprecated('Use jobInfoDescriptor instead')
const JobInfo$json = {
  '1': 'JobInfo',
  '2': [
    {'1': 'job_id', '3': 1, '4': 1, '5': 9, '10': 'jobId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {
      '1': 'state',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.JobState',
      '10': 'state'
    },
    {
      '1': 'results',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.StatementResult',
      '10': 'results'
    },
    {'1': 'messages', '3': 6, '4': 3, '5': 9, '10': 'messages'},
    {'1': 'duration_ms', '3': 7, '4': 1, '5': 4, '10': 'durationMs'},
    {'1': 'error_code', '3': 8, '4': 1, '5': 9, '10': 'errorCode'},
    {'1': 'progress_rows', '3': 9, '4': 1, '5': 4, '10': 'progressRows'},
    {'1': 'committed_rows', '3': 10, '4': 1, '5': 4, '10': 'committedRows'},
    {'1': 'rejected_rows', '3': 11, '4': 1, '5': 4, '10': 'rejectedRows'},
    {
      '1': 'target',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'target'
    },
    {
      '1': 'tool_kind',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ToolKind',
      '9': 0,
      '10': 'toolKind',
      '17': true
    },
    {'1': 'source_schema', '3': 14, '4': 1, '5': 9, '10': 'sourceSchema'},
  ],
  '8': [
    {'1': '_tool_kind'},
  ],
};

/// Descriptor for `JobInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jobInfoDescriptor = $convert.base64Decode(
    'CgdKb2JJbmZvEhUKBmpvYl9pZBgBIAEoCVIFam9iSWQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2'
    'Vzc2lvbklkEiEKDGV4ZWN1dGlvbl9pZBgDIAEoCVILZXhlY3V0aW9uSWQSKwoFc3RhdGUYBCAB'
    'KA4yFS5idXN5ZGF0YS52MS5Kb2JTdGF0ZVIFc3RhdGUSNgoHcmVzdWx0cxgFIAMoCzIcLmJ1c3'
    'lkYXRhLnYxLlN0YXRlbWVudFJlc3VsdFIHcmVzdWx0cxIaCghtZXNzYWdlcxgGIAMoCVIIbWVz'
    'c2FnZXMSHwoLZHVyYXRpb25fbXMYByABKARSCmR1cmF0aW9uTXMSHQoKZXJyb3JfY29kZRgIIA'
    'EoCVIJZXJyb3JDb2RlEiMKDXByb2dyZXNzX3Jvd3MYCSABKARSDHByb2dyZXNzUm93cxIlCg5j'
    'b21taXR0ZWRfcm93cxgKIAEoBFINY29tbWl0dGVkUm93cxIjCg1yZWplY3RlZF9yb3dzGAsgAS'
    'gEUgxyZWplY3RlZFJvd3MSLAoGdGFyZ2V0GAwgASgLMhQuYnVzeWRhdGEudjEuUHJvZmlsZVIG'
    'dGFyZ2V0EjcKCXRvb2xfa2luZBgNIAEoDjIVLmJ1c3lkYXRhLnYxLlRvb2xLaW5kSABSCHRvb2'
    'xLaW5kiAEBEiMKDXNvdXJjZV9zY2hlbWEYDiABKAlSDHNvdXJjZVNjaGVtYUIMCgpfdG9vbF9r'
    'aW5k');

@$core.Deprecated('Use statementResultDescriptor instead')
const StatementResult$json = {
  '1': 'StatementResult',
  '2': [
    {'1': 'statement_index', '3': 1, '4': 1, '5': 13, '10': 'statementIndex'},
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {
      '1': 'columns',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Column',
      '10': 'columns'
    },
    {'1': 'update_count', '3': 4, '4': 1, '5': 18, '10': 'updateCount'},
    {'1': 'fetched_rows', '3': 5, '4': 1, '5': 4, '10': 'fetchedRows'},
    {'1': 'complete', '3': 6, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'limited', '3': 7, '4': 1, '5': 8, '10': 'limited'},
    {'1': 'plan', '3': 8, '4': 1, '5': 8, '10': 'plan'},
  ],
};

/// Descriptor for `StatementResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statementResultDescriptor = $convert.base64Decode(
    'Cg9TdGF0ZW1lbnRSZXN1bHQSJwoPc3RhdGVtZW50X2luZGV4GAEgASgNUg5zdGF0ZW1lbnRJbm'
    'RleBIbCglyZXN1bHRfaWQYAiABKAlSCHJlc3VsdElkEi0KB2NvbHVtbnMYAyADKAsyEy5idXN5'
    'ZGF0YS52MS5Db2x1bW5SB2NvbHVtbnMSIQoMdXBkYXRlX2NvdW50GAQgASgSUgt1cGRhdGVDb3'
    'VudBIhCgxmZXRjaGVkX3Jvd3MYBSABKARSC2ZldGNoZWRSb3dzEhoKCGNvbXBsZXRlGAYgASgI'
    'Ughjb21wbGV0ZRIYCgdsaW1pdGVkGAcgASgIUgdsaW1pdGVkEhIKBHBsYW4YCCABKAhSBHBsYW'
    '4=');

@$core.Deprecated('Use columnDescriptor instead')
const Column$json = {
  '1': 'Column',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type_name', '3': 2, '4': 1, '5': 9, '10': 'typeName'},
    {'1': 'jdbc_type', '3': 3, '4': 1, '5': 5, '10': 'jdbcType'},
    {'1': 'precision', '3': 4, '4': 1, '5': 13, '10': 'precision'},
    {'1': 'scale', '3': 5, '4': 1, '5': 17, '10': 'scale'},
    {'1': 'nullable', '3': 6, '4': 1, '5': 8, '10': 'nullable'},
    {'1': 'signed', '3': 7, '4': 1, '5': 8, '10': 'signed'},
    {'1': 'catalog', '3': 8, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 9, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 10, '4': 1, '5': 9, '10': 'table'},
    {'1': 'read_only', '3': 11, '4': 1, '5': 8, '10': 'readOnly'},
    {'1': 'base_column', '3': 12, '4': 1, '5': 9, '10': 'baseColumn'},
    {'1': 'ordinal', '3': 13, '4': 1, '5': 13, '10': 'ordinal'},
    {'1': 'provenance_known', '3': 14, '4': 1, '5': 8, '10': 'provenanceKnown'},
    {
      '1': 'metadata_identity',
      '3': 15,
      '4': 1,
      '5': 9,
      '10': 'metadataIdentity'
    },
    {
      '1': 'metadata_snapshot_revision',
      '3': 16,
      '4': 1,
      '5': 4,
      '10': 'metadataSnapshotRevision'
    },
  ],
};

/// Descriptor for `Column`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List columnDescriptor = $convert.base64Decode(
    'CgZDb2x1bW4SEgoEbmFtZRgBIAEoCVIEbmFtZRIbCgl0eXBlX25hbWUYAiABKAlSCHR5cGVOYW'
    '1lEhsKCWpkYmNfdHlwZRgDIAEoBVIIamRiY1R5cGUSHAoJcHJlY2lzaW9uGAQgASgNUglwcmVj'
    'aXNpb24SFAoFc2NhbGUYBSABKBFSBXNjYWxlEhoKCG51bGxhYmxlGAYgASgIUghudWxsYWJsZR'
    'IWCgZzaWduZWQYByABKAhSBnNpZ25lZBIYCgdjYXRhbG9nGAggASgJUgdjYXRhbG9nEhYKBnNj'
    'aGVtYRgJIAEoCVIGc2NoZW1hEhQKBXRhYmxlGAogASgJUgV0YWJsZRIbCglyZWFkX29ubHkYCy'
    'ABKAhSCHJlYWRPbmx5Eh8KC2Jhc2VfY29sdW1uGAwgASgJUgpiYXNlQ29sdW1uEhgKB29yZGlu'
    'YWwYDSABKA1SB29yZGluYWwSKQoQcHJvdmVuYW5jZV9rbm93bhgOIAEoCFIPcHJvdmVuYW5jZU'
    'tub3duEisKEW1ldGFkYXRhX2lkZW50aXR5GA8gASgJUhBtZXRhZGF0YUlkZW50aXR5EjwKGm1l'
    'dGFkYXRhX3NuYXBzaG90X3JldmlzaW9uGBAgASgEUhhtZXRhZGF0YVNuYXBzaG90UmV2aXNpb2'
    '4=');

@$core.Deprecated('Use nullDescriptor instead')
const Null$json = {
  '1': 'Null',
};

/// Descriptor for `Null`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nullDescriptor = $convert.base64Decode('CgROdWxs');

@$core.Deprecated('Use temporalDescriptor instead')
const Temporal$json = {
  '1': 'Temporal',
  '2': [
    {'1': 'iso', '3': 1, '4': 1, '5': 9, '10': 'iso'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'zone', '3': 3, '4': 1, '5': 9, '10': 'zone'},
  ],
};

/// Descriptor for `Temporal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List temporalDescriptor = $convert.base64Decode(
    'CghUZW1wb3JhbBIQCgNpc28YASABKAlSA2lzbxISCgRraW5kGAIgASgJUgRraW5kEhIKBHpvbm'
    'UYAyABKAlSBHpvbmU=');

@$core.Deprecated('Use engineValueDescriptor instead')
const EngineValue$json = {
  '1': 'EngineValue',
  '2': [
    {'1': 'type_name', '3': 1, '4': 1, '5': 9, '10': 'typeName'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `EngineValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List engineValueDescriptor = $convert.base64Decode(
    'CgtFbmdpbmVWYWx1ZRIbCgl0eXBlX25hbWUYASABKAlSCHR5cGVOYW1lEhIKBHRleHQYAiABKA'
    'lSBHRleHQ=');

@$core.Deprecated('Use arrayValueDescriptor instead')
const ArrayValue$json = {
  '1': 'ArrayValue',
  '2': [
    {
      '1': 'values',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'values'
    },
    {'1': 'native_literal', '3': 2, '4': 1, '5': 9, '10': 'nativeLiteral'},
    {
      '1': 'element_native_type',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'elementNativeType'
    },
    {'1': 'native_binary', '3': 4, '4': 1, '5': 12, '10': 'nativeBinary'},
  ],
};

/// Descriptor for `ArrayValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arrayValueDescriptor = $convert.base64Decode(
    'CgpBcnJheVZhbHVlEioKBnZhbHVlcxgBIAMoCzISLmJ1c3lkYXRhLnYxLlZhbHVlUgZ2YWx1ZX'
    'MSJQoObmF0aXZlX2xpdGVyYWwYAiABKAlSDW5hdGl2ZUxpdGVyYWwSLgoTZWxlbWVudF9uYXRp'
    'dmVfdHlwZRgDIAEoCVIRZWxlbWVudE5hdGl2ZVR5cGUSIwoNbmF0aXZlX2JpbmFyeRgEIAEoDF'
    'IMbmF0aXZlQmluYXJ5');

@$core.Deprecated('Use valueDescriptor instead')
const Value$json = {
  '1': 'Value',
  '2': [
    {
      '1': 'null_value',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Null',
      '9': 0,
      '10': 'nullValue'
    },
    {'1': 'boolean', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'boolean'},
    {
      '1': 'signed_integer',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'signedInteger'
    },
    {
      '1': 'unsigned_integer',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'unsignedInteger'
    },
    {'1': 'decimal', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'decimal'},
    {'1': 'text', '3': 6, '4': 1, '5': 9, '9': 0, '10': 'text'},
    {'1': 'binary', '3': 7, '4': 1, '5': 12, '9': 0, '10': 'binary'},
    {
      '1': 'temporal',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Temporal',
      '9': 0,
      '10': 'temporal'
    },
    {'1': 'json', '3': 9, '4': 1, '5': 9, '9': 0, '10': 'json'},
    {
      '1': 'array',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ArrayValue',
      '9': 0,
      '10': 'array'
    },
    {
      '1': 'engine_value',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.EngineValue',
      '9': 0,
      '10': 'engineValue'
    },
    {'1': 'real', '3': 12, '4': 1, '5': 1, '9': 0, '10': 'real'},
    {'1': 'truncated', '3': 20, '4': 1, '5': 8, '10': 'truncated'},
    {'1': 'original_bytes', '3': 21, '4': 1, '5': 4, '10': 'originalBytes'},
    {'1': 'value_id', '3': 22, '4': 1, '5': 9, '10': 'valueId'},
  ],
  '8': [
    {'1': 'data'},
  ],
};

/// Descriptor for `Value`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List valueDescriptor = $convert.base64Decode(
    'CgVWYWx1ZRIyCgpudWxsX3ZhbHVlGAEgASgLMhEuYnVzeWRhdGEudjEuTnVsbEgAUgludWxsVm'
    'FsdWUSGgoHYm9vbGVhbhgCIAEoCEgAUgdib29sZWFuEicKDnNpZ25lZF9pbnRlZ2VyGAMgASgJ'
    'SABSDXNpZ25lZEludGVnZXISKwoQdW5zaWduZWRfaW50ZWdlchgEIAEoCUgAUg91bnNpZ25lZE'
    'ludGVnZXISGgoHZGVjaW1hbBgFIAEoCUgAUgdkZWNpbWFsEhQKBHRleHQYBiABKAlIAFIEdGV4'
    'dBIYCgZiaW5hcnkYByABKAxIAFIGYmluYXJ5EjMKCHRlbXBvcmFsGAggASgLMhUuYnVzeWRhdG'
    'EudjEuVGVtcG9yYWxIAFIIdGVtcG9yYWwSFAoEanNvbhgJIAEoCUgAUgRqc29uEi8KBWFycmF5'
    'GAogASgLMhcuYnVzeWRhdGEudjEuQXJyYXlWYWx1ZUgAUgVhcnJheRI9CgxlbmdpbmVfdmFsdW'
    'UYCyABKAsyGC5idXN5ZGF0YS52MS5FbmdpbmVWYWx1ZUgAUgtlbmdpbmVWYWx1ZRIUCgRyZWFs'
    'GAwgASgBSABSBHJlYWwSHAoJdHJ1bmNhdGVkGBQgASgIUgl0cnVuY2F0ZWQSJQoOb3JpZ2luYW'
    'xfYnl0ZXMYFSABKARSDW9yaWdpbmFsQnl0ZXMSGQoIdmFsdWVfaWQYFiABKAlSB3ZhbHVlSWRC'
    'BgoEZGF0YQ==');

@$core.Deprecated('Use valueRequestDescriptor instead')
const ValueRequest$json = {
  '1': 'ValueRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'value_id', '3': 3, '4': 1, '5': 9, '10': 'valueId'},
    {'1': 'offset', '3': 4, '4': 1, '5': 4, '10': 'offset'},
    {'1': 'max_bytes', '3': 5, '4': 1, '5': 13, '10': 'maxBytes'},
  ],
};

/// Descriptor for `ValueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List valueRequestDescriptor = $convert.base64Decode(
    'CgxWYWx1ZVJlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleHRSB2'
    'NvbnRleHQSGwoJcmVzdWx0X2lkGAIgASgJUghyZXN1bHRJZBIZCgh2YWx1ZV9pZBgDIAEoCVIH'
    'dmFsdWVJZBIWCgZvZmZzZXQYBCABKARSBm9mZnNldBIbCgltYXhfYnl0ZXMYBSABKA1SCG1heE'
    'J5dGVz');

@$core.Deprecated('Use valueChunkDescriptor instead')
const ValueChunk$json = {
  '1': 'ValueChunk',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'total_bytes', '3': 2, '4': 1, '5': 4, '10': 'totalBytes'},
    {'1': 'complete', '3': 3, '4': 1, '5': 8, '10': 'complete'},
  ],
};

/// Descriptor for `ValueChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List valueChunkDescriptor = $convert.base64Decode(
    'CgpWYWx1ZUNodW5rEhIKBGRhdGEYASABKAxSBGRhdGESHwoLdG90YWxfYnl0ZXMYAiABKARSCn'
    'RvdGFsQnl0ZXMSGgoIY29tcGxldGUYAyABKAhSCGNvbXBsZXRl');

@$core.Deprecated('Use rowDescriptor instead')
const Row$json = {
  '1': 'Row',
  '2': [
    {
      '1': 'values',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'values'
    },
  ],
};

/// Descriptor for `Row`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowDescriptor = $convert.base64Decode(
    'CgNSb3cSKgoGdmFsdWVzGAEgAygLMhIuYnVzeWRhdGEudjEuVmFsdWVSBnZhbHVlcw==');

@$core.Deprecated('Use pageRequestDescriptor instead')
const PageRequest$json = {
  '1': 'PageRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'offset', '3': 3, '4': 1, '5': 4, '10': 'offset'},
    {'1': 'limit', '3': 4, '4': 1, '5': 13, '10': 'limit'},
    {'1': 'max_bytes', '3': 5, '4': 1, '5': 13, '10': 'maxBytes'},
  ],
};

/// Descriptor for `PageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageRequestDescriptor = $convert.base64Decode(
    'CgtQYWdlUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dFIHY2'
    '9udGV4dBIbCglyZXN1bHRfaWQYAiABKAlSCHJlc3VsdElkEhYKBm9mZnNldBgDIAEoBFIGb2Zm'
    'c2V0EhQKBWxpbWl0GAQgASgNUgVsaW1pdBIbCgltYXhfYnl0ZXMYBSABKA1SCG1heEJ5dGVz');

@$core.Deprecated('Use copySqlRequestDescriptor instead')
const CopySqlRequest$json = {
  '1': 'CopySqlRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'first_row', '3': 3, '4': 1, '5': 4, '10': 'firstRow'},
    {'1': 'row_count', '3': 4, '4': 1, '5': 13, '10': 'rowCount'},
    {'1': 'first_column', '3': 5, '4': 1, '5': 13, '10': 'firstColumn'},
    {'1': 'column_count', '3': 6, '4': 1, '5': 13, '10': 'columnCount'},
  ],
};

/// Descriptor for `CopySqlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List copySqlRequestDescriptor = $convert.base64Decode(
    'Cg5Db3B5U3FsUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIbCglyZXN1bHRfaWQYAiABKAlSCHJlc3VsdElkEhsKCWZpcnN0X3JvdxgDIAEo'
    'BFIIZmlyc3RSb3cSGwoJcm93X2NvdW50GAQgASgNUghyb3dDb3VudBIhCgxmaXJzdF9jb2x1bW'
    '4YBSABKA1SC2ZpcnN0Q29sdW1uEiEKDGNvbHVtbl9jb3VudBgGIAEoDVILY29sdW1uQ291bnQ=');

@$core.Deprecated('Use copySqlReplyDescriptor instead')
const CopySqlReply$json = {
  '1': 'CopySqlReply',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `CopySqlReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List copySqlReplyDescriptor =
    $convert.base64Decode('CgxDb3B5U3FsUmVwbHkSEgoEdGV4dBgBIAEoCVIEdGV4dA==');

@$core.Deprecated('Use pageDescriptor instead')
const Page$json = {
  '1': 'Page',
  '2': [
    {
      '1': 'columns',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Column',
      '10': 'columns'
    },
    {
      '1': 'rows',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Row',
      '10': 'rows'
    },
    {'1': 'fetched_rows', '3': 3, '4': 1, '5': 4, '10': 'fetchedRows'},
    {'1': 'complete', '3': 4, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'limited', '3': 5, '4': 1, '5': 8, '10': 'limited'},
    {'1': 'first_offset', '3': 6, '4': 1, '5': 4, '10': 'firstOffset'},
    {'1': 'next_offset', '3': 7, '4': 1, '5': 4, '10': 'nextOffset'},
    {
      '1': 'state',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.PageState',
      '10': 'state'
    },
    {'1': 'availability', '3': 9, '4': 1, '5': 9, '10': 'availability'},
    {'1': 'source_rows', '3': 10, '4': 3, '5': 4, '10': 'sourceRows'},
  ],
};

/// Descriptor for `Page`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageDescriptor = $convert.base64Decode(
    'CgRQYWdlEi0KB2NvbHVtbnMYASADKAsyEy5idXN5ZGF0YS52MS5Db2x1bW5SB2NvbHVtbnMSJA'
    'oEcm93cxgCIAMoCzIQLmJ1c3lkYXRhLnYxLlJvd1IEcm93cxIhCgxmZXRjaGVkX3Jvd3MYAyAB'
    'KARSC2ZldGNoZWRSb3dzEhoKCGNvbXBsZXRlGAQgASgIUghjb21wbGV0ZRIYCgdsaW1pdGVkGA'
    'UgASgIUgdsaW1pdGVkEiEKDGZpcnN0X29mZnNldBgGIAEoBFILZmlyc3RPZmZzZXQSHwoLbmV4'
    'dF9vZmZzZXQYByABKARSCm5leHRPZmZzZXQSLAoFc3RhdGUYCCABKA4yFi5idXN5ZGF0YS52MS'
    '5QYWdlU3RhdGVSBXN0YXRlEiIKDGF2YWlsYWJpbGl0eRgJIAEoCVIMYXZhaWxhYmlsaXR5Eh8K'
    'C3NvdXJjZV9yb3dzGAogAygEUgpzb3VyY2VSb3dz');

@$core.Deprecated('Use resultViewRequestDescriptor instead')
const ResultViewRequest$json = {
  '1': 'ResultViewRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'view_id', '3': 3, '4': 1, '5': 9, '10': 'viewId'},
    {
      '1': 'conditions',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RowCondition',
      '10': 'conditions'
    },
    {
      '1': 'order',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RowOrder',
      '10': 'order'
    },
  ],
};

/// Descriptor for `ResultViewRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resultViewRequestDescriptor = $convert.base64Decode(
    'ChFSZXN1bHRWaWV3UmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udG'
    'V4dFIHY29udGV4dBIbCglyZXN1bHRfaWQYAiABKAlSCHJlc3VsdElkEhcKB3ZpZXdfaWQYAyAB'
    'KAlSBnZpZXdJZBI5Cgpjb25kaXRpb25zGAQgAygLMhkuYnVzeWRhdGEudjEuUm93Q29uZGl0aW'
    '9uUgpjb25kaXRpb25zEisKBW9yZGVyGAUgAygLMhUuYnVzeWRhdGEudjEuUm93T3JkZXJSBW9y'
    'ZGVy');

@$core.Deprecated('Use resultViewInfoDescriptor instead')
const ResultViewInfo$json = {
  '1': 'ResultViewInfo',
  '2': [
    {'1': 'view_id', '3': 1, '4': 1, '5': 9, '10': 'viewId'},
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'source_rows', '3': 3, '4': 1, '5': 4, '10': 'sourceRows'},
    {'1': 'visible_rows', '3': 4, '4': 1, '5': 4, '10': 'visibleRows'},
    {'1': 'partial', '3': 5, '4': 1, '5': 8, '10': 'partial'},
    {'1': 'availability', '3': 6, '4': 1, '5': 9, '10': 'availability'},
  ],
};

/// Descriptor for `ResultViewInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resultViewInfoDescriptor = $convert.base64Decode(
    'Cg5SZXN1bHRWaWV3SW5mbxIXCgd2aWV3X2lkGAEgASgJUgZ2aWV3SWQSGwoJcmVzdWx0X2lkGA'
    'IgASgJUghyZXN1bHRJZBIfCgtzb3VyY2Vfcm93cxgDIAEoBFIKc291cmNlUm93cxIhCgx2aXNp'
    'YmxlX3Jvd3MYBCABKARSC3Zpc2libGVSb3dzEhgKB3BhcnRpYWwYBSABKAhSB3BhcnRpYWwSIg'
    'oMYXZhaWxhYmlsaXR5GAYgASgJUgxhdmFpbGFiaWxpdHk=');

@$core.Deprecated('Use inspectionSettingDescriptor instead')
const InspectionSetting$json = {
  '1': 'InspectionSetting',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'enabled', '3': 2, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'severity', '3': 3, '4': 1, '5': 9, '10': 'severity'},
  ],
};

/// Descriptor for `InspectionSetting`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inspectionSettingDescriptor = $convert.base64Decode(
    'ChFJbnNwZWN0aW9uU2V0dGluZxISCgRjb2RlGAEgASgJUgRjb2RlEhgKB2VuYWJsZWQYAiABKA'
    'hSB2VuYWJsZWQSGgoIc2V2ZXJpdHkYAyABKAlSCHNldmVyaXR5');

@$core.Deprecated('Use formatSettingsDescriptor instead')
const FormatSettings$json = {
  '1': 'FormatSettings',
  '2': [
    {'1': 'keyword_case', '3': 1, '4': 1, '5': 9, '10': 'keywordCase'},
    {
      '1': 'indentation_width',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'indentationWidth'
    },
    {
      '1': 'continuation_indent',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'continuationIndent'
    },
    {
      '1': 'clause_line_breaks',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'clauseLineBreaks'
    },
    {'1': 'join_layout', '3': 5, '4': 1, '5': 9, '10': 'joinLayout'},
    {'1': 'comma_placement', '3': 6, '4': 1, '5': 9, '10': 'commaPlacement'},
    {
      '1': 'logical_operator_placement',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'logicalOperatorPlacement'
    },
    {'1': 'wrap_lists', '3': 8, '4': 1, '5': 8, '10': 'wrapLists'},
    {'1': 'wrap_arguments', '3': 9, '4': 1, '5': 8, '10': 'wrapArguments'},
    {
      '1': 'indent_subqueries',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'indentSubqueries'
    },
    {'1': 'cte_line_breaks', '3': 11, '4': 1, '5': 8, '10': 'cteLineBreaks'},
    {
      '1': 'parenthesis_spacing',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'parenthesisSpacing'
    },
    {'1': 'operator_spacing', '3': 13, '4': 1, '5': 8, '10': 'operatorSpacing'},
    {'1': 'alignment', '3': 14, '4': 1, '5': 8, '10': 'alignment'},
    {'1': 'max_line_length', '3': 15, '4': 1, '5': 13, '10': 'maxLineLength'},
    {
      '1': 'preserve_blank_lines',
      '3': 16,
      '4': 1,
      '5': 8,
      '10': 'preserveBlankLines'
    },
    {'1': 'start_utf16', '3': 17, '4': 1, '5': 13, '10': 'startUtf16'},
    {'1': 'end_utf16', '3': 18, '4': 1, '5': 13, '10': 'endUtf16'},
  ],
};

/// Descriptor for `FormatSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatSettingsDescriptor = $convert.base64Decode(
    'Cg5Gb3JtYXRTZXR0aW5ncxIhCgxrZXl3b3JkX2Nhc2UYASABKAlSC2tleXdvcmRDYXNlEisKEW'
    'luZGVudGF0aW9uX3dpZHRoGAIgASgNUhBpbmRlbnRhdGlvbldpZHRoEi8KE2NvbnRpbnVhdGlv'
    'bl9pbmRlbnQYAyABKA1SEmNvbnRpbnVhdGlvbkluZGVudBIsChJjbGF1c2VfbGluZV9icmVha3'
    'MYBCABKAhSEGNsYXVzZUxpbmVCcmVha3MSHwoLam9pbl9sYXlvdXQYBSABKAlSCmpvaW5MYXlv'
    'dXQSJwoPY29tbWFfcGxhY2VtZW50GAYgASgJUg5jb21tYVBsYWNlbWVudBI8Chpsb2dpY2FsX2'
    '9wZXJhdG9yX3BsYWNlbWVudBgHIAEoCVIYbG9naWNhbE9wZXJhdG9yUGxhY2VtZW50Eh0KCndy'
    'YXBfbGlzdHMYCCABKAhSCXdyYXBMaXN0cxIlCg53cmFwX2FyZ3VtZW50cxgJIAEoCFINd3JhcE'
    'FyZ3VtZW50cxIrChFpbmRlbnRfc3VicXVlcmllcxgKIAEoCFIQaW5kZW50U3VicXVlcmllcxIm'
    'Cg9jdGVfbGluZV9icmVha3MYCyABKAhSDWN0ZUxpbmVCcmVha3MSLwoTcGFyZW50aGVzaXNfc3'
    'BhY2luZxgMIAEoCFIScGFyZW50aGVzaXNTcGFjaW5nEikKEG9wZXJhdG9yX3NwYWNpbmcYDSAB'
    'KAhSD29wZXJhdG9yU3BhY2luZxIcCglhbGlnbm1lbnQYDiABKAhSCWFsaWdubWVudBImCg9tYX'
    'hfbGluZV9sZW5ndGgYDyABKA1SDW1heExpbmVMZW5ndGgSMAoUcHJlc2VydmVfYmxhbmtfbGlu'
    'ZXMYECABKAhSEnByZXNlcnZlQmxhbmtMaW5lcxIfCgtzdGFydF91dGYxNhgRIAEoDVIKc3Rhcn'
    'RVdGYxNhIbCgllbmRfdXRmMTYYEiABKA1SCGVuZFV0ZjE2');

@$core.Deprecated('Use analysisRequestDescriptor instead')
const AnalysisRequest$json = {
  '1': 'AnalysisRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'document_id', '3': 2, '4': 1, '5': 9, '10': 'documentId'},
    {'1': 'document_version', '3': 3, '4': 1, '5': 4, '10': 'documentVersion'},
    {'1': 'sql', '3': 4, '4': 1, '5': 9, '10': 'sql'},
    {'1': 'caret_utf16', '3': 5, '4': 1, '5': 13, '10': 'caretUtf16'},
    {'1': 'session_id', '3': 6, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'engine',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.Engine',
      '10': 'engine'
    },
    {'1': 'context_revision', '3': 8, '4': 1, '5': 4, '10': 'contextRevision'},
    {'1': 'session_revision', '3': 9, '4': 1, '5': 4, '10': 'sessionRevision'},
    {
      '1': 'operation',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.AnalysisOperation',
      '10': 'operation'
    },
    {
      '1': 'metadata_snapshot_revision',
      '3': 12,
      '4': 1,
      '5': 4,
      '10': 'metadataSnapshotRevision'
    },
    {
      '1': 'metadata_configuration_revision',
      '3': 13,
      '4': 1,
      '5': 4,
      '10': 'metadataConfigurationRevision'
    },
    {
      '1': 'format_settings',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.FormatSettings',
      '10': 'formatSettings'
    },
    {
      '1': 'inspections',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.InspectionSetting',
      '10': 'inspections'
    },
    {
      '1': 'format_current_statement',
      '3': 16,
      '4': 1,
      '5': 8,
      '10': 'formatCurrentStatement'
    },
    {
      '1': 'snippets',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.AnalysisRequest.SnippetsEntry',
      '10': 'snippets'
    },
  ],
  '3': [AnalysisRequest_SnippetsEntry$json],
  '9': [
    {'1': 10, '2': 11},
  ],
};

@$core.Deprecated('Use analysisRequestDescriptor instead')
const AnalysisRequest_SnippetsEntry$json = {
  '1': 'SnippetsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `AnalysisRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List analysisRequestDescriptor = $convert.base64Decode(
    'Cg9BbmFseXNpc1JlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleH'
    'RSB2NvbnRleHQSHwoLZG9jdW1lbnRfaWQYAiABKAlSCmRvY3VtZW50SWQSKQoQZG9jdW1lbnRf'
    'dmVyc2lvbhgDIAEoBFIPZG9jdW1lbnRWZXJzaW9uEhAKA3NxbBgEIAEoCVIDc3FsEh8KC2Nhcm'
    'V0X3V0ZjE2GAUgASgNUgpjYXJldFV0ZjE2Eh0KCnNlc3Npb25faWQYBiABKAlSCXNlc3Npb25J'
    'ZBIrCgZlbmdpbmUYByABKA4yEy5idXN5ZGF0YS52MS5FbmdpbmVSBmVuZ2luZRIpChBjb250ZX'
    'h0X3JldmlzaW9uGAggASgEUg9jb250ZXh0UmV2aXNpb24SKQoQc2Vzc2lvbl9yZXZpc2lvbhgJ'
    'IAEoBFIPc2Vzc2lvblJldmlzaW9uEjwKCW9wZXJhdGlvbhgLIAEoDjIeLmJ1c3lkYXRhLnYxLk'
    'FuYWx5c2lzT3BlcmF0aW9uUglvcGVyYXRpb24SPAoabWV0YWRhdGFfc25hcHNob3RfcmV2aXNp'
    'b24YDCABKARSGG1ldGFkYXRhU25hcHNob3RSZXZpc2lvbhJGCh9tZXRhZGF0YV9jb25maWd1cm'
    'F0aW9uX3JldmlzaW9uGA0gASgEUh1tZXRhZGF0YUNvbmZpZ3VyYXRpb25SZXZpc2lvbhJECg9m'
    'b3JtYXRfc2V0dGluZ3MYDiABKAsyGy5idXN5ZGF0YS52MS5Gb3JtYXRTZXR0aW5nc1IOZm9ybW'
    'F0U2V0dGluZ3MSQAoLaW5zcGVjdGlvbnMYDyADKAsyHi5idXN5ZGF0YS52MS5JbnNwZWN0aW9u'
    'U2V0dGluZ1ILaW5zcGVjdGlvbnMSOAoYZm9ybWF0X2N1cnJlbnRfc3RhdGVtZW50GBAgASgIUh'
    'Zmb3JtYXRDdXJyZW50U3RhdGVtZW50EkYKCHNuaXBwZXRzGBEgAygLMiouYnVzeWRhdGEudjEu'
    'QW5hbHlzaXNSZXF1ZXN0LlNuaXBwZXRzRW50cnlSCHNuaXBwZXRzGjsKDVNuaXBwZXRzRW50cn'
    'kSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AUoECAoQCw==');

@$core.Deprecated('Use spanDescriptor instead')
const Span$json = {
  '1': 'Span',
  '2': [
    {'1': 'start_utf16', '3': 1, '4': 1, '5': 13, '10': 'startUtf16'},
    {'1': 'end_utf16', '3': 2, '4': 1, '5': 13, '10': 'endUtf16'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'supported', '3': 4, '4': 1, '5': 8, '10': 'supported'},
  ],
};

/// Descriptor for `Span`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spanDescriptor = $convert.base64Decode(
    'CgRTcGFuEh8KC3N0YXJ0X3V0ZjE2GAEgASgNUgpzdGFydFV0ZjE2EhsKCWVuZF91dGYxNhgCIA'
    'EoDVIIZW5kVXRmMTYSEgoEdGV4dBgDIAEoCVIEdGV4dBIcCglzdXBwb3J0ZWQYBCABKAhSCXN1'
    'cHBvcnRlZA==');

@$core.Deprecated('Use diagnosticDescriptor instead')
const Diagnostic$json = {
  '1': 'Diagnostic',
  '2': [
    {'1': 'start_utf16', '3': 1, '4': 1, '5': 13, '10': 'startUtf16'},
    {'1': 'end_utf16', '3': 2, '4': 1, '5': 13, '10': 'endUtf16'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {'1': 'severity', '3': 4, '4': 1, '5': 9, '10': 'severity'},
    {'1': 'code', '3': 5, '4': 1, '5': 9, '10': 'code'},
    {'1': 'source', '3': 6, '4': 1, '5': 9, '10': 'source'},
    {'1': 'incomplete', '3': 7, '4': 1, '5': 8, '10': 'incomplete'},
    {
      '1': 'related',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Span',
      '10': 'related'
    },
    {
      '1': 'fixes',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.QuickFix',
      '10': 'fixes'
    },
    {
      '1': 'engine',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.Engine',
      '10': 'engine'
    },
  ],
};

/// Descriptor for `Diagnostic`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List diagnosticDescriptor = $convert.base64Decode(
    'CgpEaWFnbm9zdGljEh8KC3N0YXJ0X3V0ZjE2GAEgASgNUgpzdGFydFV0ZjE2EhsKCWVuZF91dG'
    'YxNhgCIAEoDVIIZW5kVXRmMTYSGAoHbWVzc2FnZRgDIAEoCVIHbWVzc2FnZRIaCghzZXZlcml0'
    'eRgEIAEoCVIIc2V2ZXJpdHkSEgoEY29kZRgFIAEoCVIEY29kZRIWCgZzb3VyY2UYBiABKAlSBn'
    'NvdXJjZRIeCgppbmNvbXBsZXRlGAcgASgIUgppbmNvbXBsZXRlEisKB3JlbGF0ZWQYCCADKAsy'
    'ES5idXN5ZGF0YS52MS5TcGFuUgdyZWxhdGVkEisKBWZpeGVzGAkgAygLMhUuYnVzeWRhdGEudj'
    'EuUXVpY2tGaXhSBWZpeGVzEisKBmVuZ2luZRgKIAEoDjITLmJ1c3lkYXRhLnYxLkVuZ2luZVIG'
    'ZW5naW5l');

@$core.Deprecated('Use quickFixDescriptor instead')
const QuickFix$json = {
  '1': 'QuickFix',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'start_utf16', '3': 2, '4': 1, '5': 13, '10': 'startUtf16'},
    {'1': 'end_utf16', '3': 3, '4': 1, '5': 13, '10': 'endUtf16'},
    {'1': 'replacement', '3': 4, '4': 1, '5': 9, '10': 'replacement'},
  ],
};

/// Descriptor for `QuickFix`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quickFixDescriptor = $convert.base64Decode(
    'CghRdWlja0ZpeBIUCgVsYWJlbBgBIAEoCVIFbGFiZWwSHwoLc3RhcnRfdXRmMTYYAiABKA1SCn'
    'N0YXJ0VXRmMTYSGwoJZW5kX3V0ZjE2GAMgASgNUghlbmRVdGYxNhIgCgtyZXBsYWNlbWVudBgE'
    'IAEoCVILcmVwbGFjZW1lbnQ=');

@$core.Deprecated('Use completionDescriptor instead')
const Completion$json = {
  '1': 'Completion',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'insert_text', '3': 2, '4': 1, '5': 9, '10': 'insertText'},
    {'1': 'kind', '3': 3, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'start_utf16', '3': 4, '4': 1, '5': 13, '10': 'startUtf16'},
    {'1': 'end_utf16', '3': 5, '4': 1, '5': 13, '10': 'endUtf16'},
    {'1': 'detail', '3': 6, '4': 1, '5': 9, '10': 'detail'},
    {'1': 'target_identity', '3': 7, '4': 1, '5': 9, '10': 'targetIdentity'},
    {'1': 'rank', '3': 8, '4': 1, '5': 17, '10': 'rank'},
    {
      '1': 'qualification_required',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'qualificationRequired'
    },
    {'1': 'quoted', '3': 10, '4': 1, '5': 8, '10': 'quoted'},
    {'1': 'documentation', '3': 11, '4': 1, '5': 9, '10': 'documentation'},
    {
      '1': 'commit_characters',
      '3': 12,
      '4': 3,
      '5': 9,
      '10': 'commitCharacters'
    },
  ],
};

/// Descriptor for `Completion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completionDescriptor = $convert.base64Decode(
    'CgpDb21wbGV0aW9uEhQKBWxhYmVsGAEgASgJUgVsYWJlbBIfCgtpbnNlcnRfdGV4dBgCIAEoCV'
    'IKaW5zZXJ0VGV4dBISCgRraW5kGAMgASgJUgRraW5kEh8KC3N0YXJ0X3V0ZjE2GAQgASgNUgpz'
    'dGFydFV0ZjE2EhsKCWVuZF91dGYxNhgFIAEoDVIIZW5kVXRmMTYSFgoGZGV0YWlsGAYgASgJUg'
    'ZkZXRhaWwSJwoPdGFyZ2V0X2lkZW50aXR5GAcgASgJUg50YXJnZXRJZGVudGl0eRISCgRyYW5r'
    'GAggASgRUgRyYW5rEjUKFnF1YWxpZmljYXRpb25fcmVxdWlyZWQYCSABKAhSFXF1YWxpZmljYX'
    'Rpb25SZXF1aXJlZBIWCgZxdW90ZWQYCiABKAhSBnF1b3RlZBIkCg1kb2N1bWVudGF0aW9uGAsg'
    'ASgJUg1kb2N1bWVudGF0aW9uEisKEWNvbW1pdF9jaGFyYWN0ZXJzGAwgAygJUhBjb21taXRDaG'
    'FyYWN0ZXJz');

@$core.Deprecated('Use formatTokenDescriptor instead')
const FormatToken$json = {
  '1': 'FormatToken',
  '2': [
    {
      '1': 'source_start_utf16',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'sourceStartUtf16'
    },
    {'1': 'source_end_utf16', '3': 2, '4': 1, '5': 13, '10': 'sourceEndUtf16'},
    {
      '1': 'formatted_start_utf16',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'formattedStartUtf16'
    },
  ],
};

/// Descriptor for `FormatToken`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List formatTokenDescriptor = $convert.base64Decode(
    'CgtGb3JtYXRUb2tlbhIsChJzb3VyY2Vfc3RhcnRfdXRmMTYYASABKA1SEHNvdXJjZVN0YXJ0VX'
    'RmMTYSKAoQc291cmNlX2VuZF91dGYxNhgCIAEoDVIOc291cmNlRW5kVXRmMTYSMgoVZm9ybWF0'
    'dGVkX3N0YXJ0X3V0ZjE2GAMgASgNUhNmb3JtYXR0ZWRTdGFydFV0ZjE2');

@$core.Deprecated('Use resolvedSymbolDescriptor instead')
const ResolvedSymbol$json = {
  '1': 'ResolvedSymbol',
  '2': [
    {
      '1': 'span',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Span',
      '10': 'span'
    },
    {
      '1': 'candidates',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.SchemaObject',
      '10': 'candidates'
    },
    {'1': 'complete', '3': 3, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'availability', '3': 4, '4': 1, '5': 9, '10': 'availability'},
    {'1': 'catalog', '3': 5, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 6, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'profile_id', '3': 7, '4': 1, '5': 9, '10': 'profileId'},
  ],
};

/// Descriptor for `ResolvedSymbol`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolvedSymbolDescriptor = $convert.base64Decode(
    'Cg5SZXNvbHZlZFN5bWJvbBIlCgRzcGFuGAEgASgLMhEuYnVzeWRhdGEudjEuU3BhblIEc3Bhbh'
    'I5CgpjYW5kaWRhdGVzGAIgAygLMhkuYnVzeWRhdGEudjEuU2NoZW1hT2JqZWN0UgpjYW5kaWRh'
    'dGVzEhoKCGNvbXBsZXRlGAMgASgIUghjb21wbGV0ZRIiCgxhdmFpbGFiaWxpdHkYBCABKAlSDG'
    'F2YWlsYWJpbGl0eRIYCgdjYXRhbG9nGAUgASgJUgdjYXRhbG9nEhYKBnNjaGVtYRgGIAEoCVIG'
    'c2NoZW1hEh0KCnByb2ZpbGVfaWQYByABKAlSCXByb2ZpbGVJZA==');

@$core.Deprecated('Use analysisDescriptor instead')
const Analysis$json = {
  '1': 'Analysis',
  '2': [
    {'1': 'document_id', '3': 1, '4': 1, '5': 9, '10': 'documentId'},
    {'1': 'document_version', '3': 2, '4': 1, '5': 4, '10': 'documentVersion'},
    {
      '1': 'statements',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Span',
      '10': 'statements'
    },
    {
      '1': 'diagnostics',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Diagnostic',
      '10': 'diagnostics'
    },
    {
      '1': 'completions',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Completion',
      '10': 'completions'
    },
    {'1': 'formatted_sql', '3': 6, '4': 1, '5': 9, '10': 'formattedSql'},
    {'1': 'backend_instance', '3': 7, '4': 1, '5': 9, '10': 'backendInstance'},
    {'1': 'session_id', '3': 8, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'context_revision', '3': 9, '4': 1, '5': 4, '10': 'contextRevision'},
    {'1': 'caret_utf16', '3': 10, '4': 1, '5': 13, '10': 'caretUtf16'},
    {'1': 'session_revision', '3': 11, '4': 1, '5': 4, '10': 'sessionRevision'},
    {
      '1': 'format_tokens',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.FormatToken',
      '10': 'formatTokens'
    },
    {
      '1': 'symbol',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ResolvedSymbol',
      '10': 'symbol'
    },
    {
      '1': 'operation',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.AnalysisOperation',
      '10': 'operation'
    },
    {
      '1': 'metadata_snapshot_revision',
      '3': 15,
      '4': 1,
      '5': 4,
      '10': 'metadataSnapshotRevision'
    },
    {
      '1': 'metadata_configuration_revision',
      '3': 16,
      '4': 1,
      '5': 4,
      '10': 'metadataConfigurationRevision'
    },
    {
      '1': 'parameter_information',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ParameterInformation',
      '10': 'parameterInformation'
    },
    {
      '1': 'ddl_effects',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.DdlEffect',
      '10': 'ddlEffects'
    },
    {'1': 'availability', '3': 19, '4': 1, '5': 9, '10': 'availability'},
    {
      '1': 'completion_limited',
      '3': 20,
      '4': 1,
      '5': 8,
      '10': 'completionLimited'
    },
    {
      '1': 'metadata_source_identity',
      '3': 21,
      '4': 1,
      '5': 9,
      '10': 'metadataSourceIdentity'
    },
  ],
};

/// Descriptor for `Analysis`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List analysisDescriptor = $convert.base64Decode(
    'CghBbmFseXNpcxIfCgtkb2N1bWVudF9pZBgBIAEoCVIKZG9jdW1lbnRJZBIpChBkb2N1bWVudF'
    '92ZXJzaW9uGAIgASgEUg9kb2N1bWVudFZlcnNpb24SMQoKc3RhdGVtZW50cxgDIAMoCzIRLmJ1'
    'c3lkYXRhLnYxLlNwYW5SCnN0YXRlbWVudHMSOQoLZGlhZ25vc3RpY3MYBCADKAsyFy5idXN5ZG'
    'F0YS52MS5EaWFnbm9zdGljUgtkaWFnbm9zdGljcxI5Cgtjb21wbGV0aW9ucxgFIAMoCzIXLmJ1'
    'c3lkYXRhLnYxLkNvbXBsZXRpb25SC2NvbXBsZXRpb25zEiMKDWZvcm1hdHRlZF9zcWwYBiABKA'
    'lSDGZvcm1hdHRlZFNxbBIpChBiYWNrZW5kX2luc3RhbmNlGAcgASgJUg9iYWNrZW5kSW5zdGFu'
    'Y2USHQoKc2Vzc2lvbl9pZBgIIAEoCVIJc2Vzc2lvbklkEikKEGNvbnRleHRfcmV2aXNpb24YCS'
    'ABKARSD2NvbnRleHRSZXZpc2lvbhIfCgtjYXJldF91dGYxNhgKIAEoDVIKY2FyZXRVdGYxNhIp'
    'ChBzZXNzaW9uX3JldmlzaW9uGAsgASgEUg9zZXNzaW9uUmV2aXNpb24SPQoNZm9ybWF0X3Rva2'
    'VucxgMIAMoCzIYLmJ1c3lkYXRhLnYxLkZvcm1hdFRva2VuUgxmb3JtYXRUb2tlbnMSMwoGc3lt'
    'Ym9sGA0gASgLMhsuYnVzeWRhdGEudjEuUmVzb2x2ZWRTeW1ib2xSBnN5bWJvbBI8CglvcGVyYX'
    'Rpb24YDiABKA4yHi5idXN5ZGF0YS52MS5BbmFseXNpc09wZXJhdGlvblIJb3BlcmF0aW9uEjwK'
    'Gm1ldGFkYXRhX3NuYXBzaG90X3JldmlzaW9uGA8gASgEUhhtZXRhZGF0YVNuYXBzaG90UmV2aX'
    'Npb24SRgofbWV0YWRhdGFfY29uZmlndXJhdGlvbl9yZXZpc2lvbhgQIAEoBFIdbWV0YWRhdGFD'
    'b25maWd1cmF0aW9uUmV2aXNpb24SVgoVcGFyYW1ldGVyX2luZm9ybWF0aW9uGBEgASgLMiEuYn'
    'VzeWRhdGEudjEuUGFyYW1ldGVySW5mb3JtYXRpb25SFHBhcmFtZXRlckluZm9ybWF0aW9uEjcK'
    'C2RkbF9lZmZlY3RzGBIgAygLMhYuYnVzeWRhdGEudjEuRGRsRWZmZWN0UgpkZGxFZmZlY3RzEi'
    'IKDGF2YWlsYWJpbGl0eRgTIAEoCVIMYXZhaWxhYmlsaXR5Ei0KEmNvbXBsZXRpb25fbGltaXRl'
    'ZBgUIAEoCFIRY29tcGxldGlvbkxpbWl0ZWQSOAoYbWV0YWRhdGFfc291cmNlX2lkZW50aXR5GB'
    'UgASgJUhZtZXRhZGF0YVNvdXJjZUlkZW50aXR5');

@$core.Deprecated('Use routineParameterDescriptor instead')
const RoutineParameter$json = {
  '1': 'RoutineParameter',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'mode', '3': 2, '4': 1, '5': 9, '10': 'mode'},
    {'1': 'native_type', '3': 3, '4': 1, '5': 9, '10': 'nativeType'},
    {'1': 'optional', '3': 4, '4': 1, '5': 8, '10': 'optional'},
    {'1': 'variadic', '3': 5, '4': 1, '5': 8, '10': 'variadic'},
    {
      '1': 'default_expression',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'defaultExpression'
    },
  ],
};

/// Descriptor for `RoutineParameter`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routineParameterDescriptor = $convert.base64Decode(
    'ChBSb3V0aW5lUGFyYW1ldGVyEhIKBG5hbWUYASABKAlSBG5hbWUSEgoEbW9kZRgCIAEoCVIEbW'
    '9kZRIfCgtuYXRpdmVfdHlwZRgDIAEoCVIKbmF0aXZlVHlwZRIaCghvcHRpb25hbBgEIAEoCFII'
    'b3B0aW9uYWwSGgoIdmFyaWFkaWMYBSABKAhSCHZhcmlhZGljEi0KEmRlZmF1bHRfZXhwcmVzc2'
    'lvbhgGIAEoCVIRZGVmYXVsdEV4cHJlc3Npb24=');

@$core.Deprecated('Use routineSignatureDescriptor instead')
const RoutineSignature$json = {
  '1': 'RoutineSignature',
  '2': [
    {'1': 'identity', '3': 1, '4': 1, '5': 9, '10': 'identity'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'signature', '3': 3, '4': 1, '5': 9, '10': 'signature'},
    {
      '1': 'parameters',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RoutineParameter',
      '10': 'parameters'
    },
    {'1': 'return_type', '3': 5, '4': 1, '5': 9, '10': 'returnType'},
  ],
};

/// Descriptor for `RoutineSignature`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routineSignatureDescriptor = $convert.base64Decode(
    'ChBSb3V0aW5lU2lnbmF0dXJlEhoKCGlkZW50aXR5GAEgASgJUghpZGVudGl0eRISCgRuYW1lGA'
    'IgASgJUgRuYW1lEhwKCXNpZ25hdHVyZRgDIAEoCVIJc2lnbmF0dXJlEj0KCnBhcmFtZXRlcnMY'
    'BCADKAsyHS5idXN5ZGF0YS52MS5Sb3V0aW5lUGFyYW1ldGVyUgpwYXJhbWV0ZXJzEh8KC3JldH'
    'Vybl90eXBlGAUgASgJUgpyZXR1cm5UeXBl');

@$core.Deprecated('Use parameterInformationDescriptor instead')
const ParameterInformation$json = {
  '1': 'ParameterInformation',
  '2': [
    {'1': 'start_utf16', '3': 1, '4': 1, '5': 13, '10': 'startUtf16'},
    {'1': 'end_utf16', '3': 2, '4': 1, '5': 13, '10': 'endUtf16'},
    {'1': 'active_argument', '3': 3, '4': 1, '5': 13, '10': 'activeArgument'},
    {
      '1': 'overloads',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RoutineSignature',
      '10': 'overloads'
    },
    {'1': 'availability', '3': 5, '4': 1, '5': 9, '10': 'availability'},
  ],
};

/// Descriptor for `ParameterInformation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parameterInformationDescriptor = $convert.base64Decode(
    'ChRQYXJhbWV0ZXJJbmZvcm1hdGlvbhIfCgtzdGFydF91dGYxNhgBIAEoDVIKc3RhcnRVdGYxNh'
    'IbCgllbmRfdXRmMTYYAiABKA1SCGVuZFV0ZjE2EicKD2FjdGl2ZV9hcmd1bWVudBgDIAEoDVIO'
    'YWN0aXZlQXJndW1lbnQSOwoJb3ZlcmxvYWRzGAQgAygLMh0uYnVzeWRhdGEudjEuUm91dGluZV'
    'NpZ25hdHVyZVIJb3ZlcmxvYWRzEiIKDGF2YWlsYWJpbGl0eRgFIAEoCVIMYXZhaWxhYmlsaXR5');

@$core.Deprecated('Use ddlEffectDescriptor instead')
const DdlEffect$json = {
  '1': 'DdlEffect',
  '2': [
    {'1': 'operation', '3': 1, '4': 1, '5': 9, '10': 'operation'},
    {'1': 'catalog', '3': 2, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 3, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'kind',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kind'
    },
    {'1': 'temporary', '3': 6, '4': 1, '5': 8, '10': 'temporary'},
    {'1': 'conservative', '3': 7, '4': 1, '5': 8, '10': 'conservative'},
  ],
};

/// Descriptor for `DdlEffect`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ddlEffectDescriptor = $convert.base64Decode(
    'CglEZGxFZmZlY3QSHAoJb3BlcmF0aW9uGAEgASgJUglvcGVyYXRpb24SGAoHY2F0YWxvZxgCIA'
    'EoCVIHY2F0YWxvZxIWCgZzY2hlbWEYAyABKAlSBnNjaGVtYRISCgRuYW1lGAQgASgJUgRuYW1l'
    'EisKBGtpbmQYBSABKA4yFy5idXN5ZGF0YS52MS5PYmplY3RLaW5kUgRraW5kEhwKCXRlbXBvcm'
    'FyeRgGIAEoCFIJdGVtcG9yYXJ5EiIKDGNvbnNlcnZhdGl2ZRgHIAEoCFIMY29uc2VydmF0aXZl');

@$core.Deprecated('Use exploreRequestDescriptor instead')
const ExploreRequest$json = {
  '1': 'ExploreRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'kind',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kind'
    },
    {'1': 'catalog', '3': 4, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 5, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 6, '4': 1, '5': 9, '10': 'table'},
    {'1': 'search', '3': 7, '4': 1, '5': 9, '10': 'search'},
    {'1': 'refresh', '3': 8, '4': 1, '5': 8, '10': 'refresh'},
    {'1': 'global_search', '3': 9, '4': 1, '5': 8, '10': 'globalSearch'},
    {'1': 'continuation', '3': 10, '4': 1, '5': 9, '10': 'continuation'},
    {'1': 'limit', '3': 11, '4': 1, '5': 13, '10': 'limit'},
    {
      '1': 'expected_session_revision',
      '3': 12,
      '4': 1,
      '5': 4,
      '9': 0,
      '10': 'expectedSessionRevision',
      '17': true
    },
    {
      '1': 'expected_context_revision',
      '3': 13,
      '4': 1,
      '5': 4,
      '9': 1,
      '10': 'expectedContextRevision',
      '17': true
    },
    {'1': 'exact_name', '3': 14, '4': 1, '5': 8, '10': 'exactName'},
    {'1': 'identifier', '3': 15, '4': 1, '5': 9, '10': 'identifier'},
    {
      '1': 'subtype',
      '3': 16,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectSubtype',
      '10': 'subtype'
    },
    {
      '1': 'independent_metadata',
      '3': 17,
      '4': 1,
      '5': 8,
      '10': 'independentMetadata'
    },
    {
      '1': 'introspection_level',
      '3': 18,
      '4': 1,
      '5': 13,
      '10': 'introspectionLevel'
    },
    {'1': 'refresh_mode', '3': 19, '4': 1, '5': 9, '10': 'refreshMode'},
  ],
  '8': [
    {'1': '_expected_session_revision'},
    {'1': '_expected_context_revision'},
  ],
};

/// Descriptor for `ExploreRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exploreRequestDescriptor = $convert.base64Decode(
    'Cg5FeHBsb3JlUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSKwoEa2luZBgDIAEoDjIX'
    'LmJ1c3lkYXRhLnYxLk9iamVjdEtpbmRSBGtpbmQSGAoHY2F0YWxvZxgEIAEoCVIHY2F0YWxvZx'
    'IWCgZzY2hlbWEYBSABKAlSBnNjaGVtYRIUCgV0YWJsZRgGIAEoCVIFdGFibGUSFgoGc2VhcmNo'
    'GAcgASgJUgZzZWFyY2gSGAoHcmVmcmVzaBgIIAEoCFIHcmVmcmVzaBIjCg1nbG9iYWxfc2Vhcm'
    'NoGAkgASgIUgxnbG9iYWxTZWFyY2gSIgoMY29udGludWF0aW9uGAogASgJUgxjb250aW51YXRp'
    'b24SFAoFbGltaXQYCyABKA1SBWxpbWl0Ej8KGWV4cGVjdGVkX3Nlc3Npb25fcmV2aXNpb24YDC'
    'ABKARIAFIXZXhwZWN0ZWRTZXNzaW9uUmV2aXNpb26IAQESPwoZZXhwZWN0ZWRfY29udGV4dF9y'
    'ZXZpc2lvbhgNIAEoBEgBUhdleHBlY3RlZENvbnRleHRSZXZpc2lvbogBARIdCgpleGFjdF9uYW'
    '1lGA4gASgIUglleGFjdE5hbWUSHgoKaWRlbnRpZmllchgPIAEoCVIKaWRlbnRpZmllchI0Cgdz'
    'dWJ0eXBlGBAgASgOMhouYnVzeWRhdGEudjEuT2JqZWN0U3VidHlwZVIHc3VidHlwZRIxChRpbm'
    'RlcGVuZGVudF9tZXRhZGF0YRgRIAEoCFITaW5kZXBlbmRlbnRNZXRhZGF0YRIvChNpbnRyb3Nw'
    'ZWN0aW9uX2xldmVsGBIgASgNUhJpbnRyb3NwZWN0aW9uTGV2ZWwSIQoMcmVmcmVzaF9tb2RlGB'
    'MgASgJUgtyZWZyZXNoTW9kZUIcChpfZXhwZWN0ZWRfc2Vzc2lvbl9yZXZpc2lvbkIcChpfZXhw'
    'ZWN0ZWRfY29udGV4dF9yZXZpc2lvbg==');

@$core.Deprecated('Use schemaObjectDescriptor instead')
const SchemaObject$json = {
  '1': 'SchemaObject',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kind'
    },
    {'1': 'catalog', '3': 3, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 4, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 5, '4': 1, '5': 9, '10': 'table'},
    {'1': 'definition', '3': 6, '4': 1, '5': 9, '10': 'definition'},
    {
      '1': 'properties',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.SchemaObject.PropertiesEntry',
      '10': 'properties'
    },
    {'1': 'identifier', '3': 8, '4': 1, '5': 9, '10': 'identifier'},
    {
      '1': 'subtype',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectSubtype',
      '10': 'subtype'
    },
    {'1': 'stable_identity', '3': 10, '4': 1, '5': 9, '10': 'stableIdentity'},
    {
      '1': 'quoted_identifier',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'quotedIdentifier'
    },
    {
      '1': 'normalized_identifier',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'normalizedIdentifier'
    },
    {'1': 'parent_identity', '3': 13, '4': 1, '5': 9, '10': 'parentIdentity'},
    {
      '1': 'metadata_snapshot_revision',
      '3': 14,
      '4': 1,
      '5': 4,
      '10': 'metadataSnapshotRevision'
    },
    {
      '1': 'introspection_level',
      '3': 15,
      '4': 1,
      '5': 13,
      '10': 'introspectionLevel'
    },
    {'1': 'metadata_state', '3': 16, '4': 1, '5': 9, '10': 'metadataState'},
    {'1': 'source_revision', '3': 17, '4': 1, '5': 9, '10': 'sourceRevision'},
  ],
  '3': [SchemaObject_PropertiesEntry$json],
};

@$core.Deprecated('Use schemaObjectDescriptor instead')
const SchemaObject_PropertiesEntry$json = {
  '1': 'PropertiesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SchemaObject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaObjectDescriptor = $convert.base64Decode(
    'CgxTY2hlbWFPYmplY3QSEgoEbmFtZRgBIAEoCVIEbmFtZRIrCgRraW5kGAIgASgOMhcuYnVzeW'
    'RhdGEudjEuT2JqZWN0S2luZFIEa2luZBIYCgdjYXRhbG9nGAMgASgJUgdjYXRhbG9nEhYKBnNj'
    'aGVtYRgEIAEoCVIGc2NoZW1hEhQKBXRhYmxlGAUgASgJUgV0YWJsZRIeCgpkZWZpbml0aW9uGA'
    'YgASgJUgpkZWZpbml0aW9uEkkKCnByb3BlcnRpZXMYByADKAsyKS5idXN5ZGF0YS52MS5TY2hl'
    'bWFPYmplY3QuUHJvcGVydGllc0VudHJ5Ugpwcm9wZXJ0aWVzEh4KCmlkZW50aWZpZXIYCCABKA'
    'lSCmlkZW50aWZpZXISNAoHc3VidHlwZRgJIAEoDjIaLmJ1c3lkYXRhLnYxLk9iamVjdFN1YnR5'
    'cGVSB3N1YnR5cGUSJwoPc3RhYmxlX2lkZW50aXR5GAogASgJUg5zdGFibGVJZGVudGl0eRIrCh'
    'FxdW90ZWRfaWRlbnRpZmllchgLIAEoCVIQcXVvdGVkSWRlbnRpZmllchIzChVub3JtYWxpemVk'
    'X2lkZW50aWZpZXIYDCABKAlSFG5vcm1hbGl6ZWRJZGVudGlmaWVyEicKD3BhcmVudF9pZGVudG'
    'l0eRgNIAEoCVIOcGFyZW50SWRlbnRpdHkSPAoabWV0YWRhdGFfc25hcHNob3RfcmV2aXNpb24Y'
    'DiABKARSGG1ldGFkYXRhU25hcHNob3RSZXZpc2lvbhIvChNpbnRyb3NwZWN0aW9uX2xldmVsGA'
    '8gASgNUhJpbnRyb3NwZWN0aW9uTGV2ZWwSJQoObWV0YWRhdGFfc3RhdGUYECABKAlSDW1ldGFk'
    'YXRhU3RhdGUSJwoPc291cmNlX3JldmlzaW9uGBEgASgJUg5zb3VyY2VSZXZpc2lvbho9Cg9Qcm'
    '9wZXJ0aWVzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4'
    'AQ==');

@$core.Deprecated('Use schemaObjectsDescriptor instead')
const SchemaObjects$json = {
  '1': 'SchemaObjects',
  '2': [
    {
      '1': 'objects',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.SchemaObject',
      '10': 'objects'
    },
    {'1': 'availability', '3': 2, '4': 1, '5': 9, '10': 'availability'},
    {'1': 'continuation', '3': 3, '4': 1, '5': 9, '10': 'continuation'},
    {'1': 'complete', '3': 4, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'context_revision', '3': 5, '4': 1, '5': 4, '10': 'contextRevision'},
    {'1': 'session_revision', '3': 6, '4': 1, '5': 4, '10': 'sessionRevision'},
    {'1': 'profile_id', '3': 7, '4': 1, '5': 9, '10': 'profileId'},
    {'1': 'session_id', '3': 8, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'instance_id', '3': 9, '4': 1, '5': 9, '10': 'instanceId'},
    {'1': 'catalog', '3': 10, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 11, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'parent', '3': 12, '4': 1, '5': 9, '10': 'parent'},
    {
      '1': 'kind',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kind'
    },
    {
      '1': 'count_availability',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.MetadataCount',
      '10': 'countAvailability'
    },
    {
      '1': 'total_count',
      '3': 15,
      '4': 1,
      '5': 4,
      '9': 0,
      '10': 'totalCount',
      '17': true
    },
    {
      '1': 'default_namespace',
      '3': 16,
      '4': 1,
      '5': 9,
      '10': 'defaultNamespace'
    },
    {
      '1': 'subtype',
      '3': 17,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectSubtype',
      '10': 'subtype'
    },
    {
      '1': 'metadata_snapshot_revision',
      '3': 18,
      '4': 1,
      '5': 4,
      '10': 'metadataSnapshotRevision'
    },
    {
      '1': 'metadata_configuration_revision',
      '3': 19,
      '4': 1,
      '5': 4,
      '10': 'metadataConfigurationRevision'
    },
    {
      '1': 'introspection_level',
      '3': 20,
      '4': 1,
      '5': 13,
      '10': 'introspectionLevel'
    },
    {'1': 'metadata_state', '3': 21, '4': 1, '5': 9, '10': 'metadataState'},
    {
      '1': 'metadata_source_identity',
      '3': 22,
      '4': 1,
      '5': 9,
      '10': 'metadataSourceIdentity'
    },
  ],
  '8': [
    {'1': '_total_count'},
  ],
};

/// Descriptor for `SchemaObjects`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaObjectsDescriptor = $convert.base64Decode(
    'Cg1TY2hlbWFPYmplY3RzEjMKB29iamVjdHMYASADKAsyGS5idXN5ZGF0YS52MS5TY2hlbWFPYm'
    'plY3RSB29iamVjdHMSIgoMYXZhaWxhYmlsaXR5GAIgASgJUgxhdmFpbGFiaWxpdHkSIgoMY29u'
    'dGludWF0aW9uGAMgASgJUgxjb250aW51YXRpb24SGgoIY29tcGxldGUYBCABKAhSCGNvbXBsZX'
    'RlEikKEGNvbnRleHRfcmV2aXNpb24YBSABKARSD2NvbnRleHRSZXZpc2lvbhIpChBzZXNzaW9u'
    'X3JldmlzaW9uGAYgASgEUg9zZXNzaW9uUmV2aXNpb24SHQoKcHJvZmlsZV9pZBgHIAEoCVIJcH'
    'JvZmlsZUlkEh0KCnNlc3Npb25faWQYCCABKAlSCXNlc3Npb25JZBIfCgtpbnN0YW5jZV9pZBgJ'
    'IAEoCVIKaW5zdGFuY2VJZBIYCgdjYXRhbG9nGAogASgJUgdjYXRhbG9nEhYKBnNjaGVtYRgLIA'
    'EoCVIGc2NoZW1hEhYKBnBhcmVudBgMIAEoCVIGcGFyZW50EisKBGtpbmQYDSABKA4yFy5idXN5'
    'ZGF0YS52MS5PYmplY3RLaW5kUgRraW5kEkkKEmNvdW50X2F2YWlsYWJpbGl0eRgOIAEoDjIaLm'
    'J1c3lkYXRhLnYxLk1ldGFkYXRhQ291bnRSEWNvdW50QXZhaWxhYmlsaXR5EiQKC3RvdGFsX2Nv'
    'dW50GA8gASgESABSCnRvdGFsQ291bnSIAQESKwoRZGVmYXVsdF9uYW1lc3BhY2UYECABKAlSEG'
    'RlZmF1bHROYW1lc3BhY2USNAoHc3VidHlwZRgRIAEoDjIaLmJ1c3lkYXRhLnYxLk9iamVjdFN1'
    'YnR5cGVSB3N1YnR5cGUSPAoabWV0YWRhdGFfc25hcHNob3RfcmV2aXNpb24YEiABKARSGG1ldG'
    'FkYXRhU25hcHNob3RSZXZpc2lvbhJGCh9tZXRhZGF0YV9jb25maWd1cmF0aW9uX3JldmlzaW9u'
    'GBMgASgEUh1tZXRhZGF0YUNvbmZpZ3VyYXRpb25SZXZpc2lvbhIvChNpbnRyb3NwZWN0aW9uX2'
    'xldmVsGBQgASgNUhJpbnRyb3NwZWN0aW9uTGV2ZWwSJQoObWV0YWRhdGFfc3RhdGUYFSABKAlS'
    'DW1ldGFkYXRhU3RhdGUSOAoYbWV0YWRhdGFfc291cmNlX2lkZW50aXR5GBYgASgJUhZtZXRhZG'
    'F0YVNvdXJjZUlkZW50aXR5Qg4KDF90b3RhbF9jb3VudA==');

@$core.Deprecated('Use schemaToolRequestDescriptor instead')
const SchemaToolRequest$json = {
  '1': 'SchemaToolRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'action',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.SchemaToolAction',
      '10': 'action'
    },
    {'1': 'schema', '3': 4, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 5, '4': 1, '5': 9, '10': 'table'},
    {'1': 'source_snapshot', '3': 6, '4': 1, '5': 9, '10': 'sourceSnapshot'},
    {'1': 'target_snapshot', '3': 7, '4': 1, '5': 9, '10': 'targetSnapshot'},
    {'1': 'column', '3': 8, '4': 1, '5': 9, '10': 'column'},
    {'1': 'type', '3': 9, '4': 1, '5': 9, '10': 'type'},
    {'1': 'nullable', '3': 10, '4': 1, '5': 8, '10': 'nullable'},
    {'1': 'operation', '3': 11, '4': 1, '5': 9, '10': 'operation'},
    {'1': 'property', '3': 12, '4': 1, '5': 9, '10': 'property'},
    {'1': 'value', '3': 13, '4': 1, '5': 9, '10': 'value'},
    {'1': 'object_name', '3': 14, '4': 1, '5': 9, '10': 'objectName'},
    {'1': 'object_columns', '3': 15, '4': 3, '5': 9, '10': 'objectColumns'},
    {'1': 'unique', '3': 16, '4': 1, '5': 8, '10': 'unique'},
    {'1': 'reference_schema', '3': 17, '4': 1, '5': 9, '10': 'referenceSchema'},
    {'1': 'reference_table', '3': 18, '4': 1, '5': 9, '10': 'referenceTable'},
    {
      '1': 'reference_columns',
      '3': 19,
      '4': 3,
      '5': 9,
      '10': 'referenceColumns'
    },
    {'1': 'expression', '3': 20, '4': 1, '5': 9, '10': 'expression'},
    {'1': 'definition', '3': 21, '4': 1, '5': 9, '10': 'definition'},
    {'1': 'object_kind', '3': 22, '4': 1, '5': 9, '10': 'objectKind'},
    {
      '1': 'designed_columns',
      '3': 23,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.DesignedColumn',
      '10': 'designedColumns'
    },
    {'1': 'on_delete', '3': 24, '4': 1, '5': 9, '10': 'onDelete'},
    {'1': 'on_update', '3': 25, '4': 1, '5': 9, '10': 'onUpdate'},
    {'1': 'deferrable', '3': 26, '4': 1, '5': 8, '10': 'deferrable'},
    {
      '1': 'initially_deferred',
      '3': 27,
      '4': 1,
      '5': 8,
      '10': 'initiallyDeferred'
    },
    {'1': 'catalog', '3': 28, '4': 1, '5': 9, '10': 'catalog'},
    {
      '1': 'kind',
      '3': 29,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kind'
    },
    {'1': 'identifier', '3': 30, '4': 1, '5': 9, '10': 'identifier'},
  ],
};

/// Descriptor for `SchemaToolRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaToolRequestDescriptor = $convert.base64Decode(
    'ChFTY2hlbWFUb29sUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udG'
    'V4dFIHY29udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSNQoGYWN0aW9uGAMg'
    'ASgOMh0uYnVzeWRhdGEudjEuU2NoZW1hVG9vbEFjdGlvblIGYWN0aW9uEhYKBnNjaGVtYRgEIA'
    'EoCVIGc2NoZW1hEhQKBXRhYmxlGAUgASgJUgV0YWJsZRInCg9zb3VyY2Vfc25hcHNob3QYBiAB'
    'KAlSDnNvdXJjZVNuYXBzaG90EicKD3RhcmdldF9zbmFwc2hvdBgHIAEoCVIOdGFyZ2V0U25hcH'
    'Nob3QSFgoGY29sdW1uGAggASgJUgZjb2x1bW4SEgoEdHlwZRgJIAEoCVIEdHlwZRIaCghudWxs'
    'YWJsZRgKIAEoCFIIbnVsbGFibGUSHAoJb3BlcmF0aW9uGAsgASgJUglvcGVyYXRpb24SGgoIcH'
    'JvcGVydHkYDCABKAlSCHByb3BlcnR5EhQKBXZhbHVlGA0gASgJUgV2YWx1ZRIfCgtvYmplY3Rf'
    'bmFtZRgOIAEoCVIKb2JqZWN0TmFtZRIlCg5vYmplY3RfY29sdW1ucxgPIAMoCVINb2JqZWN0Q2'
    '9sdW1ucxIWCgZ1bmlxdWUYECABKAhSBnVuaXF1ZRIpChByZWZlcmVuY2Vfc2NoZW1hGBEgASgJ'
    'Ug9yZWZlcmVuY2VTY2hlbWESJwoPcmVmZXJlbmNlX3RhYmxlGBIgASgJUg5yZWZlcmVuY2VUYW'
    'JsZRIrChFyZWZlcmVuY2VfY29sdW1ucxgTIAMoCVIQcmVmZXJlbmNlQ29sdW1ucxIeCgpleHBy'
    'ZXNzaW9uGBQgASgJUgpleHByZXNzaW9uEh4KCmRlZmluaXRpb24YFSABKAlSCmRlZmluaXRpb2'
    '4SHwoLb2JqZWN0X2tpbmQYFiABKAlSCm9iamVjdEtpbmQSRgoQZGVzaWduZWRfY29sdW1ucxgX'
    'IAMoCzIbLmJ1c3lkYXRhLnYxLkRlc2lnbmVkQ29sdW1uUg9kZXNpZ25lZENvbHVtbnMSGwoJb2'
    '5fZGVsZXRlGBggASgJUghvbkRlbGV0ZRIbCglvbl91cGRhdGUYGSABKAlSCG9uVXBkYXRlEh4K'
    'CmRlZmVycmFibGUYGiABKAhSCmRlZmVycmFibGUSLQoSaW5pdGlhbGx5X2RlZmVycmVkGBsgAS'
    'gIUhFpbml0aWFsbHlEZWZlcnJlZBIYCgdjYXRhbG9nGBwgASgJUgdjYXRhbG9nEisKBGtpbmQY'
    'HSABKA4yFy5idXN5ZGF0YS52MS5PYmplY3RLaW5kUgRraW5kEh4KCmlkZW50aWZpZXIYHiABKA'
    'lSCmlkZW50aWZpZXI=');

@$core.Deprecated('Use designedColumnDescriptor instead')
const DesignedColumn$json = {
  '1': 'DesignedColumn',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 2, '4': 1, '5': 9, '10': 'type'},
    {'1': 'nullable', '3': 3, '4': 1, '5': 8, '10': 'nullable'},
    {
      '1': 'default_expression',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'defaultExpression'
    },
    {'1': 'identity', '3': 5, '4': 1, '5': 9, '10': 'identity'},
    {
      '1': 'generated_expression',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'generatedExpression'
    },
    {'1': 'comment', '3': 7, '4': 1, '5': 9, '10': 'comment'},
    {'1': 'collation', '3': 8, '4': 1, '5': 9, '10': 'collation'},
  ],
};

/// Descriptor for `DesignedColumn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List designedColumnDescriptor = $convert.base64Decode(
    'Cg5EZXNpZ25lZENvbHVtbhISCgRuYW1lGAEgASgJUgRuYW1lEhIKBHR5cGUYAiABKAlSBHR5cG'
    'USGgoIbnVsbGFibGUYAyABKAhSCG51bGxhYmxlEi0KEmRlZmF1bHRfZXhwcmVzc2lvbhgEIAEo'
    'CVIRZGVmYXVsdEV4cHJlc3Npb24SGgoIaWRlbnRpdHkYBSABKAlSCGlkZW50aXR5EjEKFGdlbm'
    'VyYXRlZF9leHByZXNzaW9uGAYgASgJUhNnZW5lcmF0ZWRFeHByZXNzaW9uEhgKB2NvbW1lbnQY'
    'ByABKAlSB2NvbW1lbnQSHAoJY29sbGF0aW9uGAggASgJUgljb2xsYXRpb24=');

@$core.Deprecated('Use schemaDifferenceDescriptor instead')
const SchemaDifference$json = {
  '1': 'SchemaDifference',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'state', '3': 3, '4': 1, '5': 9, '10': 'state'},
    {
      '1': 'before_definition',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'beforeDefinition'
    },
    {'1': 'after_definition', '3': 5, '4': 1, '5': 9, '10': 'afterDefinition'},
    {
      '1': 'presentation_limited',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'presentationLimited'
    },
  ],
};

/// Descriptor for `SchemaDifference`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaDifferenceDescriptor = $convert.base64Decode(
    'ChBTY2hlbWFEaWZmZXJlbmNlEhIKBGtpbmQYASABKAlSBGtpbmQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRIUCgVzdGF0ZRgDIAEoCVIFc3RhdGUSKwoRYmVmb3JlX2RlZmluaXRpb24YBCABKAlSEGJl'
    'Zm9yZURlZmluaXRpb24SKQoQYWZ0ZXJfZGVmaW5pdGlvbhgFIAEoCVIPYWZ0ZXJEZWZpbml0aW'
    '9uEjEKFHByZXNlbnRhdGlvbl9saW1pdGVkGAYgASgIUhNwcmVzZW50YXRpb25MaW1pdGVk');

@$core.Deprecated('Use schemaToolResultDescriptor instead')
const SchemaToolResult$json = {
  '1': 'SchemaToolResult',
  '2': [
    {'1': 'snapshot', '3': 1, '4': 1, '5': 9, '10': 'snapshot'},
    {'1': 'sql', '3': 2, '4': 3, '5': 9, '10': 'sql'},
    {'1': 'risks', '3': 3, '4': 3, '5': 9, '10': 'risks'},
    {'1': 'unsupported', '3': 4, '4': 3, '5': 9, '10': 'unsupported'},
    {'1': 'definition', '3': 5, '4': 1, '5': 9, '10': 'definition'},
    {'1': 'complete', '3': 6, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'equivalent', '3': 7, '4': 1, '5': 8, '10': 'equivalent'},
    {'1': 'dependencies', '3': 8, '4': 3, '5': 9, '10': 'dependencies'},
    {
      '1': 'differences',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.SchemaDifference',
      '10': 'differences'
    },
    {
      '1': 'differences_limited',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'differencesLimited'
    },
    {
      '1': 'inspected_object',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.SchemaObject',
      '10': 'inspectedObject'
    },
    {'1': 'provenance', '3': 12, '4': 1, '5': 9, '10': 'provenance'},
  ],
};

/// Descriptor for `SchemaToolResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaToolResultDescriptor = $convert.base64Decode(
    'ChBTY2hlbWFUb29sUmVzdWx0EhoKCHNuYXBzaG90GAEgASgJUghzbmFwc2hvdBIQCgNzcWwYAi'
    'ADKAlSA3NxbBIUCgVyaXNrcxgDIAMoCVIFcmlza3MSIAoLdW5zdXBwb3J0ZWQYBCADKAlSC3Vu'
    'c3VwcG9ydGVkEh4KCmRlZmluaXRpb24YBSABKAlSCmRlZmluaXRpb24SGgoIY29tcGxldGUYBi'
    'ABKAhSCGNvbXBsZXRlEh4KCmVxdWl2YWxlbnQYByABKAhSCmVxdWl2YWxlbnQSIgoMZGVwZW5k'
    'ZW5jaWVzGAggAygJUgxkZXBlbmRlbmNpZXMSPwoLZGlmZmVyZW5jZXMYCSADKAsyHS5idXN5ZG'
    'F0YS52MS5TY2hlbWFEaWZmZXJlbmNlUgtkaWZmZXJlbmNlcxIvChNkaWZmZXJlbmNlc19saW1p'
    'dGVkGAogASgIUhJkaWZmZXJlbmNlc0xpbWl0ZWQSRAoQaW5zcGVjdGVkX29iamVjdBgLIAEoCz'
    'IZLmJ1c3lkYXRhLnYxLlNjaGVtYU9iamVjdFIPaW5zcGVjdGVkT2JqZWN0Eh4KCnByb3ZlbmFu'
    'Y2UYDCABKAlSCnByb3ZlbmFuY2U=');

@$core.Deprecated('Use authenticationRequestDescriptor instead')
const AuthenticationRequest$json = {
  '1': 'AuthenticationRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {
      '1': 'action',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.AuthenticationAction',
      '10': 'action'
    },
    {
      '1': 'principal',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Principal',
      '10': 'principal'
    },
    {'1': 'password', '3': 6, '4': 1, '5': 9, '10': 'password'},
    {'1': 'approval_token', '3': 7, '4': 1, '5': 9, '10': 'approvalToken'},
  ],
};

/// Descriptor for `AuthenticationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authenticationRequestDescriptor = $convert.base64Decode(
    'ChVBdXRoZW50aWNhdGlvblJlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLk'
    'NvbnRleHRSB2NvbnRleHQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2lvbklkEiEKDGV4ZWN1'
    'dGlvbl9pZBgDIAEoCVILZXhlY3V0aW9uSWQSOQoGYWN0aW9uGAQgASgOMiEuYnVzeWRhdGEudj'
    'EuQXV0aGVudGljYXRpb25BY3Rpb25SBmFjdGlvbhI0CglwcmluY2lwYWwYBSABKAsyFi5idXN5'
    'ZGF0YS52MS5QcmluY2lwYWxSCXByaW5jaXBhbBIaCghwYXNzd29yZBgGIAEoCVIIcGFzc3dvcm'
    'QSJQoOYXBwcm92YWxfdG9rZW4YByABKAlSDWFwcHJvdmFsVG9rZW4=');

@$core.Deprecated('Use principalDescriptor instead')
const Principal$json = {
  '1': 'Principal',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'host', '3': 2, '4': 1, '5': 9, '10': 'host'},
    {'1': 'kind', '3': 3, '4': 1, '5': 9, '10': 'kind'},
  ],
};

/// Descriptor for `Principal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List principalDescriptor = $convert.base64Decode(
    'CglQcmluY2lwYWwSEgoEbmFtZRgBIAEoCVIEbmFtZRISCgRob3N0GAIgASgJUgRob3N0EhIKBG'
    'tpbmQYAyABKAlSBGtpbmQ=');

@$core.Deprecated('Use privilegeRequestDescriptor instead')
const PrivilegeRequest$json = {
  '1': 'PrivilegeRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'action',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.PrivilegeAction',
      '10': 'action'
    },
    {
      '1': 'grantee',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Principal',
      '10': 'grantee'
    },
    {
      '1': 'scope',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.PrivilegeScope',
      '10': 'scope'
    },
    {'1': 'schema', '3': 6, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 7, '4': 1, '5': 9, '10': 'table'},
    {'1': 'privileges', '3': 8, '4': 3, '5': 9, '10': 'privileges'},
    {'1': 'revoke', '3': 9, '4': 1, '5': 8, '10': 'revoke'},
    {'1': 'delegation', '3': 10, '4': 1, '5': 8, '10': 'delegation'},
    {
      '1': 'role',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Principal',
      '10': 'role'
    },
    {'1': 'search', '3': 12, '4': 1, '5': 9, '10': 'search'},
  ],
};

/// Descriptor for `PrivilegeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List privilegeRequestDescriptor = $convert.base64Decode(
    'ChBQcml2aWxlZ2VSZXF1ZXN0Ei4KB2NvbnRleHQYASABKAsyFC5idXN5ZGF0YS52MS5Db250ZX'
    'h0Ugdjb250ZXh0Eh0KCnNlc3Npb25faWQYAiABKAlSCXNlc3Npb25JZBI0CgZhY3Rpb24YAyAB'
    'KA4yHC5idXN5ZGF0YS52MS5Qcml2aWxlZ2VBY3Rpb25SBmFjdGlvbhIwCgdncmFudGVlGAQgAS'
    'gLMhYuYnVzeWRhdGEudjEuUHJpbmNpcGFsUgdncmFudGVlEjEKBXNjb3BlGAUgASgOMhsuYnVz'
    'eWRhdGEudjEuUHJpdmlsZWdlU2NvcGVSBXNjb3BlEhYKBnNjaGVtYRgGIAEoCVIGc2NoZW1hEh'
    'QKBXRhYmxlGAcgASgJUgV0YWJsZRIeCgpwcml2aWxlZ2VzGAggAygJUgpwcml2aWxlZ2VzEhYK'
    'BnJldm9rZRgJIAEoCFIGcmV2b2tlEh4KCmRlbGVnYXRpb24YCiABKAhSCmRlbGVnYXRpb24SKg'
    'oEcm9sZRgLIAEoCzIWLmJ1c3lkYXRhLnYxLlByaW5jaXBhbFIEcm9sZRIWCgZzZWFyY2gYDCAB'
    'KAlSBnNlYXJjaA==');

@$core.Deprecated('Use privilegeReplyDescriptor instead')
const PrivilegeReply$json = {
  '1': 'PrivilegeReply',
  '2': [
    {
      '1': 'principals',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Principal',
      '10': 'principals'
    },
    {'1': 'definition', '3': 2, '4': 1, '5': 9, '10': 'definition'},
    {'1': 'sql', '3': 3, '4': 3, '5': 9, '10': 'sql'},
    {'1': 'risks', '3': 4, '4': 3, '5': 9, '10': 'risks'},
    {'1': 'limited', '3': 5, '4': 1, '5': 8, '10': 'limited'},
  ],
};

/// Descriptor for `PrivilegeReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List privilegeReplyDescriptor = $convert.base64Decode(
    'Cg5Qcml2aWxlZ2VSZXBseRI2CgpwcmluY2lwYWxzGAEgAygLMhYuYnVzeWRhdGEudjEuUHJpbm'
    'NpcGFsUgpwcmluY2lwYWxzEh4KCmRlZmluaXRpb24YAiABKAlSCmRlZmluaXRpb24SEAoDc3Fs'
    'GAMgAygJUgNzcWwSFAoFcmlza3MYBCADKAlSBXJpc2tzEhgKB2xpbWl0ZWQYBSABKAhSB2xpbW'
    'l0ZWQ=');

@$core.Deprecated('Use defaultValueDescriptor instead')
const DefaultValue$json = {
  '1': 'DefaultValue',
};

/// Descriptor for `DefaultValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List defaultValueDescriptor =
    $convert.base64Decode('CgxEZWZhdWx0VmFsdWU=');

@$core.Deprecated('Use valueAssignmentDescriptor instead')
const ValueAssignment$json = {
  '1': 'ValueAssignment',
  '2': [
    {
      '1': 'value',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Value',
      '9': 0,
      '10': 'value'
    },
    {
      '1': 'null_value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Null',
      '9': 0,
      '10': 'nullValue'
    },
    {
      '1': 'default_value',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.DefaultValue',
      '9': 0,
      '10': 'defaultValue'
    },
  ],
  '8': [
    {'1': 'assignment'},
  ],
};

/// Descriptor for `ValueAssignment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List valueAssignmentDescriptor = $convert.base64Decode(
    'Cg9WYWx1ZUFzc2lnbm1lbnQSKgoFdmFsdWUYASABKAsyEi5idXN5ZGF0YS52MS5WYWx1ZUgAUg'
    'V2YWx1ZRIyCgpudWxsX3ZhbHVlGAIgASgLMhEuYnVzeWRhdGEudjEuTnVsbEgAUgludWxsVmFs'
    'dWUSQAoNZGVmYXVsdF92YWx1ZRgDIAEoCzIZLmJ1c3lkYXRhLnYxLkRlZmF1bHRWYWx1ZUgAUg'
    'xkZWZhdWx0VmFsdWVCDAoKYXNzaWdubWVudA==');

@$core.Deprecated('Use stagedChangeDescriptor instead')
const StagedChange$json = {
  '1': 'StagedChange',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ChangeKind',
      '10': 'kind'
    },
    {'1': 'source_row', '3': 4, '4': 1, '5': 4, '10': 'sourceRow'},
    {
      '1': 'values',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.StagedChange.ValuesEntry',
      '10': 'values'
    },
  ],
  '3': [StagedChange_ValuesEntry$json],
  '9': [
    {'1': 2, '2': 3},
    {'1': 3, '2': 4},
  ],
};

@$core.Deprecated('Use stagedChangeDescriptor instead')
const StagedChange_ValuesEntry$json = {
  '1': 'ValuesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 13, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ValueAssignment',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `StagedChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stagedChangeDescriptor = $convert.base64Decode(
    'CgxTdGFnZWRDaGFuZ2USKwoEa2luZBgBIAEoDjIXLmJ1c3lkYXRhLnYxLkNoYW5nZUtpbmRSBG'
    'tpbmQSHQoKc291cmNlX3JvdxgEIAEoBFIJc291cmNlUm93Ej0KBnZhbHVlcxgFIAMoCzIlLmJ1'
    'c3lkYXRhLnYxLlN0YWdlZENoYW5nZS5WYWx1ZXNFbnRyeVIGdmFsdWVzGlcKC1ZhbHVlc0VudH'
    'J5EhAKA2tleRgBIAEoDVIDa2V5EjIKBXZhbHVlGAIgASgLMhwuYnVzeWRhdGEudjEuVmFsdWVB'
    'c3NpZ25tZW50UgV2YWx1ZToCOAFKBAgCEANKBAgDEAQ=');

@$core.Deprecated('Use changeRequestDescriptor instead')
const ChangeRequest$json = {
  '1': 'ChangeRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'catalog', '3': 3, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 4, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 5, '4': 1, '5': 9, '10': 'table'},
    {
      '1': 'changes',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.StagedChange',
      '10': 'changes'
    },
    {'1': 'result_id', '3': 7, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'recovery_id', '3': 8, '4': 1, '5': 9, '10': 'recoveryId'},
  ],
};

/// Descriptor for `ChangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List changeRequestDescriptor = $convert.base64Decode(
    'Cg1DaGFuZ2VSZXF1ZXN0Ei4KB2NvbnRleHQYASABKAsyFC5idXN5ZGF0YS52MS5Db250ZXh0Ug'
    'djb250ZXh0Eh0KCnNlc3Npb25faWQYAiABKAlSCXNlc3Npb25JZBIYCgdjYXRhbG9nGAMgASgJ'
    'UgdjYXRhbG9nEhYKBnNjaGVtYRgEIAEoCVIGc2NoZW1hEhQKBXRhYmxlGAUgASgJUgV0YWJsZR'
    'IzCgdjaGFuZ2VzGAYgAygLMhkuYnVzeWRhdGEudjEuU3RhZ2VkQ2hhbmdlUgdjaGFuZ2VzEhsK'
    'CXJlc3VsdF9pZBgHIAEoCVIIcmVzdWx0SWQSHwoLcmVjb3ZlcnlfaWQYCCABKAlSCnJlY292ZX'
    'J5SWQ=');

@$core.Deprecated('Use reviewedChangeDescriptor instead')
const ReviewedChange$json = {
  '1': 'ReviewedChange',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ChangeKind',
      '10': 'kind'
    },
    {
      '1': 'values',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.ReviewedChange.ValuesEntry',
      '10': 'values'
    },
    {
      '1': 'original',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.ReviewedChange.OriginalEntry',
      '10': 'original'
    },
    {'1': 'source_row', '3': 4, '4': 1, '5': 4, '10': 'sourceRow'},
  ],
  '3': [ReviewedChange_ValuesEntry$json, ReviewedChange_OriginalEntry$json],
};

@$core.Deprecated('Use reviewedChangeDescriptor instead')
const ReviewedChange_ValuesEntry$json = {
  '1': 'ValuesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ValueAssignment',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use reviewedChangeDescriptor instead')
const ReviewedChange_OriginalEntry$json = {
  '1': 'OriginalEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `ReviewedChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reviewedChangeDescriptor = $convert.base64Decode(
    'Cg5SZXZpZXdlZENoYW5nZRIrCgRraW5kGAEgASgOMhcuYnVzeWRhdGEudjEuQ2hhbmdlS2luZF'
    'IEa2luZBI/CgZ2YWx1ZXMYAiADKAsyJy5idXN5ZGF0YS52MS5SZXZpZXdlZENoYW5nZS5WYWx1'
    'ZXNFbnRyeVIGdmFsdWVzEkUKCG9yaWdpbmFsGAMgAygLMikuYnVzeWRhdGEudjEuUmV2aWV3ZW'
    'RDaGFuZ2UuT3JpZ2luYWxFbnRyeVIIb3JpZ2luYWwSHQoKc291cmNlX3JvdxgEIAEoBFIJc291'
    'cmNlUm93GlcKC1ZhbHVlc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EjIKBXZhbHVlGAIgASgLMh'
    'wuYnVzeWRhdGEudjEuVmFsdWVBc3NpZ25tZW50UgV2YWx1ZToCOAEaTwoNT3JpZ2luYWxFbnRy'
    'eRIQCgNrZXkYASABKAlSA2tleRIoCgV2YWx1ZRgCIAEoCzISLmJ1c3lkYXRhLnYxLlZhbHVlUg'
    'V2YWx1ZToCOAE=');

@$core.Deprecated('Use changePlanDescriptor instead')
const ChangePlan$json = {
  '1': 'ChangePlan',
  '2': [
    {'1': 'plan_id', '3': 1, '4': 1, '5': 9, '10': 'planId'},
    {'1': 'sql', '3': 2, '4': 3, '5': 9, '10': 'sql'},
    {'1': 'risks', '3': 3, '4': 3, '5': 9, '10': 'risks'},
    {'1': 'expires_unix_ms', '3': 4, '4': 1, '5': 4, '10': 'expiresUnixMs'},
    {
      '1': 'changes',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.ReviewedChange',
      '10': 'changes'
    },
    {
      '1': 'target',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'target'
    },
  ],
};

/// Descriptor for `ChangePlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List changePlanDescriptor = $convert.base64Decode(
    'CgpDaGFuZ2VQbGFuEhcKB3BsYW5faWQYASABKAlSBnBsYW5JZBIQCgNzcWwYAiADKAlSA3NxbB'
    'IUCgVyaXNrcxgDIAMoCVIFcmlza3MSJgoPZXhwaXJlc191bml4X21zGAQgASgEUg1leHBpcmVz'
    'VW5peE1zEjUKB2NoYW5nZXMYBSADKAsyGy5idXN5ZGF0YS52MS5SZXZpZXdlZENoYW5nZVIHY2'
    'hhbmdlcxIsCgZ0YXJnZXQYBiABKAsyFC5idXN5ZGF0YS52MS5Qcm9maWxlUgZ0YXJnZXQ=');

@$core.Deprecated('Use editabilityDescriptor instead')
const Editability$json = {
  '1': 'Editability',
  '2': [
    {'1': 'editable', '3': 1, '4': 1, '5': 8, '10': 'editable'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'editable_columns', '3': 3, '4': 3, '5': 13, '10': 'editableColumns'},
    {'1': 'reason_code', '3': 4, '4': 1, '5': 9, '10': 'reasonCode'},
  ],
};

/// Descriptor for `Editability`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editabilityDescriptor = $convert.base64Decode(
    'CgtFZGl0YWJpbGl0eRIaCghlZGl0YWJsZRgBIAEoCFIIZWRpdGFibGUSFgoGcmVhc29uGAIgAS'
    'gJUgZyZWFzb24SKQoQZWRpdGFibGVfY29sdW1ucxgDIAMoDVIPZWRpdGFibGVDb2x1bW5zEh8K'
    'C3JlYXNvbl9jb2RlGAQgASgJUgpyZWFzb25Db2Rl');

@$core.Deprecated('Use applyRequestDescriptor instead')
const ApplyRequest$json = {
  '1': 'ApplyRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {'1': 'plan_id', '3': 4, '4': 1, '5': 9, '10': 'planId'},
  ],
};

/// Descriptor for `ApplyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List applyRequestDescriptor = $convert.base64Decode(
    'CgxBcHBseVJlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleHRSB2'
    'NvbnRleHQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2lvbklkEiEKDGV4ZWN1dGlvbl9pZBgD'
    'IAEoCVILZXhlY3V0aW9uSWQSFwoHcGxhbl9pZBgEIAEoCVIGcGxhbklk');

@$core.Deprecated('Use toolRequestDescriptor instead')
const ToolRequest$json = {
  '1': 'ToolRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'execution_id', '3': 3, '4': 1, '5': 9, '10': 'executionId'},
    {
      '1': 'kind',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ToolKind',
      '10': 'kind'
    },
    {'1': 'sql', '3': 5, '4': 1, '5': 9, '10': 'sql'},
    {'1': 'schema', '3': 6, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 7, '4': 1, '5': 9, '10': 'table'},
    {'1': 'path', '3': 8, '4': 1, '5': 9, '10': 'path'},
    {'1': 'format', '3': 9, '4': 1, '5': 9, '10': 'format'},
    {'1': 'result_id', '3': 10, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'approval_token', '3': 11, '4': 1, '5': 9, '10': 'approvalToken'},
    {'1': 'overwrite', '3': 12, '4': 1, '5': 8, '10': 'overwrite'},
    {'1': 'columns', '3': 13, '4': 3, '5': 9, '10': 'columns'},
    {'1': 'null_marker', '3': 14, '4': 1, '5': 9, '10': 'nullMarker'},
    {'1': 'encoding', '3': 15, '4': 1, '5': 9, '10': 'encoding'},
    {'1': 'native_tool_path', '3': 16, '4': 1, '5': 9, '10': 'nativeToolPath'},
    {'1': 'value_id', '3': 17, '4': 1, '5': 9, '10': 'valueId'},
    {'1': 'target_id', '3': 18, '4': 1, '5': 4, '10': 'targetId'},
    {
      '1': 'column_mapping',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.ToolRequest.ColumnMappingEntry',
      '10': 'columnMapping'
    },
    {'1': 'source_sha256', '3': 20, '4': 1, '5': 9, '10': 'sourceSha256'},
    {'1': 'delimiter', '3': 21, '4': 1, '5': 9, '10': 'delimiter'},
    {
      '1': 'import_policy',
      '3': 22,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ImportPolicy',
      '10': 'importPolicy'
    },
    {'1': 'batch_rows', '3': 23, '4': 1, '5': 13, '10': 'batchRows'},
    {'1': 'error_limit', '3': 24, '4': 1, '5': 13, '10': 'errorLimit'},
    {
      '1': 'output_limit_bytes',
      '3': 25,
      '4': 1,
      '5': 4,
      '10': 'outputLimitBytes'
    },
    {
      '1': 'activity_fingerprint',
      '3': 26,
      '4': 1,
      '5': 9,
      '10': 'activityFingerprint'
    },
  ],
  '3': [ToolRequest_ColumnMappingEntry$json],
};

@$core.Deprecated('Use toolRequestDescriptor instead')
const ToolRequest_ColumnMappingEntry$json = {
  '1': 'ColumnMappingEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ToolRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toolRequestDescriptor = $convert.base64Decode(
    'CgtUb29sUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dFIHY2'
    '9udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSIQoMZXhlY3V0aW9uX2lkGAMg'
    'ASgJUgtleGVjdXRpb25JZBIpCgRraW5kGAQgASgOMhUuYnVzeWRhdGEudjEuVG9vbEtpbmRSBG'
    'tpbmQSEAoDc3FsGAUgASgJUgNzcWwSFgoGc2NoZW1hGAYgASgJUgZzY2hlbWESFAoFdGFibGUY'
    'ByABKAlSBXRhYmxlEhIKBHBhdGgYCCABKAlSBHBhdGgSFgoGZm9ybWF0GAkgASgJUgZmb3JtYX'
    'QSGwoJcmVzdWx0X2lkGAogASgJUghyZXN1bHRJZBIlCg5hcHByb3ZhbF90b2tlbhgLIAEoCVIN'
    'YXBwcm92YWxUb2tlbhIcCglvdmVyd3JpdGUYDCABKAhSCW92ZXJ3cml0ZRIYCgdjb2x1bW5zGA'
    '0gAygJUgdjb2x1bW5zEh8KC251bGxfbWFya2VyGA4gASgJUgpudWxsTWFya2VyEhoKCGVuY29k'
    'aW5nGA8gASgJUghlbmNvZGluZxIoChBuYXRpdmVfdG9vbF9wYXRoGBAgASgJUg5uYXRpdmVUb2'
    '9sUGF0aBIZCgh2YWx1ZV9pZBgRIAEoCVIHdmFsdWVJZBIbCgl0YXJnZXRfaWQYEiABKARSCHRh'
    'cmdldElkElIKDmNvbHVtbl9tYXBwaW5nGBMgAygLMisuYnVzeWRhdGEudjEuVG9vbFJlcXVlc3'
    'QuQ29sdW1uTWFwcGluZ0VudHJ5Ug1jb2x1bW5NYXBwaW5nEiMKDXNvdXJjZV9zaGEyNTYYFCAB'
    'KAlSDHNvdXJjZVNoYTI1NhIcCglkZWxpbWl0ZXIYFSABKAlSCWRlbGltaXRlchI+Cg1pbXBvcn'
    'RfcG9saWN5GBYgASgOMhkuYnVzeWRhdGEudjEuSW1wb3J0UG9saWN5UgxpbXBvcnRQb2xpY3kS'
    'HQoKYmF0Y2hfcm93cxgXIAEoDVIJYmF0Y2hSb3dzEh8KC2Vycm9yX2xpbWl0GBggASgNUgplcn'
    'JvckxpbWl0EiwKEm91dHB1dF9saW1pdF9ieXRlcxgZIAEoBFIQb3V0cHV0TGltaXRCeXRlcxIx'
    'ChRhY3Rpdml0eV9maW5nZXJwcmludBgaIAEoCVITYWN0aXZpdHlGaW5nZXJwcmludBpAChJDb2'
    'x1bW5NYXBwaW5nRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVl'
    'OgI4AQ==');

@$core.Deprecated('Use activityRequestDescriptor instead')
const ActivityRequest$json = {
  '1': 'ActivityRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `ActivityRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityRequestDescriptor = $convert.base64Decode(
    'Cg9BY3Rpdml0eVJlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleH'
    'RSB2NvbnRleHQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2lvbklk');

@$core.Deprecated('Use activityDescriptor instead')
const Activity$json = {
  '1': 'Activity',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'principal', '3': 2, '4': 1, '5': 9, '10': 'principal'},
    {'1': 'database', '3': 3, '4': 1, '5': 9, '10': 'database'},
    {'1': 'state', '3': 4, '4': 1, '5': 9, '10': 'state'},
    {'1': 'query_preview', '3': 5, '4': 1, '5': 9, '10': 'queryPreview'},
    {'1': 'fingerprint', '3': 6, '4': 1, '5': 9, '10': 'fingerprint'},
    {'1': 'blockers', '3': 7, '4': 3, '5': 4, '10': 'blockers'},
    {'1': 'wait', '3': 8, '4': 1, '5': 9, '10': 'wait'},
    {'1': 'cancellable', '3': 9, '4': 1, '5': 8, '10': 'cancellable'},
  ],
};

/// Descriptor for `Activity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityDescriptor = $convert.base64Decode(
    'CghBY3Rpdml0eRIOCgJpZBgBIAEoBFICaWQSHAoJcHJpbmNpcGFsGAIgASgJUglwcmluY2lwYW'
    'wSGgoIZGF0YWJhc2UYAyABKAlSCGRhdGFiYXNlEhQKBXN0YXRlGAQgASgJUgVzdGF0ZRIjCg1x'
    'dWVyeV9wcmV2aWV3GAUgASgJUgxxdWVyeVByZXZpZXcSIAoLZmluZ2VycHJpbnQYBiABKAlSC2'
    'ZpbmdlcnByaW50EhoKCGJsb2NrZXJzGAcgAygEUghibG9ja2VycxISCgR3YWl0GAggASgJUgR3'
    'YWl0EiAKC2NhbmNlbGxhYmxlGAkgASgIUgtjYW5jZWxsYWJsZQ==');

@$core.Deprecated('Use activityListDescriptor instead')
const ActivityList$json = {
  '1': 'ActivityList',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Activity',
      '10': 'entries'
    },
    {'1': 'limited', '3': 2, '4': 1, '5': 8, '10': 'limited'},
    {'1': 'availability', '3': 3, '4': 1, '5': 9, '10': 'availability'},
  ],
};

/// Descriptor for `ActivityList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityListDescriptor = $convert.base64Decode(
    'CgxBY3Rpdml0eUxpc3QSLwoHZW50cmllcxgBIAMoCzIVLmJ1c3lkYXRhLnYxLkFjdGl2aXR5Ug'
    'dlbnRyaWVzEhgKB2xpbWl0ZWQYAiABKAhSB2xpbWl0ZWQSIgoMYXZhaWxhYmlsaXR5GAMgASgJ'
    'UgxhdmFpbGFiaWxpdHk=');

@$core.Deprecated('Use importPreviewDescriptor instead')
const ImportPreview$json = {
  '1': 'ImportPreview',
  '2': [
    {'1': 'source_columns', '3': 1, '4': 3, '5': 9, '10': 'sourceColumns'},
    {
      '1': 'rows',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Row',
      '10': 'rows'
    },
    {'1': 'limited', '3': 3, '4': 1, '5': 8, '10': 'limited'},
    {'1': 'encoding', '3': 4, '4': 1, '5': 9, '10': 'encoding'},
    {'1': 'null_marker', '3': 5, '4': 1, '5': 9, '10': 'nullMarker'},
    {'1': 'warnings', '3': 6, '4': 3, '5': 9, '10': 'warnings'},
    {'1': 'source_sha256', '3': 7, '4': 1, '5': 9, '10': 'sourceSha256'},
  ],
};

/// Descriptor for `ImportPreview`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importPreviewDescriptor = $convert.base64Decode(
    'Cg1JbXBvcnRQcmV2aWV3EiUKDnNvdXJjZV9jb2x1bW5zGAEgAygJUg1zb3VyY2VDb2x1bW5zEi'
    'QKBHJvd3MYAiADKAsyEC5idXN5ZGF0YS52MS5Sb3dSBHJvd3MSGAoHbGltaXRlZBgDIAEoCFIH'
    'bGltaXRlZBIaCghlbmNvZGluZxgEIAEoCVIIZW5jb2RpbmcSHwoLbnVsbF9tYXJrZXIYBSABKA'
    'lSCm51bGxNYXJrZXISGgoId2FybmluZ3MYBiADKAlSCHdhcm5pbmdzEiMKDXNvdXJjZV9zaGEy'
    'NTYYByABKAlSDHNvdXJjZVNoYTI1Ng==');

@$core.Deprecated('Use historyRequestDescriptor instead')
const HistoryRequest$json = {
  '1': 'HistoryRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {
      '1': 'action',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.HistoryAction',
      '10': 'action'
    },
    {'1': 'search', '3': 3, '4': 1, '5': 9, '10': 'search'},
    {'1': 'retain_sql', '3': 4, '4': 1, '5': 8, '10': 'retainSql'},
    {'1': 'retention_days', '3': 5, '4': 1, '5': 13, '10': 'retentionDays'},
    {'1': 'entry_id', '3': 6, '4': 1, '5': 9, '10': 'entryId'},
    {'1': 'offset', '3': 7, '4': 1, '5': 13, '10': 'offset'},
    {'1': 'limit', '3': 8, '4': 1, '5': 13, '10': 'limit'},
  ],
};

/// Descriptor for `HistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyRequestDescriptor = $convert.base64Decode(
    'Cg5IaXN0b3J5UmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udGV4dF'
    'IHY29udGV4dBIyCgZhY3Rpb24YAiABKA4yGi5idXN5ZGF0YS52MS5IaXN0b3J5QWN0aW9uUgZh'
    'Y3Rpb24SFgoGc2VhcmNoGAMgASgJUgZzZWFyY2gSHQoKcmV0YWluX3NxbBgEIAEoCFIJcmV0YW'
    'luU3FsEiUKDnJldGVudGlvbl9kYXlzGAUgASgNUg1yZXRlbnRpb25EYXlzEhkKCGVudHJ5X2lk'
    'GAYgASgJUgdlbnRyeUlkEhYKBm9mZnNldBgHIAEoDVIGb2Zmc2V0EhQKBWxpbWl0GAggASgNUg'
    'VsaW1pdA==');

@$core.Deprecated('Use historyEntryDescriptor instead')
const HistoryEntry$json = {
  '1': 'HistoryEntry',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'target', '3': 2, '4': 1, '5': 9, '10': 'target'},
    {'1': 'sql', '3': 3, '4': 1, '5': 9, '10': 'sql'},
    {
      '1': 'state',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.JobState',
      '10': 'state'
    },
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 4, '10': 'durationMs'},
    {'1': 'started_unix_ms', '3': 6, '4': 1, '5': 4, '10': 'startedUnixMs'},
    {'1': 'sql_truncated', '3': 7, '4': 1, '5': 8, '10': 'sqlTruncated'},
  ],
};

/// Descriptor for `HistoryEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyEntryDescriptor = $convert.base64Decode(
    'CgxIaXN0b3J5RW50cnkSDgoCaWQYASABKAlSAmlkEhYKBnRhcmdldBgCIAEoCVIGdGFyZ2V0Eh'
    'AKA3NxbBgDIAEoCVIDc3FsEisKBXN0YXRlGAQgASgOMhUuYnVzeWRhdGEudjEuSm9iU3RhdGVS'
    'BXN0YXRlEh8KC2R1cmF0aW9uX21zGAUgASgEUgpkdXJhdGlvbk1zEiYKD3N0YXJ0ZWRfdW5peF'
    '9tcxgGIAEoBFINc3RhcnRlZFVuaXhNcxIjCg1zcWxfdHJ1bmNhdGVkGAcgASgIUgxzcWxUcnVu'
    'Y2F0ZWQ=');

@$core.Deprecated('Use historyListDescriptor instead')
const HistoryList$json = {
  '1': 'HistoryList',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.HistoryEntry',
      '10': 'entries'
    },
    {'1': 'retain_sql', '3': 2, '4': 1, '5': 8, '10': 'retainSql'},
    {'1': 'retention_days', '3': 3, '4': 1, '5': 13, '10': 'retentionDays'},
    {'1': 'limited', '3': 4, '4': 1, '5': 8, '10': 'limited'},
    {'1': 'next_offset', '3': 5, '4': 1, '5': 13, '10': 'nextOffset'},
  ],
};

/// Descriptor for `HistoryList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyListDescriptor = $convert.base64Decode(
    'CgtIaXN0b3J5TGlzdBIzCgdlbnRyaWVzGAEgAygLMhkuYnVzeWRhdGEudjEuSGlzdG9yeUVudH'
    'J5UgdlbnRyaWVzEh0KCnJldGFpbl9zcWwYAiABKAhSCXJldGFpblNxbBIlCg5yZXRlbnRpb25f'
    'ZGF5cxgDIAEoDVINcmV0ZW50aW9uRGF5cxIYCgdsaW1pdGVkGAQgASgIUgdsaW1pdGVkEh8KC2'
    '5leHRfb2Zmc2V0GAUgASgNUgpuZXh0T2Zmc2V0');

@$core.Deprecated('Use historySqlRequestDescriptor instead')
const HistorySqlRequest$json = {
  '1': 'HistorySqlRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'entry_id', '3': 2, '4': 1, '5': 9, '10': 'entryId'},
    {'1': 'offset_utf16', '3': 3, '4': 1, '5': 13, '10': 'offsetUtf16'},
    {'1': 'max_units', '3': 4, '4': 1, '5': 13, '10': 'maxUnits'},
  ],
};

/// Descriptor for `HistorySqlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historySqlRequestDescriptor = $convert.base64Decode(
    'ChFIaXN0b3J5U3FsUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudjEuQ29udG'
    'V4dFIHY29udGV4dBIZCghlbnRyeV9pZBgCIAEoCVIHZW50cnlJZBIhCgxvZmZzZXRfdXRmMTYY'
    'AyABKA1SC29mZnNldFV0ZjE2EhsKCW1heF91bml0cxgEIAEoDVIIbWF4VW5pdHM=');

@$core.Deprecated('Use historySqlChunkDescriptor instead')
const HistorySqlChunk$json = {
  '1': 'HistorySqlChunk',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'total_units', '3': 2, '4': 1, '5': 13, '10': 'totalUnits'},
    {
      '1': 'next_offset_utf16',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'nextOffsetUtf16'
    },
    {'1': 'complete', '3': 4, '4': 1, '5': 8, '10': 'complete'},
  ],
};

/// Descriptor for `HistorySqlChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historySqlChunkDescriptor = $convert.base64Decode(
    'Cg9IaXN0b3J5U3FsQ2h1bmsSEgoEdGV4dBgBIAEoCVIEdGV4dBIfCgt0b3RhbF91bml0cxgCIA'
    'EoDVIKdG90YWxVbml0cxIqChFuZXh0X29mZnNldF91dGYxNhgDIAEoDVIPbmV4dE9mZnNldFV0'
    'ZjE2EhoKCGNvbXBsZXRlGAQgASgIUghjb21wbGV0ZQ==');

@$core.Deprecated('Use editDraftRequestDescriptor instead')
const EditDraftRequest$json = {
  '1': 'EditDraftRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {
      '1': 'action',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.EditDraftAction',
      '10': 'action'
    },
    {'1': 'draft_id', '3': 3, '4': 1, '5': 9, '10': 'draftId'},
    {'1': 'session_id', '3': 4, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'document_id', '3': 5, '4': 1, '5': 9, '10': 'documentId'},
    {
      '1': 'changes',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ChangeRequest',
      '10': 'changes'
    },
  ],
};

/// Descriptor for `EditDraftRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editDraftRequestDescriptor = $convert.base64Decode(
    'ChBFZGl0RHJhZnRSZXF1ZXN0Ei4KB2NvbnRleHQYASABKAsyFC5idXN5ZGF0YS52MS5Db250ZX'
    'h0Ugdjb250ZXh0EjQKBmFjdGlvbhgCIAEoDjIcLmJ1c3lkYXRhLnYxLkVkaXREcmFmdEFjdGlv'
    'blIGYWN0aW9uEhkKCGRyYWZ0X2lkGAMgASgJUgdkcmFmdElkEh0KCnNlc3Npb25faWQYBCABKA'
    'lSCXNlc3Npb25JZBIfCgtkb2N1bWVudF9pZBgFIAEoCVIKZG9jdW1lbnRJZBI0CgdjaGFuZ2Vz'
    'GAYgASgLMhouYnVzeWRhdGEudjEuQ2hhbmdlUmVxdWVzdFIHY2hhbmdlcw==');

@$core.Deprecated('Use editDraftInfoDescriptor instead')
const EditDraftInfo$json = {
  '1': 'EditDraftInfo',
  '2': [
    {'1': 'draft_id', '3': 1, '4': 1, '5': 9, '10': 'draftId'},
    {'1': 'document_id', '3': 2, '4': 1, '5': 9, '10': 'documentId'},
    {
      '1': 'target',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'target'
    },
    {'1': 'schema', '3': 4, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 5, '4': 1, '5': 9, '10': 'table'},
    {'1': 'changes', '3': 6, '4': 1, '5': 13, '10': 'changes'},
    {'1': 'state', '3': 7, '4': 1, '5': 9, '10': 'state'},
    {'1': 'created_unix_ms', '3': 8, '4': 1, '5': 4, '10': 'createdUnixMs'},
  ],
};

/// Descriptor for `EditDraftInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editDraftInfoDescriptor = $convert.base64Decode(
    'Cg1FZGl0RHJhZnRJbmZvEhkKCGRyYWZ0X2lkGAEgASgJUgdkcmFmdElkEh8KC2RvY3VtZW50X2'
    'lkGAIgASgJUgpkb2N1bWVudElkEiwKBnRhcmdldBgDIAEoCzIULmJ1c3lkYXRhLnYxLlByb2Zp'
    'bGVSBnRhcmdldBIWCgZzY2hlbWEYBCABKAlSBnNjaGVtYRIUCgV0YWJsZRgFIAEoCVIFdGFibG'
    'USGAoHY2hhbmdlcxgGIAEoDVIHY2hhbmdlcxIUCgVzdGF0ZRgHIAEoCVIFc3RhdGUSJgoPY3Jl'
    'YXRlZF91bml4X21zGAggASgEUg1jcmVhdGVkVW5peE1z');

@$core.Deprecated('Use editDraftReplyDescriptor instead')
const EditDraftReply$json = {
  '1': 'EditDraftReply',
  '2': [
    {
      '1': 'drafts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.EditDraftInfo',
      '10': 'drafts'
    },
    {
      '1': 'changes',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ChangeRequest',
      '10': 'changes'
    },
    {
      '1': 'result',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.RetainedResult',
      '10': 'result'
    },
  ],
};

/// Descriptor for `EditDraftReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editDraftReplyDescriptor = $convert.base64Decode(
    'Cg5FZGl0RHJhZnRSZXBseRIyCgZkcmFmdHMYASADKAsyGi5idXN5ZGF0YS52MS5FZGl0RHJhZn'
    'RJbmZvUgZkcmFmdHMSNAoHY2hhbmdlcxgCIAEoCzIaLmJ1c3lkYXRhLnYxLkNoYW5nZVJlcXVl'
    'c3RSB2NoYW5nZXMSMwoGcmVzdWx0GAMgASgLMhsuYnVzeWRhdGEudjEuUmV0YWluZWRSZXN1bH'
    'RSBnJlc3VsdA==');

@$core.Deprecated('Use editDraftRowDescriptor instead')
const EditDraftRow$json = {
  '1': 'EditDraftRow',
  '2': [
    {'1': 'source_row', '3': 1, '4': 1, '5': 4, '10': 'sourceRow'},
    {'1': 'row', '3': 2, '4': 1, '5': 11, '6': '.busydata.v1.Row', '10': 'row'},
  ],
};

/// Descriptor for `EditDraftRow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editDraftRowDescriptor = $convert.base64Decode(
    'CgxFZGl0RHJhZnRSb3cSHQoKc291cmNlX3JvdxgBIAEoBFIJc291cmNlUm93EiIKA3JvdxgCIA'
    'EoCzIQLmJ1c3lkYXRhLnYxLlJvd1IDcm93');

@$core.Deprecated('Use storedEditDraftDescriptor instead')
const StoredEditDraft$json = {
  '1': 'StoredEditDraft',
  '2': [
    {
      '1': 'changes',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.ChangeRequest',
      '10': 'changes'
    },
    {
      '1': 'columns',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.Column',
      '10': 'columns'
    },
    {
      '1': 'rows',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.EditDraftRow',
      '10': 'rows'
    },
    {'1': 'source_sql', '3': 4, '4': 1, '5': 9, '10': 'sourceSql'},
    {
      '1': 'target',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Profile',
      '10': 'target'
    },
    {'1': 'schema_signature', '3': 6, '4': 1, '5': 9, '10': 'schemaSignature'},
    {'1': 'document_id', '3': 7, '4': 1, '5': 9, '10': 'documentId'},
    {'1': 'source_sql_mode', '3': 8, '4': 1, '5': 9, '10': 'sourceSqlMode'},
    {
      '1': 'standard_conforming_strings',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'standardConformingStrings',
      '17': true
    },
    {
      '1': 'source_time_zone',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'sourceTimeZone',
      '17': true
    },
    {
      '1': 'source_system_time_zone',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'sourceSystemTimeZone',
      '17': true
    },
  ],
  '8': [
    {'1': '_standard_conforming_strings'},
    {'1': '_source_time_zone'},
    {'1': '_source_system_time_zone'},
  ],
};

/// Descriptor for `StoredEditDraft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storedEditDraftDescriptor = $convert.base64Decode(
    'Cg9TdG9yZWRFZGl0RHJhZnQSNAoHY2hhbmdlcxgBIAEoCzIaLmJ1c3lkYXRhLnYxLkNoYW5nZV'
    'JlcXVlc3RSB2NoYW5nZXMSLQoHY29sdW1ucxgCIAMoCzITLmJ1c3lkYXRhLnYxLkNvbHVtblIH'
    'Y29sdW1ucxItCgRyb3dzGAMgAygLMhkuYnVzeWRhdGEudjEuRWRpdERyYWZ0Um93UgRyb3dzEh'
    '0KCnNvdXJjZV9zcWwYBCABKAlSCXNvdXJjZVNxbBIsCgZ0YXJnZXQYBSABKAsyFC5idXN5ZGF0'
    'YS52MS5Qcm9maWxlUgZ0YXJnZXQSKQoQc2NoZW1hX3NpZ25hdHVyZRgGIAEoCVIPc2NoZW1hU2'
    'lnbmF0dXJlEh8KC2RvY3VtZW50X2lkGAcgASgJUgpkb2N1bWVudElkEiYKD3NvdXJjZV9zcWxf'
    'bW9kZRgIIAEoCVINc291cmNlU3FsTW9kZRJDChtzdGFuZGFyZF9jb25mb3JtaW5nX3N0cmluZ3'
    'MYCSABKAhIAFIZc3RhbmRhcmRDb25mb3JtaW5nU3RyaW5nc4gBARItChBzb3VyY2VfdGltZV96'
    'b25lGAogASgJSAFSDnNvdXJjZVRpbWVab25liAEBEjoKF3NvdXJjZV9zeXN0ZW1fdGltZV96b2'
    '5lGAsgASgJSAJSFHNvdXJjZVN5c3RlbVRpbWVab25liAEBQh4KHF9zdGFuZGFyZF9jb25mb3Jt'
    'aW5nX3N0cmluZ3NCEwoRX3NvdXJjZV90aW1lX3pvbmVCGgoYX3NvdXJjZV9zeXN0ZW1fdGltZV'
    '96b25l');

@$core.Deprecated('Use resultAggregateRequestDescriptor instead')
const ResultAggregateRequest$json = {
  '1': 'ResultAggregateRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'result_id', '3': 2, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'first_row', '3': 3, '4': 1, '5': 4, '10': 'firstRow'},
    {'1': 'row_count', '3': 4, '4': 1, '5': 13, '10': 'rowCount'},
    {'1': 'ordinals', '3': 5, '4': 3, '5': 13, '10': 'ordinals'},
    {'1': 'view_id', '3': 6, '4': 1, '5': 9, '10': 'viewId'},
  ],
};

/// Descriptor for `ResultAggregateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resultAggregateRequestDescriptor = $convert.base64Decode(
    'ChZSZXN1bHRBZ2dyZWdhdGVSZXF1ZXN0Ei4KB2NvbnRleHQYASABKAsyFC5idXN5ZGF0YS52MS'
    '5Db250ZXh0Ugdjb250ZXh0EhsKCXJlc3VsdF9pZBgCIAEoCVIIcmVzdWx0SWQSGwoJZmlyc3Rf'
    'cm93GAMgASgEUghmaXJzdFJvdxIbCglyb3dfY291bnQYBCABKA1SCHJvd0NvdW50EhoKCG9yZG'
    'luYWxzGAUgAygNUghvcmRpbmFscxIXCgd2aWV3X2lkGAYgASgJUgZ2aWV3SWQ=');

@$core.Deprecated('Use columnAggregateDescriptor instead')
const ColumnAggregate$json = {
  '1': 'ColumnAggregate',
  '2': [
    {'1': 'ordinal', '3': 1, '4': 1, '5': 13, '10': 'ordinal'},
    {'1': 'selected_count', '3': 2, '4': 1, '5': 4, '10': 'selectedCount'},
    {'1': 'non_null_count', '3': 3, '4': 1, '5': 4, '10': 'nonNullCount'},
    {'1': 'null_count', '3': 4, '4': 1, '5': 4, '10': 'nullCount'},
    {'1': 'distinct_count', '3': 5, '4': 1, '5': 4, '10': 'distinctCount'},
    {'1': 'sum', '3': 6, '4': 1, '5': 9, '10': 'sum'},
    {'1': 'average', '3': 7, '4': 1, '5': 9, '10': 'average'},
    {
      '1': 'minimum',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'minimum'
    },
    {
      '1': 'maximum',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Value',
      '10': 'maximum'
    },
    {'1': 'availability', '3': 10, '4': 1, '5': 9, '10': 'availability'},
  ],
};

/// Descriptor for `ColumnAggregate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List columnAggregateDescriptor = $convert.base64Decode(
    'Cg9Db2x1bW5BZ2dyZWdhdGUSGAoHb3JkaW5hbBgBIAEoDVIHb3JkaW5hbBIlCg5zZWxlY3RlZF'
    '9jb3VudBgCIAEoBFINc2VsZWN0ZWRDb3VudBIkCg5ub25fbnVsbF9jb3VudBgDIAEoBFIMbm9u'
    'TnVsbENvdW50Eh0KCm51bGxfY291bnQYBCABKARSCW51bGxDb3VudBIlCg5kaXN0aW5jdF9jb3'
    'VudBgFIAEoBFINZGlzdGluY3RDb3VudBIQCgNzdW0YBiABKAlSA3N1bRIYCgdhdmVyYWdlGAcg'
    'ASgJUgdhdmVyYWdlEiwKB21pbmltdW0YCCABKAsyEi5idXN5ZGF0YS52MS5WYWx1ZVIHbWluaW'
    '11bRIsCgdtYXhpbXVtGAkgASgLMhIuYnVzeWRhdGEudjEuVmFsdWVSB21heGltdW0SIgoMYXZh'
    'aWxhYmlsaXR5GAogASgJUgxhdmFpbGFiaWxpdHk=');

@$core.Deprecated('Use resultAggregateReplyDescriptor instead')
const ResultAggregateReply$json = {
  '1': 'ResultAggregateReply',
  '2': [
    {'1': 'result_id', '3': 1, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'view_id', '3': 2, '4': 1, '5': 9, '10': 'viewId'},
    {'1': 'scope', '3': 3, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'partial', '3': 4, '4': 1, '5': 8, '10': 'partial'},
    {
      '1': 'columns',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.ColumnAggregate',
      '10': 'columns'
    },
  ],
};

/// Descriptor for `ResultAggregateReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resultAggregateReplyDescriptor = $convert.base64Decode(
    'ChRSZXN1bHRBZ2dyZWdhdGVSZXBseRIbCglyZXN1bHRfaWQYASABKAlSCHJlc3VsdElkEhcKB3'
    'ZpZXdfaWQYAiABKAlSBnZpZXdJZBIUCgVzY29wZRgDIAEoCVIFc2NvcGUSGAoHcGFydGlhbBgE'
    'IAEoCFIHcGFydGlhbBI2Cgdjb2x1bW5zGAUgAygLMhwuYnVzeWRhdGEudjEuQ29sdW1uQWdncm'
    'VnYXRlUgdjb2x1bW5z');

@$core.Deprecated('Use relatedRowsRequestDescriptor instead')
const RelatedRowsRequest$json = {
  '1': 'RelatedRowsRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'result_id', '3': 3, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'source_row', '3': 4, '4': 1, '5': 4, '10': 'sourceRow'},
    {
      '1': 'snapshot_revision',
      '3': 5,
      '4': 1,
      '5': 4,
      '10': 'snapshotRevision'
    },
    {'1': 'document_id', '3': 6, '4': 1, '5': 9, '10': 'documentId'},
    {
      '1': 'expected_session_revision',
      '3': 7,
      '4': 1,
      '5': 4,
      '9': 0,
      '10': 'expectedSessionRevision',
      '17': true
    },
    {
      '1': 'expected_context_revision',
      '3': 8,
      '4': 1,
      '5': 4,
      '9': 1,
      '10': 'expectedContextRevision',
      '17': true
    },
  ],
  '8': [
    {'1': '_expected_session_revision'},
    {'1': '_expected_context_revision'},
  ],
};

/// Descriptor for `RelatedRowsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatedRowsRequestDescriptor = $convert.base64Decode(
    'ChJSZWxhdGVkUm93c1JlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbn'
    'RleHRSB2NvbnRleHQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2lvbklkEhsKCXJlc3VsdF9p'
    'ZBgDIAEoCVIIcmVzdWx0SWQSHQoKc291cmNlX3JvdxgEIAEoBFIJc291cmNlUm93EisKEXNuYX'
    'BzaG90X3JldmlzaW9uGAUgASgEUhBzbmFwc2hvdFJldmlzaW9uEh8KC2RvY3VtZW50X2lkGAYg'
    'ASgJUgpkb2N1bWVudElkEj8KGWV4cGVjdGVkX3Nlc3Npb25fcmV2aXNpb24YByABKARIAFIXZX'
    'hwZWN0ZWRTZXNzaW9uUmV2aXNpb26IAQESPwoZZXhwZWN0ZWRfY29udGV4dF9yZXZpc2lvbhgI'
    'IAEoBEgBUhdleHBlY3RlZENvbnRleHRSZXZpc2lvbogBAUIcChpfZXhwZWN0ZWRfc2Vzc2lvbl'
    '9yZXZpc2lvbkIcChpfZXhwZWN0ZWRfY29udGV4dF9yZXZpc2lvbg==');

@$core.Deprecated('Use relatedRelationshipDescriptor instead')
const RelatedRelationship$json = {
  '1': 'RelatedRelationship',
  '2': [
    {'1': 'identity', '3': 1, '4': 1, '5': 9, '10': 'identity'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'incoming', '3': 3, '4': 1, '5': 8, '10': 'incoming'},
    {
      '1': 'browse',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.BrowseRequest',
      '10': 'browse'
    },
    {'1': 'availability', '3': 5, '4': 1, '5': 9, '10': 'availability'},
  ],
};

/// Descriptor for `RelatedRelationship`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatedRelationshipDescriptor = $convert.base64Decode(
    'ChNSZWxhdGVkUmVsYXRpb25zaGlwEhoKCGlkZW50aXR5GAEgASgJUghpZGVudGl0eRISCgRuYW'
    '1lGAIgASgJUgRuYW1lEhoKCGluY29taW5nGAMgASgIUghpbmNvbWluZxIyCgZicm93c2UYBCAB'
    'KAsyGi5idXN5ZGF0YS52MS5Ccm93c2VSZXF1ZXN0UgZicm93c2USIgoMYXZhaWxhYmlsaXR5GA'
    'UgASgJUgxhdmFpbGFiaWxpdHk=');

@$core.Deprecated('Use relatedRowsReplyDescriptor instead')
const RelatedRowsReply$json = {
  '1': 'RelatedRowsReply',
  '2': [
    {'1': 'result_id', '3': 1, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'source_row', '3': 2, '4': 1, '5': 4, '10': 'sourceRow'},
    {
      '1': 'snapshot_revision',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'snapshotRevision'
    },
    {
      '1': 'relationships',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.RelatedRelationship',
      '10': 'relationships'
    },
    {'1': 'availability', '3': 5, '4': 1, '5': 9, '10': 'availability'},
    {'1': 'backend_instance', '3': 6, '4': 1, '5': 9, '10': 'backendInstance'},
    {'1': 'profile_id', '3': 7, '4': 1, '5': 9, '10': 'profileId'},
    {
      '1': 'metadata_source_identity',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'metadataSourceIdentity'
    },
    {'1': 'session_id', '3': 9, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'session_revision', '3': 10, '4': 1, '5': 4, '10': 'sessionRevision'},
    {'1': 'context_revision', '3': 11, '4': 1, '5': 4, '10': 'contextRevision'},
    {
      '1': 'metadata_configuration_revision',
      '3': 12,
      '4': 1,
      '5': 4,
      '10': 'metadataConfigurationRevision'
    },
  ],
};

/// Descriptor for `RelatedRowsReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatedRowsReplyDescriptor = $convert.base64Decode(
    'ChBSZWxhdGVkUm93c1JlcGx5EhsKCXJlc3VsdF9pZBgBIAEoCVIIcmVzdWx0SWQSHQoKc291cm'
    'NlX3JvdxgCIAEoBFIJc291cmNlUm93EisKEXNuYXBzaG90X3JldmlzaW9uGAMgASgEUhBzbmFw'
    'c2hvdFJldmlzaW9uEkYKDXJlbGF0aW9uc2hpcHMYBCADKAsyIC5idXN5ZGF0YS52MS5SZWxhdG'
    'VkUmVsYXRpb25zaGlwUg1yZWxhdGlvbnNoaXBzEiIKDGF2YWlsYWJpbGl0eRgFIAEoCVIMYXZh'
    'aWxhYmlsaXR5EikKEGJhY2tlbmRfaW5zdGFuY2UYBiABKAlSD2JhY2tlbmRJbnN0YW5jZRIdCg'
    'pwcm9maWxlX2lkGAcgASgJUglwcm9maWxlSWQSOAoYbWV0YWRhdGFfc291cmNlX2lkZW50aXR5'
    'GAggASgJUhZtZXRhZGF0YVNvdXJjZUlkZW50aXR5Eh0KCnNlc3Npb25faWQYCSABKAlSCXNlc3'
    'Npb25JZBIpChBzZXNzaW9uX3JldmlzaW9uGAogASgEUg9zZXNzaW9uUmV2aXNpb24SKQoQY29u'
    'dGV4dF9yZXZpc2lvbhgLIAEoBFIPY29udGV4dFJldmlzaW9uEkYKH21ldGFkYXRhX2NvbmZpZ3'
    'VyYXRpb25fcmV2aXNpb24YDCABKARSHW1ldGFkYXRhQ29uZmlndXJhdGlvblJldmlzaW9u');

@$core.Deprecated('Use cloneRowRequestDescriptor instead')
const CloneRowRequest$json = {
  '1': 'CloneRowRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'result_id', '3': 3, '4': 1, '5': 9, '10': 'resultId'},
    {'1': 'source_row', '3': 4, '4': 1, '5': 4, '10': 'sourceRow'},
    {'1': 'catalog', '3': 5, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 6, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'table', '3': 7, '4': 1, '5': 9, '10': 'table'},
  ],
};

/// Descriptor for `CloneRowRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cloneRowRequestDescriptor = $convert.base64Decode(
    'Cg9DbG9uZVJvd1JlcXVlc3QSLgoHY29udGV4dBgBIAEoCzIULmJ1c3lkYXRhLnYxLkNvbnRleH'
    'RSB2NvbnRleHQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2lvbklkEhsKCXJlc3VsdF9pZBgD'
    'IAEoCVIIcmVzdWx0SWQSHQoKc291cmNlX3JvdxgEIAEoBFIJc291cmNlUm93EhgKB2NhdGFsb2'
    'cYBSABKAlSB2NhdGFsb2cSFgoGc2NoZW1hGAYgASgJUgZzY2hlbWESFAoFdGFibGUYByABKAlS'
    'BXRhYmxl');

@$core.Deprecated('Use metadataScopeLevelDescriptor instead')
const MetadataScopeLevel$json = {
  '1': 'MetadataScopeLevel',
  '2': [
    {'1': 'catalog', '3': 1, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 2, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'level', '3': 3, '4': 1, '5': 13, '10': 'level'},
  ],
};

/// Descriptor for `MetadataScopeLevel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataScopeLevelDescriptor = $convert.base64Decode(
    'ChJNZXRhZGF0YVNjb3BlTGV2ZWwSGAoHY2F0YWxvZxgBIAEoCVIHY2F0YWxvZxIWCgZzY2hlbW'
    'EYAiABKAlSBnNjaGVtYRIUCgVsZXZlbBgDIAEoDVIFbGV2ZWw=');

@$core.Deprecated('Use metadataIntrospectionConfigurationDescriptor instead')
const MetadataIntrospectionConfiguration$json = {
  '1': 'MetadataIntrospectionConfiguration',
  '2': [
    {
      '1': 'included_catalogs',
      '3': 1,
      '4': 3,
      '5': 9,
      '10': 'includedCatalogs'
    },
    {
      '1': 'excluded_catalogs',
      '3': 2,
      '4': 3,
      '5': 9,
      '10': 'excludedCatalogs'
    },
    {'1': 'included_schemas', '3': 3, '4': 3, '5': 9, '10': 'includedSchemas'},
    {'1': 'excluded_schemas', '3': 4, '4': 3, '5': 9, '10': 'excludedSchemas'},
    {'1': 'system_objects', '3': 5, '4': 1, '5': 8, '10': 'systemObjects'},
    {
      '1': 'kinds',
      '3': 6,
      '4': 3,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kinds'
    },
    {'1': 'include_patterns', '3': 7, '4': 3, '5': 9, '10': 'includePatterns'},
    {'1': 'exclude_patterns', '3': 8, '4': 3, '5': 9, '10': 'excludePatterns'},
    {'1': 'default_level', '3': 9, '4': 1, '5': 13, '10': 'defaultLevel'},
    {
      '1': 'scope_levels',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.MetadataScopeLevel',
      '10': 'scopeLevels'
    },
  ],
};

/// Descriptor for `MetadataIntrospectionConfiguration`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataIntrospectionConfigurationDescriptor = $convert.base64Decode(
    'CiJNZXRhZGF0YUludHJvc3BlY3Rpb25Db25maWd1cmF0aW9uEisKEWluY2x1ZGVkX2NhdGFsb2'
    'dzGAEgAygJUhBpbmNsdWRlZENhdGFsb2dzEisKEWV4Y2x1ZGVkX2NhdGFsb2dzGAIgAygJUhBl'
    'eGNsdWRlZENhdGFsb2dzEikKEGluY2x1ZGVkX3NjaGVtYXMYAyADKAlSD2luY2x1ZGVkU2NoZW'
    '1hcxIpChBleGNsdWRlZF9zY2hlbWFzGAQgAygJUg9leGNsdWRlZFNjaGVtYXMSJQoOc3lzdGVt'
    'X29iamVjdHMYBSABKAhSDXN5c3RlbU9iamVjdHMSLQoFa2luZHMYBiADKA4yFy5idXN5ZGF0YS'
    '52MS5PYmplY3RLaW5kUgVraW5kcxIpChBpbmNsdWRlX3BhdHRlcm5zGAcgAygJUg9pbmNsdWRl'
    'UGF0dGVybnMSKQoQZXhjbHVkZV9wYXR0ZXJucxgIIAMoCVIPZXhjbHVkZVBhdHRlcm5zEiMKDW'
    'RlZmF1bHRfbGV2ZWwYCSABKA1SDGRlZmF1bHRMZXZlbBJCCgxzY29wZV9sZXZlbHMYCiADKAsy'
    'Hy5idXN5ZGF0YS52MS5NZXRhZGF0YVNjb3BlTGV2ZWxSC3Njb3BlTGV2ZWxz');

@$core.Deprecated('Use metadataSettingsRequestDescriptor instead')
const MetadataSettingsRequest$json = {
  '1': 'MetadataSettingsRequest',
  '2': [
    {
      '1': 'context',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.Context',
      '10': 'context'
    },
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'session_revision', '3': 3, '4': 1, '5': 4, '10': 'sessionRevision'},
    {'1': 'context_revision', '3': 4, '4': 1, '5': 4, '10': 'contextRevision'},
    {
      '1': 'action',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.MetadataSettingsAction',
      '10': 'action'
    },
    {
      '1': 'expected_configuration_revision',
      '3': 6,
      '4': 1,
      '5': 4,
      '10': 'expectedConfigurationRevision'
    },
    {
      '1': 'configuration',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.MetadataIntrospectionConfiguration',
      '10': 'configuration'
    },
    {'1': 'offset', '3': 8, '4': 1, '5': 13, '10': 'offset'},
    {'1': 'limit', '3': 9, '4': 1, '5': 13, '10': 'limit'},
    {
      '1': 'expected_snapshot_revision',
      '3': 10,
      '4': 1,
      '5': 4,
      '10': 'expectedSnapshotRevision'
    },
  ],
};

/// Descriptor for `MetadataSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataSettingsRequestDescriptor = $convert.base64Decode(
    'ChdNZXRhZGF0YVNldHRpbmdzUmVxdWVzdBIuCgdjb250ZXh0GAEgASgLMhQuYnVzeWRhdGEudj'
    'EuQ29udGV4dFIHY29udGV4dBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSKQoQc2Vz'
    'c2lvbl9yZXZpc2lvbhgDIAEoBFIPc2Vzc2lvblJldmlzaW9uEikKEGNvbnRleHRfcmV2aXNpb2'
    '4YBCABKARSD2NvbnRleHRSZXZpc2lvbhI7CgZhY3Rpb24YBSABKA4yIy5idXN5ZGF0YS52MS5N'
    'ZXRhZGF0YVNldHRpbmdzQWN0aW9uUgZhY3Rpb24SRgofZXhwZWN0ZWRfY29uZmlndXJhdGlvbl'
    '9yZXZpc2lvbhgGIAEoBFIdZXhwZWN0ZWRDb25maWd1cmF0aW9uUmV2aXNpb24SVQoNY29uZmln'
    'dXJhdGlvbhgHIAEoCzIvLmJ1c3lkYXRhLnYxLk1ldGFkYXRhSW50cm9zcGVjdGlvbkNvbmZpZ3'
    'VyYXRpb25SDWNvbmZpZ3VyYXRpb24SFgoGb2Zmc2V0GAggASgNUgZvZmZzZXQSFAoFbGltaXQY'
    'CSABKA1SBWxpbWl0EjwKGmV4cGVjdGVkX3NuYXBzaG90X3JldmlzaW9uGAogASgEUhhleHBlY3'
    'RlZFNuYXBzaG90UmV2aXNpb24=');

@$core.Deprecated('Use metadataScopeStatusDescriptor instead')
const MetadataScopeStatus$json = {
  '1': 'MetadataScopeStatus',
  '2': [
    {'1': 'catalog', '3': 1, '4': 1, '5': 9, '10': 'catalog'},
    {'1': 'schema', '3': 2, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'parent', '3': 3, '4': 1, '5': 9, '10': 'parent'},
    {
      '1': 'kind',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.busydata.v1.ObjectKind',
      '10': 'kind'
    },
    {'1': 'level', '3': 5, '4': 1, '5': 13, '10': 'level'},
    {'1': 'state', '3': 6, '4': 1, '5': 9, '10': 'state'},
    {'1': 'complete', '3': 7, '4': 1, '5': 8, '10': 'complete'},
    {
      '1': 'last_successful_refresh_unix_ms',
      '3': 8,
      '4': 1,
      '5': 4,
      '10': 'lastSuccessfulRefreshUnixMs'
    },
    {'1': 'limitation', '3': 9, '4': 1, '5': 9, '10': 'limitation'},
    {'1': 'object_count', '3': 10, '4': 1, '5': 4, '10': 'objectCount'},
  ],
};

/// Descriptor for `MetadataScopeStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataScopeStatusDescriptor = $convert.base64Decode(
    'ChNNZXRhZGF0YVNjb3BlU3RhdHVzEhgKB2NhdGFsb2cYASABKAlSB2NhdGFsb2cSFgoGc2NoZW'
    '1hGAIgASgJUgZzY2hlbWESFgoGcGFyZW50GAMgASgJUgZwYXJlbnQSKwoEa2luZBgEIAEoDjIX'
    'LmJ1c3lkYXRhLnYxLk9iamVjdEtpbmRSBGtpbmQSFAoFbGV2ZWwYBSABKA1SBWxldmVsEhQKBX'
    'N0YXRlGAYgASgJUgVzdGF0ZRIaCghjb21wbGV0ZRgHIAEoCFIIY29tcGxldGUSRAofbGFzdF9z'
    'dWNjZXNzZnVsX3JlZnJlc2hfdW5peF9tcxgIIAEoBFIbbGFzdFN1Y2Nlc3NmdWxSZWZyZXNoVW'
    '5peE1zEh4KCmxpbWl0YXRpb24YCSABKAlSCmxpbWl0YXRpb24SIQoMb2JqZWN0X2NvdW50GAog'
    'ASgEUgtvYmplY3RDb3VudA==');

@$core.Deprecated('Use metadataSettingsReplyDescriptor instead')
const MetadataSettingsReply$json = {
  '1': 'MetadataSettingsReply',
  '2': [
    {'1': 'backend_instance', '3': 1, '4': 1, '5': 9, '10': 'backendInstance'},
    {'1': 'profile_id', '3': 2, '4': 1, '5': 9, '10': 'profileId'},
    {'1': 'session_id', '3': 3, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'session_revision', '3': 4, '4': 1, '5': 4, '10': 'sessionRevision'},
    {'1': 'context_revision', '3': 5, '4': 1, '5': 4, '10': 'contextRevision'},
    {
      '1': 'configuration_revision',
      '3': 6,
      '4': 1,
      '5': 4,
      '10': 'configurationRevision'
    },
    {
      '1': 'snapshot_revision',
      '3': 7,
      '4': 1,
      '5': 4,
      '10': 'snapshotRevision'
    },
    {
      '1': 'configuration',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.busydata.v1.MetadataIntrospectionConfiguration',
      '10': 'configuration'
    },
    {
      '1': 'scopes',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.busydata.v1.MetadataScopeStatus',
      '10': 'scopes'
    },
    {'1': 'next_offset', '3': 10, '4': 1, '5': 13, '10': 'nextOffset'},
    {'1': 'complete', '3': 11, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'cache_state', '3': 12, '4': 1, '5': 9, '10': 'cacheState'},
    {'1': 'refresh_strategy', '3': 13, '4': 1, '5': 9, '10': 'refreshStrategy'},
    {'1': 'scanned_scopes', '3': 14, '4': 1, '5': 4, '10': 'scannedScopes'},
    {'1': 'fetched_scopes', '3': 15, '4': 1, '5': 4, '10': 'fetchedScopes'},
    {'1': 'fetched_objects', '3': 16, '4': 1, '5': 4, '10': 'fetchedObjects'},
    {
      '1': 'refresh_duration_ms',
      '3': 17,
      '4': 1,
      '5': 4,
      '10': 'refreshDurationMs'
    },
    {
      '1': 'metadata_source_identity',
      '3': 18,
      '4': 1,
      '5': 9,
      '10': 'metadataSourceIdentity'
    },
  ],
};

/// Descriptor for `MetadataSettingsReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataSettingsReplyDescriptor = $convert.base64Decode(
    'ChVNZXRhZGF0YVNldHRpbmdzUmVwbHkSKQoQYmFja2VuZF9pbnN0YW5jZRgBIAEoCVIPYmFja2'
    'VuZEluc3RhbmNlEh0KCnByb2ZpbGVfaWQYAiABKAlSCXByb2ZpbGVJZBIdCgpzZXNzaW9uX2lk'
    'GAMgASgJUglzZXNzaW9uSWQSKQoQc2Vzc2lvbl9yZXZpc2lvbhgEIAEoBFIPc2Vzc2lvblJldm'
    'lzaW9uEikKEGNvbnRleHRfcmV2aXNpb24YBSABKARSD2NvbnRleHRSZXZpc2lvbhI1ChZjb25m'
    'aWd1cmF0aW9uX3JldmlzaW9uGAYgASgEUhVjb25maWd1cmF0aW9uUmV2aXNpb24SKwoRc25hcH'
    'Nob3RfcmV2aXNpb24YByABKARSEHNuYXBzaG90UmV2aXNpb24SVQoNY29uZmlndXJhdGlvbhgI'
    'IAEoCzIvLmJ1c3lkYXRhLnYxLk1ldGFkYXRhSW50cm9zcGVjdGlvbkNvbmZpZ3VyYXRpb25SDW'
    'NvbmZpZ3VyYXRpb24SOAoGc2NvcGVzGAkgAygLMiAuYnVzeWRhdGEudjEuTWV0YWRhdGFTY29w'
    'ZVN0YXR1c1IGc2NvcGVzEh8KC25leHRfb2Zmc2V0GAogASgNUgpuZXh0T2Zmc2V0EhoKCGNvbX'
    'BsZXRlGAsgASgIUghjb21wbGV0ZRIfCgtjYWNoZV9zdGF0ZRgMIAEoCVIKY2FjaGVTdGF0ZRIp'
    'ChByZWZyZXNoX3N0cmF0ZWd5GA0gASgJUg9yZWZyZXNoU3RyYXRlZ3kSJQoOc2Nhbm5lZF9zY2'
    '9wZXMYDiABKARSDXNjYW5uZWRTY29wZXMSJQoOZmV0Y2hlZF9zY29wZXMYDyABKARSDWZldGNo'
    'ZWRTY29wZXMSJwoPZmV0Y2hlZF9vYmplY3RzGBAgASgEUg5mZXRjaGVkT2JqZWN0cxIuChNyZW'
    'ZyZXNoX2R1cmF0aW9uX21zGBEgASgEUhFyZWZyZXNoRHVyYXRpb25NcxI4ChhtZXRhZGF0YV9z'
    'b3VyY2VfaWRlbnRpdHkYEiABKAlSFm1ldGFkYXRhU291cmNlSWRlbnRpdHk=');
