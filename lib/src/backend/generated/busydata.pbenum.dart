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

import 'package:protobuf/protobuf.dart' as $pb;

/// Strict per-release protocol identity. Older and newer peers are rejected;
/// there is no negotiation or compatibility path for discarded wire contracts.
class ProtocolVersion extends $pb.ProtobufEnum {
  static const ProtocolVersion PROTOCOL_VERSION_UNSPECIFIED = ProtocolVersion._(
      0, _omitEnumNames ? '' : 'PROTOCOL_VERSION_UNSPECIFIED');
  static const ProtocolVersion BUSYDATA_PROTOCOL_VERSION =
      ProtocolVersion._(15, _omitEnumNames ? '' : 'BUSYDATA_PROTOCOL_VERSION');

  static const $core.List<ProtocolVersion> values = <ProtocolVersion>[
    PROTOCOL_VERSION_UNSPECIFIED,
    BUSYDATA_PROTOCOL_VERSION,
  ];

  static final $core.Map<$core.int, ProtocolVersion> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ProtocolVersion? valueOf($core.int value) => _byValue[value];

  const ProtocolVersion._(super.value, super.name);
}

class Engine extends $pb.ProtobufEnum {
  static const Engine ENGINE_UNSPECIFIED =
      Engine._(0, _omitEnumNames ? '' : 'ENGINE_UNSPECIFIED');
  static const Engine POSTGRESQL =
      Engine._(1, _omitEnumNames ? '' : 'POSTGRESQL');
  static const Engine MYSQL = Engine._(2, _omitEnumNames ? '' : 'MYSQL');
  static const Engine MARIADB = Engine._(3, _omitEnumNames ? '' : 'MARIADB');

  static const $core.List<Engine> values = <Engine>[
    ENGINE_UNSPECIFIED,
    POSTGRESQL,
    MYSQL,
    MARIADB,
  ];

  static final $core.List<Engine?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Engine? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Engine._(super.value, super.name);
}

class Environment extends $pb.ProtobufEnum {
  static const Environment DEVELOPMENT =
      Environment._(0, _omitEnumNames ? '' : 'DEVELOPMENT');
  static const Environment STAGING =
      Environment._(1, _omitEnumNames ? '' : 'STAGING');
  static const Environment PRODUCTION =
      Environment._(2, _omitEnumNames ? '' : 'PRODUCTION');

  static const $core.List<Environment> values = <Environment>[
    DEVELOPMENT,
    STAGING,
    PRODUCTION,
  ];

  static final $core.List<Environment?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Environment? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Environment._(super.value, super.name);
}

/// Old persisted values keep their meaning. DRIVER_DEFAULT deliberately leaves
/// negotiation to the bundled driver; it is distinct from explicitly disabled.
class TlsMode extends $pb.ProtobufEnum {
  static const TlsMode VERIFY_FULL =
      TlsMode._(0, _omitEnumNames ? '' : 'VERIFY_FULL');
  static const TlsMode INSECURE =
      TlsMode._(1, _omitEnumNames ? '' : 'INSECURE');
  static const TlsMode DISABLED =
      TlsMode._(2, _omitEnumNames ? '' : 'DISABLED');
  static const TlsMode VERIFY_CA =
      TlsMode._(3, _omitEnumNames ? '' : 'VERIFY_CA');
  static const TlsMode DRIVER_DEFAULT =
      TlsMode._(4, _omitEnumNames ? '' : 'DRIVER_DEFAULT');

  static const $core.List<TlsMode> values = <TlsMode>[
    VERIFY_FULL,
    INSECURE,
    DISABLED,
    VERIFY_CA,
    DRIVER_DEFAULT,
  ];

  static final $core.List<TlsMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TlsMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TlsMode._(super.value, super.name);
}

class ProfileAction extends $pb.ProtobufEnum {
  static const ProfileAction LIST_PROFILES =
      ProfileAction._(0, _omitEnumNames ? '' : 'LIST_PROFILES');
  static const ProfileAction SAVE_PROFILE =
      ProfileAction._(1, _omitEnumNames ? '' : 'SAVE_PROFILE');
  static const ProfileAction DELETE_PROFILE =
      ProfileAction._(2, _omitEnumNames ? '' : 'DELETE_PROFILE');

