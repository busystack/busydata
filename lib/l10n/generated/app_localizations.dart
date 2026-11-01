import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_et.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('et'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pl'),
    Locale('pt'),
    Locale('pt', 'PT'),
    Locale('ru'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @databaseExplorer.
  ///
  /// In en, this message translates to:
  /// **'Database Explorer'**
  String get databaseExplorer;

  /// No description provided for @databases.
  ///
  /// In en, this message translates to:
  /// **'Databases'**
  String get databases;

  /// No description provided for @newConnection.
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get newConnection;

  /// No description provided for @filterTree.
  ///
  /// In en, this message translates to:
  /// **'Filter connections and objects'**
  String get filterTree;

  /// No description provided for @treeFilterScope.
  ///
  /// In en, this message translates to:
  /// **'Filters loaded tree objects'**
  String get treeFilterScope;

  /// No description provided for @searchObjects.
  ///
  /// In en, this message translates to:
  /// **'Search database objects'**
  String get searchObjects;

  /// No description provided for @fileMenu.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileMenu;

  /// No description provided for @editMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMenu;

  /// No description provided for @viewMenu.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewMenu;

  /// No description provided for @connectionMenu.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionMenu;

  /// No description provided for @objectMenu.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get objectMenu;

  /// No description provided for @runMenu.
  ///
  /// In en, this message translates to:
  /// **'Run options'**
  String get runMenu;

  /// No description provided for @commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commands;

  /// No description provided for @findCommand.
  ///
  /// In en, this message translates to:
  /// **'Find command'**
  String get findCommand;

  /// No description provided for @newSql.
  ///
  /// In en, this message translates to:
  /// **'New query'**
  String get newSql;

  /// No description provided for @openSql.
  ///
  /// In en, this message translates to:
  /// **'Open SQL'**
  String get openSql;

  /// No description provided for @openSqlFile.
  ///
  /// In en, this message translates to:
  /// **'Open SQL file'**
  String get openSqlFile;

  /// No description provided for @saveSql.
  ///
  /// In en, this message translates to:
  /// **'Save SQL'**
  String get saveSql;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get closeTab;

  /// No description provided for @openWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open workspace'**
  String get openWorkspace;

  /// No description provided for @saveWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Save workspace'**
  String get saveWorkspace;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @findText.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findText;

  /// No description provided for @replaceText.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replaceText;

  /// No description provided for @formatSql.
  ///
  /// In en, this message translates to:
  /// **'Format SQL'**
  String get formatSql;

  /// No description provided for @lineComments.
  ///
  /// In en, this message translates to:
  /// **'Toggle line comments'**
  String get lineComments;

  /// No description provided for @snippets.
  ///
  /// In en, this message translates to:
  /// **'SQL snippets'**
  String get snippets;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @runStatement.
  ///
  /// In en, this message translates to:
  /// **'Run current statement'**
  String get runStatement;

  /// No description provided for @runSelection.
  ///
  /// In en, this message translates to:
  /// **'Run selection'**
  String get runSelection;

  /// No description provided for @runScript.
  ///
  /// In en, this message translates to:
  /// **'Run script'**
  String get runScript;

  /// No description provided for @explain.
  ///
  /// In en, this message translates to:
  /// **'Explain'**
  String get explain;

  /// No description provided for @explainAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Explain analyze'**
  String get explainAnalyze;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @sessionDetails.
  ///
  /// In en, this message translates to:
  /// **'Session details'**
  String get sessionDetails;

  /// No description provided for @beginTransaction.
  ///
  /// In en, this message translates to:
  /// **'Begin transaction'**
  String get beginTransaction;

  /// No description provided for @commitTransaction.
  ///
  /// In en, this message translates to:
  /// **'Commit transaction'**
  String get commitTransaction;

  /// No description provided for @rollbackTransaction.
  ///
  /// In en, this message translates to:
  /// **'Roll back transaction'**
  String get rollbackTransaction;

  /// No description provided for @enableAutoCommit.
  ///
  /// In en, this message translates to:
  /// **'Enable auto-commit'**
  String get enableAutoCommit;

  /// No description provided for @disableAutoCommit.
  ///
  /// In en, this message translates to:
  /// **'Disable auto-commit'**
  String get disableAutoCommit;

  /// No description provided for @outcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown'**
  String get outcomeUnknown;

  /// No description provided for @outcomeUnknownNote.
  ///
  /// In en, this message translates to:
  /// **'The operation may have completed. This session cannot run further SQL. Never retry automatically; reconcile the outcome before starting new work.'**
  String get outcomeUnknownNote;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get notConnected;

  /// No description provided for @autoCommit.
  ///
  /// In en, this message translates to:
  /// **'Auto-commit'**
  String get autoCommit;

  /// No description provided for @manualTransaction.
  ///
  /// In en, this message translates to:
  /// **'Manual transaction'**
  String get manualTransaction;

  /// No description provided for @readOnlyPolicy.
  ///
  /// In en, this message translates to:
  /// **'BusyData read-only policy'**
  String get readOnlyPolicy;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @structure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get structure;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changes;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @jobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get jobs;

  /// No description provided for @retainedResults.
  ///
  /// In en, this message translates to:
  /// **'Retained results'**
  String get retainedResults;

  /// No description provided for @recoverEdits.
  ///
  /// In en, this message translates to:
  /// **'Recover staged changes'**
  String get recoverEdits;

  /// No description provided for @applyAndCommit.
  ///
  /// In en, this message translates to:
  /// **'Apply and commit'**
  String get applyAndCommit;

  /// No description provided for @inspectStructure.
  ///
  /// In en, this message translates to:
  /// **'Inspect structure'**
  String get inspectStructure;

  /// No description provided for @openData.
  ///
  /// In en, this message translates to:
  /// **'Open data'**
  String get openData;

  /// No description provided for @openDefinition.
  ///
  /// In en, this message translates to:
  /// **'Open definition'**
  String get openDefinition;

  /// No description provided for @copyQualifiedName.
  ///
  /// In en, this message translates to:
  /// **'Copy qualified name'**
  String get copyQualifiedName;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @columns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// No description provided for @indexes.
  ///
  /// In en, this message translates to:
  /// **'Indexes'**
  String get indexes;

  /// No description provided for @constraints.
  ///
  /// In en, this message translates to:
  /// **'Keys and constraints'**
  String get constraints;

  /// No description provided for @foreignKeys.
  ///
  /// In en, this message translates to:
  /// **'Foreign keys'**
  String get foreignKeys;

  /// No description provided for @triggers.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get triggers;

  /// No description provided for @definition.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get definition;

  /// No description provided for @dependencies.
  ///
  /// In en, this message translates to:
  /// **'Dependencies'**
  String get dependencies;

  /// No description provided for @connectionCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Connection overview'**
  String get connectionCapabilities;

  /// No description provided for @sessionsAndLocks.
  ///
  /// In en, this message translates to:
  /// **'Sessions and locks'**
  String get sessionsAndLocks;

  /// No description provided for @usersAndRoles.
  ///
  /// In en, this message translates to:
  /// **'Users and roles'**
  String get usersAndRoles;

  /// No description provided for @saveSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Save schema snapshot'**
  String get saveSnapshot;

  /// No description provided for @compareSchemas.
  ///
  /// In en, this message translates to:
  /// **'Compare schemas'**
  String get compareSchemas;

  /// No description provided for @objectDesigner.
  ///
  /// In en, this message translates to:
  /// **'Object designer'**
  String get objectDesigner;

  /// No description provided for @diagram.
  ///
  /// In en, this message translates to:
  /// **'ER diagram'**
  String get diagram;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importData;

  /// No description provided for @exportRetained.
  ///
  /// In en, this message translates to:
  /// **'Export retained data'**
  String get exportRetained;

  /// No description provided for @exportSql.
  ///
  /// In en, this message translates to:
  /// **'Run SQL export'**
  String get exportSql;

  /// No description provided for @stageInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert row'**
  String get stageInsert;

  /// No description provided for @stageUpdate.
  ///
  /// In en, this message translates to:
  /// **'Edit row'**
  String get stageUpdate;

  /// No description provided for @stageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get stageDelete;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard pending changes'**
  String get discardChanges;

  /// No description provided for @disposeResult.
  ///
  /// In en, this message translates to:
  /// **'Dispose retained data'**
  String get disposeResult;

  /// No description provided for @currentSchema.
  ///
  /// In en, this message translates to:
  /// **'Current schema (to be changed)'**
  String get currentSchema;

  /// No description provided for @desiredSchema.
  ///
  /// In en, this message translates to:
  /// **'Desired schema'**
  String get desiredSchema;

  /// No description provided for @applyTo.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get applyTo;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'No objects in this scope'**
  String get empty;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @selectTarget.
  ///
  /// In en, this message translates to:
  /// **'Choose connection'**
  String get selectTarget;

  /// No description provided for @requireSql.
  ///
  /// In en, this message translates to:
  /// **'Requires a SQL document'**
  String get requireSql;

  /// No description provided for @requireSession.
  ///
  /// In en, this message translates to:
  /// **'Requires a connected, known session'**
  String get requireSession;

  /// No description provided for @requireResult.
  ///
  /// In en, this message translates to:
  /// **'Requires retained data'**
  String get requireResult;

  /// No description provided for @requireObject.
  ///
  /// In en, this message translates to:
  /// **'Requires an object target'**
  String get requireObject;

  /// No description provided for @cancelRequested.
  ///
  /// In en, this message translates to:
  /// **'Cancellation requested'**
  String get cancelRequested;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @queued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queued;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @sessionSharing.
  ///
  /// In en, this message translates to:
  /// **'Share an existing session (advanced)'**
  String get sessionSharing;

  /// No description provided for @production.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get production;

  /// No description provided for @staging.
  ///
  /// In en, this message translates to:
  /// **'Staging'**
  String get staging;

  /// No description provided for @development.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get development;

  /// No description provided for @executionOptions.
  ///
  /// In en, this message translates to:
  /// **'Execution options'**
  String get executionOptions;

  /// No description provided for @resultRowLimit.
  ///
  /// In en, this message translates to:
  /// **'Result row limit (1–1000000)'**
  String get resultRowLimit;

  /// No description provided for @boundedRead.
  ///
  /// In en, this message translates to:
  /// **'Bounded read'**
  String get boundedRead;

  /// No description provided for @streamingRead.
  ///
  /// In en, this message translates to:
  /// **'Streaming read · owns a read transaction'**
  String get streamingRead;

  /// No description provided for @stopOnError.
  ///
  /// In en, this message translates to:
  /// **'Stop script on error'**
  String get stopOnError;

  /// No description provided for @continueOnError.
  ///
  /// In en, this message translates to:
  /// **'Continue on error · prior statements may have committed'**
  String get continueOnError;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Toggle favorite'**
  String get favorite;

  /// No description provided for @connectionGroup.
  ///
  /// In en, this message translates to:
  /// **'Connection group'**
  String get connectionGroup;

  /// No description provided for @copyRange.
  ///
  /// In en, this message translates to:
  /// **'Copy range'**
  String get copyRange;

  /// No description provided for @inspectValue.
  ///
  /// In en, this message translates to:
  /// **'Inspect value'**
  String get inspectValue;

  /// No description provided for @editConnection.
  ///
  /// In en, this message translates to:
  /// **'Edit connection'**
  String get editConnection;

  /// No description provided for @chooseSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Choose snapshot'**
  String get chooseSnapshot;

  /// No description provided for @captureSchema.
  ///
  /// In en, this message translates to:
  /// **'Capture schema'**
  String get captureSchema;

  /// No description provided for @sameSchemaRestriction.
  ///
  /// In en, this message translates to:
  /// **'Snapshots must have the same engine, schema name and snapshot version. Comparing and saving never applies changes.'**
  String get sameSchemaRestriction;

  /// No description provided for @restoredTaskState.
  ///
  /// In en, this message translates to:
  /// **'This document reference was restored. Previous backend evidence, sessions and jobs are unavailable. Choose an explicit action to inspect or start new work; restoration never connects, executes SQL or replays changes.'**
  String get restoredTaskState;

  /// No description provided for @preChangeSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Pre-change snapshot · changes committed. Refresh explicitly to inspect current rows and server defaults.'**
  String get preChangeSnapshot;

  /// No description provided for @sqlProvenance.
  ///
  /// In en, this message translates to:
  /// **'SQL provenance'**
  String get sqlProvenance;

  /// No description provided for @assessEditing.
  ///
  /// In en, this message translates to:
  /// **'Assess editing'**
  String get assessEditing;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @gridMenu.
  ///
  /// In en, this message translates to:
  /// **'Data grid'**
  String get gridMenu;

  /// No description provided for @visibleColumns.
  ///
  /// In en, this message translates to:
  /// **'Visible columns'**
  String get visibleColumns;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @equals.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get equals;

  /// No description provided for @notEqual.
  ///
  /// In en, this message translates to:
  /// **'Does not equal'**
  String get notEqual;

  /// No description provided for @lessThan.
  ///
  /// In en, this message translates to:
  /// **'Less than'**
  String get lessThan;

  /// No description provided for @greaterThan.
  ///
  /// In en, this message translates to:
  /// **'Greater than'**
  String get greaterThan;

  /// No description provided for @isNull.
  ///
  /// In en, this message translates to:
  /// **'Is NULL'**
  String get isNull;

  /// No description provided for @isNotNull.
  ///
  /// In en, this message translates to:
  /// **'Is not NULL'**
  String get isNotNull;

  /// No description provided for @exactValue.
  ///
  /// In en, this message translates to:
  /// **'Exact value'**
  String get exactValue;

  /// No description provided for @sortTable.
  ///
  /// In en, this message translates to:
  /// **'Sort table data'**
  String get sortTable;

  /// No description provided for @filterTable.
  ///
  /// In en, this message translates to:
  /// **'Filter table data'**
  String get filterTable;

  /// No description provided for @sortRetained.
  ///
  /// In en, this message translates to:
  /// **'Sort retained snapshot'**
  String get sortRetained;

  /// No description provided for @filterRetained.
  ///
  /// In en, this message translates to:
  /// **'Filter retained snapshot'**
  String get filterRetained;

  /// No description provided for @applyView.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyView;

  /// No description provided for @rowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rowsLabel;

  /// No description provided for @fetchedRows.
  ///
  /// In en, this message translates to:
  /// **'Fetched rows'**
  String get fetchedRows;

  /// No description provided for @fixedSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Fixed fetched-row snapshot'**
  String get fixedSnapshot;

  /// No description provided for @limitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get limitReached;

  /// No description provided for @retainedData.
  ///
  /// In en, this message translates to:
  /// **'Retained data'**
  String get retainedData;

  /// No description provided for @applyRequiresAutoCommit.
  ///
  /// In en, this message translates to:
  /// **'Apply and commit requires an idle session with auto-commit enabled.'**
  String get applyRequiresAutoCommit;

  /// No description provided for @connectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Connection profile'**
  String get connectionProfile;

  /// No description provided for @basic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get basic;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @connectionName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get connectionName;

  /// No description provided for @hostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname (also used for TLS verification)'**
  String get hostname;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @writableProfile.
  ///
  /// In en, this message translates to:
  /// **'Writable profile'**
  String get writableProfile;

  /// No description provided for @readonlyProfile.
  ///
  /// In en, this message translates to:
  /// **'Read-only profile'**
  String get readonlyProfile;

  /// No description provided for @tlsVerify.
  ///
  /// In en, this message translates to:
  /// **'TLS: verify certificate and hostname'**
  String get tlsVerify;

  /// No description provided for @tlsInsecure.
  ///
  /// In en, this message translates to:
  /// **'TLS: INSECURE, do not verify'**
  String get tlsInsecure;

  /// No description provided for @tlsDisabled.
  ///
  /// In en, this message translates to:
  /// **'TLS: DISABLED'**
  String get tlsDisabled;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test without saving'**
  String get testConnection;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveProfile;

  /// No description provided for @saveConnect.
  ///
  /// In en, this message translates to:
  /// **'Save & connect'**
  String get saveConnect;

  /// No description provided for @sessionPassword.
  ///
  /// In en, this message translates to:
  /// **'Session-only password'**
  String get sessionPassword;

  /// No description provided for @storedPassword.
  ///
  /// In en, this message translates to:
  /// **'Store password in OS secure storage'**
  String get storedPassword;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @testRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get testRunning;

  /// No description provided for @cancelTest.
  ///
  /// In en, this message translates to:
  /// **'Cancel test'**
  String get cancelTest;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @activeTransaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction open'**
  String get activeTransaction;

  /// No description provided for @failedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction failed'**
  String get failedTransaction;

  /// No description provided for @inspectionContext.
  ///
  /// In en, this message translates to:
  /// **'Inspection session'**
  String get inspectionContext;

  /// No description provided for @requireTableOrView.
  ///
  /// In en, this message translates to:
  /// **'Select a table or view'**
  String get requireTableOrView;

  /// No description provided for @operationPending.
  ///
  /// In en, this message translates to:
  /// **'A document operation is awaiting acknowledgement'**
  String get operationPending;

  /// No description provided for @requirePlan.
  ///
  /// In en, this message translates to:
  /// **'Select a retained Explain execution'**
  String get requirePlan;

  /// No description provided for @openPlanDocument.
  ///
  /// In en, this message translates to:
  /// **'Open plan document'**
  String get openPlanDocument;

  /// No description provided for @locks.
  ///
  /// In en, this message translates to:
  /// **'Locks'**
  String get locks;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @queryStatistics.
  ///
  /// In en, this message translates to:
  /// **'Query statistics'**
  String get queryStatistics;

  /// No description provided for @indexDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Index diagnostics'**
  String get indexDiagnostics;

  /// No description provided for @grants.
  ///
  /// In en, this message translates to:
  /// **'Grants'**
  String get grants;

  /// No description provided for @sqlExecution.
  ///
  /// In en, this message translates to:
  /// **'SQL execution'**
  String get sqlExecution;

  /// No description provided for @planReady.
  ///
  /// In en, this message translates to:
  /// **'Retained plan ready; SQL was not rerun'**
  String get planReady;

  /// No description provided for @executionPlan.
  ///
  /// In en, this message translates to:
  /// **'Execution plan'**
  String get executionPlan;

  /// No description provided for @openOwner.
  ///
  /// In en, this message translates to:
  /// **'Open owner'**
  String get openOwner;

  /// No description provided for @terminateActivity.
  ///
  /// In en, this message translates to:
  /// **'Terminate activity'**
  String get terminateActivity;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @replaceSelection.
  ///
  /// In en, this message translates to:
  /// **'Replace selection'**
  String get replaceSelection;

  /// No description provided for @replaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceAll;

  /// No description provided for @restartBackend.
  ///
  /// In en, this message translates to:
  /// **'Restart backend'**
  String get restartBackend;

  /// No description provided for @structuredTree.
  ///
  /// In en, this message translates to:
  /// **'Structured tree'**
  String get structuredTree;

  /// No description provided for @rawOutput.
  ///
  /// In en, this message translates to:
  /// **'Raw output'**
  String get rawOutput;

  /// No description provided for @previousTextPage.
  ///
  /// In en, this message translates to:
  /// **'Previous text page'**
  String get previousTextPage;

  /// No description provided for @nextTextPage.
  ///
  /// In en, this message translates to:
  /// **'Next text page'**
  String get nextTextPage;

  /// No description provided for @filterChangedObjects.
  ///
  /// In en, this message translates to:
  /// **'Filter changed objects'**
  String get filterChangedObjects;

  /// No description provided for @rebindVerifiedEdits.
  ///
  /// In en, this message translates to:
  /// **'Rebind verified edits'**
  String get rebindVerifiedEdits;

  /// No description provided for @discardRecoveryRecord.
  ///
  /// In en, this message translates to:
  /// **'Discard recovery record'**
  String get discardRecoveryRecord;

  /// No description provided for @revertChange.
  ///
  /// In en, this message translates to:
  /// **'Revert pending change'**
  String get revertChange;

  /// No description provided for @chooseSource.
  ///
  /// In en, this message translates to:
  /// **'Choose source'**
  String get chooseSource;

  /// No description provided for @chooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get chooseDestination;

  /// No description provided for @delimiterField.
  ///
  /// In en, this message translates to:
  /// **'Delimiter (one character)'**
  String get delimiterField;

  /// No description provided for @batchRowsField.
  ///
  /// In en, this message translates to:
  /// **'Rows per batch (1–1000)'**
  String get batchRowsField;

  /// No description provided for @rejectedLimit.
  ///
  /// In en, this message translates to:
  /// **'Rejected-row limit (1–1000)'**
  String get rejectedLimit;

  /// No description provided for @previewSource.
  ///
  /// In en, this message translates to:
  /// **'Preview source'**
  String get previewSource;

  /// No description provided for @reviewTransfer.
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get reviewTransfer;

  /// No description provided for @startImport.
  ///
  /// In en, this message translates to:
  /// **'Start import'**
  String get startImport;

  /// No description provided for @startRestore.
  ///
  /// In en, this message translates to:
  /// **'Start restore'**
  String get startRestore;

  /// No description provided for @startExport.
  ///
  /// In en, this message translates to:
  /// **'Start export'**
  String get startExport;

  /// No description provided for @requestCancel.
  ///
  /// In en, this message translates to:
  /// **'Request cancellation'**
  String get requestCancel;

  /// No description provided for @sourceMapping.
  ///
  /// In en, this message translates to:
  /// **'Source and target mapping'**
  String get sourceMapping;

  /// No description provided for @nativeTool.
  ///
  /// In en, this message translates to:
  /// **'Native tool'**
  String get nativeTool;

  /// No description provided for @defaultOmit.
  ///
  /// In en, this message translates to:
  /// **'Omit / database default'**
  String get defaultOmit;

  /// No description provided for @overwriteNever.
  ///
  /// In en, this message translates to:
  /// **'Do not overwrite'**
  String get overwriteNever;

  /// No description provided for @overwriteExisting.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing file'**
  String get overwriteExisting;

  /// No description provided for @planDetails.
  ///
  /// In en, this message translates to:
  /// **'Plan details'**
  String get planDetails;

  /// No description provided for @planMetricsNote.
  ///
  /// In en, this message translates to:
  /// **'Estimates and actual measurements use the server’s field names. Missing measurements are unavailable.'**
  String get planMetricsNote;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @tables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get tables;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get views;

  /// No description provided for @routines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get routines;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @databaseWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Database workbench'**
  String get databaseWorkbench;

  /// No description provided for @sidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get sidebar;

  /// No description provided for @unchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get unchanged;

  /// No description provided for @reviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get reviewDetails;

  /// No description provided for @generatedSql.
  ///
  /// In en, this message translates to:
  /// **'Generated SQL'**
  String get generatedSql;

  /// No description provided for @changeReverted.
  ///
  /// In en, this message translates to:
  /// **'Pending change reverted. Request a fresh review.'**
  String get changeReverted;

  /// No description provided for @unknownBatch.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown. The batch may have committed. Never replay it automatically; reconcile the session and recovery record.'**
  String get unknownBatch;

  /// No description provided for @expiredChangeReview.
  ///
  /// In en, this message translates to:
  /// **'The target changed or the review expired. Request a fresh review.'**
  String get expiredChangeReview;

  /// No description provided for @applyCommitExplanation.
  ///
  /// In en, this message translates to:
  /// **'Apply and commit starts and commits its own transaction. The source console must be idle with auto-commit enabled. Resolve manual SQL transactions separately.'**
  String get applyCommitExplanation;

  /// No description provided for @newRow.
  ///
  /// In en, this message translates to:
  /// **'New row'**
  String get newRow;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @proposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get proposed;

  /// No description provided for @changeCounts.
  ///
  /// In en, this message translates to:
  /// **'{inserts} inserts · {updates} updates · {deletes} deletes'**
  String changeCounts(int inserts, int updates, int deletes);

  /// No description provided for @sourceRow.
  ///
  /// In en, this message translates to:
  /// **'Source row {row}'**
  String sourceRow(String row);

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get refreshing;

  /// No description provided for @refreshActivities.
  ///
  /// In en, this message translates to:
  /// **'Refresh activities'**
  String get refreshActivities;

  /// No description provided for @explicitRefresh.
  ///
  /// In en, this message translates to:
  /// **'Explicit refresh'**
  String get explicitRefresh;

  /// No description provided for @pollFiveSeconds.
  ///
  /// In en, this message translates to:
  /// **'Poll every 5 seconds'**
  String get pollFiveSeconds;

  /// No description provided for @cancelSelectedActivity.
  ///
  /// In en, this message translates to:
  /// **'Cancel selected activity'**
  String get cancelSelectedActivity;

  /// No description provided for @terminateSelectedSession.
  ///
  /// In en, this message translates to:
  /// **'Terminate selected session'**
  String get terminateSelectedSession;

  /// No description provided for @filterActivities.
  ///
  /// In en, this message translates to:
  /// **'Filter current activities'**
  String get filterActivities;

  /// No description provided for @blockedBy.
  ///
  /// In en, this message translates to:
  /// **'Blocked by:'**
  String get blockedBy;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get up;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @insert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insert;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @migrationEngineMismatch.
  ///
  /// In en, this message translates to:
  /// **'The Apply to connection must use the same engine as the compared snapshots. Cross-engine migration is unsupported.'**
  String get migrationEngineMismatch;

  /// No description provided for @metadataContextChanged.
  ///
  /// In en, this message translates to:
  /// **'Inspection context changed. Refresh metadata explicitly.'**
  String get metadataContextChanged;

  /// No description provided for @newTableName.
  ///
  /// In en, this message translates to:
  /// **'New table name'**
  String get newTableName;

  /// No description provided for @routineIdentity.
  ///
  /// In en, this message translates to:
  /// **'Exact routine identity'**
  String get routineIdentity;

  /// No description provided for @objectColumnName.
  ///
  /// In en, this message translates to:
  /// **'Object / column name'**
  String get objectColumnName;

  /// No description provided for @builtInType.
  ///
  /// In en, this message translates to:
  /// **'Built-in type'**
  String get builtInType;

  /// No description provided for @sqlExpression.
  ///
  /// In en, this message translates to:
  /// **'SQL expression (empty removes it)'**
  String get sqlExpression;

  /// No description provided for @newPropertyValue.
  ///
  /// In en, this message translates to:
  /// **'New property value'**
  String get newPropertyValue;

  /// No description provided for @columnComment.
  ///
  /// In en, this message translates to:
  /// **'Column comment'**
  String get columnComment;

  /// No description provided for @columnCollation.
  ///
  /// In en, this message translates to:
  /// **'Column collation (empty uses server default)'**
  String get columnCollation;

  /// No description provided for @addDesignedColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column to new table'**
  String get addDesignedColumn;

  /// No description provided for @checkExpression.
  ///
  /// In en, this message translates to:
  /// **'CHECK expression'**
  String get checkExpression;

  /// No description provided for @referencedSchema.
  ///
  /// In en, this message translates to:
  /// **'Referenced schema / database'**
  String get referencedSchema;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// No description provided for @generateReviewedDdl.
  ///
  /// In en, this message translates to:
  /// **'Generate reviewed DDL'**
  String get generateReviewedDdl;

  /// No description provided for @inspectCapturedDefinition.
  ///
  /// In en, this message translates to:
  /// **'Inspect captured definition'**
  String get inspectCapturedDefinition;

  /// No description provided for @capturedObject.
  ///
  /// In en, this message translates to:
  /// **'Captured object'**
  String get capturedObject;

  /// No description provided for @designReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Changes are generated for review. Database contents remain unchanged until reviewed execution.'**
  String get designReviewNote;

  /// No description provided for @columnMetadataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Column metadata unavailable for this scope; inspect the selected schema before designing a column list.'**
  String get columnMetadataUnavailable;

  /// No description provided for @ordinaryColumn.
  ///
  /// In en, this message translates to:
  /// **'Ordinary column'**
  String get ordinaryColumn;

  /// No description provided for @columnWithDefault.
  ///
  /// In en, this message translates to:
  /// **'Column with default'**
  String get columnWithDefault;

  /// No description provided for @identityColumn.
  ///
  /// In en, this message translates to:
  /// **'Identity / auto-increment'**
  String get identityColumn;

  /// No description provided for @generatedColumn.
  ///
  /// In en, this message translates to:
  /// **'Generated column'**
  String get generatedColumn;

  /// No description provided for @columnType.
  ///
  /// In en, this message translates to:
  /// **'Column type'**
  String get columnType;

  /// No description provided for @nullableNotNull.
  ///
  /// In en, this message translates to:
  /// **'Nullable / NOT NULL'**
  String get nullableNotNull;

  /// No description provided for @defaultExpression.
  ///
  /// In en, this message translates to:
  /// **'Default expression'**
  String get defaultExpression;

  /// No description provided for @generatedExpression.
  ///
  /// In en, this message translates to:
  /// **'Generated expression'**
  String get generatedExpression;

  /// No description provided for @columnCollationProperty.
  ///
  /// In en, this message translates to:
  /// **'Column collation'**
  String get columnCollationProperty;

  /// No description provided for @loggedUnlogged.
  ///
  /// In en, this message translates to:
  /// **'Logged / unlogged'**
  String get loggedUnlogged;

  /// No description provided for @tableComment.
  ///
  /// In en, this message translates to:
  /// **'Table comment'**
  String get tableComment;

  /// No description provided for @storageEngine.
  ///
  /// In en, this message translates to:
  /// **'Storage engine'**
  String get storageEngine;

  /// No description provided for @tableCollation.
  ///
  /// In en, this message translates to:
  /// **'Table collation'**
  String get tableCollation;

  /// No description provided for @rowFormat.
  ///
  /// In en, this message translates to:
  /// **'Row format'**
  String get rowFormat;

  /// No description provided for @createOrReplace.
  ///
  /// In en, this message translates to:
  /// **'Create or replace'**
  String get createOrReplace;

  /// No description provided for @dropSelectedObject.
  ///
  /// In en, this message translates to:
  /// **'Drop selected object'**
  String get dropSelectedObject;

  /// No description provided for @addColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get addColumn;

  /// No description provided for @editColumnProperties.
  ///
  /// In en, this message translates to:
  /// **'Edit column properties'**
  String get editColumnProperties;

  /// No description provided for @tableProperties.
  ///
  /// In en, this message translates to:
  /// **'Table properties'**
  String get tableProperties;

  /// No description provided for @triggerDefinition.
  ///
  /// In en, this message translates to:
  /// **'Trigger definition'**
  String get triggerDefinition;

  /// No description provided for @createTable.
  ///
  /// In en, this message translates to:
  /// **'Create table'**
  String get createTable;

  /// No description provided for @viewDefinition.
  ///
  /// In en, this message translates to:
  /// **'View definition'**
  String get viewDefinition;

  /// No description provided for @routineDefinition.
  ///
  /// In en, this message translates to:
  /// **'Routine definition'**
  String get routineDefinition;

  /// No description provided for @chooseExistingObject.
  ///
  /// In en, this message translates to:
  /// **'Choose existing object'**
  String get chooseExistingObject;

  /// No description provided for @nullable.
  ///
  /// In en, this message translates to:
  /// **'Nullable'**
  String get nullable;

  /// No description provided for @removeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Remove identity'**
  String get removeIdentity;

  /// No description provided for @generatedAlways.
  ///
  /// In en, this message translates to:
  /// **'Generated always'**
  String get generatedAlways;

  /// No description provided for @generatedByDefault.
  ///
  /// In en, this message translates to:
  /// **'Generated by default / auto-increment'**
  String get generatedByDefault;

  /// No description provided for @loggedTable.
  ///
  /// In en, this message translates to:
  /// **'Logged table'**
  String get loggedTable;

  /// No description provided for @unloggedTable.
  ///
  /// In en, this message translates to:
  /// **'Unlogged table'**
  String get unloggedTable;

  /// No description provided for @orderedPrimaryKeyColumns.
  ///
  /// In en, this message translates to:
  /// **'Ordered primary-key columns'**
  String get orderedPrimaryKeyColumns;

  /// No description provided for @orderedColumns.
  ///
  /// In en, this message translates to:
  /// **'Ordered columns'**
  String get orderedColumns;

  /// No description provided for @ordinaryIndex.
  ///
  /// In en, this message translates to:
  /// **'Ordinary index'**
  String get ordinaryIndex;

  /// No description provided for @uniqueIndex.
  ///
  /// In en, this message translates to:
  /// **'Unique index'**
  String get uniqueIndex;

  /// No description provided for @primaryKey.
  ///
  /// In en, this message translates to:
  /// **'Primary key'**
  String get primaryKey;

  /// No description provided for @uniqueConstraint.
  ///
  /// In en, this message translates to:
  /// **'Unique constraint'**
  String get uniqueConstraint;

  /// No description provided for @foreignKey.
  ///
  /// In en, this message translates to:
  /// **'Foreign key'**
  String get foreignKey;

  /// No description provided for @checkConstraint.
  ///
  /// In en, this message translates to:
  /// **'CHECK constraint'**
  String get checkConstraint;

  /// No description provided for @immediateChecking.
  ///
  /// In en, this message translates to:
  /// **'Immediate checking'**
  String get immediateChecking;

  /// No description provided for @deferrableChecking.
  ///
  /// In en, this message translates to:
  /// **'Deferrable checking'**
  String get deferrableChecking;

  /// No description provided for @initiallyImmediate.
  ///
  /// In en, this message translates to:
  /// **'Initially immediate'**
  String get initiallyImmediate;

  /// No description provided for @initiallyDeferred.
  ///
  /// In en, this message translates to:
  /// **'Initially deferred'**
  String get initiallyDeferred;

  /// No description provided for @referencedTable.
  ///
  /// In en, this message translates to:
  /// **'Referenced table'**
  String get referencedTable;

  /// No description provided for @orderedReferencedColumns.
  ///
  /// In en, this message translates to:
  /// **'Referenced columns in matching order'**
  String get orderedReferencedColumns;

  /// No description provided for @objectDefinitionEditor.
  ///
  /// In en, this message translates to:
  /// **'Native object definition SQL editor'**
  String get objectDefinitionEditor;

  /// No description provided for @onDelete.
  ///
  /// In en, this message translates to:
  /// **'On delete'**
  String get onDelete;

  /// No description provided for @onUpdate.
  ///
  /// In en, this message translates to:
  /// **'On update'**
  String get onUpdate;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @saveSqlClose.
  ///
  /// In en, this message translates to:
  /// **'Save SQL and close'**
  String get saveSqlClose;

  /// No description provided for @discardSqlClose.
  ///
  /// In en, this message translates to:
  /// **'Discard SQL and close'**
  String get discardSqlClose;

  /// No description provided for @closeBusyData.
  ///
  /// In en, this message translates to:
  /// **'Close BusyData'**
  String get closeBusyData;

  /// No description provided for @saveDraftsClose.
  ///
  /// In en, this message translates to:
  /// **'Save drafts and close'**
  String get saveDraftsClose;

  /// No description provided for @closeWithoutRecovery.
  ///
  /// In en, this message translates to:
  /// **'Close without recovery'**
  String get closeWithoutRecovery;

  /// No description provided for @recoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Recovery failed'**
  String get recoveryFailed;

  /// No description provided for @discardFailedSaveClose.
  ///
  /// In en, this message translates to:
  /// **'Discard failed save and close'**
  String get discardFailedSaveClose;

  /// No description provided for @closeWithoutSavingRecovery.
  ///
  /// In en, this message translates to:
  /// **'Close without saving recovery'**
  String get closeWithoutSavingRecovery;

  /// No description provided for @disableSqlRecovery.
  ///
  /// In en, this message translates to:
  /// **'Disable SQL recovery'**
  String get disableSqlRecovery;

  /// No description provided for @historyPrivacy.
  ///
  /// In en, this message translates to:
  /// **'History privacy'**
  String get historyPrivacy;

  /// No description provided for @enableSqlRetention.
  ///
  /// In en, this message translates to:
  /// **'Enable SQL retention'**
  String get enableSqlRetention;

  /// No description provided for @disableSqlRetention.
  ///
  /// In en, this message translates to:
  /// **'Disable SQL retention'**
  String get disableSqlRetention;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @deleteHistoryEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete history entry'**
  String get deleteHistoryEntry;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// No description provided for @saveRetention.
  ///
  /// In en, this message translates to:
  /// **'Save retention'**
  String get saveRetention;

  /// No description provided for @retentionDays.
  ///
  /// In en, this message translates to:
  /// **'Retention days'**
  String get retentionDays;

  /// No description provided for @sqlTextRetained.
  ///
  /// In en, this message translates to:
  /// **'SQL text retained'**
  String get sqlTextRetained;

  /// No description provided for @sqlTextDisabled.
  ///
  /// In en, this message translates to:
  /// **'SQL text disabled'**
  String get sqlTextDisabled;

  /// No description provided for @openHistoryQuery.
  ///
  /// In en, this message translates to:
  /// **'Open as new SQL tab'**
  String get openHistoryQuery;

  /// No description provided for @caCertificateFile.
  ///
  /// In en, this message translates to:
  /// **'CA certificate file'**
  String get caCertificateFile;

  /// No description provided for @clientCertificateFile.
  ///
  /// In en, this message translates to:
  /// **'Client certificate file'**
  String get clientCertificateFile;

  /// No description provided for @clientKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Client key file'**
  String get clientKeyFile;

  /// No description provided for @directConnection.
  ///
  /// In en, this message translates to:
  /// **'Direct connection'**
  String get directConnection;

  /// No description provided for @sshTunnel.
  ///
  /// In en, this message translates to:
  /// **'SSH tunnel'**
  String get sshTunnel;

  /// No description provided for @sshHost.
  ///
  /// In en, this message translates to:
  /// **'SSH host'**
  String get sshHost;

  /// No description provided for @sshPort.
  ///
  /// In en, this message translates to:
  /// **'SSH port'**
  String get sshPort;

  /// No description provided for @sshUser.
  ///
  /// In en, this message translates to:
  /// **'SSH user'**
  String get sshUser;

  /// No description provided for @reviewedKnownHosts.
  ///
  /// In en, this message translates to:
  /// **'Reviewed known_hosts file'**
  String get reviewedKnownHosts;

  /// No description provided for @reviewSshKey.
  ///
  /// In en, this message translates to:
  /// **'Review SSH host key'**
  String get reviewSshKey;

  /// No description provided for @changedSshKey.
  ///
  /// In en, this message translates to:
  /// **'Changed SSH host key'**
  String get changedSshKey;

  /// No description provided for @verifyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Verify this fingerprint independently before trusting it.'**
  String get verifyFingerprint;

  /// No description provided for @selectedKeyPassword.
  ///
  /// In en, this message translates to:
  /// **'Selected key or password'**
  String get selectedKeyPassword;

  /// No description provided for @selectedAgentIdentity.
  ///
  /// In en, this message translates to:
  /// **'Selected SSH-agent identity'**
  String get selectedAgentIdentity;

  /// No description provided for @selectedAgentSocket.
  ///
  /// In en, this message translates to:
  /// **'Selected Linux agent socket / Windows named pipe'**
  String get selectedAgentSocket;

  /// No description provided for @selectedKeyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Selected key fingerprint · SHA256:…'**
  String get selectedKeyFingerprint;

  /// No description provided for @selectedPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Selected private key (optional)'**
  String get selectedPrivateKey;

  /// No description provided for @sshPassword.
  ///
  /// In en, this message translates to:
  /// **'SSH password'**
  String get sshPassword;

  /// No description provided for @keyPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase'**
  String get keyPassphrase;

  /// No description provided for @connectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout · 1–120 seconds'**
  String get connectionTimeout;

  /// No description provided for @sqlTimeout.
  ///
  /// In en, this message translates to:
  /// **'SQL execution/fetch deadline · 1–3600 seconds (0 = 60)'**
  String get sqlTimeout;

  /// No description provided for @schemasEquivalent.
  ///
  /// In en, this message translates to:
  /// **'Captured schemas are equivalent.'**
  String get schemasEquivalent;

  /// No description provided for @migrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Migration covers supported captured differences.'**
  String get migrationComplete;

  /// No description provided for @migrationPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial migration; unsupported differences remain.'**
  String get migrationPartial;

  /// No description provided for @differencesLimited.
  ///
  /// In en, this message translates to:
  /// **'Difference presentation is limited. Review the complete saved snapshots and generated SQL.'**
  String get differencesLimited;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absent;

  /// No description provided for @definitionPreviewLimited.
  ///
  /// In en, this message translates to:
  /// **'Definition preview is limited; use the original snapshot for full evidence.'**
  String get definitionPreviewLimited;

  /// No description provided for @migrationBatchNote.
  ///
  /// In en, this message translates to:
  /// **'SQL is one dependency-ordered batch. Individual object selection is for inspection and does not select statements for application.'**
  String get migrationBatchNote;

  /// No description provided for @unsupportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get unsupportedLabel;

  /// No description provided for @differenceAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get differenceAdded;

  /// No description provided for @differenceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get differenceRemoved;

  /// No description provided for @differenceChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get differenceChanged;

  /// No description provided for @selectHistoryEntry.
  ///
  /// In en, this message translates to:
  /// **'Select a history entry'**
  String get selectHistoryEntry;

  /// No description provided for @searchSqlTarget.
  ///
  /// In en, this message translates to:
  /// **'Search SQL or target'**
  String get searchSqlTarget;

  /// No description provided for @closeSqlTab.
  ///
  /// In en, this message translates to:
  /// **'Close SQL tab'**
  String get closeSqlTab;

  /// No description provided for @historyMetadataRetained.
  ///
  /// In en, this message translates to:
  /// **'Status and target metadata remain in history.'**
  String get historyMetadataRetained;

  /// No description provided for @historyPreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Preview only. Open as new SQL tab to retrieve retained text.'**
  String get historyPreviewNote;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @authReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Review the exact principal and target before applying. Credentials are never put in SQL documents or history. Existing connections and saved passwords remain separate.'**
  String get authReviewNote;

  /// No description provided for @createLogin.
  ///
  /// In en, this message translates to:
  /// **'Create login account'**
  String get createLogin;

  /// No description provided for @createRole.
  ///
  /// In en, this message translates to:
  /// **'Create non-login role'**
  String get createRole;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// No description provided for @preventLogin.
  ///
  /// In en, this message translates to:
  /// **'Prevent new logins'**
  String get preventLogin;

  /// No description provided for @allowLogin.
  ///
  /// In en, this message translates to:
  /// **'Allow new logins'**
  String get allowLogin;

  /// No description provided for @dropPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Drop principal'**
  String get dropPrincipal;

  /// No description provided for @principalName.
  ///
  /// In en, this message translates to:
  /// **'Exact principal name'**
  String get principalName;

  /// No description provided for @accountHost.
  ///
  /// In en, this message translates to:
  /// **'Exact account host (wildcards grant broad login scope)'**
  String get accountHost;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get repeatPassword;

  /// No description provided for @reviewAccount.
  ///
  /// In en, this message translates to:
  /// **'Review account operation'**
  String get reviewAccount;

  /// No description provided for @passwordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Enter the same nonempty password twice'**
  String get passwordsMismatch;

  /// No description provided for @accountSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Account operation could not be submitted. Check the target, authentication policy and database privileges.'**
  String get accountSubmitFailed;

  /// No description provided for @privilegeReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Inspect direct grants; generated SQL still requires execution review.'**
  String get privilegeReviewNote;

  /// No description provided for @inspectionLimited.
  ///
  /// In en, this message translates to:
  /// **'Limited to 500 rows per section. Narrow the search; an empty section does not prove absence of effective access.'**
  String get inspectionLimited;

  /// No description provided for @findPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Find user / role name'**
  String get findPrincipal;

  /// No description provided for @searchPrincipals.
  ///
  /// In en, this message translates to:
  /// **'Search principals'**
  String get searchPrincipals;

  /// No description provided for @choosePrincipal.
  ///
  /// In en, this message translates to:
  /// **'Choose a principal'**
  String get choosePrincipal;

  /// No description provided for @inspectGrants.
  ///
  /// In en, this message translates to:
  /// **'Inspect selected grants'**
  String get inspectGrants;

  /// No description provided for @tablePrivileges.
  ///
  /// In en, this message translates to:
  /// **'Table / view privileges'**
  String get tablePrivileges;

  /// No description provided for @schemaPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Schema privileges'**
  String get schemaPrivileges;

  /// No description provided for @databasePrivileges.
  ///
  /// In en, this message translates to:
  /// **'Database privileges'**
  String get databasePrivileges;

  /// No description provided for @roleMembership.
  ///
  /// In en, this message translates to:
  /// **'Role membership'**
  String get roleMembership;

  /// No description provided for @defaultRole.
  ///
  /// In en, this message translates to:
  /// **'Default role activation'**
  String get defaultRole;

  /// No description provided for @chooseGrantRole.
  ///
  /// In en, this message translates to:
  /// **'Choose the role to grant / revoke'**
  String get chooseGrantRole;

  /// No description provided for @tableView.
  ///
  /// In en, this message translates to:
  /// **'Table / view'**
  String get tableView;

  /// No description provided for @explicitPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Explicit privileges (comma separated)'**
  String get explicitPrivileges;

  /// No description provided for @setDefaultRole.
  ///
  /// In en, this message translates to:
  /// **'Set selected default role'**
  String get setDefaultRole;

  /// No description provided for @clearDefaultRole.
  ///
  /// In en, this message translates to:
  /// **'Clear default role'**
  String get clearDefaultRole;

  /// No description provided for @grantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get grantAccess;

  /// No description provided for @revokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get revokeAccess;

  /// No description provided for @withoutDelegation.
  ///
  /// In en, this message translates to:
  /// **'Without delegation'**
  String get withoutDelegation;

  /// No description provided for @allowDelegation.
  ///
  /// In en, this message translates to:
  /// **'Allow recipient to grant to others'**
  String get allowDelegation;

  /// No description provided for @readonlyChanges.
  ///
  /// In en, this message translates to:
  /// **'This profile is read-only. Changes require an explicitly writable session.'**
  String get readonlyChanges;

  /// No description provided for @createPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Create user / role'**
  String get createPrincipal;

  /// No description provided for @manageAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Manage selected authentication'**
  String get manageAuthentication;

  /// No description provided for @openPrivilegeSql.
  ///
  /// In en, this message translates to:
  /// **'Open privilege SQL for review'**
  String get openPrivilegeSql;

  /// No description provided for @inspectPrincipalFirst.
  ///
  /// In en, this message translates to:
  /// **'Inspect the selected principal before drafting a change'**
  String get inspectPrincipalFirst;

  /// No description provided for @accountAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Account authentication'**
  String get accountAuthentication;

  /// No description provided for @schema.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get schema;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @availableEmpty.
  ///
  /// In en, this message translates to:
  /// **'Available · empty data'**
  String get availableEmpty;

  /// No description provided for @limitedVisibility.
  ///
  /// In en, this message translates to:
  /// **'Limited visibility or scope'**
  String get limitedVisibility;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permissionDenied;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @profileDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled by profile'**
  String get profileDisabled;

  /// No description provided for @unknownState.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownState;

  /// No description provided for @inspecting.
  ///
  /// In en, this message translates to:
  /// **'Inspecting…'**
  String get inspecting;

  /// No description provided for @refreshCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Refresh capabilities'**
  String get refreshCapabilities;

  /// No description provided for @staleRefresh.
  ///
  /// In en, this message translates to:
  /// **'Stale · refresh after connecting'**
  String get staleRefresh;

  /// No description provided for @staleContext.
  ///
  /// In en, this message translates to:
  /// **'Stale · refresh after connecting or changing context'**
  String get staleContext;

  /// No description provided for @partialTreeLimit.
  ///
  /// In en, this message translates to:
  /// **'Partial · tree limit reached; narrow with database object search'**
  String get partialTreeLimit;

  /// No description provided for @schemaComparison.
  ///
  /// In en, this message translates to:
  /// **'Schema comparison'**
  String get schemaComparison;

  /// No description provided for @searchTable.
  ///
  /// In en, this message translates to:
  /// **'Search table'**
  String get searchTable;

  /// No description provided for @focusObject.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focusObject;

  /// No description provided for @exportSvg.
  ///
  /// In en, this message translates to:
  /// **'Export SVG'**
  String get exportSvg;

  /// No description provided for @exportPng.
  ///
  /// In en, this message translates to:
  /// **'Export PNG'**
  String get exportPng;

  /// No description provided for @diagramNotes.
  ///
  /// In en, this message translates to:
  /// **'Diagram notes (included in SVG)'**
  String get diagramNotes;

  /// No description provided for @openNotes.
  ///
  /// In en, this message translates to:
  /// **'Open notes'**
  String get openNotes;

  /// No description provided for @saveNotes.
  ///
  /// In en, this message translates to:
  /// **'Save notes'**
  String get saveNotes;

  /// No description provided for @newSnippet.
  ///
  /// In en, this message translates to:
  /// **'New snippet'**
  String get newSnippet;

  /// No description provided for @snippetName.
  ///
  /// In en, this message translates to:
  /// **'Snippet name'**
  String get snippetName;

  /// No description provided for @saveSnippet.
  ///
  /// In en, this message translates to:
  /// **'Save snippet'**
  String get saveSnippet;

  /// No description provided for @deleteSnippet.
  ///
  /// In en, this message translates to:
  /// **'Delete saved snippet'**
  String get deleteSnippet;

  /// No description provided for @insertSnippet.
  ///
  /// In en, this message translates to:
  /// **'Insert into SQL document'**
  String get insertSnippet;

  /// No description provided for @snippetEditor.
  ///
  /// In en, this message translates to:
  /// **'SQL snippet editor'**
  String get snippetEditor;

  /// No description provided for @snippetsNote.
  ///
  /// In en, this message translates to:
  /// **'Insert saved local SQL into the captured document with undo. Execution remains explicit.'**
  String get snippetsNote;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @expanded.
  ///
  /// In en, this message translates to:
  /// **'expanded'**
  String get expanded;

  /// No description provided for @collapsed.
  ///
  /// In en, this message translates to:
  /// **'collapsed'**
  String get collapsed;

  /// No description provided for @treeLevel.
  ///
  /// In en, this message translates to:
  /// **'level'**
  String get treeLevel;

  /// No description provided for @retainedView.
  ///
  /// In en, this message translates to:
  /// **'Retained view'**
  String get retainedView;

  /// No description provided for @tableQuerySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Table query snapshot'**
  String get tableQuerySnapshot;

  /// No description provided for @originalResultNote.
  ///
  /// In en, this message translates to:
  /// **'Original retained result; SQL is not executed by paging or inspection'**
  String get originalResultNote;

  /// No description provided for @tableFilterNote.
  ///
  /// In en, this message translates to:
  /// **'Apply submits a new reviewed database query. The previous snapshot remains available.'**
  String get tableFilterNote;

  /// No description provided for @retainedFilterNote.
  ///
  /// In en, this message translates to:
  /// **'All fetched rows in a fixed snapshot. SQL is not rerun. Retained ordering can differ from database collation.'**
  String get retainedFilterNote;

  /// No description provided for @retainedRowNote.
  ///
  /// In en, this message translates to:
  /// **'Choose a row within the already fetched result. SQL is not rerun.'**
  String get retainedRowNote;

  /// No description provided for @copyLimitNote.
  ///
  /// In en, this message translates to:
  /// **'Copy is limited to 10,000 cells; export retained data for larger ranges.'**
  String get copyLimitNote;

  /// No description provided for @inlineValueLimit.
  ///
  /// In en, this message translates to:
  /// **'Inline edits support 8KiB values'**
  String get inlineValueLimit;

  /// No description provided for @editContextChanged.
  ///
  /// In en, this message translates to:
  /// **'The source session or editability context changed; inspect or refresh the assessment before staging'**
  String get editContextChanged;

  /// No description provided for @editAssessmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Editability unavailable; refresh assessment after the session is idle'**
  String get editAssessmentUnavailable;

  /// No description provided for @rowChangeReverted.
  ///
  /// In en, this message translates to:
  /// **'Pending row change reverted; database unchanged'**
  String get rowChangeReverted;

  /// No description provided for @sqlCopyRequiresMetadata.
  ///
  /// In en, this message translates to:
  /// **'SQL copy requires the backend and its retained type metadata.'**
  String get sqlCopyRequiresMetadata;

  /// No description provided for @exportFullValue.
  ///
  /// In en, this message translates to:
  /// **'Export full retained value'**
  String get exportFullValue;

  /// No description provided for @valueExportReview.
  ///
  /// In en, this message translates to:
  /// **'Save {bytes} bytes to {path}? Existing contents will be replaced. SQL is not rerun.'**
  String valueExportReview(String bytes, String path);

  /// No description provided for @goToRetainedRow.
  ///
  /// In en, this message translates to:
  /// **'Go to retained row'**
  String get goToRetainedRow;

  /// No description provided for @row.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get row;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @retryRows.
  ///
  /// In en, this message translates to:
  /// **'Retry retained rows'**
  String get retryRows;

  /// No description provided for @previousRows.
  ///
  /// In en, this message translates to:
  /// **'Previous rows'**
  String get previousRows;

  /// No description provided for @nextRows.
  ///
  /// In en, this message translates to:
  /// **'Next rows'**
  String get nextRows;

  /// No description provided for @firstWindow.
  ///
  /// In en, this message translates to:
  /// **'First retained window'**
  String get firstWindow;

  /// No description provided for @lastWindow.
  ///
  /// In en, this message translates to:
  /// **'Last fetched window'**
  String get lastWindow;

  /// No description provided for @setNull.
  ///
  /// In en, this message translates to:
  /// **'Set NULL'**
  String get setNull;

  /// No description provided for @copyFormat.
  ///
  /// In en, this message translates to:
  /// **'Copy {format}'**
  String copyFormat(String format);

  /// No description provided for @textValue.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textValue;

  /// No description provided for @sqlValues.
  ///
  /// In en, this message translates to:
  /// **'SQL values'**
  String get sqlValues;

  /// No description provided for @rowSelection.
  ///
  /// In en, this message translates to:
  /// **'Row selection'**
  String get rowSelection;

  /// No description provided for @selectRow.
  ///
  /// In en, this message translates to:
  /// **'Select row {row}'**
  String selectRow(String row);

  /// No description provided for @columnHeader.
  ///
  /// In en, this message translates to:
  /// **'Column {column}'**
  String columnHeader(String column);

  /// No description provided for @pendingChange.
  ///
  /// In en, this message translates to:
  /// **'pending change'**
  String get pendingChange;

  /// No description provided for @readonlyCell.
  ///
  /// In en, this message translates to:
  /// **'Read-only cell'**
  String get readonlyCell;

  /// No description provided for @editableCell.
  ///
  /// In en, this message translates to:
  /// **'Editable cell'**
  String get editableCell;

  /// No description provided for @loadValueFirst.
  ///
  /// In en, this message translates to:
  /// **'Load this retained value first'**
  String get loadValueFirst;

  /// No description provided for @editUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Editability is not available'**
  String get editUnavailable;

  /// No description provided for @editCell.
  ///
  /// In en, this message translates to:
  /// **'Edit cell'**
  String get editCell;

  /// No description provided for @unsupportedEditValue.
  ///
  /// In en, this message translates to:
  /// **'This retained value supports inspection only'**
  String get unsupportedEditValue;

  /// No description provided for @bytesCount.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes'**
  String bytesCount(String bytes);

  /// No description provided for @problems.
  ///
  /// In en, this message translates to:
  /// **'Problems'**
  String get problems;

  /// No description provided for @ownedSessions.
  ///
  /// In en, this message translates to:
  /// **'Owned sessions'**
  String get ownedSessions;

  /// No description provided for @noProblems.
  ///
  /// In en, this message translates to:
  /// **'No recorded problems'**
  String get noProblems;

  /// No description provided for @duplicateConnection.
  ///
  /// In en, this message translates to:
  /// **'Duplicate connection'**
  String get duplicateConnection;

  /// No description provided for @deleteConnection.
  ///
  /// In en, this message translates to:
  /// **'Delete connection'**
  String get deleteConnection;

  /// No description provided for @deleteConnectionReview.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? Existing physical sessions keep their original settings.'**
  String deleteConnectionReview(String name);

  /// No description provided for @unresolvedSessions.
  ///
  /// In en, this message translates to:
  /// **'Unresolved sessions'**
  String get unresolvedSessions;

  /// No description provided for @disconnectSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Resolve active jobs and transactions first. Disconnect affects every client of this physical session; it never commits or replays SQL. Unknown outcomes remain unknown.'**
  String get disconnectSessionNote;

  /// No description provided for @transferSettingsChanged.
  ///
  /// In en, this message translates to:
  /// **'Transfer settings changed; review again'**
  String get transferSettingsChanged;

  /// No description provided for @transferReviewReady.
  ///
  /// In en, this message translates to:
  /// **'Review ready · verify target, scope, mapping and file behavior before starting'**
  String get transferReviewReady;

  /// No description provided for @sourcePreviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Source preview · no database rows imported'**
  String get sourcePreviewNotice;

  /// No description provided for @transferRequiresReview.
  ///
  /// In en, this message translates to:
  /// **'Review this exact transfer first'**
  String get transferRequiresReview;

  /// No description provided for @transferSubmittedNotice.
  ///
  /// In en, this message translates to:
  /// **'Submitted · cancellation does not undo acknowledged commits or published files'**
  String get transferSubmittedNotice;

  /// No description provided for @sqlExportExecutionNote.
  ///
  /// In en, this message translates to:
  /// **'A new reviewed SQL execution'**
  String get sqlExportExecutionNote;

  /// No description provided for @retainedExportSnapshotNote.
  ///
  /// In en, this message translates to:
  /// **'Fetched snapshot; SQL is not executed'**
  String get retainedExportSnapshotNote;

  /// No description provided for @restorePartialCommitNote.
  ///
  /// In en, this message translates to:
  /// **'Restore may partially commit. Cancelling does not undo the restore.'**
  String get restorePartialCommitNote;

  /// No description provided for @sourcePreviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Source preview · up to 20 rows'**
  String get sourcePreviewLimit;

  /// No description provided for @importBatchSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'Errors or cancellation preserve earlier batch commits. Source hashes and selected immutable material are verified before dispatch.'**
  String get importBatchSafetyNote;

  /// No description provided for @nullMarkerLiteralNote.
  ///
  /// In en, this message translates to:
  /// **'Unquoted NULL marker; quoted marker is literal text'**
  String get nullMarkerLiteralNote;

  /// No description provided for @immutableSourceHash.
  ///
  /// In en, this message translates to:
  /// **'Immutable source SHA-256: {hash}'**
  String immutableSourceHash(String hash);

  /// No description provided for @sourceColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Source column {column}'**
  String sourceColumnLabel(String column);

  /// No description provided for @previewRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview row {row}, {column}: {value}'**
  String previewRowLabel(String row, String column, String value);

  /// No description provided for @transferCancellationNotice.
  ///
  /// In en, this message translates to:
  /// **'Cancellation requested · wait for acknowledgement'**
  String get transferCancellationNotice;

  /// No description provided for @transferProgress.
  ///
  /// In en, this message translates to:
  /// **'{processed} processed · {committed} committed · {rejected} rejected'**
  String transferProgress(String processed, String committed, String rejected);

  /// No description provided for @importAtomicPolicy.
  ///
  /// In en, this message translates to:
  /// **'All rows in one transaction'**
  String get importAtomicPolicy;

  /// No description provided for @importBatchPolicy.
  ///
  /// In en, this message translates to:
  /// **'Commit batches; stop on error'**
  String get importBatchPolicy;

  /// No description provided for @importSkipPolicy.
  ///
  /// In en, this message translates to:
  /// **'Skip invalid rows; commit batches'**
  String get importSkipPolicy;

  /// No description provided for @closeWorkCounts.
  ///
  /// In en, this message translates to:
  /// **'Acknowledgements/connections: {operations}\nUnsaved documents: {documents}\nSaves in progress: {saves}\nStaged edits: {edits}\nActive jobs: {jobs}\nTransactions requiring cleanup: {transactions}\nUnknown operation outcomes: {unknown}\nUncertain sessions: {sessions}'**
  String closeWorkCounts(
    String operations,
    String documents,
    String saves,
    String edits,
    String jobs,
    String transactions,
    String unknown,
    String sessions,
  );

  /// No description provided for @closeDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'SQL drafts will be saved locally.'**
  String get closeDraftSaved;

  /// No description provided for @closeDraftLost.
  ///
  /// In en, this message translates to:
  /// **'Recovery is disabled; unsaved SQL and object designs will be lost.'**
  String get closeDraftLost;

  /// No description provided for @closeDesignRecovery.
  ///
  /// In en, this message translates to:
  /// **'Object designs use private bounded recovery. Reconnect and inspect metadata explicitly after reopening.'**
  String get closeDesignRecovery;

  /// No description provided for @closeCleanupReview.
  ///
  /// In en, this message translates to:
  /// **'Closing a final session owner requests cancellation, rolls back acknowledged transactions and disconnects. Unknown outcomes remain unknown; SQL is never committed or replayed.'**
  String get closeCleanupReview;

  /// No description provided for @closeSharedSession.
  ///
  /// In en, this message translates to:
  /// **'Other clients retain their shared physical session.'**
  String get closeSharedSession;

  /// No description provided for @closeStagedRecovery.
  ///
  /// In en, this message translates to:
  /// **'Pending changes require acknowledged private recovery, explicit reconnection and a fresh review.'**
  String get closeStagedRecovery;

  /// No description provided for @closeRecoveryLoss.
  ///
  /// In en, this message translates to:
  /// **'Latest documents and layout could not be saved. Closing may lose unsaved SQL and pending changes; existing files and recovery data are preserved.'**
  String get closeRecoveryLoss;

  /// No description provided for @closeWaitNotice.
  ///
  /// In en, this message translates to:
  /// **'Wait for pending acknowledgements and connection cleanup before closing.'**
  String get closeWaitNotice;

  /// No description provided for @saveFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'SQL save failed. Preserve the dirty SQL or explicitly discard it.'**
  String get saveFailedNotice;

  /// No description provided for @closeCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backend cleanup failed; BusyData remains open.'**
  String get closeCleanupFailed;

  /// No description provided for @closeBackendUnverified.
  ///
  /// In en, this message translates to:
  /// **'Backend status is unverified; work may still be pending.'**
  String get closeBackendUnverified;

  /// No description provided for @historyRetainSqlReview.
  ///
  /// In en, this message translates to:
  /// **'SQL can contain secrets. Store SQL text for {days} days?'**
  String historyRetainSqlReview(String days);

  /// No description provided for @historyStopSqlReview.
  ///
  /// In en, this message translates to:
  /// **'Stop storing SQL text and remove it from existing history?'**
  String get historyStopSqlReview;

  /// No description provided for @historyClearReview.
  ///
  /// In en, this message translates to:
  /// **'Delete all history? Active operations can record their outcome when they finish.'**
  String get historyClearReview;

  /// No description provided for @historyDeleteReview.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected history entry?'**
  String get historyDeleteReview;

  /// No description provided for @historyRetentionRange.
  ///
  /// In en, this message translates to:
  /// **'Retention must be 1–3650 days'**
  String get historyRetentionRange;

  /// No description provided for @enableSqlHistory.
  ///
  /// In en, this message translates to:
  /// **'Enable SQL history'**
  String get enableSqlHistory;

  /// No description provided for @stopSqlHistory.
  ///
  /// In en, this message translates to:
  /// **'Stop SQL retention'**
  String get stopSqlHistory;

  /// No description provided for @recoveryDiscardReview.
  ///
  /// In en, this message translates to:
  /// **'Discard this recovery record? Reconcile unknown outcomes first; discarding never undoes committed changes.'**
  String get recoveryDiscardReview;

  /// No description provided for @closeSqlSummary.
  ///
  /// In en, this message translates to:
  /// **'Unsaved SQL: {unsaved}\nPending changes: {edits}\nActive jobs: {jobs}'**
  String closeSqlSummary(String unsaved, String edits, String jobs);

  /// No description provided for @recoveryStayOpen.
  ///
  /// In en, this message translates to:
  /// **'Recovery failed. BusyData remains open; unsaved work is preserved.'**
  String get recoveryStayOpen;

  /// No description provided for @commitUncertaintyNote.
  ///
  /// In en, this message translates to:
  /// **'A network failure can leave the commit outcome unknown. Never retry automatically.'**
  String get commitUncertaintyNote;

  /// No description provided for @closeObjectDesignDiscard.
  ///
  /// In en, this message translates to:
  /// **'Unsaved object design fields will be discarded. Generate and save SQL first to retain the design.'**
  String get closeObjectDesignDiscard;

  /// No description provided for @savePrivateDrafts.
  ///
  /// In en, this message translates to:
  /// **'Save private recovery drafts'**
  String get savePrivateDrafts;

  /// No description provided for @noPrivateDrafts.
  ///
  /// In en, this message translates to:
  /// **'Do not save recovery drafts'**
  String get noPrivateDrafts;

  /// No description provided for @shortcutField.
  ///
  /// In en, this message translates to:
  /// **'{command} shortcut'**
  String shortcutField(String command);

  /// No description provided for @shortcutInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a valid shortcut that is not assigned to another action. F6 and Shift+F6 are reserved.'**
  String get shortcutInvalid;

  /// No description provided for @disableRecoveryReview.
  ///
  /// In en, this message translates to:
  /// **'Delete local SQL, design and staged-change recovery? Unsaved work stays open; a crash can lose it. Reconcile unknown outcomes first.'**
  String get disableRecoveryReview;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get preferencesSaved;

  /// No description provided for @sharingSessionReview.
  ///
  /// In en, this message translates to:
  /// **'This query shares the named physical session, transaction, temporary objects and settings with its listed clients. Closing one client preserves the others.'**
  String get sharingSessionReview;

  /// No description provided for @recoveryReconcileFirst.
  ///
  /// In en, this message translates to:
  /// **'Reconcile applying or unknown changes before disabling recovery. Discard recovery records only through their explicit review.'**
  String get recoveryReconcileFirst;

  /// No description provided for @enterSearchText.
  ///
  /// In en, this message translates to:
  /// **'Enter search text'**
  String get enterSearchText;

  /// No description provided for @noSearchMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noSearchMatches;

  /// No description provided for @searchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total} matches'**
  String searchMatchCount(String position, String total);

  /// No description provided for @formatSqlChanged.
  ///
  /// In en, this message translates to:
  /// **'SQL or target changed. Original SQL preserved; request a fresh format preview.'**
  String get formatSqlChanged;

  /// No description provided for @formatSqlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Formatting unavailable for incomplete or unsupported syntax or analysis limits. Original SQL preserved.'**
  String get formatSqlUnavailable;

  /// No description provided for @stageChange.
  ///
  /// In en, this message translates to:
  /// **'Stage change'**
  String get stageChange;

  /// No description provided for @pendingChangesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending changes; database unchanged until reviewed application.'**
  String pendingChangesCount(String count);

  /// No description provided for @discardChangesCount.
  ///
  /// In en, this message translates to:
  /// **'Discard {count} pending changes? No database operation is submitted.'**
  String discardChangesCount(String count);

  /// No description provided for @recoveryNoExecution.
  ///
  /// In en, this message translates to:
  /// **'Recovery never connects, runs source SQL, resumes transactions or replays changes. Unknown and committed records cannot be reapplied.'**
  String get recoveryNoExecution;

  /// No description provided for @recoveredDesign.
  ///
  /// In en, this message translates to:
  /// **'Recovered design. Connect explicitly and inspect current metadata before generating a fresh review. Restoration fetched no SQL or metadata.'**
  String get recoveredDesign;

  /// No description provided for @retainedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Retained data unavailable. Saved SQL and private recovery remain local.'**
  String get retainedUnavailable;

  /// No description provided for @activityFingerprintNote.
  ///
  /// In en, this message translates to:
  /// **'The selected activity fingerprint is revalidated before dispatch. Writes may have unknown outcomes.'**
  String get activityFingerprintNote;

  /// No description provided for @replaceFileReview.
  ///
  /// In en, this message translates to:
  /// **'Replace the reviewed file at {path}? A changed destination requires a fresh review.'**
  String replaceFileReview(String path);

  /// No description provided for @diagramPngSaved.
  ///
  /// In en, this message translates to:
  /// **'Diagram PNG saved. Long notes show up to six lines.'**
  String get diagramPngSaved;

  /// No description provided for @editTargetChanged.
  ///
  /// In en, this message translates to:
  /// **'The edit target changed. Reopen the row editor before staging.'**
  String get editTargetChanged;

  /// Database-reported affected row count in execution messages.
  ///
  /// In en, this message translates to:
  /// **'Affected rows: {count}'**
  String affectedRowCount(String count);

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @resetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get resetView;

  /// No description provided for @diagramKeys.
  ///
  /// In en, this message translates to:
  /// **'Arrows pan; + and - zoom; Home resets the view.'**
  String get diagramKeys;

  /// No description provided for @explorerConnected.
  ///
  /// In en, this message translates to:
  /// **'Explorer connected'**
  String get explorerConnected;

  /// No description provided for @explorerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Explorer disconnected'**
  String get explorerDisconnected;

  /// Physical query sessions separate from the Explorer inspection session.
  ///
  /// In en, this message translates to:
  /// **'Query sessions {count}'**
  String querySessionCount(String count);

  /// No description provided for @metadataColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get metadataColumn;

  /// No description provided for @metadataPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get metadataPosition;

  /// No description provided for @metadataUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get metadataUnique;

  /// No description provided for @metadataJdbcType.
  ///
  /// In en, this message translates to:
  /// **'JDBC type'**
  String get metadataJdbcType;

  /// No description provided for @metadataAutoIncrement.
  ///
  /// In en, this message translates to:
  /// **'Auto-increment'**
  String get metadataAutoIncrement;

  /// No description provided for @metadataReferencedColumn.
  ///
  /// In en, this message translates to:
  /// **'Referenced column'**
  String get metadataReferencedColumn;

  /// No description provided for @metadataComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get metadataComment;

  /// No description provided for @metadataType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get metadataType;

  /// No description provided for @metadataEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get metadataEvent;

  /// No description provided for @metadataSpecificName.
  ///
  /// In en, this message translates to:
  /// **'Native specific identifier'**
  String get metadataSpecificName;

  /// No description provided for @metadataOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get metadataOptions;

  /// No description provided for @metadataInheritance.
  ///
  /// In en, this message translates to:
  /// **'Inheritance'**
  String get metadataInheritance;

  /// No description provided for @metadataDefinitionCaptured.
  ///
  /// In en, this message translates to:
  /// **'Captured native definition'**
  String get metadataDefinitionCaptured;

  /// No description provided for @metadataDefinitionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Definition unavailable in captured metadata'**
  String get metadataDefinitionUnavailable;

  /// No description provided for @metadataDefinitionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Captured object has no supported native definition'**
  String get metadataDefinitionUnsupported;

  /// No description provided for @connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connections;

  /// No description provided for @noConnections.
  ///
  /// In en, this message translates to:
  /// **'No connections yet'**
  String get noConnections;

  /// No description provided for @startTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to a database'**
  String get startTitle;

  /// No description provided for @startDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to PostgreSQL, MySQL, or MariaDB to browse objects, manage data, and run queries.'**
  String get startDescription;

  /// No description provided for @savedStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a connection'**
  String get savedStartTitle;

  /// No description provided for @savedStartDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to a saved connection in Database Explorer to browse objects and run queries.'**
  String get savedStartDescription;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @queryTitle.
  ///
  /// In en, this message translates to:
  /// **'Query {number}'**
  String queryTitle(int number);

  /// No description provided for @sessionMenu.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionMenu;

  /// No description provided for @noFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching connections or loaded objects'**
  String get noFilterMatches;

  /// No description provided for @activityState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get activityState;

  /// No description provided for @activityWait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get activityWait;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSettings;

  /// No description provided for @optionsSettings.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsSettings;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @databaseSystem.
  ///
  /// In en, this message translates to:
  /// **'Database system'**
  String get databaseSystem;

  /// No description provided for @passwordStorage.
  ///
  /// In en, this message translates to:
  /// **'Password storage'**
  String get passwordStorage;

  /// No description provided for @environmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environmentLabel;

  /// No description provided for @readOnlySettings.
  ///
  /// In en, this message translates to:
  /// **'Read-only policy'**
  String get readOnlySettings;

  /// No description provided for @tlsPolicy.
  ///
  /// In en, this message translates to:
  /// **'TLS policy'**
  String get tlsPolicy;

  /// No description provided for @sshConnection.
  ///
  /// In en, this message translates to:
  /// **'SSH connection'**
  String get sshConnection;

  /// No description provided for @sshAuthentication.
  ///
  /// In en, this message translates to:
  /// **'SSH authentication'**
  String get sshAuthentication;

  /// No description provided for @connectionTestAction.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get connectionTestAction;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @copyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get copyDetails;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @filterCellValue.
  ///
  /// In en, this message translates to:
  /// **'Filter by this value'**
  String get filterCellValue;

  /// No description provided for @connectsWhenRun.
  ///
  /// In en, this message translates to:
  /// **'Connects when run'**
  String get connectsWhenRun;

  /// No description provided for @connectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get connectionSaving;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionConnecting;

  /// No description provided for @connectionCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get connectionCancelling;

  /// No description provided for @connectionSettingsChanged.
  ///
  /// In en, this message translates to:
  /// **'Settings changed. Test this revision to verify the connection.'**
  String get connectionSettingsChanged;

  /// No description provided for @connectionTestChanged.
  ///
  /// In en, this message translates to:
  /// **'Settings changed during testing. Test this revision again.'**
  String get connectionTestChanged;

  /// No description provided for @connectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get connectionRequired;

  /// No description provided for @connectionCorrectFields.
  ///
  /// In en, this message translates to:
  /// **'Correct the indicated fields.'**
  String get connectionCorrectFields;

  /// No description provided for @connectionHostname.
  ///
  /// In en, this message translates to:
  /// **'Enter a hostname or IP address'**
  String get connectionHostname;

  /// No description provided for @connectionSshHostname.
  ///
  /// In en, this message translates to:
  /// **'Enter an SSH hostname or IP address'**
  String get connectionSshHostname;

  /// No description provided for @connectionMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Use at most 256 characters'**
  String get connectionMaxLength;

  /// No description provided for @connectionTlsHelp.
  ///
  /// In en, this message translates to:
  /// **'The certificate and Host must verify. Select a CA in SSH/SSL when needed.'**
  String get connectionTlsHelp;

  /// No description provided for @connectionTlsReview.
  ///
  /// In en, this message translates to:
  /// **'Review the selected TLS policy before connecting.'**
  String get connectionTlsReview;

  /// No description provided for @connectionStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Secure storage unavailable. Enter a password; choose session-only explicitly to save without secure storage.'**
  String get connectionStorageUnavailable;

  /// No description provided for @connectionHostReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed host identity selected for this profile and endpoint.'**
  String get connectionHostReviewed;

  /// No description provided for @connectionSshReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing SSH host…'**
  String get connectionSshReviewing;

  /// No description provided for @connectionFailureAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Database authentication was rejected. Check User and Password in General.'**
  String get connectionFailureAuthentication;

  /// No description provided for @connectionFailureTls.
  ///
  /// In en, this message translates to:
  /// **'TLS verification failed. Check the hostname and certificates in SSH/SSL.'**
  String get connectionFailureTls;

  /// No description provided for @connectionFailureSshKey.
  ///
  /// In en, this message translates to:
  /// **'The SSH host key was refused. Review the exact host identity in SSH/SSL.'**
  String get connectionFailureSshKey;

  /// No description provided for @connectionFailureEndpoint.
  ///
  /// In en, this message translates to:
  /// **'The endpoint could not be reached. Check Host, Port and SSH/SSL.'**
  String get connectionFailureEndpoint;

  /// No description provided for @connectionFailureCancelled.
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled. Your values are preserved.'**
  String get connectionFailureCancelled;

  /// No description provided for @connectionFailureSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection settings were rejected. Review the labeled fields.'**
  String get connectionFailureSettings;

  /// No description provided for @connectionFailureAccess.
  ///
  /// In en, this message translates to:
  /// **'The server rejected access. Check credentials and permissions.'**
  String get connectionFailureAccess;

  /// No description provided for @connectionFailureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Connection unavailable. Check the endpoint, TLS and SSH settings.'**
  String get connectionFailureUnavailable;

  /// No description provided for @connectionFailureTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check the endpoint and connection timeout.'**
  String get connectionFailureTimeout;

  /// No description provided for @connectionFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Connection was not completed. Review the endpoint, credentials and SSH/SSL settings.'**
  String get connectionFailureUnknown;

  /// No description provided for @connectionNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {min} to {max}'**
  String connectionNumber(int min, int max);

  /// No description provided for @connectionSavedFailure.
  ///
  /// In en, this message translates to:
  /// **'Connection saved: {name}. Connection attempt failed. '**
  String connectionSavedFailure(String name);

  /// No description provided for @backendBusy.
  ///
  /// In en, this message translates to:
  /// **'The backend is busy. Wait for the current request, then try again.'**
  String get backendBusy;

  /// No description provided for @rpcRequestUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The request was not confirmed (RPC {code}).'**
  String rpcRequestUnconfirmed(String code);

  /// No description provided for @operationUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed.'**
  String get operationUnconfirmed;

  /// No description provided for @connectionFailureTlsMaterial.
  ///
  /// In en, this message translates to:
  /// **'TLS material is unavailable or invalid. Check trust sources and the client key in SSH/SSL.'**
  String get connectionFailureTlsMaterial;

  /// No description provided for @managerTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Sources and Drivers'**
  String get managerTitle;

  /// No description provided for @sourceListTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Sources'**
  String get sourceListTitle;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverLabel;

  /// No description provided for @connectionTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get connectionTypeLabel;

  /// No description provided for @defaultTcp.
  ///
  /// In en, this message translates to:
  /// **'Default (TCP)'**
  String get defaultTcp;

  /// No description provided for @authenticationLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authenticationLabel;

  /// No description provided for @userPasswordAuth.
  ///
  /// In en, this message translates to:
  /// **'User & Password'**
  String get userPasswordAuth;

  /// No description provided for @neverStorage.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get neverStorage;

  /// No description provided for @initialDatabaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Initial database'**
  String get initialDatabaseLabel;

  /// No description provided for @useSshTunnel.
  ///
  /// In en, this message translates to:
  /// **'Use SSH tunnel'**
  String get useSshTunnel;

  /// No description provided for @sshConfigurationLabel.
  ///
  /// In en, this message translates to:
  /// **'SSH configuration'**
  String get sshConfigurationLabel;

  /// No description provided for @createSshConfig.
  ///
  /// In en, this message translates to:
  /// **'<create configuration>'**
  String get createSshConfig;

  /// No description provided for @copySshSettings.
  ///
  /// In en, this message translates to:
  /// **'Copy SSH settings'**
  String get copySshSettings;

  /// No description provided for @localPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Local port'**
  String get localPortLabel;

  /// No description provided for @dynamicPortLabel.
  ///
  /// In en, this message translates to:
  /// **'<Dynamic>'**
  String get dynamicPortLabel;

  /// No description provided for @useSsl.
  ///
  /// In en, this message translates to:
  /// **'Use SSL'**
  String get useSsl;

  /// No description provided for @useTruststore.
  ///
  /// In en, this message translates to:
  /// **'Use truststore'**
  String get useTruststore;

  /// No description provided for @clientKeyPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Client key password'**
  String get clientKeyPasswordLabel;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @requireTls.
  ///
  /// In en, this message translates to:
  /// **'Require'**
  String get requireTls;

  /// No description provided for @verifyCa.
  ///
  /// In en, this message translates to:
  /// **'Verify CA'**
  String get verifyCa;

  /// No description provided for @fullVerification.
  ///
  /// In en, this message translates to:
  /// **'Full Verification'**
  String get fullVerification;

  /// No description provided for @connectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionSection;

  /// No description provided for @configurationApplied.
  ///
  /// In en, this message translates to:
  /// **'Configuration applied'**
  String get configurationApplied;

  /// No description provided for @noOtherSshConfig.
  ///
  /// In en, this message translates to:
  /// **'No other source has an SSH configuration.'**
  String get noOtherSshConfig;

  /// No description provided for @generatedUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Generated, read-only JDBC address.'**
  String get generatedUrlHelp;

  /// No description provided for @tlsDriverDefaultHelp.
  ///
  /// In en, this message translates to:
  /// **'SSL is unconfigured; the bundled driver uses its default.'**
  String get tlsDriverDefaultHelp;

  /// No description provided for @tlsClientKeyHelp.
  ///
  /// In en, this message translates to:
  /// **'PEM keys: PKCS#8 or OpenSSL; encrypted or unencrypted.'**
  String get tlsClientKeyHelp;

  /// No description provided for @legacyMariaTrustHelp.
  ///
  /// In en, this message translates to:
  /// **'Existing driver verification is retained. Select trust sources to configure explicit roots.'**
  String get legacyMariaTrustHelp;

  /// No description provided for @metadataStartValue.
  ///
  /// In en, this message translates to:
  /// **'Start value'**
  String get metadataStartValue;

  /// No description provided for @metadataMinimumValue.
  ///
  /// In en, this message translates to:
  /// **'Minimum value'**
  String get metadataMinimumValue;

  /// No description provided for @metadataMaximumValue.
  ///
  /// In en, this message translates to:
  /// **'Maximum value'**
  String get metadataMaximumValue;

  /// No description provided for @metadataIncrement.
  ///
  /// In en, this message translates to:
  /// **'Increment'**
  String get metadataIncrement;

  /// No description provided for @metadataCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get metadataCycle;

  /// No description provided for @metadataCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Cache size'**
  String get metadataCacheSize;

  /// No description provided for @metadataLastValue.
  ///
  /// In en, this message translates to:
  /// **'Last value'**
  String get metadataLastValue;

  /// No description provided for @sequences.
  ///
  /// In en, this message translates to:
  /// **'Sequences'**
  String get sequences;

  /// No description provided for @namespaceSelection.
  ///
  /// In en, this message translates to:
  /// **'Select namespaces'**
  String get namespaceSelection;

  /// No description provided for @namespaceSelectionNotice.
  ///
  /// In en, this message translates to:
  /// **'Selection controls introspection. Query consoles keep their execution context.'**
  String get namespaceSelectionNotice;

  /// No description provided for @allNamespaces.
  ///
  /// In en, this message translates to:
  /// **'All Namespaces'**
  String get allNamespaces;

  /// No description provided for @defaultNamespace.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultNamespace;

  /// No description provided for @namespacePattern.
  ///
  /// In en, this message translates to:
  /// **'Name pattern (regular expression)'**
  String get namespacePattern;

  /// No description provided for @namespaceCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {known}'**
  String namespaceCount(int selected, int known);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @patternRejected.
  ///
  /// In en, this message translates to:
  /// **'The pattern is invalid or exceeds its work limit. The previous selection is retained.'**
  String get patternRejected;

  /// No description provided for @namespaceNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Namespace not selected for introspection'**
  String get namespaceNotSelected;

  /// No description provided for @newMenu.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newMenu;

  /// No description provided for @queryConsoles.
  ///
  /// In en, this message translates to:
  /// **'Query consoles'**
  String get queryConsoles;

  /// No description provided for @viewOptions.
  ///
  /// In en, this message translates to:
  /// **'View options'**
  String get viewOptions;

  /// No description provided for @quickDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Quick Documentation'**
  String get quickDocumentation;

  /// No description provided for @showEmptyGroups.
  ///
  /// In en, this message translates to:
  /// **'Show empty groups'**
  String get showEmptyGroups;

  /// No description provided for @speedSearch.
  ///
  /// In en, this message translates to:
  /// **'Speed Search'**
  String get speedSearch;

  /// No description provided for @speedSearchScope.
  ///
  /// In en, this message translates to:
  /// **'Expanded, loaded nodes only.'**
  String get speedSearchScope;

  /// No description provided for @newSourceFolder.
  ///
  /// In en, this message translates to:
  /// **'New source folder'**
  String get newSourceFolder;

  /// No description provided for @renameSourceFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameSourceFolder;

  /// No description provided for @moveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolder;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @folderMustBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Move contained sources and folders before removing this folder.'**
  String get folderMustBeEmpty;

  /// No description provided for @newVirtualView.
  ///
  /// In en, this message translates to:
  /// **'New virtual view'**
  String get newVirtualView;

  /// No description provided for @editVirtualDefinition.
  ///
  /// In en, this message translates to:
  /// **'Edit local definition'**
  String get editVirtualDefinition;

  /// No description provided for @unboundVirtualView.
  ///
  /// In en, this message translates to:
  /// **'Unbound virtual views'**
  String get unboundVirtualView;

  /// No description provided for @localVirtualViewNotice.
  ///
  /// In en, this message translates to:
  /// **'Local SQL definition. Saving does not execute SQL or create a server view. Run uses the normal SQL review and an independent console.'**
  String get localVirtualViewNotice;

  /// No description provided for @rebindVirtualView.
  ///
  /// In en, this message translates to:
  /// **'Rebind local definition here'**
  String get rebindVirtualView;

  /// No description provided for @sourceFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get sourceFolderName;

  /// No description provided for @sourceFolderPathNotice.
  ///
  /// In en, this message translates to:
  /// **'Use / to create nested folders.'**
  String get sourceFolderPathNotice;

  /// No description provided for @topLevel.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get topLevel;

  /// No description provided for @virtualViewName.
  ///
  /// In en, this message translates to:
  /// **'Virtual view name'**
  String get virtualViewName;

  /// No description provided for @virtualViewSql.
  ///
  /// In en, this message translates to:
  /// **'Virtual view SQL definition'**
  String get virtualViewSql;

  /// No description provided for @virtualViews.
  ///
  /// In en, this message translates to:
  /// **'Virtual views'**
  String get virtualViews;

  /// No description provided for @revealInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Reveal in Database Explorer'**
  String get revealInExplorer;

  /// No description provided for @objectNotFound.
  ///
  /// In en, this message translates to:
  /// **'Object not found in this namespace; refresh metadata or check permissions.'**
  String get objectNotFound;

  /// No description provided for @objectHiddenByFilter.
  ///
  /// In en, this message translates to:
  /// **'Object is hidden by the current view filter.'**
  String get objectHiddenByFilter;

  /// No description provided for @revealFilterNotice.
  ///
  /// In en, this message translates to:
  /// **'Object lookup narrows this page; the full category total is omitted.'**
  String get revealFilterNotice;

  /// No description provided for @clearObjectFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear object lookup'**
  String get clearObjectFilter;

  /// No description provided for @compareStructure.
  ///
  /// In en, this message translates to:
  /// **'Compare structure'**
  String get compareStructure;

  /// No description provided for @selectTwoCompatibleObjects.
  ///
  /// In en, this message translates to:
  /// **'Select two compatible tables using Ctrl-click.'**
  String get selectTwoCompatibleObjects;

  /// No description provided for @scopedComparisonRestriction.
  ///
  /// In en, this message translates to:
  /// **'Scoped comparison requires ordinary tables with the same native name, schema and engine. Other kinds and rename matching are unavailable.'**
  String get scopedComparisonRestriction;

  /// No description provided for @groupNamespaces.
  ///
  /// In en, this message translates to:
  /// **'Group databases and schemas'**
  String get groupNamespaces;

  /// No description provided for @groupSchemaObjects.
  ///
  /// In en, this message translates to:
  /// **'Group schema objects'**
  String get groupSchemaObjects;

  /// No description provided for @groupTableElements.
  ///
  /// In en, this message translates to:
  /// **'Group table elements'**
  String get groupTableElements;

  /// No description provided for @sortAlphabetically.
  ///
  /// In en, this message translates to:
  /// **'Sort alphabetically'**
  String get sortAlphabetically;

  /// No description provided for @showVirtualObjects.
  ///
  /// In en, this message translates to:
  /// **'Show virtual objects'**
  String get showVirtualObjects;

  /// No description provided for @showObjectComments.
  ///
  /// In en, this message translates to:
  /// **'Show object comments'**
  String get showObjectComments;

  /// No description provided for @objectTypeFilter.
  ///
  /// In en, this message translates to:
  /// **'Object type filter'**
  String get objectTypeFilter;

  /// No description provided for @partitionedTable.
  ///
  /// In en, this message translates to:
  /// **'Partitioned table'**
  String get partitionedTable;

  /// No description provided for @foreignTable.
  ///
  /// In en, this message translates to:
  /// **'Foreign table'**
  String get foreignTable;

  /// No description provided for @materializedView.
  ///
  /// In en, this message translates to:
  /// **'Materialized view'**
  String get materializedView;

  /// No description provided for @functionObject.
  ///
  /// In en, this message translates to:
  /// **'Function'**
  String get functionObject;

  /// No description provided for @procedureObject.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get procedureObject;

  /// No description provided for @sqlSymbolUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No safely resolved persistent object at the caret. Connect this console and use a table or view reference outside literals and comments.'**
  String get sqlSymbolUnavailable;

  /// No description provided for @sqlSymbolAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous SQL object reference. Qualify its namespace or choose an exact database object.'**
  String get sqlSymbolAmbiguous;

  /// No description provided for @deactivateSource.
  ///
  /// In en, this message translates to:
  /// **'Deactivate source'**
  String get deactivateSource;

  /// No description provided for @functions.
  ///
  /// In en, this message translates to:
  /// **'Functions'**
  String get functions;

  /// No description provided for @procedures.
  ///
  /// In en, this message translates to:
  /// **'Procedures'**
  String get procedures;

  /// No description provided for @separateProceduresFunctions.
  ///
  /// In en, this message translates to:
  /// **'Separate procedures and functions'**
  String get separateProceduresFunctions;

  /// No description provided for @renameVirtualView.
  ///
  /// In en, this message translates to:
  /// **'Rename virtual view'**
  String get renameVirtualView;

  /// No description provided for @metadataPersistentScope.
  ///
  /// In en, this message translates to:
  /// **'Persistent objects only; temporary/session-local objects remain in console navigation.'**
  String get metadataPersistentScope;

  /// No description provided for @metadataSessionScope.
  ///
  /// In en, this message translates to:
  /// **'Persistent objects only; refresh console-local objects after execution.'**
  String get metadataSessionScope;

  /// No description provided for @metadataLimitScope.
  ///
  /// In en, this message translates to:
  /// **'Metadata limit reached. Narrow the object scope.'**
  String get metadataLimitScope;

  /// No description provided for @completeColumnMetadataRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete column metadata is required before importing or staging changes.'**
  String get completeColumnMetadataRequired;

  /// No description provided for @resizeColumn.
  ///
  /// In en, this message translates to:
  /// **'Resize column {name}'**
  String resizeColumn(String name);

  /// No description provided for @keyboardShortcutsHeading.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcutsHeading;

  /// No description provided for @sqlEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'SQL editor {title}'**
  String sqlEditorLabel(String title);

  /// No description provided for @editorResultsDivider.
  ///
  /// In en, this message translates to:
  /// **'Editor and results divider'**
  String get editorResultsDivider;

  /// No description provided for @editorExtent.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent editor'**
  String editorExtent(String percent);

  /// No description provided for @largerEditor.
  ///
  /// In en, this message translates to:
  /// **'Larger editor'**
  String get largerEditor;

  /// No description provided for @smallerEditor.
  ///
  /// In en, this message translates to:
  /// **'Smaller editor'**
  String get smallerEditor;

  /// No description provided for @explorerWidthDivider.
  ///
  /// In en, this message translates to:
  /// **'Explorer width divider'**
  String get explorerWidthDivider;

  /// No description provided for @widerExplorer.
  ///
  /// In en, this message translates to:
  /// **'Wider Explorer'**
  String get widerExplorer;

  /// No description provided for @narrowerExplorer.
  ///
  /// In en, this message translates to:
  /// **'Narrower Explorer'**
  String get narrowerExplorer;

  /// No description provided for @explorerExtent.
  ///
  /// In en, this message translates to:
  /// **'{width} pixels wide'**
  String explorerExtent(String width);

  /// No description provided for @planTextPage.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end} of {total} UTF-16 units'**
  String planTextPage(String start, String end, String total);

  /// No description provided for @dropDesignedColumn.
  ///
  /// In en, this message translates to:
  /// **'Drop column'**
  String get dropDesignedColumn;

  /// No description provided for @liveCatalogLabel.
  ///
  /// In en, this message translates to:
  /// **'Live catalog'**
  String get liveCatalogLabel;

  /// No description provided for @liveSchemaLabel.
  ///
  /// In en, this message translates to:
  /// **'Live schema'**
  String get liveSchemaLabel;

  /// No description provided for @searchPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Search path'**
  String get searchPathLabel;

  /// No description provided for @physicalSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Physical session'**
  String get physicalSessionLabel;

  /// No description provided for @queryTimeoutDetail.
  ///
  /// In en, this message translates to:
  /// **'Timeout: {seconds} s · Row limit: {rows}'**
  String queryTimeoutDetail(String seconds, String rows);

  /// No description provided for @saveFailedCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'SQL save failed · Close BusyData'**
  String get saveFailedCloseTitle;

  /// No description provided for @createSection.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createSection;

  /// No description provided for @newConnectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure a database connection'**
  String get newConnectionDescription;

  /// No description provided for @newQueryDescription.
  ///
  /// In en, this message translates to:
  /// **'Write SQL in a new query'**
  String get newQueryDescription;

  /// No description provided for @openSqlDescription.
  ///
  /// In en, this message translates to:
  /// **'Open an existing SQL document'**
  String get openSqlDescription;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching actions'**
  String get searchNoResults;

  /// No description provided for @actionsCategory.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsCategory;

  /// No description provided for @privateRecoveryCategory.
  ///
  /// In en, this message translates to:
  /// **'Private recovery'**
  String get privateRecoveryCategory;

  /// No description provided for @shortcutRecordHelp.
  ///
  /// In en, this message translates to:
  /// **'Press a shortcut. Escape cancels. F6 and Shift+F6 are reserved for pane navigation.'**
  String get shortcutRecordHelp;

  /// No description provided for @rowLimitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a row limit from 1 to 1,000,000.'**
  String get rowLimitInvalid;

  /// No description provided for @errorPolicy.
  ///
  /// In en, this message translates to:
  /// **'On execution error'**
  String get errorPolicy;

  /// No description provided for @tlsEncrypted.
  ///
  /// In en, this message translates to:
  /// **'encrypted'**
  String get tlsEncrypted;

  /// No description provided for @tlsUnencrypted.
  ///
  /// In en, this message translates to:
  /// **'unencrypted'**
  String get tlsUnencrypted;

  /// No description provided for @tlsUnobserved.
  ///
  /// In en, this message translates to:
  /// **'unobserved'**
  String get tlsUnobserved;

  /// No description provided for @encryptionVerificationNote.
  ///
  /// In en, this message translates to:
  /// **'Encryption does not establish certificate or hostname verification.'**
  String get encryptionVerificationNote;

  /// No description provided for @uniqueDesignedColumnName.
  ///
  /// In en, this message translates to:
  /// **'Use a unique column name; new tables support up to 128 columns'**
  String get uniqueDesignedColumnName;

  /// No description provided for @activityBlockerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Blocker {id} is no longer visible; refresh and check database permissions'**
  String activityBlockerUnavailable(String id);

  /// No description provided for @sshChangedKeyReview.
  ///
  /// In en, this message translates to:
  /// **'Verify the changed key independently before replacing this profile binding.'**
  String get sshChangedKeyReview;

  /// No description provided for @sshProfileTrustBinding.
  ///
  /// In en, this message translates to:
  /// **'Trust applies only to this profile and exact endpoint.'**
  String get sshProfileTrustBinding;

  /// No description provided for @databaseTlsEvidence.
  ///
  /// In en, this message translates to:
  /// **'Database TLS'**
  String get databaseTlsEvidence;

  /// No description provided for @sshAlgorithmLabel.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get sshAlgorithmLabel;

  /// No description provided for @sshFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get sshFingerprintLabel;

  /// No description provided for @sshPreviousFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous fingerprint'**
  String get sshPreviousFingerprintLabel;

  /// No description provided for @sshReviewedLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get sshReviewedLabel;

  /// No description provided for @shortcutRecordAction.
  ///
  /// In en, this message translates to:
  /// **'Record shortcut'**
  String get shortcutRecordAction;

  /// No description provided for @fileFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'File format'**
  String get fileFormatLabel;

  /// No description provided for @encodingLabel.
  ///
  /// In en, this message translates to:
  /// **'Encoding'**
  String get encodingLabel;

  /// No description provided for @importPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Import policy'**
  String get importPolicyLabel;

  /// No description provided for @mainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get mainMenu;

  /// No description provided for @activityReplyTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Activity response exceeds the inspector limit.'**
  String get activityReplyTooLarge;

  /// No description provided for @activityListLimited.
  ///
  /// In en, this message translates to:
  /// **'List limited; inspect a narrower target with explicit SQL.'**
  String get activityListLimited;

  /// No description provided for @activitySelectionChanged.
  ///
  /// In en, this message translates to:
  /// **'The selected activity ended or changed. Select its current identity before reviewing an action.'**
  String get activitySelectionChanged;

  /// No description provided for @connectionSavedDraftChanged.
  ///
  /// In en, this message translates to:
  /// **'Connection fields changed while saving; configuration was saved: {name}. Review the current values before connecting.'**
  String connectionSavedDraftChanged(String name);

  /// No description provided for @sshReviewTargetChanged.
  ///
  /// In en, this message translates to:
  /// **'SSH review target changed; review again'**
  String get sshReviewTargetChanged;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get appLanguage;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @noSelection.
  ///
  /// In en, this message translates to:
  /// **'No text is available'**
  String get noSelection;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard has no text'**
  String get clipboardEmpty;

  /// No description provided for @settingsDraftNotice.
  ///
  /// In en, this message translates to:
  /// **'Execution and private recovery changes have not been saved.'**
  String get settingsDraftNotice;

  /// No description provided for @documentsMenu.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsMenu;

  /// No description provided for @currentSql.
  ///
  /// In en, this message translates to:
  /// **'Current SQL'**
  String get currentSql;

  /// No description provided for @searchActionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search actions…'**
  String get searchActionsHint;

  /// No description provided for @searchCurrentSqlHint.
  ///
  /// In en, this message translates to:
  /// **'Search current SQL…'**
  String get searchCurrentSqlHint;

  /// No description provided for @searchObjectsHint.
  ///
  /// In en, this message translates to:
  /// **'Search database objects…'**
  String get searchObjectsHint;

  /// No description provided for @searchHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Search query history…'**
  String get searchHistoryHint;

  /// No description provided for @metadataAttributes.
  ///
  /// In en, this message translates to:
  /// **'Attributes'**
  String get metadataAttributes;

  /// No description provided for @metadataSelectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Select an item to inspect its captured properties. The previous selection is unavailable.'**
  String get metadataSelectionUnavailable;

  /// No description provided for @secureStorage.
  ///
  /// In en, this message translates to:
  /// **'OS secure storage'**
  String get secureStorage;

  /// No description provided for @resultPresentation.
  ///
  /// In en, this message translates to:
  /// **'View as'**
  String get resultPresentation;

  /// No description provided for @resultTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get resultTable;

  /// No description provided for @resultTranspose.
  ///
  /// In en, this message translates to:
  /// **'Transpose'**
  String get resultTranspose;

  /// No description provided for @resultTree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get resultTree;

  /// No description provided for @resultText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get resultText;

  /// No description provided for @recordView.
  ///
  /// In en, this message translates to:
  /// **'Record View'**
  String get recordView;

  /// No description provided for @valueEditor.
  ///
  /// In en, this message translates to:
  /// **'Value Editor'**
  String get valueEditor;

  /// No description provided for @aggregateView.
  ///
  /// In en, this message translates to:
  /// **'Aggregate View'**
  String get aggregateView;

  /// No description provided for @relatedRows.
  ///
  /// In en, this message translates to:
  /// **'Related Rows'**
  String get relatedRows;

  /// No description provided for @cloneRow.
  ///
  /// In en, this message translates to:
  /// **'Clone Row'**
  String get cloneRow;

  /// No description provided for @displayFormat.
  ///
  /// In en, this message translates to:
  /// **'Display format'**
  String get displayFormat;

  /// No description provided for @canonicalValue.
  ///
  /// In en, this message translates to:
  /// **'Canonical / raw'**
  String get canonicalValue;

  /// No description provided for @groupedNumber.
  ///
  /// In en, this message translates to:
  /// **'Numeric grouping'**
  String get groupedNumber;

  /// No description provided for @jsonPretty.
  ///
  /// In en, this message translates to:
  /// **'JSON formatted text'**
  String get jsonPretty;

  /// No description provided for @binaryHex.
  ///
  /// In en, this message translates to:
  /// **'Binary hexadecimal'**
  String get binaryHex;

  /// No description provided for @binaryBase64.
  ///
  /// In en, this message translates to:
  /// **'Binary Base64'**
  String get binaryBase64;

  /// No description provided for @uuidPresentation.
  ///
  /// In en, this message translates to:
  /// **'UUID (16 bytes)'**
  String get uuidPresentation;

  /// No description provided for @wrapText.
  ///
  /// In en, this message translates to:
  /// **'Wrap text'**
  String get wrapText;

  /// No description provided for @selectedCellsScope.
  ///
  /// In en, this message translates to:
  /// **'Selected cells only'**
  String get selectedCellsScope;

  /// No description provided for @retainedWindowScope.
  ///
  /// In en, this message translates to:
  /// **'Current retained window only'**
  String get retainedWindowScope;

  /// No description provided for @serverDataOperations.
  ///
  /// In en, this message translates to:
  /// **'Server-side table sorting and filtering'**
  String get serverDataOperations;

  /// No description provided for @localDataOperations.
  ///
  /// In en, this message translates to:
  /// **'Local sorting and filtering of retained data'**
  String get localDataOperations;

  /// No description provided for @partialRetainedScope.
  ///
  /// In en, this message translates to:
  /// **'Partial retained result; this view does not represent the complete server table.'**
  String get partialRetainedScope;

  /// No description provided for @valueComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete retained value'**
  String get valueComplete;

  /// No description provided for @valueTruncated.
  ///
  /// In en, this message translates to:
  /// **'Truncated preview; the complete value is retained.'**
  String get valueTruncated;

  /// No description provided for @loadValueChunk.
  ///
  /// In en, this message translates to:
  /// **'Load next 64 KiB'**
  String get loadValueChunk;

  /// No description provided for @resetValueChunks.
  ///
  /// In en, this message translates to:
  /// **'Reset value preview'**
  String get resetValueChunks;

  /// No description provided for @structuredParseError.
  ///
  /// In en, this message translates to:
  /// **'Structured interpretation is unavailable; exact raw content remains accessible.'**
  String get structuredParseError;

  /// No description provided for @structuredValueLimit.
  ///
  /// In en, this message translates to:
  /// **'Structured display is limited to 256 KiB, 4,096 nodes and 32 levels.'**
  String get structuredValueLimit;

  /// No description provided for @valueChunkRange.
  ///
  /// In en, this message translates to:
  /// **'Bytes {start}–{end} of {total}'**
  String valueChunkRange(String start, String end, String total);

  /// No description provided for @presentationScopeLimit.
  ///
  /// In en, this message translates to:
  /// **'This presentation exceeds its bounded scope. Select fewer cells or use Export.'**
  String get presentationScopeLimit;

  /// No description provided for @transposeSelectionLimit.
  ///
  /// In en, this message translates to:
  /// **'Transpose shows at most 32 selected rows. Narrow the selection to inspect another range.'**
  String get transposeSelectionLimit;

  /// No description provided for @jsonTree.
  ///
  /// In en, this message translates to:
  /// **'JSON tree'**
  String get jsonTree;

  /// No description provided for @xmlInterpretation.
  ///
  /// In en, this message translates to:
  /// **'XML interpretation'**
  String get xmlInterpretation;

  /// No description provided for @imagePreview.
  ///
  /// In en, this message translates to:
  /// **'Image preview'**
  String get imagePreview;

  /// No description provided for @imagePreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image preview requires recognized image bytes within the 1 MiB / 4 megapixel limit.'**
  String get imagePreviewUnavailable;

  /// No description provided for @valueDraftLimit.
  ///
  /// In en, this message translates to:
  /// **'Value drafts exceed the shared 1 MiB text / 2 MiB complete-value limit. Stage or discard another draft first.'**
  String get valueDraftLimit;

  /// No description provided for @valueDraftPreserved.
  ///
  /// In en, this message translates to:
  /// **'Value draft preserved; stored value is unchanged.'**
  String get valueDraftPreserved;

  /// No description provided for @setDefault.
  ///
  /// In en, this message translates to:
  /// **'Set DEFAULT'**
  String get setDefault;

  /// No description provided for @assignmentUnset.
  ///
  /// In en, this message translates to:
  /// **'Unchanged / unset'**
  String get assignmentUnset;

  /// No description provided for @assignmentValue.
  ///
  /// In en, this message translates to:
  /// **'Exact value'**
  String get assignmentValue;

  /// No description provided for @assignmentNull.
  ///
  /// In en, this message translates to:
  /// **'SQL NULL'**
  String get assignmentNull;

  /// No description provided for @assignmentDefault.
  ///
  /// In en, this message translates to:
  /// **'Server DEFAULT'**
  String get assignmentDefault;

  /// No description provided for @originalValue.
  ///
  /// In en, this message translates to:
  /// **'Original value'**
  String get originalValue;

  /// No description provided for @stagedValue.
  ///
  /// In en, this message translates to:
  /// **'Staged value'**
  String get stagedValue;

  /// No description provided for @noRelatedRows.
  ///
  /// In en, this message translates to:
  /// **'No available relationships for this retained row.'**
  String get noRelatedRows;

  /// No description provided for @aggregateSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected count'**
  String get aggregateSelectedCount;

  /// No description provided for @aggregateNonNull.
  ///
  /// In en, this message translates to:
  /// **'Non-NULL count'**
  String get aggregateNonNull;

  /// No description provided for @aggregateNull.
  ///
  /// In en, this message translates to:
  /// **'NULL count'**
  String get aggregateNull;

  /// No description provided for @aggregateDistinct.
  ///
  /// In en, this message translates to:
  /// **'Distinct count'**
  String get aggregateDistinct;

  /// No description provided for @aggregateSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get aggregateSum;

  /// No description provided for @aggregateAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get aggregateAverage;

  /// No description provided for @aggregateMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get aggregateMinimum;

  /// No description provided for @aggregateMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get aggregateMaximum;

  /// No description provided for @aggregateStoredValues.
  ///
  /// In en, this message translates to:
  /// **'Aggregates use original retained values; staged edits are excluded.'**
  String get aggregateStoredValues;

  /// No description provided for @relatedRowsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Related-row navigation requires complete metadata and verified retained provenance.'**
  String get relatedRowsUnavailable;

  /// No description provided for @stagedInsertReview.
  ///
  /// In en, this message translates to:
  /// **'Clone staged as an insert. Review and edit its assignments before Apply.'**
  String get stagedInsertReview;

  /// No description provided for @rawValue.
  ///
  /// In en, this message translates to:
  /// **'Raw value'**
  String get rawValue;

  /// No description provided for @previousRecord.
  ///
  /// In en, this message translates to:
  /// **'Previous record'**
  String get previousRecord;

  /// No description provided for @nextRecord.
  ///
  /// In en, this message translates to:
  /// **'Next record'**
  String get nextRecord;

  /// No description provided for @binaryInputError.
  ///
  /// In en, this message translates to:
  /// **'Enter complete hexadecimal bytes or valid Base64 for the selected binary mode.'**
  String get binaryInputError;

  /// No description provided for @valueChunkEncoding.
  ///
  /// In en, this message translates to:
  /// **'This byte page begins or ends inside a UTF-8 character. Use hexadecimal or export the complete value.'**
  String get valueChunkEncoding;

  /// No description provided for @copyDisplayedText.
  ///
  /// In en, this message translates to:
  /// **'Copy displayed text'**
  String get copyDisplayedText;

  /// No description provided for @requiredColumn.
  ///
  /// In en, this message translates to:
  /// **'NOT NULL'**
  String get requiredColumn;

  /// No description provided for @editStagedInserts.
  ///
  /// In en, this message translates to:
  /// **'Edit staged inserts'**
  String get editStagedInserts;

  /// No description provided for @metadataSettings.
  ///
  /// In en, this message translates to:
  /// **'Metadata and introspection'**
  String get metadataSettings;

  /// No description provided for @metadataIncludeCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Included databases (one exact name per line; empty uses current database)'**
  String get metadataIncludeCatalogs;

  /// No description provided for @metadataExcludeCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Excluded databases'**
  String get metadataExcludeCatalogs;

  /// No description provided for @metadataIncludeSchemas.
  ///
  /// In en, this message translates to:
  /// **'Included schemas (empty uses current resolution path)'**
  String get metadataIncludeSchemas;

  /// No description provided for @metadataExcludeSchemas.
  ///
  /// In en, this message translates to:
  /// **'Excluded schemas'**
  String get metadataExcludeSchemas;

  /// No description provided for @metadataIncludePatterns.
  ///
  /// In en, this message translates to:
  /// **'Included object patterns'**
  String get metadataIncludePatterns;

  /// No description provided for @metadataExcludePatterns.
  ///
  /// In en, this message translates to:
  /// **'Excluded object patterns'**
  String get metadataExcludePatterns;

  /// No description provided for @metadataSystemObjects.
  ///
  /// In en, this message translates to:
  /// **'Include system objects'**
  String get metadataSystemObjects;

  /// No description provided for @metadataDefaultLevel.
  ///
  /// In en, this message translates to:
  /// **'Default introspection level'**
  String get metadataDefaultLevel;

  /// No description provided for @metadataLevelNames.
  ///
  /// In en, this message translates to:
  /// **'Names and identities'**
  String get metadataLevelNames;

  /// No description provided for @metadataLevelStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get metadataLevelStructure;

  /// No description provided for @metadataLevelSource.
  ///
  /// In en, this message translates to:
  /// **'Structure and source'**
  String get metadataLevelSource;

  /// No description provided for @metadataFullRefresh.
  ///
  /// In en, this message translates to:
  /// **'Full refresh'**
  String get metadataFullRefresh;

  /// No description provided for @metadataIncrementalRefresh.
  ///
  /// In en, this message translates to:
  /// **'Incremental refresh'**
  String get metadataIncrementalRefresh;

  /// No description provided for @metadataScopeLevels.
  ///
  /// In en, this message translates to:
  /// **'Scope levels: catalog / schema / level, one per line'**
  String get metadataScopeLevels;

  /// No description provided for @metadataCacheState.
  ///
  /// In en, this message translates to:
  /// **'Cache state'**
  String get metadataCacheState;

  /// No description provided for @metadataConfigurationChanged.
  ///
  /// In en, this message translates to:
  /// **'Metadata configuration changed; reopen to review current settings'**
  String get metadataConfigurationChanged;

  /// No description provided for @metadataAddScope.
  ///
  /// In en, this message translates to:
  /// **'Add scope level'**
  String get metadataAddScope;

  /// No description provided for @metadataAddName.
  ///
  /// In en, this message translates to:
  /// **'Add exact name'**
  String get metadataAddName;

  /// No description provided for @metadataObjectKinds.
  ///
  /// In en, this message translates to:
  /// **'Object kinds'**
  String get metadataObjectKinds;

  /// No description provided for @metadataLastRefresh.
  ///
  /// In en, this message translates to:
  /// **'Last successful refresh'**
  String get metadataLastRefresh;

  /// No description provided for @metadataPatternsNote.
  ///
  /// In en, this message translates to:
  /// **'Patterns use * for any characters and ? for one character. Names remain exact database identifiers.'**
  String get metadataPatternsNote;

  /// No description provided for @sqlLanguage.
  ///
  /// In en, this message translates to:
  /// **'SQL language'**
  String get sqlLanguage;

  /// No description provided for @sqlDialect.
  ///
  /// In en, this message translates to:
  /// **'SQL dialect'**
  String get sqlDialect;

  /// No description provided for @sqlPostgresql.
  ///
  /// In en, this message translates to:
  /// **'PostgreSQL'**
  String get sqlPostgresql;

  /// No description provided for @sqlMysql.
  ///
  /// In en, this message translates to:
  /// **'MySQL'**
  String get sqlMysql;

  /// No description provided for @sqlMariadb.
  ///
  /// In en, this message translates to:
  /// **'MariaDB'**
  String get sqlMariadb;

  /// No description provided for @sqlPreferenceScope.
  ///
  /// In en, this message translates to:
  /// **'Settings scope'**
  String get sqlPreferenceScope;

  /// No description provided for @sqlDialectDefaults.
  ///
  /// In en, this message translates to:
  /// **'Dialect defaults'**
  String get sqlDialectDefaults;

  /// No description provided for @sqlDialectDefaultsDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies to SQL documents using this dialect unless their connection has an override.'**
  String get sqlDialectDefaultsDescription;

  /// No description provided for @sqlProfileOverrideDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies only to SQL documents owned by the selected connection.'**
  String get sqlProfileOverrideDescription;

  /// No description provided for @sqlUseDialectDefaults.
  ///
  /// In en, this message translates to:
  /// **'Use dialect defaults for this connection'**
  String get sqlUseDialectDefaults;

  /// No description provided for @sqlFormatting.
  ///
  /// In en, this message translates to:
  /// **'SQL formatting'**
  String get sqlFormatting;

  /// No description provided for @sqlKeywordCase.
  ///
  /// In en, this message translates to:
  /// **'Keyword case'**
  String get sqlKeywordCase;

  /// No description provided for @sqlPreserveCase.
  ///
  /// In en, this message translates to:
  /// **'Preserve case'**
  String get sqlPreserveCase;

  /// No description provided for @sqlUpperCase.
  ///
  /// In en, this message translates to:
  /// **'Uppercase'**
  String get sqlUpperCase;

  /// No description provided for @sqlLowerCase.
  ///
  /// In en, this message translates to:
  /// **'Lowercase'**
  String get sqlLowerCase;

  /// No description provided for @sqlIndentationWidth.
  ///
  /// In en, this message translates to:
  /// **'Indentation width'**
  String get sqlIndentationWidth;

  /// No description provided for @sqlContinuationIndent.
  ///
  /// In en, this message translates to:
  /// **'Continuation indentation'**
  String get sqlContinuationIndent;

  /// No description provided for @sqlClauseBreaks.
  ///
  /// In en, this message translates to:
  /// **'Start clauses on new lines'**
  String get sqlClauseBreaks;

  /// No description provided for @sqlJoinLayout.
  ///
  /// In en, this message translates to:
  /// **'JOIN layout'**
  String get sqlJoinLayout;

  /// No description provided for @sqlNewLine.
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get sqlNewLine;

  /// No description provided for @sqlSameLine.
  ///
  /// In en, this message translates to:
  /// **'Same line'**
  String get sqlSameLine;

  /// No description provided for @sqlCommaPlacement.
  ///
  /// In en, this message translates to:
  /// **'Comma placement'**
  String get sqlCommaPlacement;

  /// No description provided for @sqlLeading.
  ///
  /// In en, this message translates to:
  /// **'Leading'**
  String get sqlLeading;

  /// No description provided for @sqlTrailing.
  ///
  /// In en, this message translates to:
  /// **'Trailing'**
  String get sqlTrailing;

  /// No description provided for @sqlLogicalPlacement.
  ///
  /// In en, this message translates to:
  /// **'Logical operator placement'**
  String get sqlLogicalPlacement;

  /// No description provided for @sqlWrapLists.
  ///
  /// In en, this message translates to:
  /// **'Wrap field and assignment lists'**
  String get sqlWrapLists;

  /// No description provided for @sqlWrapArguments.
  ///
  /// In en, this message translates to:
  /// **'Wrap function arguments'**
  String get sqlWrapArguments;

  /// No description provided for @sqlIndentSubqueries.
  ///
  /// In en, this message translates to:
  /// **'Indent subqueries'**
  String get sqlIndentSubqueries;

  /// No description provided for @sqlCteBreaks.
  ///
  /// In en, this message translates to:
  /// **'Separate common table expressions'**
  String get sqlCteBreaks;

  /// No description provided for @sqlParenthesisSpacing.
  ///
  /// In en, this message translates to:
  /// **'Space inside parentheses'**
  String get sqlParenthesisSpacing;

  /// No description provided for @sqlOperatorSpacing.
  ///
  /// In en, this message translates to:
  /// **'Space around operators'**
  String get sqlOperatorSpacing;

  /// No description provided for @sqlAlignment.
  ///
  /// In en, this message translates to:
  /// **'Align wrapped assignments'**
  String get sqlAlignment;

  /// No description provided for @sqlMaximumLine.
  ///
  /// In en, this message translates to:
  /// **'Maximum line length'**
  String get sqlMaximumLine;

  /// No description provided for @sqlPreserveBlankLines.
  ///
  /// In en, this message translates to:
  /// **'Preserve intentional blank lines'**
  String get sqlPreserveBlankLines;

  /// No description provided for @sqlInspections.
  ///
  /// In en, this message translates to:
  /// **'SQL inspections'**
  String get sqlInspections;

  /// No description provided for @sqlInspectionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get sqlInspectionDisabled;

  /// No description provided for @sqlSeverityError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sqlSeverityError;

  /// No description provided for @sqlSeverityWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get sqlSeverityWarning;

  /// No description provided for @sqlSeverityInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get sqlSeverityInformation;

  /// No description provided for @sqlSeverityHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get sqlSeverityHint;

  /// No description provided for @sqlInspectionUpdateWhere.
  ///
  /// In en, this message translates to:
  /// **'UPDATE without WHERE'**
  String get sqlInspectionUpdateWhere;

  /// No description provided for @sqlInspectionDeleteWhere.
  ///
  /// In en, this message translates to:
  /// **'DELETE without WHERE'**
  String get sqlInspectionDeleteWhere;

  /// No description provided for @sqlInspectionRelation.
  ///
  /// In en, this message translates to:
  /// **'Unresolved relation'**
  String get sqlInspectionRelation;

  /// No description provided for @sqlInspectionColumn.
  ///
  /// In en, this message translates to:
  /// **'Unresolved column'**
  String get sqlInspectionColumn;

  /// No description provided for @sqlInspectionAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous column'**
  String get sqlInspectionAmbiguous;

  /// No description provided for @sqlInspectionDerived.
  ///
  /// In en, this message translates to:
  /// **'Invalid derived-table column'**
  String get sqlInspectionDerived;

  /// No description provided for @sqlInspectionDuplicateAlias.
  ///
  /// In en, this message translates to:
  /// **'Duplicate relation alias'**
  String get sqlInspectionDuplicateAlias;

  /// No description provided for @sqlInspectionDuplicateCte.
  ///
  /// In en, this message translates to:
  /// **'Duplicate common table expression'**
  String get sqlInspectionDuplicateCte;

  /// No description provided for @sqlInspectionDuplicateInsert.
  ///
  /// In en, this message translates to:
  /// **'Duplicate INSERT column'**
  String get sqlInspectionDuplicateInsert;

  /// No description provided for @sqlInspectionInsertTarget.
  ///
  /// In en, this message translates to:
  /// **'Unknown INSERT target column'**
  String get sqlInspectionInsertTarget;

  /// No description provided for @sqlInspectionUpdateTarget.
  ///
  /// In en, this message translates to:
  /// **'Unknown UPDATE target column'**
  String get sqlInspectionUpdateTarget;

  /// No description provided for @sqlInspectionArguments.
  ///
  /// In en, this message translates to:
  /// **'Invalid routine argument count'**
  String get sqlInspectionArguments;

  /// No description provided for @sqlInspectionOverload.
  ///
  /// In en, this message translates to:
  /// **'No matching routine overload'**
  String get sqlInspectionOverload;

  /// No description provided for @sqlInspectionAggregate.
  ///
  /// In en, this message translates to:
  /// **'Invalid aggregate or window expression'**
  String get sqlInspectionAggregate;

  /// No description provided for @sqlInspectionComparison.
  ///
  /// In en, this message translates to:
  /// **'Incompatible comparison types'**
  String get sqlInspectionComparison;

  /// No description provided for @sqlInspectionAssignment.
  ///
  /// In en, this message translates to:
  /// **'Incompatible assignment type'**
  String get sqlInspectionAssignment;

  /// No description provided for @parameterInformation.
  ///
  /// In en, this message translates to:
  /// **'Parameter information'**
  String get parameterInformation;

  /// No description provided for @activeArgument.
  ///
  /// In en, this message translates to:
  /// **'Active argument: {index}'**
  String activeArgument(int index);

  /// No description provided for @numericScale2.
  ///
  /// In en, this message translates to:
  /// **'Numeric grouping · 2 decimal places'**
  String get numericScale2;

  /// No description provided for @numericScale4.
  ///
  /// In en, this message translates to:
  /// **'Numeric grouping · 4 decimal places'**
  String get numericScale4;

  /// No description provided for @temporalDate.
  ///
  /// In en, this message translates to:
  /// **'Temporal date · yyyy-MM-dd'**
  String get temporalDate;

  /// No description provided for @temporalTime.
  ///
  /// In en, this message translates to:
  /// **'Temporal time · ISO'**
  String get temporalTime;

  /// No description provided for @temporalUtc.
  ///
  /// In en, this message translates to:
  /// **'Timestamp · UTC (requires explicit offset)'**
  String get temporalUtc;

  /// No description provided for @temporalLocal.
  ///
  /// In en, this message translates to:
  /// **'Timestamp · local timezone (requires explicit offset)'**
  String get temporalLocal;

  /// No description provided for @formatCurrentStatement.
  ///
  /// In en, this message translates to:
  /// **'Format current statement'**
  String get formatCurrentStatement;

  /// No description provided for @completionLimited.
  ///
  /// In en, this message translates to:
  /// **'More matches are available. Type a longer prefix.'**
  String get completionLimited;

  /// No description provided for @parameterInformationLimited.
  ///
  /// In en, this message translates to:
  /// **'More overloads exist; parameter information is limited.'**
  String get parameterInformationLimited;

  /// No description provided for @sqlInspectionSyntax.
  ///
  /// In en, this message translates to:
  /// **'SQL syntax error'**
  String get sqlInspectionSyntax;

  /// No description provided for @sqlInspectionDialect.
  ///
  /// In en, this message translates to:
  /// **'SQL construct is unavailable for this dialect'**
  String get sqlInspectionDialect;

  /// No description provided for @sqlInspectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SQL analysis is unavailable for this construct'**
  String get sqlInspectionUnavailable;

  /// No description provided for @sqlInspectionUnknownFunction.
  ///
  /// In en, this message translates to:
  /// **'Unknown routine'**
  String get sqlInspectionUnknownFunction;

  /// No description provided for @sqlInspectionMetadata.
  ///
  /// In en, this message translates to:
  /// **'SQL inspection is incomplete because metadata is unavailable'**
  String get sqlInspectionMetadata;

  /// No description provided for @sqlDiagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No SQL inspections were reported for this document.'**
  String get sqlDiagnosticsEmpty;

  /// No description provided for @sqlDiagnosticSpan.
  ///
  /// In en, this message translates to:
  /// **'UTF-16 {start}–{end} · {source}'**
  String sqlDiagnosticSpan(int start, int end, String source);

  /// No description provided for @sqlDiagnosticGo.
  ///
  /// In en, this message translates to:
  /// **'Go to SQL span'**
  String get sqlDiagnosticGo;

  /// No description provided for @sqlDiagnosticFix.
  ///
  /// In en, this message translates to:
  /// **'Apply selected correction'**
  String get sqlDiagnosticFix;

  /// No description provided for @sqlDiagnosticReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement text'**
  String get sqlDiagnosticReplacement;

  /// No description provided for @sqlDiagnosticStale.
  ///
  /// In en, this message translates to:
  /// **'SQL inspection context changed. Request inspections again.'**
  String get sqlDiagnosticStale;

  /// No description provided for @sqlDiagnosticUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SQL inspections are unavailable for the current document.'**
  String get sqlDiagnosticUnavailable;

  /// No description provided for @sqlDiagnosticCount.
  ///
  /// In en, this message translates to:
  /// **'{count} SQL inspections'**
  String sqlDiagnosticCount(int count);

  /// No description provided for @aggregateTextOrder.
  ///
  /// In en, this message translates to:
  /// **'Text minimum/maximum use retained UTF-16 ordinal order; database collation is not applied.'**
  String get aggregateTextOrder;

  /// No description provided for @aggregateMixedTypes.
  ///
  /// In en, this message translates to:
  /// **'The selected values have incompatible types. Select values with a common type.'**
  String get aggregateMixedTypes;

  /// No description provided for @aggregateUnsupportedOrder.
  ///
  /// In en, this message translates to:
  /// **'Ordering and numeric calculations are unavailable for this value type.'**
  String get aggregateUnsupportedOrder;

  /// No description provided for @relatedKeyNotProjected.
  ///
  /// In en, this message translates to:
  /// **'Select all relationship key columns in the source result before navigating.'**
  String get relatedKeyNotProjected;

  /// No description provided for @relatedNullKey.
  ///
  /// In en, this message translates to:
  /// **'A NULL relationship key has no matching related row.'**
  String get relatedNullKey;

  /// No description provided for @relatedTargetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The relationship target is outside this session’s supported database scope.'**
  String get relatedTargetUnavailable;

  /// No description provided for @relatedValueLimited.
  ///
  /// In en, this message translates to:
  /// **'The relationship key is truncated or exceeds navigation limits. Browse the target explicitly.'**
  String get relatedValueLimited;

  /// No description provided for @temporalCustomPattern.
  ///
  /// In en, this message translates to:
  /// **'Temporal · custom pattern'**
  String get temporalCustomPattern;

  /// No description provided for @temporalPattern.
  ///
  /// In en, this message translates to:
  /// **'Temporal display pattern'**
  String get temporalPattern;

  /// No description provided for @temporalSourceZone.
  ///
  /// In en, this message translates to:
  /// **'Original calendar fields'**
  String get temporalSourceZone;

  /// No description provided for @temporalZone.
  ///
  /// In en, this message translates to:
  /// **'Display timezone'**
  String get temporalZone;

  /// No description provided for @temporalPatternHelp.
  ///
  /// In en, this message translates to:
  /// **'Use ICU calendar fields and up to six S digits for exact fractions. UTC/local conversion requires an explicit offset. Unsupported temporal values remain raw.'**
  String get temporalPatternHelp;

  /// No description provided for @temporalPatternInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a pattern of 1–128 characters with supported calendar fields, balanced quotes, and at most six S digits. Timezone letters z, Z and v are unsupported; choose the display timezone separately.'**
  String get temporalPatternInvalid;

  /// No description provided for @editCompleteValue.
  ///
  /// In en, this message translates to:
  /// **'Edit complete value'**
  String get editCompleteValue;

  /// No description provided for @completeValueEditLimit.
  ///
  /// In en, this message translates to:
  /// **'Complete editing requires verified retained ownership, at most 1 MiB across original and new values, and 262,144 text units per value. Larger values remain available for export.'**
  String get completeValueEditLimit;

  /// No description provided for @completeValueReady.
  ///
  /// In en, this message translates to:
  /// **'Complete retained value loaded for editing; changes are staged only.'**
  String get completeValueReady;

  /// No description provided for @binaryNextEditPage.
  ///
  /// In en, this message translates to:
  /// **'Next 16 KiB'**
  String get binaryNextEditPage;

  /// No description provided for @binaryPreviousEditPage.
  ///
  /// In en, this message translates to:
  /// **'Previous 16 KiB'**
  String get binaryPreviousEditPage;

  /// No description provided for @arrayEditLimit.
  ///
  /// In en, this message translates to:
  /// **'Array edits use exact native PostgreSQL text, at most 16 KiB of text, six dimensions and 1,024 scalar values. Java validates the captured element type.'**
  String get arrayEditLimit;

  /// No description provided for @valueChangedDuringStage.
  ///
  /// In en, this message translates to:
  /// **'The earlier value was staged. Your newer draft is preserved; review it before staging again.'**
  String get valueChangedDuringStage;

  /// Bounded native value/text presentation.
  ///
  /// In en, this message translates to:
  /// **'Text page {current} of {total}'**
  String textValuePage(String current, String total);

  /// Bounded native value/text presentation.
  ///
  /// In en, this message translates to:
  /// **'Only this text page is shown. Copy and export actions keep their stated scope.'**
  String get textValuePagesScope;

  /// Bounded native value/text presentation.
  ///
  /// In en, this message translates to:
  /// **'Stage change includes every text page.'**
  String get textValueEditScope;

  /// Bounded native value/text presentation.
  ///
  /// In en, this message translates to:
  /// **'Previous text page'**
  String get textValuePreviousPage;

  /// Bounded native value/text presentation.
  ///
  /// In en, this message translates to:
  /// **'Next text page'**
  String get textValueNextPage;

  /// Bounded native value/text presentation.
  ///
  /// In en, this message translates to:
  /// **'That text is invalid or too large for this page. The previous text was kept.'**
  String get valuePageEditLimit;

  /// Bounded value editing control.
  ///
  /// In en, this message translates to:
  /// **'Add editing page'**
  String get valueAddEditPage;

  /// Bounded value editing control.
  ///
  /// In en, this message translates to:
  /// **'Finish a valid, full last binary page before adding another page. Bytes are never padded.'**
  String get binaryAppendPageReason;

  /// Bounded native value presentation.
  ///
  /// In en, this message translates to:
  /// **'Value actions'**
  String get valueEditorActions;

  /// Bounded native value presentation.
  ///
  /// In en, this message translates to:
  /// **'UTF-8 hexadecimal'**
  String get utf8Hex;

  /// Bounded native value presentation.
  ///
  /// In en, this message translates to:
  /// **'UTF-8 Base64'**
  String get utf8Base64;

  /// Bounded native value presentation.
  ///
  /// In en, this message translates to:
  /// **'Plain text editing is unavailable for values containing a NUL character. UTF-8 byte views and exact export remain available.'**
  String get nativeTextNulUnavailable;

  /// Bounded native value presentation.
  ///
  /// In en, this message translates to:
  /// **'This text contains a NUL character and cannot be copied exactly. Export the value or choose another extractor.'**
  String get textClipboardNulUnavailable;

  /// No description provided for @sqlVisibleLine.
  ///
  /// In en, this message translates to:
  /// **'Visible SQL line {line} of {total}, column {column}'**
  String sqlVisibleLine(int line, int total, int column);

  /// No description provided for @sqlLinePreviewTruncated.
  ///
  /// In en, this message translates to:
  /// **'Line preview truncated'**
  String get sqlLinePreviewTruncated;

  /// No description provided for @sqlActiveCarets.
  ///
  /// In en, this message translates to:
  /// **'{count} carets active'**
  String sqlActiveCarets(int count);

  /// No description provided for @sqlCompositionActive.
  ///
  /// In en, this message translates to:
  /// **'Input composition active'**
  String get sqlCompositionActive;

  /// No description provided for @sqlEditorDocumentLimit.
  ///
  /// In en, this message translates to:
  /// **'The edit exceeds the 8M UTF-16 document limit. Use a smaller document.'**
  String get sqlEditorDocumentLimit;

  /// No description provided for @sqlEditorLineLimit.
  ///
  /// In en, this message translates to:
  /// **'The edit exceeds the 100,000-line document limit. Use a smaller document.'**
  String get sqlEditorLineLimit;

  /// No description provided for @sqlEditorCaretLimit.
  ///
  /// In en, this message translates to:
  /// **'The editor supports at most 64 carets. Remove extra carets before adding more.'**
  String get sqlEditorCaretLimit;

  /// No description provided for @sqlEditorFinishComposition.
  ///
  /// In en, this message translates to:
  /// **'Finish input composition before changing this selection.'**
  String get sqlEditorFinishComposition;

  /// No description provided for @sqlEditorClipboardLimit.
  ///
  /// In en, this message translates to:
  /// **'The exact selection exceeds the 1 MiB clipboard limit. Save or export the text instead.'**
  String get sqlEditorClipboardLimit;

  /// No description provided for @sqlEditorSelectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The editor cannot apply this selection. The original SQL is retained.'**
  String get sqlEditorSelectionUnavailable;

  /// No description provided for @sqlEditorClipboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is unavailable. Your SQL and selection have been kept.'**
  String get sqlEditorClipboardUnavailable;

  /// No description provided for @metadataCacheWriteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The cache could not be saved. Current metadata remains available.'**
  String get metadataCacheWriteUnavailable;

  /// No description provided for @metadataCacheRebuiltVersion.
  ///
  /// In en, this message translates to:
  /// **'Rebuilt for the current version'**
  String get metadataCacheRebuiltVersion;

  /// No description provided for @metadataCacheRebuiltCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Rebuilt after a cache error'**
  String get metadataCacheRebuiltCorrupt;

  /// No description provided for @editSessionBusy.
  ///
  /// In en, this message translates to:
  /// **'This session is busy. Wait for its current work to finish, then request a fresh editing assessment.'**
  String get editSessionBusy;

  /// No description provided for @editIdentityRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a complete primary key or non-nullable unique identity before editing.'**
  String get editIdentityRequired;

  /// No description provided for @editColumnsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'All projected columns are generated or read-only.'**
  String get editColumnsReadOnly;

  /// No description provided for @editResultNotReady.
  ///
  /// In en, this message translates to:
  /// **'Wait for this retained result to finish before requesting a fresh editing assessment.'**
  String get editResultNotReady;

  /// No description provided for @editProjectionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Editing requires a direct SELECT from one base table with each base column projected once.'**
  String get editProjectionUnsupported;

  /// No description provided for @sqlInspectionDuplicateUsingColumn.
  ///
  /// In en, this message translates to:
  /// **'Duplicate JOIN USING column'**
  String get sqlInspectionDuplicateUsingColumn;

  /// No description provided for @sqlInspectionUnresolvedUsingColumn.
  ///
  /// In en, this message translates to:
  /// **'JOIN USING column missing from an operand'**
  String get sqlInspectionUnresolvedUsingColumn;

  /// No description provided for @sqlInspectionAmbiguousUsingColumn.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous shared JOIN column'**
  String get sqlInspectionAmbiguousUsingColumn;

  /// No description provided for @sqlInspectionOutputColumnCount.
  ///
  /// In en, this message translates to:
  /// **'Declared output column count mismatch'**
  String get sqlInspectionOutputColumnCount;

  /// No description provided for @sqlInspectionAmbiguousOverload.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous routine overload'**
  String get sqlInspectionAmbiguousOverload;

  /// No description provided for @sqlInspectionBooleanType.
  ///
  /// In en, this message translates to:
  /// **'Invalid Boolean expression type'**
  String get sqlInspectionBooleanType;

  /// No description provided for @sqlInspectionOperatorTypes.
  ///
  /// In en, this message translates to:
  /// **'Incompatible operator operand types'**
  String get sqlInspectionOperatorTypes;

  /// No description provided for @sqlInspectionArrayTypes.
  ///
  /// In en, this message translates to:
  /// **'Incompatible array element types'**
  String get sqlInspectionArrayTypes;

  /// No description provided for @sqlInspectionCaseConditionType.
  ///
  /// In en, this message translates to:
  /// **'Incompatible CASE condition type'**
  String get sqlInspectionCaseConditionType;

  /// No description provided for @sqlInspectionCaseResultTypes.
  ///
  /// In en, this message translates to:
  /// **'Incompatible CASE result types'**
  String get sqlInspectionCaseResultTypes;

  /// No description provided for @sqlInspectionCoalesceTypes.
  ///
  /// In en, this message translates to:
  /// **'Incompatible COALESCE argument types'**
  String get sqlInspectionCoalesceTypes;

  /// No description provided for @sqlInspectionSetColumnCount.
  ///
  /// In en, this message translates to:
  /// **'Set operation column count mismatch'**
  String get sqlInspectionSetColumnCount;

  /// No description provided for @sqlInspectionSetTypes.
  ///
  /// In en, this message translates to:
  /// **'Incompatible set operation result types'**
  String get sqlInspectionSetTypes;

  /// No description provided for @sqlInspectionRecursiveCteType.
  ///
  /// In en, this message translates to:
  /// **'Recursive CTE type mismatch'**
  String get sqlInspectionRecursiveCteType;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'et',
    'fa',
    'fi',
    'fr',
    'hi',
    'it',
    'ja',
    'ko',
    'pl',
    'pt',
    'ru',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'PT':
            return AppLocalizationsPtPt();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'et':
      return AppLocalizationsEt();
    case 'fa':
      return AppLocalizationsFa();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
