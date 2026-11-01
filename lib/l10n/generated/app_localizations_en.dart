// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get databaseExplorer => 'Database Explorer';

  @override
  String get databases => 'Databases';

  @override
  String get newConnection => 'New connection';

  @override
  String get filterTree => 'Filter connections and objects';

  @override
  String get treeFilterScope => 'Filters loaded tree objects';

  @override
  String get searchObjects => 'Search database objects';

  @override
  String get fileMenu => 'File';

  @override
  String get editMenu => 'Edit';

  @override
  String get viewMenu => 'View';

  @override
  String get connectionMenu => 'Connection';

  @override
  String get objectMenu => 'Object';

  @override
  String get runMenu => 'Run options';

  @override
  String get commands => 'Commands';

  @override
  String get findCommand => 'Find command';

  @override
  String get newSql => 'New query';

  @override
  String get openSql => 'Open SQL';

  @override
  String get openSqlFile => 'Open SQL file';

  @override
  String get saveSql => 'Save SQL';

  @override
  String get closeTab => 'Close tab';

  @override
  String get openWorkspace => 'Open workspace';

  @override
  String get saveWorkspace => 'Save workspace';

  @override
  String get settings => 'Settings';

  @override
  String get findText => 'Find';

  @override
  String get replaceText => 'Replace';

  @override
  String get formatSql => 'Format SQL';

  @override
  String get lineComments => 'Toggle line comments';

  @override
  String get snippets => 'SQL snippets';

  @override
  String get run => 'Run';

  @override
  String get runStatement => 'Run current statement';

  @override
  String get runSelection => 'Run selection';

  @override
  String get runScript => 'Run script';

  @override
  String get explain => 'Explain';

  @override
  String get explainAnalyze => 'Explain analyze';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get sessionDetails => 'Session details';

  @override
  String get beginTransaction => 'Begin transaction';

  @override
  String get commitTransaction => 'Commit transaction';

  @override
  String get rollbackTransaction => 'Roll back transaction';

  @override
  String get enableAutoCommit => 'Enable auto-commit';

  @override
  String get disableAutoCommit => 'Disable auto-commit';

  @override
  String get outcomeUnknown => 'Outcome unknown';

  @override
  String get outcomeUnknownNote =>
      'The operation may have completed. This session cannot run further SQL. Never retry automatically; reconcile the outcome before starting new work.';

  @override
  String get notConnected => 'Disconnected';

  @override
  String get autoCommit => 'Auto-commit';

  @override
  String get manualTransaction => 'Manual transaction';

  @override
  String get readOnlyPolicy => 'BusyData read-only policy';

  @override
  String get data => 'Data';

  @override
  String get structure => 'Structure';

  @override
  String get results => 'Results';

  @override
  String get messages => 'Messages';

  @override
  String get plan => 'Plan';

  @override
  String get changes => 'Changes';

  @override
  String get history => 'History';

  @override
  String get jobs => 'Jobs';

  @override
  String get retainedResults => 'Retained results';

  @override
  String get recoverEdits => 'Recover staged changes';

  @override
  String get applyAndCommit => 'Apply and commit';

  @override
  String get inspectStructure => 'Inspect structure';

  @override
  String get openData => 'Open data';

  @override
  String get openDefinition => 'Open definition';

  @override
  String get copyQualifiedName => 'Copy qualified name';

  @override
  String get refresh => 'Refresh';

  @override
  String get columns => 'Columns';

  @override
  String get indexes => 'Indexes';

  @override
  String get constraints => 'Keys and constraints';

  @override
  String get foreignKeys => 'Foreign keys';

  @override
  String get triggers => 'Triggers';

  @override
  String get definition => 'Definition';

  @override
  String get dependencies => 'Dependencies';

  @override
  String get connectionCapabilities => 'Connection overview';

  @override
  String get sessionsAndLocks => 'Sessions and locks';

  @override
  String get usersAndRoles => 'Users and roles';

  @override
  String get saveSnapshot => 'Save schema snapshot';

  @override
  String get compareSchemas => 'Compare schemas';

  @override
  String get objectDesigner => 'Object designer';

  @override
  String get diagram => 'ER diagram';

  @override
  String get backup => 'Backup';

  @override
  String get restore => 'Restore';

  @override
  String get importData => 'Import data';

  @override
  String get exportRetained => 'Export retained data';

  @override
  String get exportSql => 'Run SQL export';

  @override
  String get stageInsert => 'Insert row';

  @override
  String get stageUpdate => 'Edit row';

  @override
  String get stageDelete => 'Delete row';

  @override
  String get discardChanges => 'Discard pending changes';

  @override
  String get disposeResult => 'Dispose retained data';

  @override
  String get currentSchema => 'Current schema (to be changed)';

  @override
  String get desiredSchema => 'Desired schema';

  @override
  String get applyTo => 'Apply to';

  @override
  String get loading => 'Loading';

  @override
  String get empty => 'No objects in this scope';

  @override
  String get more => 'More';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get selectTarget => 'Choose connection';

  @override
  String get requireSql => 'Requires a SQL document';

  @override
  String get requireSession => 'Requires a connected, known session';

  @override
  String get requireResult => 'Requires retained data';

  @override
  String get requireObject => 'Requires an object target';

  @override
  String get cancelRequested => 'Cancellation requested';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get queued => 'Queued';

  @override
  String get running => 'Running';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String get partial => 'Partial';

  @override
  String get sessionSharing => 'Share an existing session (advanced)';

  @override
  String get production => 'Production';

  @override
  String get staging => 'Staging';

  @override
  String get development => 'Development';

  @override
  String get executionOptions => 'Execution options';

  @override
  String get resultRowLimit => 'Result row limit (1–1000000)';

  @override
  String get boundedRead => 'Bounded read';

  @override
  String get streamingRead => 'Streaming read · owns a read transaction';

  @override
  String get stopOnError => 'Stop script on error';

  @override
  String get continueOnError =>
      'Continue on error · prior statements may have committed';

  @override
  String get loadMore => 'Load more';

  @override
  String get favorite => 'Toggle favorite';

  @override
  String get connectionGroup => 'Connection group';

  @override
  String get copyRange => 'Copy range';

  @override
  String get inspectValue => 'Inspect value';

  @override
  String get editConnection => 'Edit connection';

  @override
  String get chooseSnapshot => 'Choose snapshot';

  @override
  String get captureSchema => 'Capture schema';

  @override
  String get sameSchemaRestriction =>
      'Snapshots must have the same engine, schema name and snapshot version. Comparing and saving never applies changes.';

  @override
  String get restoredTaskState =>
      'This document reference was restored. Previous backend evidence, sessions and jobs are unavailable. Choose an explicit action to inspect or start new work; restoration never connects, executes SQL or replays changes.';

  @override
  String get preChangeSnapshot =>
      'Pre-change snapshot · changes committed. Refresh explicitly to inspect current rows and server defaults.';

  @override
  String get sqlProvenance => 'SQL provenance';

  @override
  String get assessEditing => 'Assess editing';

  @override
  String get viewDetails => 'View details';

  @override
  String get gridMenu => 'Data grid';

  @override
  String get visibleColumns => 'Visible columns';

  @override
  String get hidden => 'Hidden';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get equals => 'Equals';

  @override
  String get notEqual => 'Does not equal';

  @override
  String get lessThan => 'Less than';

  @override
  String get greaterThan => 'Greater than';

  @override
  String get isNull => 'Is NULL';

  @override
  String get isNotNull => 'Is not NULL';

  @override
  String get exactValue => 'Exact value';

  @override
  String get sortTable => 'Sort table data';

  @override
  String get filterTable => 'Filter table data';

  @override
  String get sortRetained => 'Sort retained snapshot';

  @override
  String get filterRetained => 'Filter retained snapshot';

  @override
  String get applyView => 'Apply';

  @override
  String get rowsLabel => 'Rows';

  @override
  String get fetchedRows => 'Fetched rows';

  @override
  String get fixedSnapshot => 'Fixed fetched-row snapshot';

  @override
  String get limitReached => 'Limit reached';

  @override
  String get retainedData => 'Retained data';

  @override
  String get applyRequiresAutoCommit =>
      'Apply and commit requires an idle session with auto-commit enabled.';

  @override
  String get connectionProfile => 'Connection profile';

  @override
  String get basic => 'Basic';

  @override
  String get advanced => 'Advanced';

  @override
  String get connectionName => 'Name';

  @override
  String get hostname => 'Hostname (also used for TLS verification)';

  @override
  String get port => 'Port';

  @override
  String get database => 'Database';

  @override
  String get user => 'User';

  @override
  String get password => 'Password';

  @override
  String get writableProfile => 'Writable profile';

  @override
  String get readonlyProfile => 'Read-only profile';

  @override
  String get tlsVerify => 'TLS: verify certificate and hostname';

  @override
  String get tlsInsecure => 'TLS: INSECURE, do not verify';

  @override
  String get tlsDisabled => 'TLS: DISABLED';

  @override
  String get testConnection => 'Test without saving';

  @override
  String get saveProfile => 'Save';

  @override
  String get saveConnect => 'Save & connect';

  @override
  String get sessionPassword => 'Session-only password';

  @override
  String get storedPassword => 'Store password in OS secure storage';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get testRunning => 'Testing connection…';

  @override
  String get cancelTest => 'Cancel test';

  @override
  String get idle => 'Idle';

  @override
  String get activeTransaction => 'Transaction open';

  @override
  String get failedTransaction => 'Transaction failed';

  @override
  String get inspectionContext => 'Inspection session';

  @override
  String get requireTableOrView => 'Select a table or view';

  @override
  String get operationPending =>
      'A document operation is awaiting acknowledgement';

  @override
  String get requirePlan => 'Select a retained Explain execution';

  @override
  String get openPlanDocument => 'Open plan document';

  @override
  String get locks => 'Locks';

  @override
  String get statistics => 'Statistics';

  @override
  String get queryStatistics => 'Query statistics';

  @override
  String get indexDiagnostics => 'Index diagnostics';

  @override
  String get grants => 'Grants';

  @override
  String get sqlExecution => 'SQL execution';

  @override
  String get planReady => 'Retained plan ready; SQL was not rerun';

  @override
  String get executionPlan => 'Execution plan';

  @override
  String get openOwner => 'Open owner';

  @override
  String get terminateActivity => 'Terminate activity';

  @override
  String get close => 'Close';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get replaceSelection => 'Replace selection';

  @override
  String get replaceAll => 'Replace all';

  @override
  String get restartBackend => 'Restart backend';

  @override
  String get structuredTree => 'Structured tree';

  @override
  String get rawOutput => 'Raw output';

  @override
  String get previousTextPage => 'Previous text page';

  @override
  String get nextTextPage => 'Next text page';

  @override
  String get filterChangedObjects => 'Filter changed objects';

  @override
  String get rebindVerifiedEdits => 'Rebind verified edits';

  @override
  String get discardRecoveryRecord => 'Discard recovery record';

  @override
  String get revertChange => 'Revert pending change';

  @override
  String get chooseSource => 'Choose source';

  @override
  String get chooseDestination => 'Choose destination';

  @override
  String get delimiterField => 'Delimiter (one character)';

  @override
  String get batchRowsField => 'Rows per batch (1–1000)';

  @override
  String get rejectedLimit => 'Rejected-row limit (1–1000)';

  @override
  String get previewSource => 'Preview source';

  @override
  String get reviewTransfer => 'Review transfer';

  @override
  String get startImport => 'Start import';

  @override
  String get startRestore => 'Start restore';

  @override
  String get startExport => 'Start export';

  @override
  String get requestCancel => 'Request cancellation';

  @override
  String get sourceMapping => 'Source and target mapping';

  @override
  String get nativeTool => 'Native tool';

  @override
  String get defaultOmit => 'Omit / database default';

  @override
  String get overwriteNever => 'Do not overwrite';

  @override
  String get overwriteExisting => 'Overwrite existing file';

  @override
  String get planDetails => 'Plan details';

  @override
  String get planMetricsNote =>
      'Estimates and actual measurements use the server’s field names. Missing measurements are unavailable.';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get tables => 'Tables';

  @override
  String get views => 'Views';

  @override
  String get routines => 'Routines';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get databaseWorkbench => 'Database workbench';

  @override
  String get sidebar => 'Sidebar';

  @override
  String get unchanged => 'Unchanged';

  @override
  String get reviewDetails => 'Review details';

  @override
  String get generatedSql => 'Generated SQL';

  @override
  String get changeReverted =>
      'Pending change reverted. Request a fresh review.';

  @override
  String get unknownBatch =>
      'Outcome unknown. The batch may have committed. Never replay it automatically; reconcile the session and recovery record.';

  @override
  String get expiredChangeReview =>
      'The target changed or the review expired. Request a fresh review.';

  @override
  String get applyCommitExplanation =>
      'Apply and commit starts and commits its own transaction. The source console must be idle with auto-commit enabled. Resolve manual SQL transactions separately.';

  @override
  String get newRow => 'New row';

  @override
  String get original => 'Original';

  @override
  String get proposed => 'Proposed';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts inserts · $updates updates · $deletes deletes';
  }

  @override
  String sourceRow(String row) {
    return 'Source row $row';
  }

  @override
  String get refreshing => 'Refreshing…';

  @override
  String get refreshActivities => 'Refresh activities';

  @override
  String get explicitRefresh => 'Explicit refresh';

  @override
  String get pollFiveSeconds => 'Poll every 5 seconds';

  @override
  String get cancelSelectedActivity => 'Cancel selected activity';

  @override
  String get terminateSelectedSession => 'Terminate selected session';

  @override
  String get filterActivities => 'Filter current activities';

  @override
  String get blockedBy => 'Blocked by:';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get up => 'Up';

  @override
  String get search => 'Search';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get clear => 'Clear';

  @override
  String get copy => 'Copy';

  @override
  String get insert => 'Insert';

  @override
  String get update => 'Update';

  @override
  String get open => 'Open';

  @override
  String get migrationEngineMismatch =>
      'The Apply to connection must use the same engine as the compared snapshots. Cross-engine migration is unsupported.';

  @override
  String get metadataContextChanged =>
      'Inspection context changed. Refresh metadata explicitly.';

  @override
  String get newTableName => 'New table name';

  @override
  String get routineIdentity => 'Exact routine identity';

  @override
  String get objectColumnName => 'Object / column name';

  @override
  String get builtInType => 'Built-in type';

  @override
  String get sqlExpression => 'SQL expression (empty removes it)';

  @override
  String get newPropertyValue => 'New property value';

  @override
  String get columnComment => 'Column comment';

  @override
  String get columnCollation => 'Column collation (empty uses server default)';

  @override
  String get addDesignedColumn => 'Add column to new table';

  @override
  String get checkExpression => 'CHECK expression';

  @override
  String get referencedSchema => 'Referenced schema / database';

  @override
  String get generating => 'Generating…';

  @override
  String get generateReviewedDdl => 'Generate reviewed DDL';

  @override
  String get inspectCapturedDefinition => 'Inspect captured definition';

  @override
  String get capturedObject => 'Captured object';

  @override
  String get designReviewNote =>
      'Changes are generated for review. Database contents remain unchanged until reviewed execution.';

  @override
  String get columnMetadataUnavailable =>
      'Column metadata unavailable for this scope; inspect the selected schema before designing a column list.';

  @override
  String get ordinaryColumn => 'Ordinary column';

  @override
  String get columnWithDefault => 'Column with default';

  @override
  String get identityColumn => 'Identity / auto-increment';

  @override
  String get generatedColumn => 'Generated column';

  @override
  String get columnType => 'Column type';

  @override
  String get nullableNotNull => 'Nullable / NOT NULL';

  @override
  String get defaultExpression => 'Default expression';

  @override
  String get generatedExpression => 'Generated expression';

  @override
  String get columnCollationProperty => 'Column collation';

  @override
  String get loggedUnlogged => 'Logged / unlogged';

  @override
  String get tableComment => 'Table comment';

  @override
  String get storageEngine => 'Storage engine';

  @override
  String get tableCollation => 'Table collation';

  @override
  String get rowFormat => 'Row format';

  @override
  String get createOrReplace => 'Create or replace';

  @override
  String get dropSelectedObject => 'Drop selected object';

  @override
  String get addColumn => 'Add column';

  @override
  String get editColumnProperties => 'Edit column properties';

  @override
  String get tableProperties => 'Table properties';

  @override
  String get triggerDefinition => 'Trigger definition';

  @override
  String get createTable => 'Create table';

  @override
  String get viewDefinition => 'View definition';

  @override
  String get routineDefinition => 'Routine definition';

  @override
  String get chooseExistingObject => 'Choose existing object';

  @override
  String get nullable => 'Nullable';

  @override
  String get removeIdentity => 'Remove identity';

  @override
  String get generatedAlways => 'Generated always';

  @override
  String get generatedByDefault => 'Generated by default / auto-increment';

  @override
  String get loggedTable => 'Logged table';

  @override
  String get unloggedTable => 'Unlogged table';

  @override
  String get orderedPrimaryKeyColumns => 'Ordered primary-key columns';

  @override
  String get orderedColumns => 'Ordered columns';

  @override
  String get ordinaryIndex => 'Ordinary index';

  @override
  String get uniqueIndex => 'Unique index';

  @override
  String get primaryKey => 'Primary key';

  @override
  String get uniqueConstraint => 'Unique constraint';

  @override
  String get foreignKey => 'Foreign key';

  @override
  String get checkConstraint => 'CHECK constraint';

  @override
  String get immediateChecking => 'Immediate checking';

  @override
  String get deferrableChecking => 'Deferrable checking';

  @override
  String get initiallyImmediate => 'Initially immediate';

  @override
  String get initiallyDeferred => 'Initially deferred';

  @override
  String get referencedTable => 'Referenced table';

  @override
  String get orderedReferencedColumns => 'Referenced columns in matching order';

  @override
  String get objectDefinitionEditor => 'Native object definition SQL editor';

  @override
  String get onDelete => 'On delete';

  @override
  String get onUpdate => 'On update';

  @override
  String get stay => 'Stay';

  @override
  String get saveSqlClose => 'Save SQL and close';

  @override
  String get discardSqlClose => 'Discard SQL and close';

  @override
  String get closeBusyData => 'Close BusyData';

  @override
  String get saveDraftsClose => 'Save drafts and close';

  @override
  String get closeWithoutRecovery => 'Close without recovery';

  @override
  String get recoveryFailed => 'Recovery failed';

  @override
  String get discardFailedSaveClose => 'Discard failed save and close';

  @override
  String get closeWithoutSavingRecovery => 'Close without saving recovery';

  @override
  String get disableSqlRecovery => 'Disable SQL recovery';

  @override
  String get historyPrivacy => 'History privacy';

  @override
  String get enableSqlRetention => 'Enable SQL retention';

  @override
  String get disableSqlRetention => 'Disable SQL retention';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get deleteHistoryEntry => 'Delete history entry';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String get saveRetention => 'Save retention';

  @override
  String get retentionDays => 'Retention days';

  @override
  String get sqlTextRetained => 'SQL text retained';

  @override
  String get sqlTextDisabled => 'SQL text disabled';

  @override
  String get openHistoryQuery => 'Open as new SQL tab';

  @override
  String get caCertificateFile => 'CA certificate file';

  @override
  String get clientCertificateFile => 'Client certificate file';

  @override
  String get clientKeyFile => 'Client key file';

  @override
  String get directConnection => 'Direct connection';

  @override
  String get sshTunnel => 'SSH tunnel';

  @override
  String get sshHost => 'SSH host';

  @override
  String get sshPort => 'SSH port';

  @override
  String get sshUser => 'SSH user';

  @override
  String get reviewedKnownHosts => 'Reviewed known_hosts file';

  @override
  String get reviewSshKey => 'Review SSH host key';

  @override
  String get changedSshKey => 'Changed SSH host key';

  @override
  String get verifyFingerprint =>
      'Verify this fingerprint independently before trusting it.';

  @override
  String get selectedKeyPassword => 'Selected key or password';

  @override
  String get selectedAgentIdentity => 'Selected SSH-agent identity';

  @override
  String get selectedAgentSocket =>
      'Selected Linux agent socket / Windows named pipe';

  @override
  String get selectedKeyFingerprint => 'Selected key fingerprint · SHA256:…';

  @override
  String get selectedPrivateKey => 'Selected private key (optional)';

  @override
  String get sshPassword => 'SSH password';

  @override
  String get keyPassphrase => 'Key passphrase';

  @override
  String get connectionTimeout => 'Connection timeout · 1–120 seconds';

  @override
  String get sqlTimeout =>
      'SQL execution/fetch deadline · 1–3600 seconds (0 = 60)';

  @override
  String get schemasEquivalent => 'Captured schemas are equivalent.';

  @override
  String get migrationComplete =>
      'Migration covers supported captured differences.';

  @override
  String get migrationPartial =>
      'Partial migration; unsupported differences remain.';

  @override
  String get differencesLimited =>
      'Difference presentation is limited. Review the complete saved snapshots and generated SQL.';

  @override
  String get absent => 'Absent';

  @override
  String get definitionPreviewLimited =>
      'Definition preview is limited; use the original snapshot for full evidence.';

  @override
  String get migrationBatchNote =>
      'SQL is one dependency-ordered batch. Individual object selection is for inspection and does not select statements for application.';

  @override
  String get unsupportedLabel => 'Unsupported';

  @override
  String get differenceAdded => 'Added';

  @override
  String get differenceRemoved => 'Removed';

  @override
  String get differenceChanged => 'Changed';

  @override
  String get selectHistoryEntry => 'Select a history entry';

  @override
  String get searchSqlTarget => 'Search SQL or target';

  @override
  String get closeSqlTab => 'Close SQL tab';

  @override
  String get historyMetadataRetained =>
      'Status and target metadata remain in history.';

  @override
  String get historyPreviewNote =>
      'Preview only. Open as new SQL tab to retrieve retained text.';

  @override
  String get selected => 'Selected';

  @override
  String get authReviewNote =>
      'Review the exact principal and target before applying. Credentials are never put in SQL documents or history. Existing connections and saved passwords remain separate.';

  @override
  String get createLogin => 'Create login account';

  @override
  String get createRole => 'Create non-login role';

  @override
  String get setPassword => 'Set password';

  @override
  String get preventLogin => 'Prevent new logins';

  @override
  String get allowLogin => 'Allow new logins';

  @override
  String get dropPrincipal => 'Drop principal';

  @override
  String get principalName => 'Exact principal name';

  @override
  String get accountHost =>
      'Exact account host (wildcards grant broad login scope)';

  @override
  String get newPassword => 'New password';

  @override
  String get repeatPassword => 'Repeat new password';

  @override
  String get reviewAccount => 'Review account operation';

  @override
  String get passwordsMismatch => 'Enter the same nonempty password twice';

  @override
  String get accountSubmitFailed =>
      'Account operation could not be submitted. Check the target, authentication policy and database privileges.';

  @override
  String get privilegeReviewNote =>
      'Inspect direct grants; generated SQL still requires execution review.';

  @override
  String get inspectionLimited =>
      'Limited to 500 rows per section. Narrow the search; an empty section does not prove absence of effective access.';

  @override
  String get findPrincipal => 'Find user / role name';

  @override
  String get searchPrincipals => 'Search principals';

  @override
  String get choosePrincipal => 'Choose a principal';

  @override
  String get inspectGrants => 'Inspect selected grants';

  @override
  String get tablePrivileges => 'Table / view privileges';

  @override
  String get schemaPrivileges => 'Schema privileges';

  @override
  String get databasePrivileges => 'Database privileges';

  @override
  String get roleMembership => 'Role membership';

  @override
  String get defaultRole => 'Default role activation';

  @override
  String get chooseGrantRole => 'Choose the role to grant / revoke';

  @override
  String get tableView => 'Table / view';

  @override
  String get explicitPrivileges => 'Explicit privileges (comma separated)';

  @override
  String get setDefaultRole => 'Set selected default role';

  @override
  String get clearDefaultRole => 'Clear default role';

  @override
  String get grantAccess => 'Grant access';

  @override
  String get revokeAccess => 'Revoke access';

  @override
  String get withoutDelegation => 'Without delegation';

  @override
  String get allowDelegation => 'Allow recipient to grant to others';

  @override
  String get readonlyChanges =>
      'This profile is read-only. Changes require an explicitly writable session.';

  @override
  String get createPrincipal => 'Create user / role';

  @override
  String get manageAuthentication => 'Manage selected authentication';

  @override
  String get openPrivilegeSql => 'Open privilege SQL for review';

  @override
  String get inspectPrincipalFirst =>
      'Inspect the selected principal before drafting a change';

  @override
  String get accountAuthentication => 'Account authentication';

  @override
  String get schema => 'Schema';

  @override
  String get available => 'Available';

  @override
  String get availableEmpty => 'Available · empty data';

  @override
  String get limitedVisibility => 'Limited visibility or scope';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get profileDisabled => 'Disabled by profile';

  @override
  String get unknownState => 'Unknown';

  @override
  String get inspecting => 'Inspecting…';

  @override
  String get refreshCapabilities => 'Refresh capabilities';

  @override
  String get staleRefresh => 'Stale · refresh after connecting';

  @override
  String get staleContext =>
      'Stale · refresh after connecting or changing context';

  @override
  String get partialTreeLimit =>
      'Partial · tree limit reached; narrow with database object search';

  @override
  String get schemaComparison => 'Schema comparison';

  @override
  String get searchTable => 'Search table';

  @override
  String get focusObject => 'Focus';

  @override
  String get exportSvg => 'Export SVG';

  @override
  String get exportPng => 'Export PNG';

  @override
  String get diagramNotes => 'Diagram notes (included in SVG)';

  @override
  String get openNotes => 'Open notes';

  @override
  String get saveNotes => 'Save notes';

  @override
  String get newSnippet => 'New snippet';

  @override
  String get snippetName => 'Snippet name';

  @override
  String get saveSnippet => 'Save snippet';

  @override
  String get deleteSnippet => 'Delete saved snippet';

  @override
  String get insertSnippet => 'Insert into SQL document';

  @override
  String get snippetEditor => 'SQL snippet editor';

  @override
  String get snippetsNote =>
      'Insert saved local SQL into the captured document with undo. Execution remains explicit.';

  @override
  String get level => 'Level';

  @override
  String get expanded => 'expanded';

  @override
  String get collapsed => 'collapsed';

  @override
  String get treeLevel => 'level';

  @override
  String get retainedView => 'Retained view';

  @override
  String get tableQuerySnapshot => 'Table query snapshot';

  @override
  String get originalResultNote =>
      'Original retained result; SQL is not executed by paging or inspection';

  @override
  String get tableFilterNote =>
      'Apply submits a new reviewed database query. The previous snapshot remains available.';

  @override
  String get retainedFilterNote =>
      'All fetched rows in a fixed snapshot. SQL is not rerun. Retained ordering can differ from database collation.';

  @override
  String get retainedRowNote =>
      'Choose a row within the already fetched result. SQL is not rerun.';

  @override
  String get copyLimitNote =>
      'Copy is limited to 10,000 cells; export retained data for larger ranges.';

  @override
  String get inlineValueLimit => 'Inline edits support 8KiB values';

  @override
  String get editContextChanged =>
      'The source session or editability context changed; inspect or refresh the assessment before staging';

  @override
  String get editAssessmentUnavailable =>
      'Editability unavailable; refresh assessment after the session is idle';

  @override
  String get rowChangeReverted =>
      'Pending row change reverted; database unchanged';

  @override
  String get sqlCopyRequiresMetadata =>
      'SQL copy requires the backend and its retained type metadata.';

  @override
  String get exportFullValue => 'Export full retained value';

  @override
  String valueExportReview(String bytes, String path) {
    return 'Save $bytes bytes to $path? Existing contents will be replaced. SQL is not rerun.';
  }

  @override
  String get goToRetainedRow => 'Go to retained row';

  @override
  String get row => 'Row';

  @override
  String get go => 'Go';

  @override
  String get retryRows => 'Retry retained rows';

  @override
  String get previousRows => 'Previous rows';

  @override
  String get nextRows => 'Next rows';

  @override
  String get firstWindow => 'First retained window';

  @override
  String get lastWindow => 'Last fetched window';

  @override
  String get setNull => 'Set NULL';

  @override
  String copyFormat(String format) {
    return 'Copy $format';
  }

  @override
  String get textValue => 'Text';

  @override
  String get sqlValues => 'SQL values';

  @override
  String get rowSelection => 'Row selection';

  @override
  String selectRow(String row) {
    return 'Select row $row';
  }

  @override
  String columnHeader(String column) {
    return 'Column $column';
  }

  @override
  String get pendingChange => 'pending change';

  @override
  String get readonlyCell => 'Read-only cell';

  @override
  String get editableCell => 'Editable cell';

  @override
  String get loadValueFirst => 'Load this retained value first';

  @override
  String get editUnavailable => 'Editability is not available';

  @override
  String get editCell => 'Edit cell';

  @override
  String get unsupportedEditValue =>
      'This retained value supports inspection only';

  @override
  String bytesCount(String bytes) {
    return '$bytes bytes';
  }

  @override
  String get problems => 'Problems';

  @override
  String get ownedSessions => 'Owned sessions';

  @override
  String get noProblems => 'No recorded problems';

  @override
  String get duplicateConnection => 'Duplicate connection';

  @override
  String get deleteConnection => 'Delete connection';

  @override
  String deleteConnectionReview(String name) {
    return 'Delete $name? Existing physical sessions keep their original settings.';
  }

  @override
  String get unresolvedSessions => 'Unresolved sessions';

  @override
  String get disconnectSessionNote =>
      'Resolve active jobs and transactions first. Disconnect affects every client of this physical session; it never commits or replays SQL. Unknown outcomes remain unknown.';

  @override
  String get transferSettingsChanged =>
      'Transfer settings changed; review again';

  @override
  String get transferReviewReady =>
      'Review ready · verify target, scope, mapping and file behavior before starting';

  @override
  String get sourcePreviewNotice =>
      'Source preview · no database rows imported';

  @override
  String get transferRequiresReview => 'Review this exact transfer first';

  @override
  String get transferSubmittedNotice =>
      'Submitted · cancellation does not undo acknowledged commits or published files';

  @override
  String get sqlExportExecutionNote => 'A new reviewed SQL execution';

  @override
  String get retainedExportSnapshotNote =>
      'Fetched snapshot; SQL is not executed';

  @override
  String get restorePartialCommitNote =>
      'Restore may partially commit. Cancelling does not undo the restore.';

  @override
  String get sourcePreviewLimit => 'Source preview · up to 20 rows';

  @override
  String get importBatchSafetyNote =>
      'Errors or cancellation preserve earlier batch commits. Source hashes and selected immutable material are verified before dispatch.';

  @override
  String get nullMarkerLiteralNote =>
      'Unquoted NULL marker; quoted marker is literal text';

  @override
  String immutableSourceHash(String hash) {
    return 'Immutable source SHA-256: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'Source column $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'Preview row $row, $column: $value';
  }

  @override
  String get transferCancellationNotice =>
      'Cancellation requested · wait for acknowledgement';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed processed · $committed committed · $rejected rejected';
  }

  @override
  String get importAtomicPolicy => 'All rows in one transaction';

  @override
  String get importBatchPolicy => 'Commit batches; stop on error';

  @override
  String get importSkipPolicy => 'Skip invalid rows; commit batches';

  @override
  String closeWorkCounts(
    String operations,
    String documents,
    String saves,
    String edits,
    String jobs,
    String transactions,
    String unknown,
    String sessions,
  ) {
    return 'Acknowledgements/connections: $operations\nUnsaved documents: $documents\nSaves in progress: $saves\nStaged edits: $edits\nActive jobs: $jobs\nTransactions requiring cleanup: $transactions\nUnknown operation outcomes: $unknown\nUncertain sessions: $sessions';
  }

  @override
  String get closeDraftSaved => 'SQL drafts will be saved locally.';

  @override
  String get closeDraftLost =>
      'Recovery is disabled; unsaved SQL and object designs will be lost.';

  @override
  String get closeDesignRecovery =>
      'Object designs use private bounded recovery. Reconnect and inspect metadata explicitly after reopening.';

  @override
  String get closeCleanupReview =>
      'Closing a final session owner requests cancellation, rolls back acknowledged transactions and disconnects. Unknown outcomes remain unknown; SQL is never committed or replayed.';

  @override
  String get closeSharedSession =>
      'Other clients retain their shared physical session.';

  @override
  String get closeStagedRecovery =>
      'Pending changes require acknowledged private recovery, explicit reconnection and a fresh review.';

  @override
  String get closeRecoveryLoss =>
      'Latest documents and layout could not be saved. Closing may lose unsaved SQL and pending changes; existing files and recovery data are preserved.';

  @override
  String get closeWaitNotice =>
      'Wait for pending acknowledgements and connection cleanup before closing.';

  @override
  String get saveFailedNotice =>
      'SQL save failed. Preserve the dirty SQL or explicitly discard it.';

  @override
  String get closeCleanupFailed =>
      'Backend cleanup failed; BusyData remains open.';

  @override
  String get closeBackendUnverified =>
      'Backend status is unverified; work may still be pending.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL can contain secrets. Store SQL text for $days days?';
  }

  @override
  String get historyStopSqlReview =>
      'Stop storing SQL text and remove it from existing history?';

  @override
  String get historyClearReview =>
      'Delete all history? Active operations can record their outcome when they finish.';

  @override
  String get historyDeleteReview => 'Delete the selected history entry?';

  @override
  String get historyRetentionRange => 'Retention must be 1–3650 days';

  @override
  String get enableSqlHistory => 'Enable SQL history';

  @override
  String get stopSqlHistory => 'Stop SQL retention';

  @override
  String get recoveryDiscardReview =>
      'Discard this recovery record? Reconcile unknown outcomes first; discarding never undoes committed changes.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'Unsaved SQL: $unsaved\nPending changes: $edits\nActive jobs: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'Recovery failed. BusyData remains open; unsaved work is preserved.';

  @override
  String get commitUncertaintyNote =>
      'A network failure can leave the commit outcome unknown. Never retry automatically.';

  @override
  String get closeObjectDesignDiscard =>
      'Unsaved object design fields will be discarded. Generate and save SQL first to retain the design.';

  @override
  String get savePrivateDrafts => 'Save private recovery drafts';

  @override
  String get noPrivateDrafts => 'Do not save recovery drafts';

  @override
  String shortcutField(String command) {
    return '$command shortcut';
  }

  @override
  String get shortcutInvalid =>
      'Use a valid shortcut that is not assigned to another action. F6 and Shift+F6 are reserved.';

  @override
  String get disableRecoveryReview =>
      'Delete local SQL, design and staged-change recovery? Unsaved work stays open; a crash can lose it. Reconcile unknown outcomes first.';

  @override
  String get preferencesSaved => 'Settings saved';

  @override
  String get sharingSessionReview =>
      'This query shares the named physical session, transaction, temporary objects and settings with its listed clients. Closing one client preserves the others.';

  @override
  String get recoveryReconcileFirst =>
      'Reconcile applying or unknown changes before disabling recovery. Discard recovery records only through their explicit review.';

  @override
  String get enterSearchText => 'Enter search text';

  @override
  String get noSearchMatches => 'No matches';

  @override
  String searchMatchCount(String position, String total) {
    return '$position of $total matches';
  }

  @override
  String get formatSqlChanged =>
      'SQL or target changed. Original SQL preserved; request a fresh format preview.';

  @override
  String get formatSqlUnavailable =>
      'Formatting unavailable for incomplete or unsupported syntax or analysis limits. Original SQL preserved.';

  @override
  String get stageChange => 'Stage change';

  @override
  String pendingChangesCount(String count) {
    return '$count pending changes; database unchanged until reviewed application.';
  }

  @override
  String discardChangesCount(String count) {
    return 'Discard $count pending changes? No database operation is submitted.';
  }

  @override
  String get recoveryNoExecution =>
      'Recovery never connects, runs source SQL, resumes transactions or replays changes. Unknown and committed records cannot be reapplied.';

  @override
  String get recoveredDesign =>
      'Recovered design. Connect explicitly and inspect current metadata before generating a fresh review. Restoration fetched no SQL or metadata.';

  @override
  String get retainedUnavailable =>
      'Retained data unavailable. Saved SQL and private recovery remain local.';

  @override
  String get activityFingerprintNote =>
      'The selected activity fingerprint is revalidated before dispatch. Writes may have unknown outcomes.';

  @override
  String replaceFileReview(String path) {
    return 'Replace the reviewed file at $path? A changed destination requires a fresh review.';
  }

  @override
  String get diagramPngSaved =>
      'Diagram PNG saved. Long notes show up to six lines.';

  @override
  String get editTargetChanged =>
      'The edit target changed. Reopen the row editor before staging.';

  @override
  String affectedRowCount(String count) {
    return 'Affected rows: $count';
  }

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get resetView => 'Reset view';

  @override
  String get diagramKeys => 'Arrows pan; + and - zoom; Home resets the view.';

  @override
  String get explorerConnected => 'Explorer connected';

  @override
  String get explorerDisconnected => 'Explorer disconnected';

  @override
  String querySessionCount(String count) {
    return 'Query sessions $count';
  }

  @override
  String get metadataColumn => 'Column';

  @override
  String get metadataPosition => 'Position';

  @override
  String get metadataUnique => 'Unique';

  @override
  String get metadataJdbcType => 'JDBC type';

  @override
  String get metadataAutoIncrement => 'Auto-increment';

  @override
  String get metadataReferencedColumn => 'Referenced column';

  @override
  String get metadataComment => 'Comment';

  @override
  String get metadataType => 'Type';

  @override
  String get metadataEvent => 'Event';

  @override
  String get metadataSpecificName => 'Native specific identifier';

  @override
  String get metadataOptions => 'Options';

  @override
  String get metadataInheritance => 'Inheritance';

  @override
  String get metadataDefinitionCaptured => 'Captured native definition';

  @override
  String get metadataDefinitionUnavailable =>
      'Definition unavailable in captured metadata';

  @override
  String get metadataDefinitionUnsupported =>
      'Captured object has no supported native definition';

  @override
  String get connections => 'Connections';

  @override
  String get noConnections => 'No connections yet';

  @override
  String get startTitle => 'Connect to a database';

  @override
  String get startDescription =>
      'Connect to PostgreSQL, MySQL, or MariaDB to browse objects, manage data, and run queries.';

  @override
  String get savedStartTitle => 'Select a connection';

  @override
  String get savedStartDescription =>
      'Connect to a saved connection in Database Explorer to browse objects and run queries.';

  @override
  String get noConnection => 'No connection';

  @override
  String queryTitle(int number) {
    return 'Query $number';
  }

  @override
  String get sessionMenu => 'Session';

  @override
  String get noFilterMatches => 'No matching connections or loaded objects';

  @override
  String get activityState => 'State';

  @override
  String get activityWait => 'Wait';

  @override
  String get generalSettings => 'General';

  @override
  String get optionsSettings => 'Options';

  @override
  String get host => 'Host';

  @override
  String get databaseSystem => 'Database system';

  @override
  String get passwordStorage => 'Password storage';

  @override
  String get environmentLabel => 'Environment';

  @override
  String get readOnlySettings => 'Read-only policy';

  @override
  String get tlsPolicy => 'TLS policy';

  @override
  String get sshConnection => 'SSH connection';

  @override
  String get sshAuthentication => 'SSH authentication';

  @override
  String get connectionTestAction => 'Test connection';

  @override
  String get details => 'Details';

  @override
  String get copyDetails => 'Copy details';

  @override
  String get retry => 'Retry';

  @override
  String get filterCellValue => 'Filter by this value';

  @override
  String get connectsWhenRun => 'Connects when run';

  @override
  String get connectionSaving => 'Saving…';

  @override
  String get connectionConnecting => 'Connecting…';

  @override
  String get connectionCancelling => 'Cancelling…';

  @override
  String get connectionSettingsChanged =>
      'Settings changed. Test this revision to verify the connection.';

  @override
  String get connectionTestChanged =>
      'Settings changed during testing. Test this revision again.';

  @override
  String get connectionRequired => 'Required';

  @override
  String get connectionCorrectFields => 'Correct the indicated fields.';

  @override
  String get connectionHostname => 'Enter a hostname or IP address';

  @override
  String get connectionSshHostname => 'Enter an SSH hostname or IP address';

  @override
  String get connectionMaxLength => 'Use at most 256 characters';

  @override
  String get connectionTlsHelp =>
      'The certificate and Host must verify. Select a CA in SSH/SSL when needed.';

  @override
  String get connectionTlsReview =>
      'Review the selected TLS policy before connecting.';

  @override
  String get connectionStorageUnavailable =>
      'Secure storage unavailable. Enter a password; choose session-only explicitly to save without secure storage.';

  @override
  String get connectionHostReviewed =>
      'Reviewed host identity selected for this profile and endpoint.';

  @override
  String get connectionSshReviewing => 'Reviewing SSH host…';

  @override
  String get connectionFailureAuthentication =>
      'Database authentication was rejected. Check User and Password in General.';

  @override
  String get connectionFailureTls =>
      'TLS verification failed. Check the hostname and certificates in SSH/SSL.';

  @override
  String get connectionFailureSshKey =>
      'The SSH host key was refused. Review the exact host identity in SSH/SSL.';

  @override
  String get connectionFailureEndpoint =>
      'The endpoint could not be reached. Check Host, Port and SSH/SSL.';

  @override
  String get connectionFailureCancelled =>
      'Connection cancelled. Your values are preserved.';

  @override
  String get connectionFailureSettings =>
      'Connection settings were rejected. Review the labeled fields.';

  @override
  String get connectionFailureAccess =>
      'The server rejected access. Check credentials and permissions.';

  @override
  String get connectionFailureUnavailable =>
      'Connection unavailable. Check the endpoint, TLS and SSH settings.';

  @override
  String get connectionFailureTimeout =>
      'Connection timed out. Check the endpoint and connection timeout.';

  @override
  String get connectionFailureUnknown =>
      'Connection was not completed. Review the endpoint, credentials and SSH/SSL settings.';

  @override
  String connectionNumber(int min, int max) {
    return 'Enter a whole number from $min to $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'Connection saved: $name. Connection attempt failed. ';
  }

  @override
  String get backendBusy =>
      'The backend is busy. Wait for the current request, then try again.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'The request was not confirmed (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'The operation could not be completed.';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS material is unavailable or invalid. Check trust sources and the client key in SSH/SSL.';

  @override
  String get managerTitle => 'Data Sources and Drivers';

  @override
  String get sourceListTitle => 'Data Sources';

  @override
  String get driverLabel => 'Driver';

  @override
  String get connectionTypeLabel => 'Connection type';

  @override
  String get defaultTcp => 'Default (TCP)';

  @override
  String get authenticationLabel => 'Authentication';

  @override
  String get userPasswordAuth => 'User & Password';

  @override
  String get neverStorage => 'Never';

  @override
  String get initialDatabaseLabel => 'Initial database';

  @override
  String get useSshTunnel => 'Use SSH tunnel';

  @override
  String get sshConfigurationLabel => 'SSH configuration';

  @override
  String get createSshConfig => '<create configuration>';

  @override
  String get copySshSettings => 'Copy SSH settings';

  @override
  String get localPortLabel => 'Local port';

  @override
  String get dynamicPortLabel => '<Dynamic>';

  @override
  String get useSsl => 'Use SSL';

  @override
  String get useTruststore => 'Use truststore';

  @override
  String get clientKeyPasswordLabel => 'Client key password';

  @override
  String get modeLabel => 'Mode';

  @override
  String get requireTls => 'Require';

  @override
  String get verifyCa => 'Verify CA';

  @override
  String get fullVerification => 'Full Verification';

  @override
  String get connectionSection => 'Connection';

  @override
  String get configurationApplied => 'Configuration applied';

  @override
  String get noOtherSshConfig => 'No other source has an SSH configuration.';

  @override
  String get generatedUrlHelp => 'Generated, read-only JDBC address.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL is unconfigured; the bundled driver uses its default.';

  @override
  String get tlsClientKeyHelp =>
      'PEM keys: PKCS#8 or OpenSSL; encrypted or unencrypted.';

  @override
  String get legacyMariaTrustHelp =>
      'Existing driver verification is retained. Select trust sources to configure explicit roots.';

  @override
  String get metadataStartValue => 'Start value';

  @override
  String get metadataMinimumValue => 'Minimum value';

  @override
  String get metadataMaximumValue => 'Maximum value';

  @override
  String get metadataIncrement => 'Increment';

  @override
  String get metadataCycle => 'Cycle';

  @override
  String get metadataCacheSize => 'Cache size';

  @override
  String get metadataLastValue => 'Last value';

  @override
  String get sequences => 'Sequences';

  @override
  String get namespaceSelection => 'Select namespaces';

  @override
  String get namespaceSelectionNotice =>
      'Selection controls introspection. Query consoles keep their execution context.';

  @override
  String get allNamespaces => 'All Namespaces';

  @override
  String get defaultNamespace => 'Default';

  @override
  String get namespacePattern => 'Name pattern (regular expression)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected of $known';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get patternRejected =>
      'The pattern is invalid or exceeds its work limit. The previous selection is retained.';

  @override
  String get namespaceNotSelected => 'Namespace not selected for introspection';

  @override
  String get newMenu => 'New';

  @override
  String get queryConsoles => 'Query consoles';

  @override
  String get viewOptions => 'View options';

  @override
  String get quickDocumentation => 'Quick Documentation';

  @override
  String get showEmptyGroups => 'Show empty groups';

  @override
  String get speedSearch => 'Speed Search';

  @override
  String get speedSearchScope => 'Expanded, loaded nodes only.';

  @override
  String get newSourceFolder => 'New source folder';

  @override
  String get renameSourceFolder => 'Rename folder';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get folderMustBeEmpty =>
      'Move contained sources and folders before removing this folder.';

  @override
  String get newVirtualView => 'New virtual view';

  @override
  String get editVirtualDefinition => 'Edit local definition';

  @override
  String get unboundVirtualView => 'Unbound virtual views';

  @override
  String get localVirtualViewNotice =>
      'Local SQL definition. Saving does not execute SQL or create a server view. Run uses the normal SQL review and an independent console.';

  @override
  String get rebindVirtualView => 'Rebind local definition here';

  @override
  String get sourceFolderName => 'Folder name';

  @override
  String get sourceFolderPathNotice => 'Use / to create nested folders.';

  @override
  String get topLevel => 'Top level';

  @override
  String get virtualViewName => 'Virtual view name';

  @override
  String get virtualViewSql => 'Virtual view SQL definition';

  @override
  String get virtualViews => 'Virtual views';

  @override
  String get revealInExplorer => 'Reveal in Database Explorer';

  @override
  String get objectNotFound =>
      'Object not found in this namespace; refresh metadata or check permissions.';

  @override
  String get objectHiddenByFilter =>
      'Object is hidden by the current view filter.';

  @override
  String get revealFilterNotice =>
      'Object lookup narrows this page; the full category total is omitted.';

  @override
  String get clearObjectFilter => 'Clear object lookup';

  @override
  String get compareStructure => 'Compare structure';

  @override
  String get selectTwoCompatibleObjects =>
      'Select two compatible tables using Ctrl-click.';

  @override
  String get scopedComparisonRestriction =>
      'Scoped comparison requires ordinary tables with the same native name, schema and engine. Other kinds and rename matching are unavailable.';

  @override
  String get groupNamespaces => 'Group databases and schemas';

  @override
  String get groupSchemaObjects => 'Group schema objects';

  @override
  String get groupTableElements => 'Group table elements';

  @override
  String get sortAlphabetically => 'Sort alphabetically';

  @override
  String get showVirtualObjects => 'Show virtual objects';

  @override
  String get showObjectComments => 'Show object comments';

  @override
  String get objectTypeFilter => 'Object type filter';

  @override
  String get partitionedTable => 'Partitioned table';

  @override
  String get foreignTable => 'Foreign table';

  @override
  String get materializedView => 'Materialized view';

  @override
  String get functionObject => 'Function';

  @override
  String get procedureObject => 'Procedure';

  @override
  String get sqlSymbolUnavailable =>
      'No safely resolved persistent object at the caret. Connect this console and use a table or view reference outside literals and comments.';

  @override
  String get sqlSymbolAmbiguous =>
      'Ambiguous SQL object reference. Qualify its namespace or choose an exact database object.';

  @override
  String get deactivateSource => 'Deactivate source';

  @override
  String get functions => 'Functions';

  @override
  String get procedures => 'Procedures';

  @override
  String get separateProceduresFunctions => 'Separate procedures and functions';

  @override
  String get renameVirtualView => 'Rename virtual view';

  @override
  String get metadataPersistentScope =>
      'Persistent objects only; temporary/session-local objects remain in console navigation.';

  @override
  String get metadataSessionScope =>
      'Persistent objects only; refresh console-local objects after execution.';

  @override
  String get metadataLimitScope =>
      'Metadata limit reached. Narrow the object scope.';

  @override
  String get completeColumnMetadataRequired =>
      'Complete column metadata is required before importing or staging changes.';

  @override
  String resizeColumn(String name) {
    return 'Resize column $name';
  }

  @override
  String get keyboardShortcutsHeading => 'Keyboard shortcuts';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL editor $title';
  }

  @override
  String get editorResultsDivider => 'Editor and results divider';

  @override
  String editorExtent(String percent) {
    return '$percent percent editor';
  }

  @override
  String get largerEditor => 'Larger editor';

  @override
  String get smallerEditor => 'Smaller editor';

  @override
  String get explorerWidthDivider => 'Explorer width divider';

  @override
  String get widerExplorer => 'Wider Explorer';

  @override
  String get narrowerExplorer => 'Narrower Explorer';

  @override
  String explorerExtent(String width) {
    return '$width pixels wide';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end of $total UTF-16 units';
  }

  @override
  String get dropDesignedColumn => 'Drop column';

  @override
  String get liveCatalogLabel => 'Live catalog';

  @override
  String get liveSchemaLabel => 'Live schema';

  @override
  String get searchPathLabel => 'Search path';

  @override
  String get physicalSessionLabel => 'Physical session';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'Timeout: $seconds s · Row limit: $rows';
  }

  @override
  String get saveFailedCloseTitle => 'SQL save failed · Close BusyData';

  @override
  String get createSection => 'Create';

  @override
  String get newConnectionDescription => 'Configure a database connection';

  @override
  String get newQueryDescription => 'Write SQL in a new query';

  @override
  String get openSqlDescription => 'Open an existing SQL document';

  @override
  String get searchNoResults => 'No matching actions';

  @override
  String get actionsCategory => 'Actions';

  @override
  String get privateRecoveryCategory => 'Private recovery';

  @override
  String get shortcutRecordHelp =>
      'Press a shortcut. Escape cancels. F6 and Shift+F6 are reserved for pane navigation.';

  @override
  String get rowLimitInvalid => 'Enter a row limit from 1 to 1,000,000.';

  @override
  String get errorPolicy => 'On execution error';

  @override
  String get tlsEncrypted => 'encrypted';

  @override
  String get tlsUnencrypted => 'unencrypted';

  @override
  String get tlsUnobserved => 'unobserved';

  @override
  String get encryptionVerificationNote =>
      'Encryption does not establish certificate or hostname verification.';

  @override
  String get uniqueDesignedColumnName =>
      'Use a unique column name; new tables support up to 128 columns';

  @override
  String activityBlockerUnavailable(String id) {
    return 'Blocker $id is no longer visible; refresh and check database permissions';
  }

  @override
  String get sshChangedKeyReview =>
      'Verify the changed key independently before replacing this profile binding.';

  @override
  String get sshProfileTrustBinding =>
      'Trust applies only to this profile and exact endpoint.';

  @override
  String get databaseTlsEvidence => 'Database TLS';

  @override
  String get sshAlgorithmLabel => 'Algorithm';

  @override
  String get sshFingerprintLabel => 'Fingerprint';

  @override
  String get sshPreviousFingerprintLabel => 'Previous fingerprint';

  @override
  String get sshReviewedLabel => 'Reviewed';

  @override
  String get shortcutRecordAction => 'Record shortcut';

  @override
  String get fileFormatLabel => 'File format';

  @override
  String get encodingLabel => 'Encoding';

  @override
  String get importPolicyLabel => 'Import policy';

  @override
  String get mainMenu => 'Main menu';

  @override
  String get activityReplyTooLarge =>
      'Activity response exceeds the inspector limit.';

  @override
  String get activityListLimited =>
      'List limited; inspect a narrower target with explicit SQL.';

  @override
  String get activitySelectionChanged =>
      'The selected activity ended or changed. Select its current identity before reviewing an action.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'Connection fields changed while saving; configuration was saved: $name. Review the current values before connecting.';
  }

  @override
  String get sshReviewTargetChanged =>
      'SSH review target changed; review again';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get appLanguage => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select all';

  @override
  String get noSelection => 'No text is available';

  @override
  String get clipboardEmpty => 'The clipboard has no text';

  @override
  String get settingsDraftNotice =>
      'Execution and private recovery changes have not been saved.';

  @override
  String get documentsMenu => 'Documents';

  @override
  String get currentSql => 'Current SQL';

  @override
  String get searchActionsHint => 'Search actions…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'Attributes';

  @override
  String get metadataSelectionUnavailable =>
      'Select an item to inspect its captured properties. The previous selection is unavailable.';

  @override
  String get secureStorage => 'OS secure storage';

  @override
  String get resultPresentation => 'View as';

  @override
  String get resultTable => 'Table';

  @override
  String get resultTranspose => 'Transpose';

  @override
  String get resultTree => 'Tree';

  @override
  String get resultText => 'Text';

  @override
  String get recordView => 'Record View';

  @override
  String get valueEditor => 'Value Editor';

  @override
  String get aggregateView => 'Aggregate View';

  @override
  String get relatedRows => 'Related Rows';

  @override
  String get cloneRow => 'Clone Row';

  @override
  String get displayFormat => 'Display format';

  @override
  String get canonicalValue => 'Canonical / raw';

  @override
  String get groupedNumber => 'Numeric grouping';

  @override
  String get jsonPretty => 'JSON formatted text';

  @override
  String get binaryHex => 'Binary hexadecimal';

  @override
  String get binaryBase64 => 'Binary Base64';

  @override
  String get uuidPresentation => 'UUID (16 bytes)';

  @override
  String get wrapText => 'Wrap text';

  @override
  String get selectedCellsScope => 'Selected cells only';

  @override
  String get retainedWindowScope => 'Current retained window only';

  @override
  String get serverDataOperations => 'Server-side table sorting and filtering';

  @override
  String get localDataOperations =>
      'Local sorting and filtering of retained data';

  @override
  String get partialRetainedScope =>
      'Partial retained result; this view does not represent the complete server table.';

  @override
  String get valueComplete => 'Complete retained value';

  @override
  String get valueTruncated =>
      'Truncated preview; the complete value is retained.';

  @override
  String get loadValueChunk => 'Load next 64 KiB';

  @override
  String get resetValueChunks => 'Reset value preview';

  @override
  String get structuredParseError =>
      'Structured interpretation is unavailable; exact raw content remains accessible.';

  @override
  String get structuredValueLimit =>
      'Structured display is limited to 256 KiB, 4,096 nodes and 32 levels.';

  @override
  String valueChunkRange(String start, String end, String total) {
    return 'Bytes $start–$end of $total';
  }

  @override
  String get presentationScopeLimit =>
      'This presentation exceeds its bounded scope. Select fewer cells or use Export.';

  @override
  String get transposeSelectionLimit =>
      'Transpose shows at most 32 selected rows. Narrow the selection to inspect another range.';

  @override
  String get jsonTree => 'JSON tree';

  @override
  String get xmlInterpretation => 'XML interpretation';

  @override
  String get imagePreview => 'Image preview';

  @override
  String get imagePreviewUnavailable =>
      'Image preview requires recognized image bytes within the 1 MiB / 4 megapixel limit.';

  @override
  String get valueDraftLimit =>
      'Value drafts exceed the shared 1 MiB text / 2 MiB complete-value limit. Stage or discard another draft first.';

  @override
  String get valueDraftPreserved =>
      'Value draft preserved; stored value is unchanged.';

  @override
  String get setDefault => 'Set DEFAULT';

  @override
  String get assignmentUnset => 'Unchanged / unset';

  @override
  String get assignmentValue => 'Exact value';

  @override
  String get assignmentNull => 'SQL NULL';

  @override
  String get assignmentDefault => 'Server DEFAULT';

  @override
  String get originalValue => 'Original value';

  @override
  String get stagedValue => 'Staged value';

  @override
  String get noRelatedRows =>
      'No available relationships for this retained row.';

  @override
  String get aggregateSelectedCount => 'Selected count';

  @override
  String get aggregateNonNull => 'Non-NULL count';

  @override
  String get aggregateNull => 'NULL count';

  @override
  String get aggregateDistinct => 'Distinct count';

  @override
  String get aggregateSum => 'Sum';

  @override
  String get aggregateAverage => 'Average';

  @override
  String get aggregateMinimum => 'Minimum';

  @override
  String get aggregateMaximum => 'Maximum';

  @override
  String get aggregateStoredValues =>
      'Aggregates use original retained values; staged edits are excluded.';

  @override
  String get relatedRowsUnavailable =>
      'Related-row navigation requires complete metadata and verified retained provenance.';

  @override
  String get stagedInsertReview =>
      'Clone staged as an insert. Review and edit its assignments before Apply.';

  @override
  String get rawValue => 'Raw value';

  @override
  String get previousRecord => 'Previous record';

  @override
  String get nextRecord => 'Next record';

  @override
  String get binaryInputError =>
      'Enter complete hexadecimal bytes or valid Base64 for the selected binary mode.';

  @override
  String get valueChunkEncoding =>
      'This byte page begins or ends inside a UTF-8 character. Use hexadecimal or export the complete value.';

  @override
  String get copyDisplayedText => 'Copy displayed text';

  @override
  String get requiredColumn => 'NOT NULL';

  @override
  String get editStagedInserts => 'Edit staged inserts';

  @override
  String get metadataSettings => 'Metadata and introspection';

  @override
  String get metadataIncludeCatalogs =>
      'Included databases (one exact name per line; empty uses current database)';

  @override
  String get metadataExcludeCatalogs => 'Excluded databases';

  @override
  String get metadataIncludeSchemas =>
      'Included schemas (empty uses current resolution path)';

  @override
  String get metadataExcludeSchemas => 'Excluded schemas';

  @override
  String get metadataIncludePatterns => 'Included object patterns';

  @override
  String get metadataExcludePatterns => 'Excluded object patterns';

  @override
  String get metadataSystemObjects => 'Include system objects';

  @override
  String get metadataDefaultLevel => 'Default introspection level';

  @override
  String get metadataLevelNames => 'Names and identities';

  @override
  String get metadataLevelStructure => 'Structure';

  @override
  String get metadataLevelSource => 'Structure and source';

  @override
  String get metadataFullRefresh => 'Full refresh';

  @override
  String get metadataIncrementalRefresh => 'Incremental refresh';

  @override
  String get metadataScopeLevels =>
      'Scope levels: catalog / schema / level, one per line';

  @override
  String get metadataCacheState => 'Cache state';

  @override
  String get metadataConfigurationChanged =>
      'Metadata configuration changed; reopen to review current settings';

  @override
  String get metadataAddScope => 'Add scope level';

  @override
  String get metadataAddName => 'Add exact name';

  @override
  String get metadataObjectKinds => 'Object kinds';

  @override
  String get metadataLastRefresh => 'Last successful refresh';

  @override
  String get metadataPatternsNote =>
      'Patterns use * for any characters and ? for one character. Names remain exact database identifiers.';

  @override
  String get sqlLanguage => 'SQL language';

  @override
  String get sqlDialect => 'SQL dialect';

  @override
  String get sqlPostgresql => 'PostgreSQL';

  @override
  String get sqlMysql => 'MySQL';

  @override
  String get sqlMariadb => 'MariaDB';

  @override
  String get sqlPreferenceScope => 'Settings scope';

  @override
  String get sqlDialectDefaults => 'Dialect defaults';

  @override
  String get sqlDialectDefaultsDescription =>
      'Applies to SQL documents using this dialect unless their connection has an override.';

  @override
  String get sqlProfileOverrideDescription =>
      'Applies only to SQL documents owned by the selected connection.';

  @override
  String get sqlUseDialectDefaults =>
      'Use dialect defaults for this connection';

  @override
  String get sqlFormatting => 'SQL formatting';

  @override
  String get sqlKeywordCase => 'Keyword case';

  @override
  String get sqlPreserveCase => 'Preserve case';

  @override
  String get sqlUpperCase => 'Uppercase';

  @override
  String get sqlLowerCase => 'Lowercase';

  @override
  String get sqlIndentationWidth => 'Indentation width';

  @override
  String get sqlContinuationIndent => 'Continuation indentation';

  @override
  String get sqlClauseBreaks => 'Start clauses on new lines';

  @override
  String get sqlJoinLayout => 'JOIN layout';

  @override
  String get sqlNewLine => 'New line';

  @override
  String get sqlSameLine => 'Same line';

  @override
  String get sqlCommaPlacement => 'Comma placement';

  @override
  String get sqlLeading => 'Leading';

  @override
  String get sqlTrailing => 'Trailing';

  @override
  String get sqlLogicalPlacement => 'Logical operator placement';

  @override
  String get sqlWrapLists => 'Wrap field and assignment lists';

  @override
  String get sqlWrapArguments => 'Wrap function arguments';

  @override
  String get sqlIndentSubqueries => 'Indent subqueries';

  @override
  String get sqlCteBreaks => 'Separate common table expressions';

  @override
  String get sqlParenthesisSpacing => 'Space inside parentheses';

  @override
  String get sqlOperatorSpacing => 'Space around operators';

  @override
  String get sqlAlignment => 'Align wrapped assignments';

  @override
  String get sqlMaximumLine => 'Maximum line length';

  @override
  String get sqlPreserveBlankLines => 'Preserve intentional blank lines';

  @override
  String get sqlInspections => 'SQL inspections';

  @override
  String get sqlInspectionDisabled => 'Disabled';

  @override
  String get sqlSeverityError => 'Error';

  @override
  String get sqlSeverityWarning => 'Warning';

  @override
  String get sqlSeverityInformation => 'Information';

  @override
  String get sqlSeverityHint => 'Hint';

  @override
  String get sqlInspectionUpdateWhere => 'UPDATE without WHERE';

  @override
  String get sqlInspectionDeleteWhere => 'DELETE without WHERE';

  @override
  String get sqlInspectionRelation => 'Unresolved relation';

  @override
  String get sqlInspectionColumn => 'Unresolved column';

  @override
  String get sqlInspectionAmbiguous => 'Ambiguous column';

  @override
  String get sqlInspectionDerived => 'Invalid derived-table column';

  @override
  String get sqlInspectionDuplicateAlias => 'Duplicate relation alias';

  @override
  String get sqlInspectionDuplicateCte => 'Duplicate common table expression';

  @override
  String get sqlInspectionDuplicateInsert => 'Duplicate INSERT column';

  @override
  String get sqlInspectionInsertTarget => 'Unknown INSERT target column';

  @override
  String get sqlInspectionUpdateTarget => 'Unknown UPDATE target column';

  @override
  String get sqlInspectionArguments => 'Invalid routine argument count';

  @override
  String get sqlInspectionOverload => 'No matching routine overload';

  @override
  String get sqlInspectionAggregate => 'Invalid aggregate or window expression';

  @override
  String get sqlInspectionComparison => 'Incompatible comparison types';

  @override
  String get sqlInspectionAssignment => 'Incompatible assignment type';

  @override
  String get parameterInformation => 'Parameter information';

  @override
  String activeArgument(int index) {
    return 'Active argument: $index';
  }

  @override
  String get numericScale2 => 'Numeric grouping · 2 decimal places';

  @override
  String get numericScale4 => 'Numeric grouping · 4 decimal places';

  @override
  String get temporalDate => 'Temporal date · yyyy-MM-dd';

  @override
  String get temporalTime => 'Temporal time · ISO';

  @override
  String get temporalUtc => 'Timestamp · UTC (requires explicit offset)';

  @override
  String get temporalLocal =>
      'Timestamp · local timezone (requires explicit offset)';

  @override
  String get formatCurrentStatement => 'Format current statement';

  @override
  String get completionLimited =>
      'More matches are available. Type a longer prefix.';

  @override
  String get parameterInformationLimited =>
      'More overloads exist; parameter information is limited.';

  @override
  String get sqlInspectionSyntax => 'SQL syntax error';

  @override
  String get sqlInspectionDialect =>
      'SQL construct is unavailable for this dialect';

  @override
  String get sqlInspectionUnavailable =>
      'SQL analysis is unavailable for this construct';

  @override
  String get sqlInspectionUnknownFunction => 'Unknown routine';

  @override
  String get sqlInspectionMetadata =>
      'SQL inspection is incomplete because metadata is unavailable';

  @override
  String get sqlDiagnosticsEmpty =>
      'No SQL inspections were reported for this document.';

  @override
  String sqlDiagnosticSpan(int start, int end, String source) {
    return 'UTF-16 $start–$end · $source';
  }

  @override
  String get sqlDiagnosticGo => 'Go to SQL span';

  @override
  String get sqlDiagnosticFix => 'Apply selected correction';

  @override
  String get sqlDiagnosticReplacement => 'Replacement text';

  @override
  String get sqlDiagnosticStale =>
      'SQL inspection context changed. Request inspections again.';

  @override
  String get sqlDiagnosticUnavailable =>
      'SQL inspections are unavailable for the current document.';

  @override
  String sqlDiagnosticCount(int count) {
    return '$count SQL inspections';
  }

  @override
  String get aggregateTextOrder =>
      'Text minimum/maximum use retained UTF-16 ordinal order; database collation is not applied.';

  @override
  String get aggregateMixedTypes =>
      'The selected values have incompatible types. Select values with a common type.';

  @override
  String get aggregateUnsupportedOrder =>
      'Ordering and numeric calculations are unavailable for this value type.';

  @override
  String get relatedKeyNotProjected =>
      'Select all relationship key columns in the source result before navigating.';

  @override
  String get relatedNullKey =>
      'A NULL relationship key has no matching related row.';

  @override
  String get relatedTargetUnavailable =>
      'The relationship target is outside this session’s supported database scope.';

  @override
  String get relatedValueLimited =>
      'The relationship key is truncated or exceeds navigation limits. Browse the target explicitly.';

  @override
  String get temporalCustomPattern => 'Temporal · custom pattern';

  @override
  String get temporalPattern => 'Temporal display pattern';

  @override
  String get temporalSourceZone => 'Original calendar fields';

  @override
  String get temporalZone => 'Display timezone';

  @override
  String get temporalPatternHelp =>
      'Use ICU calendar fields and up to six S digits for exact fractions. UTC/local conversion requires an explicit offset. Unsupported temporal values remain raw.';

  @override
  String get temporalPatternInvalid =>
      'Use a pattern of 1–128 characters with supported calendar fields, balanced quotes, and at most six S digits. Timezone letters z, Z and v are unsupported; choose the display timezone separately.';

  @override
  String get editCompleteValue => 'Edit complete value';

  @override
  String get completeValueEditLimit =>
      'Complete editing requires verified retained ownership, at most 1 MiB across original and new values, and 262,144 text units per value. Larger values remain available for export.';

  @override
  String get completeValueReady =>
      'Complete retained value loaded for editing; changes are staged only.';

  @override
  String get binaryNextEditPage => 'Next 16 KiB';

  @override
  String get binaryPreviousEditPage => 'Previous 16 KiB';

  @override
  String get arrayEditLimit =>
      'Array edits use exact native PostgreSQL text, at most 16 KiB of text, six dimensions and 1,024 scalar values. Java validates the captured element type.';

  @override
  String get valueChangedDuringStage =>
      'The earlier value was staged. Your newer draft is preserved; review it before staging again.';

  @override
  String textValuePage(String current, String total) {
    return 'Text page $current of $total';
  }

  @override
  String get textValuePagesScope =>
      'Only this text page is shown. Copy and export actions keep their stated scope.';

  @override
  String get textValueEditScope => 'Stage change includes every text page.';

  @override
  String get textValuePreviousPage => 'Previous text page';

  @override
  String get textValueNextPage => 'Next text page';

  @override
  String get valuePageEditLimit =>
      'That text is invalid or too large for this page. The previous text was kept.';

  @override
  String get valueAddEditPage => 'Add editing page';

  @override
  String get binaryAppendPageReason =>
      'Finish a valid, full last binary page before adding another page. Bytes are never padded.';

  @override
  String get valueEditorActions => 'Value actions';

  @override
  String get utf8Hex => 'UTF-8 hexadecimal';

  @override
  String get utf8Base64 => 'UTF-8 Base64';

  @override
  String get nativeTextNulUnavailable =>
      'Plain text editing is unavailable for values containing a NUL character. UTF-8 byte views and exact export remain available.';

  @override
  String get textClipboardNulUnavailable =>
      'This text contains a NUL character and cannot be copied exactly. Export the value or choose another extractor.';

  @override
  String sqlVisibleLine(int line, int total, int column) {
    return 'Visible SQL line $line of $total, column $column';
  }

  @override
  String get sqlLinePreviewTruncated => 'Line preview truncated';

  @override
  String sqlActiveCarets(int count) {
    return '$count carets active';
  }

  @override
  String get sqlCompositionActive => 'Input composition active';

  @override
  String get sqlEditorDocumentLimit =>
      'The edit exceeds the 8M UTF-16 document limit. Use a smaller document.';

  @override
  String get sqlEditorLineLimit =>
      'The edit exceeds the 100,000-line document limit. Use a smaller document.';

  @override
  String get sqlEditorCaretLimit =>
      'The editor supports at most 64 carets. Remove extra carets before adding more.';

  @override
  String get sqlEditorFinishComposition =>
      'Finish input composition before changing this selection.';

  @override
  String get sqlEditorClipboardLimit =>
      'The exact selection exceeds the 1 MiB clipboard limit. Save or export the text instead.';

  @override
  String get sqlEditorSelectionUnavailable =>
      'The editor cannot apply this selection. The original SQL is retained.';

  @override
  String get sqlEditorClipboardUnavailable =>
      'The clipboard is unavailable. Your SQL and selection have been kept.';

  @override
  String get metadataCacheWriteUnavailable =>
      'The cache could not be saved. Current metadata remains available.';

  @override
  String get metadataCacheRebuiltVersion => 'Rebuilt for the current version';

  @override
  String get metadataCacheRebuiltCorrupt => 'Rebuilt after a cache error';

  @override
  String get editSessionBusy =>
      'This session is busy. Wait for its current work to finish, then request a fresh editing assessment.';

  @override
  String get editIdentityRequired =>
      'Select a complete primary key or non-nullable unique identity before editing.';

  @override
  String get editColumnsReadOnly =>
      'All projected columns are generated or read-only.';

  @override
  String get editResultNotReady =>
      'Wait for this retained result to finish before requesting a fresh editing assessment.';

  @override
  String get editProjectionUnsupported =>
      'Editing requires a direct SELECT from one base table with each base column projected once.';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'Duplicate JOIN USING column';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'JOIN USING column missing from an operand';

  @override
  String get sqlInspectionAmbiguousUsingColumn =>
      'Ambiguous shared JOIN column';

  @override
  String get sqlInspectionOutputColumnCount =>
      'Declared output column count mismatch';

  @override
  String get sqlInspectionAmbiguousOverload => 'Ambiguous routine overload';

  @override
  String get sqlInspectionBooleanType => 'Invalid Boolean expression type';

  @override
  String get sqlInspectionOperatorTypes =>
      'Incompatible operator operand types';

  @override
  String get sqlInspectionArrayTypes => 'Incompatible array element types';

  @override
  String get sqlInspectionCaseConditionType =>
      'Incompatible CASE condition type';

  @override
  String get sqlInspectionCaseResultTypes => 'Incompatible CASE result types';

  @override
  String get sqlInspectionCoalesceTypes =>
      'Incompatible COALESCE argument types';

  @override
  String get sqlInspectionSetColumnCount =>
      'Set operation column count mismatch';

  @override
  String get sqlInspectionSetTypes => 'Incompatible set operation result types';

  @override
  String get sqlInspectionRecursiveCteType => 'Recursive CTE type mismatch';
}