  static const $core.List<ProfileAction> values = <ProfileAction>[
    LIST_PROFILES,
    SAVE_PROFILE,
    DELETE_PROFILE,
  ];

  static final $core.List<ProfileAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ProfileAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProfileAction._(super.value, super.name);
}

class CapabilityState extends $pb.ProtobufEnum {
  static const CapabilityState CAPABILITY_UNKNOWN =
      CapabilityState._(0, _omitEnumNames ? '' : 'CAPABILITY_UNKNOWN');
  static const CapabilityState CAPABILITY_AVAILABLE =
      CapabilityState._(1, _omitEnumNames ? '' : 'CAPABILITY_AVAILABLE');
  static const CapabilityState CAPABILITY_LIMITED =
      CapabilityState._(2, _omitEnumNames ? '' : 'CAPABILITY_LIMITED');
  static const CapabilityState CAPABILITY_DENIED =
      CapabilityState._(3, _omitEnumNames ? '' : 'CAPABILITY_DENIED');
  static const CapabilityState CAPABILITY_UNSUPPORTED =
      CapabilityState._(4, _omitEnumNames ? '' : 'CAPABILITY_UNSUPPORTED');
  static const CapabilityState CAPABILITY_UNAVAILABLE =
      CapabilityState._(5, _omitEnumNames ? '' : 'CAPABILITY_UNAVAILABLE');
  static const CapabilityState CAPABILITY_DISABLED =
      CapabilityState._(6, _omitEnumNames ? '' : 'CAPABILITY_DISABLED');

  static const $core.List<CapabilityState> values = <CapabilityState>[
    CAPABILITY_UNKNOWN,
    CAPABILITY_AVAILABLE,
    CAPABILITY_LIMITED,
    CAPABILITY_DENIED,
    CAPABILITY_UNSUPPORTED,
    CAPABILITY_UNAVAILABLE,
    CAPABILITY_DISABLED,
  ];

  static final $core.List<CapabilityState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static CapabilityState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CapabilityState._(super.value, super.name);
}

class SessionAction extends $pb.ProtobufEnum {
  static const SessionAction SESSION_STATUS =
      SessionAction._(0, _omitEnumNames ? '' : 'SESSION_STATUS');
  static const SessionAction BEGIN =
      SessionAction._(1, _omitEnumNames ? '' : 'BEGIN');
  static const SessionAction COMMIT =
      SessionAction._(2, _omitEnumNames ? '' : 'COMMIT');
  static const SessionAction ROLLBACK =
      SessionAction._(3, _omitEnumNames ? '' : 'ROLLBACK');
  static const SessionAction AUTO_COMMIT_ON =
      SessionAction._(4, _omitEnumNames ? '' : 'AUTO_COMMIT_ON');
  static const SessionAction AUTO_COMMIT_OFF =
      SessionAction._(5, _omitEnumNames ? '' : 'AUTO_COMMIT_OFF');
  static const SessionAction DISCONNECT =
      SessionAction._(6, _omitEnumNames ? '' : 'DISCONNECT');
  static const SessionAction ADOPT_SESSION =
      SessionAction._(7, _omitEnumNames ? '' : 'ADOPT_SESSION');

  static const $core.List<SessionAction> values = <SessionAction>[
    SESSION_STATUS,
    BEGIN,
    COMMIT,
    ROLLBACK,
    AUTO_COMMIT_ON,
    AUTO_COMMIT_OFF,
    DISCONNECT,
    ADOPT_SESSION,
  ];

  static final $core.List<SessionAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static SessionAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionAction._(super.value, super.name);
}

class TransactionState extends $pb.ProtobufEnum {
  static const TransactionState IDLE =
      TransactionState._(0, _omitEnumNames ? '' : 'IDLE');
  static const TransactionState ACTIVE =
      TransactionState._(1, _omitEnumNames ? '' : 'ACTIVE');
  static const TransactionState FAILED_TRANSACTION =
      TransactionState._(2, _omitEnumNames ? '' : 'FAILED_TRANSACTION');
  static const TransactionState UNKNOWN_TRANSACTION =
      TransactionState._(3, _omitEnumNames ? '' : 'UNKNOWN_TRANSACTION');
  static const TransactionState DISCONNECTED =
      TransactionState._(4, _omitEnumNames ? '' : 'DISCONNECTED');

  static const $core.List<TransactionState> values = <TransactionState>[
    IDLE,
    ACTIVE,
    FAILED_TRANSACTION,
    UNKNOWN_TRANSACTION,
    DISCONNECTED,
  ];

  static final $core.List<TransactionState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TransactionState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TransactionState._(super.value, super.name);
}

class ExecutionMode extends $pb.ProtobufEnum {
  static const ExecutionMode SCRIPT =
      ExecutionMode._(0, _omitEnumNames ? '' : 'SCRIPT');
  static const ExecutionMode CURRENT_STATEMENT =
      ExecutionMode._(1, _omitEnumNames ? '' : 'CURRENT_STATEMENT');
  static const ExecutionMode SELECTION =
      ExecutionMode._(2, _omitEnumNames ? '' : 'SELECTION');

  static const $core.List<ExecutionMode> values = <ExecutionMode>[
    SCRIPT,
    CURRENT_STATEMENT,
    SELECTION,
  ];

  static final $core.List<ExecutionMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ExecutionMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExecutionMode._(super.value, super.name);
}

class ErrorPolicy extends $pb.ProtobufEnum {
  static const ErrorPolicy STOP_ON_ERROR =
      ErrorPolicy._(0, _omitEnumNames ? '' : 'STOP_ON_ERROR');
  static const ErrorPolicy CONTINUE_ON_ERROR =
      ErrorPolicy._(1, _omitEnumNames ? '' : 'CONTINUE_ON_ERROR');

  static const $core.List<ErrorPolicy> values = <ErrorPolicy>[
    STOP_ON_ERROR,
    CONTINUE_ON_ERROR,
  ];

  static final $core.List<ErrorPolicy?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ErrorPolicy? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ErrorPolicy._(super.value, super.name);
}

class ValuePredicate extends $pb.ProtobufEnum {
  static const ValuePredicate EQUAL =
      ValuePredicate._(0, _omitEnumNames ? '' : 'EQUAL');
  static const ValuePredicate NOT_EQUAL =
      ValuePredicate._(1, _omitEnumNames ? '' : 'NOT_EQUAL');
  static const ValuePredicate LESS =
      ValuePredicate._(2, _omitEnumNames ? '' : 'LESS');
  static const ValuePredicate GREATER =
      ValuePredicate._(3, _omitEnumNames ? '' : 'GREATER');
  static const ValuePredicate IS_NULL =
      ValuePredicate._(4, _omitEnumNames ? '' : 'IS_NULL');
  static const ValuePredicate IS_NOT_NULL =
      ValuePredicate._(5, _omitEnumNames ? '' : 'IS_NOT_NULL');

  static const $core.List<ValuePredicate> values = <ValuePredicate>[
    EQUAL,
    NOT_EQUAL,
    LESS,
    GREATER,
    IS_NULL,
    IS_NOT_NULL,
  ];

  static final $core.List<ValuePredicate?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ValuePredicate? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ValuePredicate._(super.value, super.name);
}

class JobState extends $pb.ProtobufEnum {
  static const JobState QUEUED = JobState._(0, _omitEnumNames ? '' : 'QUEUED');
  static const JobState EXECUTING =
      JobState._(1, _omitEnumNames ? '' : 'EXECUTING');
  static const JobState FETCHING =
      JobState._(2, _omitEnumNames ? '' : 'FETCHING');
  static const JobState CANCELLING =
      JobState._(3, _omitEnumNames ? '' : 'CANCELLING');
  static const JobState COMPLETED =
      JobState._(4, _omitEnumNames ? '' : 'COMPLETED');
  static const JobState FAILED = JobState._(5, _omitEnumNames ? '' : 'FAILED');
  static const JobState CANCELLED =
      JobState._(6, _omitEnumNames ? '' : 'CANCELLED');
  static const JobState INTERRUPTED =
      JobState._(7, _omitEnumNames ? '' : 'INTERRUPTED');
  static const JobState UNKNOWN_OUTCOME =
      JobState._(8, _omitEnumNames ? '' : 'UNKNOWN_OUTCOME');

  static const $core.List<JobState> values = <JobState>[
    QUEUED,
    EXECUTING,
    FETCHING,
    CANCELLING,
    COMPLETED,
    FAILED,
    CANCELLED,
    INTERRUPTED,
    UNKNOWN_OUTCOME,
  ];

  static final $core.List<JobState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static JobState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const JobState._(super.value, super.name);
}

class PageState extends $pb.ProtobufEnum {
  static const PageState PAGE_DATA =
      PageState._(0, _omitEnumNames ? '' : 'PAGE_DATA');
  static const PageState PAGE_BYTE_LIMIT =
      PageState._(1, _omitEnumNames ? '' : 'PAGE_BYTE_LIMIT');
  static const PageState PAGE_WAITING =
      PageState._(2, _omitEnumNames ? '' : 'PAGE_WAITING');
  static const PageState PAGE_END =
      PageState._(3, _omitEnumNames ? '' : 'PAGE_END');
  static const PageState PAGE_METADATA_TOO_LARGE =
      PageState._(4, _omitEnumNames ? '' : 'PAGE_METADATA_TOO_LARGE');
  static const PageState PAGE_ROW_TOO_LARGE =
      PageState._(5, _omitEnumNames ? '' : 'PAGE_ROW_TOO_LARGE');
  static const PageState PAGE_DISPOSED =
      PageState._(6, _omitEnumNames ? '' : 'PAGE_DISPOSED');
  static const PageState PAGE_FAILED =
      PageState._(7, _omitEnumNames ? '' : 'PAGE_FAILED');

  static const $core.List<PageState> values = <PageState>[
    PAGE_DATA,
    PAGE_BYTE_LIMIT,
    PAGE_WAITING,
    PAGE_END,
    PAGE_METADATA_TOO_LARGE,
    PAGE_ROW_TOO_LARGE,
    PAGE_DISPOSED,
    PAGE_FAILED,
  ];

  static final $core.List<PageState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static PageState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PageState._(super.value, super.name);
}

class AnalysisOperation extends $pb.ProtobufEnum {
  static const AnalysisOperation COMPLETION =
      AnalysisOperation._(0, _omitEnumNames ? '' : 'COMPLETION');
  static const AnalysisOperation DIAGNOSTICS =
      AnalysisOperation._(1, _omitEnumNames ? '' : 'DIAGNOSTICS');
  static const AnalysisOperation PARAMETER_INFORMATION =
      AnalysisOperation._(2, _omitEnumNames ? '' : 'PARAMETER_INFORMATION');
  static const AnalysisOperation FORMAT =
      AnalysisOperation._(3, _omitEnumNames ? '' : 'FORMAT');
  static const AnalysisOperation SYMBOL_RESOLUTION =
      AnalysisOperation._(4, _omitEnumNames ? '' : 'SYMBOL_RESOLUTION');
  static const AnalysisOperation DDL_IMPACT =
      AnalysisOperation._(5, _omitEnumNames ? '' : 'DDL_IMPACT');

  static const $core.List<AnalysisOperation> values = <AnalysisOperation>[
    COMPLETION,
    DIAGNOSTICS,
    PARAMETER_INFORMATION,
    FORMAT,
    SYMBOL_RESOLUTION,
    DDL_IMPACT,
  ];

  static final $core.List<AnalysisOperation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static AnalysisOperation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AnalysisOperation._(super.value, super.name);
}

class ObjectKind extends $pb.ProtobufEnum {
  static const ObjectKind CATALOG =
      ObjectKind._(0, _omitEnumNames ? '' : 'CATALOG');
  static const ObjectKind SCHEMA =
      ObjectKind._(1, _omitEnumNames ? '' : 'SCHEMA');
  static const ObjectKind TABLE =
      ObjectKind._(2, _omitEnumNames ? '' : 'TABLE');
  static const ObjectKind VIEW = ObjectKind._(3, _omitEnumNames ? '' : 'VIEW');
  static const ObjectKind COLUMN =
      ObjectKind._(4, _omitEnumNames ? '' : 'COLUMN');
  static const ObjectKind INDEX =
      ObjectKind._(5, _omitEnumNames ? '' : 'INDEX');
  static const ObjectKind CONSTRAINT =
      ObjectKind._(6, _omitEnumNames ? '' : 'CONSTRAINT');
  static const ObjectKind ROUTINE =
      ObjectKind._(7, _omitEnumNames ? '' : 'ROUTINE');
  static const ObjectKind TRIGGER =
      ObjectKind._(8, _omitEnumNames ? '' : 'TRIGGER');
  static const ObjectKind FOREIGN_KEY =
      ObjectKind._(9, _omitEnumNames ? '' : 'FOREIGN_KEY');
  static const ObjectKind SEQUENCE =
      ObjectKind._(10, _omitEnumNames ? '' : 'SEQUENCE');
  static const ObjectKind TYPE = ObjectKind._(11, _omitEnumNames ? '' : 'TYPE');

  static const $core.List<ObjectKind> values = <ObjectKind>[
    CATALOG,
    SCHEMA,
    TABLE,
    VIEW,
    COLUMN,
    INDEX,
    CONSTRAINT,
    ROUTINE,
    TRIGGER,
    FOREIGN_KEY,
    SEQUENCE,
    TYPE,
  ];

  static final $core.List<ObjectKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
  static ObjectKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ObjectKind._(super.value, super.name);
}

class ObjectSubtype extends $pb.ProtobufEnum {
  static const ObjectSubtype OBJECT_SUBTYPE_UNSPECIFIED =
      ObjectSubtype._(0, _omitEnumNames ? '' : 'OBJECT_SUBTYPE_UNSPECIFIED');
  static const ObjectSubtype ORDINARY_TABLE =
      ObjectSubtype._(1, _omitEnumNames ? '' : 'ORDINARY_TABLE');
  static const ObjectSubtype PARTITIONED_TABLE =
      ObjectSubtype._(2, _omitEnumNames ? '' : 'PARTITIONED_TABLE');
  static const ObjectSubtype FOREIGN_TABLE =
      ObjectSubtype._(3, _omitEnumNames ? '' : 'FOREIGN_TABLE');
  static const ObjectSubtype REGULAR_VIEW =
      ObjectSubtype._(4, _omitEnumNames ? '' : 'REGULAR_VIEW');
  static const ObjectSubtype MATERIALIZED_VIEW =
      ObjectSubtype._(5, _omitEnumNames ? '' : 'MATERIALIZED_VIEW');
  static const ObjectSubtype NATIVE_SEQUENCE =
      ObjectSubtype._(6, _omitEnumNames ? '' : 'NATIVE_SEQUENCE');
  static const ObjectSubtype FUNCTION =
      ObjectSubtype._(7, _omitEnumNames ? '' : 'FUNCTION');
  static const ObjectSubtype PROCEDURE =
      ObjectSubtype._(8, _omitEnumNames ? '' : 'PROCEDURE');

  static const $core.List<ObjectSubtype> values = <ObjectSubtype>[
    OBJECT_SUBTYPE_UNSPECIFIED,
    ORDINARY_TABLE,
    PARTITIONED_TABLE,
    FOREIGN_TABLE,
    REGULAR_VIEW,
    MATERIALIZED_VIEW,
    NATIVE_SEQUENCE,
    FUNCTION,
    PROCEDURE,
  ];

  static final $core.List<ObjectSubtype?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static ObjectSubtype? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ObjectSubtype._(super.value, super.name);
}

class MetadataCount extends $pb.ProtobufEnum {
  static const MetadataCount COUNT_UNAVAILABLE =
      MetadataCount._(0, _omitEnumNames ? '' : 'COUNT_UNAVAILABLE');
  static const MetadataCount AUTHORITATIVE_TOTAL =
      MetadataCount._(1, _omitEnumNames ? '' : 'AUTHORITATIVE_TOTAL');
  static const MetadataCount COMPLETE_ENUMERATION =
      MetadataCount._(2, _omitEnumNames ? '' : 'COMPLETE_ENUMERATION');
  static const MetadataCount PARTIAL_ENUMERATION =
      MetadataCount._(3, _omitEnumNames ? '' : 'PARTIAL_ENUMERATION');

  static const $core.List<MetadataCount> values = <MetadataCount>[
    COUNT_UNAVAILABLE,
    AUTHORITATIVE_TOTAL,
    COMPLETE_ENUMERATION,
    PARTIAL_ENUMERATION,
  ];

  static final $core.List<MetadataCount?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static MetadataCount? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MetadataCount._(super.value, super.name);
}

class SchemaToolAction extends $pb.ProtobufEnum {
  static const SchemaToolAction CAPTURE_SCHEMA =
      SchemaToolAction._(0, _omitEnumNames ? '' : 'CAPTURE_SCHEMA');
  static const SchemaToolAction COMPARE_SCHEMA =
      SchemaToolAction._(1, _omitEnumNames ? '' : 'COMPARE_SCHEMA');
  static const SchemaToolAction INSPECT_OBJECT =
      SchemaToolAction._(2, _omitEnumNames ? '' : 'INSPECT_OBJECT');
  static const SchemaToolAction DESIGN_COLUMN =
      SchemaToolAction._(3, _omitEnumNames ? '' : 'DESIGN_COLUMN');
  static const SchemaToolAction OBJECT_DEFINITION =
      SchemaToolAction._(4, _omitEnumNames ? '' : 'OBJECT_DEFINITION');

  static const $core.List<SchemaToolAction> values = <SchemaToolAction>[
    CAPTURE_SCHEMA,
    COMPARE_SCHEMA,
    INSPECT_OBJECT,
    DESIGN_COLUMN,
    OBJECT_DEFINITION,
  ];

  static final $core.List<SchemaToolAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SchemaToolAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SchemaToolAction._(super.value, super.name);
}

class PrivilegeAction extends $pb.ProtobufEnum {
  static const PrivilegeAction INSPECT_PRIVILEGES =
      PrivilegeAction._(0, _omitEnumNames ? '' : 'INSPECT_PRIVILEGES');
  static const PrivilegeAction DESIGN_PRIVILEGE =
      PrivilegeAction._(1, _omitEnumNames ? '' : 'DESIGN_PRIVILEGE');

  static const $core.List<PrivilegeAction> values = <PrivilegeAction>[
    INSPECT_PRIVILEGES,
    DESIGN_PRIVILEGE,
  ];

  static final $core.List<PrivilegeAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PrivilegeAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PrivilegeAction._(super.value, super.name);
}

/// Credentials exist only in this private launch channel and executing task.
/// Reviews/history contain a redacted operation, never credential-bearing SQL.
class AuthenticationAction extends $pb.ProtobufEnum {
  static const AuthenticationAction CREATE_LOGIN =
      AuthenticationAction._(0, _omitEnumNames ? '' : 'CREATE_LOGIN');
  static const AuthenticationAction CREATE_ROLE =
      AuthenticationAction._(1, _omitEnumNames ? '' : 'CREATE_ROLE');
  static const AuthenticationAction SET_PASSWORD =
      AuthenticationAction._(2, _omitEnumNames ? '' : 'SET_PASSWORD');
  static const AuthenticationAction LOCK_LOGIN =
      AuthenticationAction._(3, _omitEnumNames ? '' : 'LOCK_LOGIN');
  static const AuthenticationAction UNLOCK_LOGIN =
      AuthenticationAction._(4, _omitEnumNames ? '' : 'UNLOCK_LOGIN');
  static const AuthenticationAction DROP_PRINCIPAL =
      AuthenticationAction._(5, _omitEnumNames ? '' : 'DROP_PRINCIPAL');

  static const $core.List<AuthenticationAction> values = <AuthenticationAction>[
    CREATE_LOGIN,
    CREATE_ROLE,
    SET_PASSWORD,
    LOCK_LOGIN,
    UNLOCK_LOGIN,
    DROP_PRINCIPAL,
  ];

  static final $core.List<AuthenticationAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static AuthenticationAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AuthenticationAction._(super.value, super.name);
}

class PrivilegeScope extends $pb.ProtobufEnum {
  static const PrivilegeScope TABLE_PRIVILEGE =
      PrivilegeScope._(0, _omitEnumNames ? '' : 'TABLE_PRIVILEGE');
  static const PrivilegeScope SCHEMA_PRIVILEGE =
      PrivilegeScope._(1, _omitEnumNames ? '' : 'SCHEMA_PRIVILEGE');
  static const PrivilegeScope DATABASE_PRIVILEGE =
      PrivilegeScope._(2, _omitEnumNames ? '' : 'DATABASE_PRIVILEGE');
  static const PrivilegeScope ROLE_MEMBERSHIP =
      PrivilegeScope._(3, _omitEnumNames ? '' : 'ROLE_MEMBERSHIP');
  static const PrivilegeScope DEFAULT_ROLE =
      PrivilegeScope._(4, _omitEnumNames ? '' : 'DEFAULT_ROLE');

  static const $core.List<PrivilegeScope> values = <PrivilegeScope>[
    TABLE_PRIVILEGE,
    SCHEMA_PRIVILEGE,
    DATABASE_PRIVILEGE,
    ROLE_MEMBERSHIP,
    DEFAULT_ROLE,
  ];

  static final $core.List<PrivilegeScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static PrivilegeScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PrivilegeScope._(super.value, super.name);
}

class ChangeKind extends $pb.ProtobufEnum {
  static const ChangeKind INSERT =
      ChangeKind._(0, _omitEnumNames ? '' : 'INSERT');
  static const ChangeKind UPDATE =
      ChangeKind._(1, _omitEnumNames ? '' : 'UPDATE');
  static const ChangeKind DELETE =
      ChangeKind._(2, _omitEnumNames ? '' : 'DELETE');

  static const $core.List<ChangeKind> values = <ChangeKind>[
    INSERT,
    UPDATE,
    DELETE,
  ];

  static final $core.List<ChangeKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ChangeKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChangeKind._(super.value, super.name);
}

class ToolKind extends $pb.ProtobufEnum {
  static const ToolKind EXPLAIN =
      ToolKind._(0, _omitEnumNames ? '' : 'EXPLAIN');
  static const ToolKind EXPLAIN_ANALYZE =
      ToolKind._(1, _omitEnumNames ? '' : 'EXPLAIN_ANALYZE');
  static const ToolKind ACTIVITY =
      ToolKind._(2, _omitEnumNames ? '' : 'ACTIVITY');
  static const ToolKind LOCKS = ToolKind._(3, _omitEnumNames ? '' : 'LOCKS');
  static const ToolKind STATISTICS =
      ToolKind._(4, _omitEnumNames ? '' : 'STATISTICS');
  static const ToolKind ROLES = ToolKind._(5, _omitEnumNames ? '' : 'ROLES');
  static const ToolKind GRANTS = ToolKind._(6, _omitEnumNames ? '' : 'GRANTS');
  static const ToolKind DEFINITION =
      ToolKind._(7, _omitEnumNames ? '' : 'DEFINITION');
  static const ToolKind SNAPSHOT =
      ToolKind._(8, _omitEnumNames ? '' : 'SNAPSHOT');
  static const ToolKind EXPORT_RESULT =
      ToolKind._(9, _omitEnumNames ? '' : 'EXPORT_RESULT');
  static const ToolKind IMPORT_CSV =
      ToolKind._(10, _omitEnumNames ? '' : 'IMPORT_CSV');
  static const ToolKind IMPORT_JSON =
      ToolKind._(11, _omitEnumNames ? '' : 'IMPORT_JSON');
  static const ToolKind DUMP = ToolKind._(12, _omitEnumNames ? '' : 'DUMP');
  static const ToolKind RESTORE =
      ToolKind._(13, _omitEnumNames ? '' : 'RESTORE');
  static const ToolKind CANCEL_ACTIVITY =
      ToolKind._(14, _omitEnumNames ? '' : 'CANCEL_ACTIVITY');
  static const ToolKind TERMINATE_ACTIVITY =
      ToolKind._(15, _omitEnumNames ? '' : 'TERMINATE_ACTIVITY');
  static const ToolKind EXPORT_QUERY =
      ToolKind._(16, _omitEnumNames ? '' : 'EXPORT_QUERY');
  static const ToolKind QUERY_STATISTICS =
      ToolKind._(17, _omitEnumNames ? '' : 'QUERY_STATISTICS');
  static const ToolKind INDEX_DIAGNOSTICS =
      ToolKind._(18, _omitEnumNames ? '' : 'INDEX_DIAGNOSTICS');

  static const $core.List<ToolKind> values = <ToolKind>[
    EXPLAIN,
    EXPLAIN_ANALYZE,
    ACTIVITY,
    LOCKS,
    STATISTICS,
    ROLES,
    GRANTS,
    DEFINITION,
    SNAPSHOT,
    EXPORT_RESULT,
    IMPORT_CSV,
    IMPORT_JSON,
    DUMP,
    RESTORE,
    CANCEL_ACTIVITY,
    TERMINATE_ACTIVITY,
    EXPORT_QUERY,
    QUERY_STATISTICS,
    INDEX_DIAGNOSTICS,
  ];

  static final $core.List<ToolKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 18);
  static ToolKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ToolKind._(super.value, super.name);
}

class ImportPolicy extends $pb.ProtobufEnum {
  static const ImportPolicy ATOMIC_IMPORT =
      ImportPolicy._(0, _omitEnumNames ? '' : 'ATOMIC_IMPORT');
  static const ImportPolicy COMMIT_BATCHES =
      ImportPolicy._(1, _omitEnumNames ? '' : 'COMMIT_BATCHES');
  static const ImportPolicy SKIP_INVALID_ROWS =
      ImportPolicy._(2, _omitEnumNames ? '' : 'SKIP_INVALID_ROWS');

  static const $core.List<ImportPolicy> values = <ImportPolicy>[
    ATOMIC_IMPORT,
    COMMIT_BATCHES,
    SKIP_INVALID_ROWS,
  ];

  static final $core.List<ImportPolicy?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ImportPolicy? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ImportPolicy._(super.value, super.name);
}

class HistoryAction extends $pb.ProtobufEnum {
  static const HistoryAction SEARCH_HISTORY =
      HistoryAction._(0, _omitEnumNames ? '' : 'SEARCH_HISTORY');
  static const HistoryAction CLEAR_HISTORY =
      HistoryAction._(1, _omitEnumNames ? '' : 'CLEAR_HISTORY');
  static const HistoryAction SET_PRIVACY =
      HistoryAction._(2, _omitEnumNames ? '' : 'SET_PRIVACY');
  static const HistoryAction DELETE_HISTORY_ENTRY =
      HistoryAction._(3, _omitEnumNames ? '' : 'DELETE_HISTORY_ENTRY');

  static const $core.List<HistoryAction> values = <HistoryAction>[
    SEARCH_HISTORY,
    CLEAR_HISTORY,
    SET_PRIVACY,
    DELETE_HISTORY_ENTRY,
  ];

  static final $core.List<HistoryAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static HistoryAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HistoryAction._(super.value, super.name);
}

/// Local recovery records remain Java-owned. Rebinding never executes source SQL.
class EditDraftAction extends $pb.ProtobufEnum {
  static const EditDraftAction LIST_EDIT_DRAFTS =
      EditDraftAction._(0, _omitEnumNames ? '' : 'LIST_EDIT_DRAFTS');
  static const EditDraftAction SAVE_EDIT_DRAFT =
      EditDraftAction._(1, _omitEnumNames ? '' : 'SAVE_EDIT_DRAFT');
  static const EditDraftAction REBIND_EDIT_DRAFT =
      EditDraftAction._(2, _omitEnumNames ? '' : 'REBIND_EDIT_DRAFT');
  static const EditDraftAction DELETE_EDIT_DRAFT =
      EditDraftAction._(3, _omitEnumNames ? '' : 'DELETE_EDIT_DRAFT');

  static const $core.List<EditDraftAction> values = <EditDraftAction>[
    LIST_EDIT_DRAFTS,
    SAVE_EDIT_DRAFT,
    REBIND_EDIT_DRAFT,
    DELETE_EDIT_DRAFT,
  ];

  static final $core.List<EditDraftAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static EditDraftAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EditDraftAction._(super.value, super.name);
}

class MetadataSettingsAction extends $pb.ProtobufEnum {
  static const MetadataSettingsAction READ_METADATA_SETTINGS =
      MetadataSettingsAction._(
          0, _omitEnumNames ? '' : 'READ_METADATA_SETTINGS');
  static const MetadataSettingsAction SAVE_METADATA_SETTINGS =
      MetadataSettingsAction._(
          1, _omitEnumNames ? '' : 'SAVE_METADATA_SETTINGS');
  static const MetadataSettingsAction FULL_METADATA_REFRESH =
      MetadataSettingsAction._(
          2, _omitEnumNames ? '' : 'FULL_METADATA_REFRESH');
  static const MetadataSettingsAction INCREMENTAL_METADATA_REFRESH =
      MetadataSettingsAction._(
          3, _omitEnumNames ? '' : 'INCREMENTAL_METADATA_REFRESH');

  static const $core.List<MetadataSettingsAction> values =
      <MetadataSettingsAction>[
    READ_METADATA_SETTINGS,
    SAVE_METADATA_SETTINGS,
    FULL_METADATA_REFRESH,
    INCREMENTAL_METADATA_REFRESH,
  ];

  static final $core.List<MetadataSettingsAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static MetadataSettingsAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MetadataSettingsAction._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
