import 'package:busydata/src/backend/tool_admission_requests.dart';
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/results/complete_value.dart';
import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
// Test-only native entrypoint. Never shipped as the ordinary product entrypoint.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:busydata/main_linux.dart' as application;
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/linux/portal_database_secrets.dart';
import 'package:busydata/src/platform/common/packaged_database_tools.dart';
import 'package:crypto/crypto.dart';
import 'package:dbus/dbus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:uuid/uuid.dart';

void require(bool condition, String message) {
  if (!condition) throw InstalledAssertion(message);
}

class InstalledAssertion extends StateError {
  InstalledAssertion(super.message);
}

class ObservedNativePortal implements SecretPortalClient {
  ObservedNativePortal(this.observe);
  final void Function(Object) observe;
  @override
  Future<PortalSecret> retrieveSecret({String? token}) async {
    try {
      return await XdgSecretPortalClient().retrieveSecret(token: token);
    } catch (error) {
      observe(error);
      rethrow;
    }
  }
}

bool terminal(rpc.JobState state) => const {
  rpc.JobState.COMPLETED,
  rpc.JobState.CANCELLED,
  rpc.JobState.FAILED,
  rpc.JobState.INTERRUPTED,
  rpc.JobState.UNKNOWN_OUTCOME,
}.contains(state);

// Check bytes before decoding a complete bootstrap line.
Future<Map<String, dynamic>> readFixture(Stream<List<int>> input) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in input) {
    final newline = chunk.indexOf(10);
    final count = newline < 0 ? chunk.length : newline;
    require(bytes.length + count <= 16384, 'Fixture bootstrap is too large');
    bytes.add(Uint8List.fromList(chunk.sublist(0, count)));
    if (newline >= 0) {
      return jsonDecode(utf8.decode(bytes.takeBytes())) as Map<String, dynamic>;
    }
  }
  throw StateError('Fixture bootstrap pipe ended before a complete line');
}

Future<void> main() async {
  WorkbenchModel? model;
  final report = <String, Object?>{
    'version': 1,
    'entrypoint': 'installed_snap_linux.dart',
    'releaseMode': kReleaseMode,
    'stages': <String, Object?>{},
    'fullInstalledDatabaseFileSecretSshAcceptance': false,
  };
  File? output;
  var code = 1;
  var checkpoint = 'starting';
  final stages = report['stages']! as Map<String, Object?>;
  Future<void> stage(String name, Future<void> Function() test) async {
    final clock = Stopwatch()..start();
    checkpoint = 'starting';
    try {
      await test().timeout(const Duration(minutes: 5));
      stages[name] = {'passed': true, 'durationMs': clock.elapsedMilliseconds};
    } catch (error) {
      // No credential, SQL, result, or server-message payload enters evidence.
      final rpcReason = WorkbenchFailureReason.fromError(error);
      stages[name] = {
        'passed': false,
        'failureType': error.runtimeType.toString(),
        'checkpoint': checkpoint,
        if (error is InstalledAssertion) 'assertion': error.message,
        if (error is GrpcError) 'rpcCode': error.code,
        if (rpcReason != null) 'rpcReason': rpcReason.wire,
        if (error is SecretStoreException) 'secretCode': error.code,
        'durationMs': clock.elapsedMilliseconds,
      };
    }
    if (output != null) {
      await atomicWrite(output, utf8.encode(jsonEncode(report)));
    }
  }

  try {
    require(kReleaseMode, 'Installed acceptance requires release mode');
    require(
      Platform.environment['SNAP'] != null,
      'Run inside the strict installed package',
    );
    // The external unconfined controller verifies actual kernel labels for
    // this process and the backend. The strict policy intentionally denies an
    // application read of /proc/self/attr/current; no introspection plug is added.
    report['flutterPid'] = pid;
    final fixture = await readFixture(
      stdin,
    ).timeout(const Duration(seconds: 30));
    require(fixture['version'] == 1, 'Fixture version mismatch');
    final root = Directory(fixture['root'] as String);
    final common = Platform.environment['SNAP_USER_COMMON']!;
    require(
      root.absolute.path.startsWith('$common/installed-'),
      'Use an isolated package-owned fixture directory',
    );
    output = File('${root.path}/desktop-acceptance.json');
    final forceTerminationProbe = fixture['forceTerminationProbe'] == true;
    model = await application.startLinux(
      supportDirectory: Directory(
        '${root.path}/${forceTerminationProbe ? 'force-parent-application' : 'application'}',
      ),
    );
    final active = model, backend = model.backend;
    require(backend != null, 'Bundled backend startup failed');
    final connection = backend!;
    report['backendInstance'] = connection.instanceId;
    report['javaRuntime'] = (await connection.client.runtimeStats(
      connection.context(),
    )).javaVersion;
    final processId = connection.process.pid;
    report['backendPid'] = processId;
    if (forceTerminationProbe) {
      await atomicWrite(
        File('${root.path}/force-parent-ready.json'),
        utf8.encode(
          jsonEncode({
            'version': 1,
            'flutterPid': pid,
            'backendPid': processId,
            'backendInstance': connection.instanceId,
            'javaRuntime': report['javaRuntime'],
            'releaseMode': kReleaseMode,
          }),
        ),
      );
      // The external owned controller kills this exact confined frontend. The
      // backend must observe parent death without a graceful shutdown command.
      await Completer<void>().future;
    }
    await stage('native-single-instance', () async {
      final second = await Process.start(Platform.resolvedExecutable, const []);
      var bytes = 0;
      Future<void> drain(Stream<List<int>> stream) async {
        await for (final chunk in stream) {
          bytes += chunk.length;
          if (bytes > 1048576) {
            second.kill();
            throw StateError('Secondary-launch diagnostic byte limit');
          }
        }
      }

      try {
        await second.stdin.close();
        final drains = Future.wait([
          drain(second.stdout),
          drain(second.stderr),
        ]);
        require(
          await second.exitCode.timeout(const Duration(seconds: 10)) == 0,
          'Secondary launch did not activate the primary instance',
        );
        await drains.timeout(const Duration(seconds: 10));
        final stats = await connection.client.runtimeStats(
          connection.context(),
        );
        require(
          stats.instanceId == connection.instanceId &&
              Directory('/proc/$processId').existsSync(),
          'Secondary launch replaced or disconnected the owned backend',
        );
      } finally {
        second.kill();
      }
    });
    Future<rpc.JobInfo> finished(String id) async {
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (DateTime.now().isBefore(deadline)) {
        final jobs = await connection.client.jobs(
          rpc.JobRequest(context: connection.context(), jobId: id),
        );
        final job = jobs.jobs.single;
        if (terminal(job.state)) {
          if (job.state != rpc.JobState.COMPLETED) {
            final errorCode =
                RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(job.errorCode)
                ? job.errorCode
                : 'UNCLASSIFIED';
            report['$checkpoint-job-failure'] = {
              'state': job.state.name,
              'code': errorCode,
              for (final message in job.messages)
                if (RegExp(
                  r'^Native tool exited [0-9]+: [a-z /-]+(?: \(database code [0-9]{3,5}\))?\. Source values and server messages omitted\.$',
                ).hasMatch(message))
                  'nativeDiagnostic': message,
            };
          }
          return job;
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      throw TimeoutException('Database job deadline');
    }

    Future<rpc.JobInfo> wait(String id) async {
      final job = await finished(id);
      require(job.state == rpc.JobState.COMPLETED, 'Database job failed');
      return job;
    }

    Future<rpc.JobInfo> submit(String session, String sql) async {
      final request = rpc.ExecuteRequest(
        context: connection.context(),
        sessionId: session,
        executionId: const Uuid().v4(),
        sql: sql,
        rowLimit: Int64(1000),
      );
      request.approvalToken = (await connection.client.review(request)).token;
      return connection.client.execute(request);
    }

    Future<rpc.JobInfo> execute(String session, String sql) async {
      return wait((await submit(session, sql)).jobId);
    }

    Future<rpc.JobInfo> tool(rpc.ToolRequest request) async {
      request.context = connection.context();
      request.executionId = const Uuid().v4();
      request.approvalToken = (await connection.client.reviewToolAdmission(
        request,
      )).token;
      return wait((await connection.client.toolAdmission(request)).jobId);
    }

    Future<void> disconnect(String session) async {
      final request = rpc.SessionRequest(
        context: connection.context(),
        sessionId: session,
        action: rpc.SessionAction.DISCONNECT,
      );
      request.approvalToken = (await connection.client.reviewSession(
        request,
      )).token;
      await connection.client.session(request);
    }

    Future<rpc.Page> page(rpc.JobInfo job) => connection.client.resultPage(
      rpc.PageRequest(
        context: connection.context(),
        resultId: job.results.single.resultId,
        limit: 10,
        maxBytes: 262144,
      ),
    );
    Future<void> dispose(rpc.JobInfo job) async {
      for (final result in job.results.where((r) => r.resultId.isNotEmpty)) {
        await connection.client.disposeResult(
          rpc.PageRequest(
            context: connection.context(),
            resultId: result.resultId,
          ),
        );
      }
    }

    final databaseCredentialFile = File(
      '${root.path}/application/database-secrets.json',
    );
    Future<String> databasePassword() async {
      final stored = await PortalDatabaseSecrets(
        databaseCredentialFile,
      ).read('installed-database');
      require(
        stored != null,
        'Installed database credential is unavailable; no plaintext fallback',
      );
      return stored!;
    }

    await stage('portal-credentials', () async {
      final file = File('${root.path}/application/portal-acceptance.json');
      final store = PortalDatabaseSecrets(
        file,
        portalClient: ObservedNativePortal((error) {
          report['portalProviderFailure'] = {
            'type': error.runtimeType.toString(),
            if (error is DBusMethodResponseException &&
                RegExp(
                  r'^org\.freedesktop\.DBus\.Error\.[A-Za-z]+$',
                ).hasMatch(error.errorName))
              'name': error.errorName,
            if (error is SecretPortalException) 'code': error.code,
            if (error is FileSystemException) 'errno': error.osError?.errorCode,
          };
        }),
      );
      checkpoint = 'write';
      await store.write('disposable-verification', 'private portal fixture 漢');
      checkpoint = 'read';
      require(
        await PortalDatabaseSecrets(file).read('disposable-verification') ==
            'private portal fixture 漢',
        'Portal secret round trip failed',
      );
      require(
        !(await file.readAsString()).contains('private portal fixture'),
        'Credential was stored in plaintext',
      );
      checkpoint = 'replace';
      await store.write('disposable-verification', 'replacement fixture 😀');
      require(
        await PortalDatabaseSecrets(file).read('disposable-verification') ==
            'replacement fixture 😀',
        'Portal credential replacement failed after reopening storage',
      );
      require(
        !(await file.readAsString()).contains('replacement fixture'),
        'Replacement credential was stored in plaintext',
      );
      await store.delete('disposable-verification');
      require(
        await PortalDatabaseSecrets(file).read('disposable-verification') ==
            null,
        'Secret deletion failed',
      );
      await PortalDatabaseSecrets(
        databaseCredentialFile,
      ).write('installed-database', 'installed-database-fixture');
      require(
        await databasePassword() == 'installed-database-fixture' &&
            !(await databaseCredentialFile.readAsString()).contains(
              'installed-database-fixture',
            ),
        'Installed database credential was not recoverable through encrypted portal storage',
      );
    });
    await stage('files-recovery', () async {
      final file = File('${root.path}/ordinary 漢.sql');
      active.document.editor.text = "SELECT 'canonical 😀';\r\n";
      await active.document.save(file.path);
      active.document.editor.text = "SELECT 'unsaved 😀';\r\n";
      await active.recoverNow();
      final recovered = await active.drafts.load();
      try {
        require(
          recovered.single.editor.text == active.document.editor.text &&
              recovered.single.dirty,
          'Dirty draft restoration failed',
        );
        require(
          await file.readAsString() == "SELECT 'canonical 😀';\r\n",
          'Ordinary SQL changed',
        );
      } finally {
        for (final document in recovered) {
          document.dispose();
        }
      }
    });
    Future<String> picker(
      String operation,
      String path, {
      bool writeSql = false,
    }) async {
      final request = File('${root.path}/picker-request.json');
      await atomicWrite(
        request,
        utf8.encode(jsonEncode({'operation': operation, 'path': path})),
      );
      String selected;
      if (operation == 'open') {
        final chosen = await openFile(
          initialDirectory: root.path,
        ).timeout(const Duration(seconds: 60));
        require(
          chosen?.path == path,
          'Native open picker returned a different file',
        );
        selected = chosen!.path;
      } else {
        final chosen = await getSaveLocation(
          initialDirectory: root.path,
          suggestedName: path.split('/').last,
        ).timeout(const Duration(seconds: 60));
        if (chosen != null && chosen.path != path) {
          // Synthetic fixture filename only; no user's directories or data.
          report['savePickerFixtureFilename'] = chosen.path.split('/').last;
          report['savePickerInFixtureDirectory'] =
              File(chosen.path).parent.path == root.path;
        }
        require(
          chosen?.path == path,
          'Native save picker returned a different file',
        );
        selected = chosen!.path;
        if (writeSql) {
          final document = SqlDocument(text: 'SELECT 7;');
          try {
            await document.save(path);
          } finally {
            document.dispose();
          }
          require(
            await File(path).readAsString() == 'SELECT 7;',
            'Selected destination failed',
          );
        }
      }
      await request.delete();
      return selected;
    }

    await stage(
      'native-open-picker',
      () => picker('open', '${root.path}/ordinary 漢.sql'),
    );
    await stage(
      'native-save-picker',
      () => picker('save', '${root.path}/portal-save 漢.sql', writeSql: true),
    );

    var selectedCa = '', selectedKey = '';
    await stage('native-ca-picker', () async {
      selectedCa = await picker('open', '${root.path}/ca.pem');
      require(
        await File(selectedCa).length() > 0,
        'Selected CA is not readable',
      );
    });
    await stage('native-key-picker', () async {
      selectedKey = await picker('open', '${root.path}/selected-key');
      require(
        await File(selectedKey).length() > 0,
        'Selected SSH key is not readable',
      );
    });
    rpc.Profile? reviewedSsh;
    for (final raw in fixture['engines'] as List) {
      final data = raw as Map<String, dynamic>;
      final engine = rpc.Engine.values.firstWhere(
        (e) => e.name == data['engine'],
      );
      final profile = rpc.Profile(
        id: 'installed-${engine.name}',
        name: 'Disposable installed acceptance',
        engine: engine,
        host: 'localhost',
        port: data['port'] as int,
        database: 'busydata',
        user: engine == rpc.Engine.POSTGRESQL ? 'busydata' : 'root',
        connectTimeoutSeconds: 10,
        queryTimeoutSeconds: 60,
        tls: rpc.Tls(mode: rpc.TlsMode.VERIFY_FULL, caFile: selectedCa),
      );
      String? session;
      await stage('${engine.name}-tls-execution', () async {
        final open = rpc.OpenRequest(
          context: connection.context(),
          profile: profile,
          password: await databasePassword(),
        );
        for (final invalid in [
          profile.deepCopy()..host = '127.0.0.1',
          profile.deepCopy()..tls.caFile = '${root.path}/unrelated-ca.pem',
        ]) {
          var rejected = false;
          try {
            final unexpected = await connection.client.openSession(
              open.deepCopy()..profile = invalid,
            );
            await disconnect(unexpected.sessionId);
          } catch (_) {
            rejected = true;
          }
          require(
            rejected,
            'Invalid database certificate/hostname was accepted',
          );
        }
        final opened = await connection.client.openSession(open);
        session = opened.sessionId;
        final adopt = rpc.SessionRequest(
          context: connection.context(),
          sessionId: session,
          action: rpc.SessionAction.ADOPT_SESSION,
        );
        await connection.client.session(adopt);
        report['${engine.name}-version'] = opened.database.version;
        await execute(
          session!,
          'CREATE TABLE package_rows(id INTEGER PRIMARY KEY,n DECIMAL(38,9),t VARCHAR(100));',
        );
        final marker = engine == rpc.Engine.POSTGRESQL ? r'\N' : r'\\N';
        await execute(
          session!,
          "INSERT INTO package_rows VALUES(1,12345678901234567890.123456789,'漢😀'),(2,NULL,'$marker'),(3,0,'');",
        );
        final result = await execute(
          session!,
          'SELECT id,n,t FROM package_rows ORDER BY id',
        );
        final rows = (await page(result)).rows;
        require(
          rows.length == 3 &&
              rows.first.values[1].decimal ==
                  '12345678901234567890.123456789' &&
              rows.first.values[2].text == '漢😀' &&
              rows[1].values[1].hasNullValue(),
          'Exact native cells failed',
        );
        await dispose(result);
      });
      if (session == null) {
        for (final name in [
          'transactions-cancellation-editing-paging',
          'p0-result-editor',
          'native-export-picker',
          'native-import-picker',
          'transfers',
          'large-streaming-transfer',
          'ssh-password-key-agent-native-backup',
          'retained-after-disconnect',
        ]) {
          stages['${engine.name}-$name'] = {
            'passed': false,
            'failureType': 'UnavailableSession',
          };
        }
        continue;
      }
      final id = session!;
      await stage('${engine.name}-p0-result-editor', () async {
        final namespace = engine == rpc.Engine.POSTGRESQL
            ? 'public'
            : 'busydata';
        final binaryType = engine == rpc.Engine.POSTGRESQL
            ? 'bytea'
            : 'longblob';
        final textType = engine == rpc.Engine.POSTGRESQL ? 'text' : 'longtext';
        checkpoint = 'p0-create-table';
        await execute(
          id,
          'CREATE TABLE package_editor_values('
          'id INTEGER PRIMARY KEY,parent_id INTEGER,body $textType,payload $binaryType,'
          'FOREIGN KEY(parent_id) REFERENCES package_rows(id))',
        );
        final binarySql = engine == rpc.Engine.POSTGRESQL
            ? "decode(REPEAT('00ff',45000),'hex')"
            : "UNHEX(REPEAT('00ff',45000))";
        checkpoint = 'p0-insert-source';
        await execute(
          id,
          "INSERT INTO package_editor_values VALUES(1,1,REPEAT('漢',30000),$binarySql)",
        );
        checkpoint = 'p0-structural-refresh';
        await connection.client.explore(
          rpc.ExploreRequest(
            context: connection.context(),
            sessionId: id,
            kind: rpc.ObjectKind.TABLE,
            catalog: 'busydata',
            schema: namespace,
            refresh: true,
            introspectionLevel: 2,
            refreshMode: 'FULL',
            limit: 100,
          ),
        );
        checkpoint = 'p0-retained-source';
        final source = await execute(
          id,
          'SELECT id,parent_id,body,payload FROM $namespace.package_editor_values ORDER BY id',
        );
        final sourceId = source.results.single.resultId;
        final original = (await page(source)).rows.single;
        require(
          original.values[2].truncated && original.values[3].truncated,
          'Installed P0 LOB values must remain chunked previews',
        );
        final originalWire = original.writeToBuffer();
        final jobsBefore = (await connection.client.jobs(
          rpc.JobRequest(context: connection.context()),
        )).jobs.map((job) => job.jobId).toSet();
        checkpoint = 'p0-complete-text';
        final text = await readCompleteValue(
          original.values[2],
          (offset) => connection.client.resultValue(
            rpc.ValueRequest(
              context: connection.context(),
              resultId: sourceId,
              valueId: original.values[2].valueId,
              offset: Int64(offset),
              maxBytes: 65536,
            ),
          ),
          () => true,
        );
        checkpoint = 'p0-complete-binary';
        final binary = await readCompleteValue(
          original.values[3],
          (offset) => connection.client.resultValue(
            rpc.ValueRequest(
              context: connection.context(),
              resultId: sourceId,
              valueId: original.values[3].valueId,
              offset: Int64(offset),
              maxBytes: 65536,
            ),
          ),
          () => true,
        );
        require(
          text.text == '漢' * 30000 &&
              binary.binary.length == 90000 &&
              binary.binary.asMap().entries.every(
                (entry) => entry.value == (entry.key.isEven ? 0 : 255),
              ),
          'Installed P0 complete-value transport changed exact Unicode or bytes',
        );
        checkpoint = 'p0-exact-aggregate';
        final aggregate = await connection.client.resultAggregate(
          rpc.ResultAggregateRequest(
            context: connection.context(),
            resultId: sourceId,
            firstRow: Int64.ZERO,
            rowCount: 1,
            ordinals: [2],
          ),
        );
        require(
          aggregate.columns.single.selectedCount == Int64.ONE &&
              aggregate.columns.single.sum == '1' &&
              aggregate.columns.single.average == '1',
          'Installed P0 aggregate was not exact for the selected retained scope',
        );
        checkpoint = 'p0-clone-row';
        final clone = await connection.client.cloneRow(
          rpc.CloneRowRequest(
            context: connection.context(),
            sessionId: id,
            resultId: sourceId,
            sourceRow: Int64.ZERO,
            catalog: 'busydata',
            schema: namespace,
            table: 'package_editor_values',
          ),
        );
        require(
          clone.kind == rpc.ChangeKind.INSERT &&
              !clone.values.containsKey(1) &&
              clone.values[2]!.value.signedInteger == '1' &&
              clone.values[3]!.value.text == text.text &&
              listEquals(clone.values[4]!.value.binary, binary.binary),
          'Installed P0 clone did not preserve exact assignments or omit the primary key',
        );
        // A clone omits the old primary key. Supply the user's new assignment
        // before reviewing the staged insert; this never applies the insert.
        final stagedClone = clone.deepCopy()
          ..values[1] = assignments.assignmentOf(rpc.Value(signedInteger: '2'));
        checkpoint = 'p0-review-clone';
        final plan = await connection.client.previewChanges(
          rpc.ChangeRequest(
            context: connection.context(),
            sessionId: id,
            schema: namespace,
            table: 'package_editor_values',
            resultId: sourceId,
            changes: [stagedClone],
          ),
        );
        require(
          plan.sql.isNotEmpty,
          'Installed P0 clone must produce a reviewable staged operation',
        );
        checkpoint = 'p0-capture-relationship-owner';
        final relatedOwner = await connection.client.session(
          rpc.SessionRequest(context: connection.context(), sessionId: id),
        );
        final metadataOwner = await connection.client.metadataSettings(
          rpc.MetadataSettingsRequest(
            context: connection.context(),
            sessionId: id,
            sessionRevision: relatedOwner.sessionRevision,
            contextRevision: relatedOwner.contextRevision,
          ),
        );
        require(
          relatedOwner.sessionId == id &&
              relatedOwner.profile.id == profile.id &&
              relatedOwner.metadataSourceIdentity.isNotEmpty &&
              metadataOwner.backendInstance ==
                  connection.context().instanceId &&
              metadataOwner.profileId == profile.id &&
              metadataOwner.sessionId == id &&
              metadataOwner.sessionRevision == relatedOwner.sessionRevision &&
              metadataOwner.contextRevision == relatedOwner.contextRevision &&
              metadataOwner.metadataSourceIdentity ==
                  relatedOwner.metadataSourceIdentity &&
              metadataOwner.snapshotRevision > Int64.ZERO,
          'Installed P0 relationship metadata owner changed',
        );
        checkpoint = 'p0-related-rows';
        final related = await connection.client.relatedRows(
          rpc.RelatedRowsRequest(
            context: connection.context(),
            sessionId: id,
            resultId: sourceId,
            sourceRow: Int64.ZERO,
            snapshotRevision: metadataOwner.snapshotRevision,
            expectedSessionRevision: relatedOwner.sessionRevision,
            expectedContextRevision: relatedOwner.contextRevision,
            documentId: const Uuid().v4(),
          ),
        );
        final relationship = related.relationships.singleWhere(
          (candidate) =>
              !candidate.incoming &&
              candidate.availability == 'available' &&
              candidate.browse.table == 'package_rows',
        );
        final browse = relationship.browse.deepCopy()
          ..context = connection.context()
          ..executionId = const Uuid().v4();
        require(
          browse.metadataObjectIdentity.isNotEmpty &&
              browse.metadataSnapshotRevision > Int64.ZERO &&
              browse.originRelationshipIdentity == relationship.identity &&
              browse.originResultId == sourceId &&
              browse.originSourceRow == Int64.ZERO,
          'Installed related-row browse lost its exact backend-issued target and origin proof',
        );
        checkpoint = 'p0-review-related-browse';
        final review = await connection.client.reviewBrowse(browse);
        require(
          review.token.isNotEmpty && review.statements.isNotEmpty,
          'Installed related-row browse did not require explicit review',
        );
        final jobsAfter = (await connection.client.jobs(
          rpc.JobRequest(context: connection.context()),
        )).jobs.map((job) => job.jobId).toSet();
        require(
          setEquals(jobsBefore, jobsAfter),
          'Installed inspection, aggregate, clone or browse review executed SQL',
        );
        browse.approvalToken = review.token;
        checkpoint = 'p0-open-related-rows';
        final opened = await wait(
          (await connection.client.browse(browse)).jobId,
        );
        final parent = (await page(opened)).rows.single;
        require(
          parent.values.first.signedInteger == '1',
          'Installed reviewed relationship opened a different source key',
        );
        final retained = (await page(source)).rows.single;
        require(
          listEquals(originalWire, retained.writeToBuffer()),
          'Installed P0 operations changed the retained source preview',
        );
        report['${engine.name}-p0ResultEditor'] = {
          'exactCompleteUnicodeAndBytes': true,
          'aggregateExactScope': true,
          'cloneStagedWithoutMutation': true,
          'relatedBrowseReviewed': true,
          'sourceRetainedUnchanged': true,
          'nonBrowseDatabaseJobsSubmitted': 0,
          'textUtf8Bytes': 90000,
          'binaryBytes': 90000,
        };
        await dispose(opened);
        await dispose(source);
        await execute(id, 'DROP TABLE package_editor_values');
      });

      await stage(
        '${engine.name}-transactions-cancellation-editing-paging',
        () async {
          final namespace = engine == rpc.Engine.POSTGRESQL
              ? 'public'
              : 'busydata';
          Future<rpc.SessionInfo> transaction(rpc.SessionAction action) async {
            final request = rpc.SessionRequest(
              context: connection.context(),
              sessionId: id,
              action: action,
            );
            request.approvalToken = (await connection.client.reviewSession(
              request,
            )).token;
            return connection.client.session(request);
          }

          Future<void> count(int expected) async {
            final result = await execute(
              id,
              'SELECT COUNT(*) FROM package_rows',
            );
            require(
              (await page(result)).rows.single.values.single.signedInteger ==
                  '$expected',
              'Durable transaction row count differs',
            );
            await dispose(result);
          }

          checkpoint = 'transaction-rollback';
          await transaction(rpc.SessionAction.BEGIN);
          await execute(
            id,
            "INSERT INTO package_rows VALUES(4,7,'rolled back')",
          );
          final rollback = await transaction(rpc.SessionAction.ROLLBACK);
          require(
            rollback.commandAcknowledged,
            'Rollback was not acknowledged',
          );
          await transaction(rpc.SessionAction.AUTO_COMMIT_ON);
          await count(3);
          checkpoint = 'transaction-commit';
          await transaction(rpc.SessionAction.BEGIN);
          await execute(id, "INSERT INTO package_rows VALUES(4,7,'committed')");
          final commit = await transaction(rpc.SessionAction.COMMIT);
          require(commit.commandAcknowledged, 'Commit was not acknowledged');
          await transaction(rpc.SessionAction.AUTO_COMMIT_ON);
          await count(4);
          await execute(id, 'DELETE FROM package_rows WHERE id=4');

          checkpoint = 'queued-running-cancellation';
          final running = await submit(
            id,
            engine == rpc.Engine.POSTGRESQL
                ? 'SELECT pg_sleep(30)'
                : 'SELECT SLEEP(30)',
          );
          final queued = await submit(id, 'SELECT 47');
          final cancelClock = Stopwatch()..start();
          await connection.client.cancel(
            rpc.JobRequest(context: connection.context(), jobId: queued.jobId),
          );
          final cancelledQueued = await finished(queued.jobId);
          require(
            cancelledQueued.state == rpc.JobState.CANCELLED &&
                cancelClock.elapsedMilliseconds < 5000,
            'Queued cancellation did not promptly complete',
          );
          final live = (await connection.client.jobs(
            rpc.JobRequest(context: connection.context(), jobId: running.jobId),
          )).jobs.single;
          require(
            !terminal(live.state),
            'Queued cancellation affected the running query',
          );
          await connection.client.cancel(
            rpc.JobRequest(context: connection.context(), jobId: running.jobId),
          );
          final cancelledRunning = await finished(running.jobId);
          require(
            cancelledRunning.state == rpc.JobState.CANCELLED ||
                cancelledRunning.state == rpc.JobState.INTERRUPTED,
            'Running query did not stop through database cancellation',
          );
          final healthy = await execute(id, 'SELECT 47');
          require(
            (await page(healthy)).rows.single.values.single.signedInteger ==
                '47',
            'Cancelled session did not retain usable execution',
          );
          await dispose(healthy);

          checkpoint = 'reviewed-edit';
          await connection.client.explore(
            rpc.ExploreRequest(
              context: connection.context(),
              sessionId: id,
              kind: rpc.ObjectKind.TABLE,
              catalog: 'busydata',
              schema: namespace,
              table: 'package_rows',
              refresh: true,
              introspectionLevel: 2,
              refreshMode: 'FRAGMENT',
              limit: 100,
            ),
          );
          final source = await execute(
            id,
            'SELECT id,n,t FROM $namespace.package_rows ORDER BY id',
          );
          final plan = await connection.client.previewChanges(
            rpc.ChangeRequest(
              context: connection.context(),
              sessionId: id,
              schema: namespace,
              table: 'package_rows',
              resultId: source.results.single.resultId,
              changes: [
                rpc.StagedChange(
                  kind: rpc.ChangeKind.UPDATE,
                  sourceRow: Int64.ZERO,
                  values: ([MapEntry(3, rpc.Value(text: 'edited 漢😀'))]).map(
                    (entry) => MapEntry(
                      entry.key,
                      assignments.assignmentOf(entry.value),
                    ),
                  ),
                ),
              ],
            ),
          );
          await wait(
            (await connection.client.applyChanges(
              rpc.ApplyRequest(
                context: connection.context(),
                sessionId: id,
                executionId: const Uuid().v4(),
                planId: plan.planId,
              ),
            )).jobId,
          );
          final changed = await execute(
            id,
            'SELECT t FROM package_rows WHERE id=1',
          );
          require(
            (await page(changed)).rows.single.values.single.text ==
                'edited 漢😀',
            'Reviewed edit did not change the actual selected row',
          );
          await dispose(changed);
          await dispose(source);
          await execute(id, "UPDATE package_rows SET t='漢😀' WHERE id=1");

          checkpoint = 'byte-limited-paging';
          final wide = await execute(
            id,
            "WITH RECURSIVE numbers(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM numbers WHERE n<300) SELECT n,REPEAT('x',4096) AS payload FROM numbers ORDER BY n",
          );
          var offset = 0;
          while (offset < 300) {
            final batch = await connection.client.resultPage(
              rpc.PageRequest(
                context: connection.context(),
                resultId: wide.results.single.resultId,
                offset: Int64(offset),
                limit: 200,
                maxBytes: 256 * 1024,
              ),
            );
            require(
              batch.firstOffset == Int64(offset) &&
                  batch.rows.isNotEmpty &&
                  batch.nextOffset > Int64(offset),
              'Byte-limited page made no progress',
            );
            require(
              batch.rows.length < 200,
              'Page byte budget did not limit the requested row count',
            );
            for (var index = 0; index < batch.rows.length; index++) {
              require(
                batch.rows[index].values[0].signedInteger ==
                        '${offset + index + 1}' &&
                    batch.rows[index].values[1].text == 'x' * 4096,
                'Byte-limited paging returned different cells',
              );
            }
            offset = batch.nextOffset.toInt();
          }
          require(offset == 300, 'Paging omitted rows');
          await dispose(wide);
          report['${engine.name}-interactiveAcceptance'] = {
            'transactionCommitRollback': true,
            'queuedRunningCancellation': true,
            'reviewedDurableEdit': true,
            'verifiedPagedRows': offset,
          };
        },
      );
      var selectedExport = '', selectedImport = '';
      await stage('${engine.name}-native-export-picker', () async {
        selectedExport = await picker(
          'save',
          '${root.path}/${engine.name} result 漢.csv',
        );
      });
      await stage('${engine.name}-transfers', () async {
        final csv = selectedExport;
        require(csv.isNotEmpty, 'A native export destination was not selected');
        checkpoint = 'direct-export';
        final exported = await tool(
          rpc.ToolRequest(
            sessionId: id,
            kind: rpc.ToolKind.EXPORT_QUERY,
            sql: 'SELECT id,n,t FROM package_rows ORDER BY id',
            path: csv,
            format: 'csv',
            delimiter: ',',
            nullMarker: r'\N',
            outputLimitBytes: Int64(1048576),
          ),
        );
        require(
          await File(csv).length() > 0 && exported.progressRows == Int64(3),
          'Streaming export file is incomplete',
        );
        await stage('${engine.name}-native-import-picker', () async {
          selectedImport = await picker('open', csv);
        });
        require(
          selectedImport.isNotEmpty,
          'A native import source was not selected',
        );
        await execute(
          id,
          'CREATE TABLE imported_rows(id INTEGER PRIMARY KEY,n DECIMAL(38,9),t VARCHAR(100))',
        );
        final request = rpc.ToolRequest(
          context: connection.context(),
          sessionId: id,
          kind: rpc.ToolKind.IMPORT_CSV,
          schema: engine == rpc.Engine.POSTGRESQL ? 'public' : 'busydata',
          table: 'imported_rows',
          path: selectedImport,
          format: 'csv',
          delimiter: ',',
          nullMarker: r'\N',
          encoding: 'UTF-8',
          columns: ['id', 'n', 't'],
          batchRows: 2,
          importPolicy: rpc.ImportPolicy.ATOMIC_IMPORT,
        );
        final preview = await connection.client.previewImportAdmission(request);
        require(
          preview.rows.length == 3 && preview.rows[1].values[1].hasNullValue(),
          'Preview NULL differs from import',
        );
        request.sourceSha256 = preview.sourceSha256;
        checkpoint = 'import';
        final imported = await tool(request);
        require(imported.progressRows == Int64(3), 'Import progress differs');
        checkpoint = 'compare-durable-rows';
        final result = await execute(
          id,
          'SELECT id,n,t FROM imported_rows ORDER BY id',
        );
        final expected = await execute(
          id,
          'SELECT id,n,t FROM package_rows ORDER BY id',
        );
        require(
          jsonEncode(
                (await page(result)).rows.map((r) => r.toProto3Json()).toList(),
              ) ==
              jsonEncode(
                (await page(
                  expected,
                )).rows.map((r) => r.toProto3Json()).toList(),
              ),
          'Imported exact values differ',
        );
        await dispose(result);
        await dispose(expected);
      });
      await stage('${engine.name}-large-streaming-transfer', () async {
        checkpoint = 'large-direct-export';
        const rows = 512, payloadBytes = 65536;
        final csv = '${root.path}/${engine.name} confined large 漢.csv';
        final exported = await tool(
          rpc.ToolRequest(
            sessionId: id,
            kind: rpc.ToolKind.EXPORT_QUERY,
            sql:
                "WITH RECURSIVE numbers(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM numbers WHERE n<$rows) SELECT n AS id,REPEAT('x',$payloadBytes) AS t FROM numbers ORDER BY n",
            path: csv,
            format: 'csv',
            delimiter: ',',
            nullMarker: r'\N',
            outputLimitBytes: Int64(64 * 1024 * 1024),
          ),
        );
        require(
          exported.progressRows == Int64(rows) &&
              await File(csv).length() > rows * payloadBytes,
          'Confined direct export did not produce the complete streamed fixture',
        );
        await execute(
          id,
          'CREATE TABLE installed_large_rows(id INTEGER PRIMARY KEY,t ${engine == rpc.Engine.POSTGRESQL ? 'TEXT' : 'LONGTEXT'})',
        );
        final request = rpc.ToolRequest(
          context: connection.context(),
          sessionId: id,
          kind: rpc.ToolKind.IMPORT_CSV,
          schema: engine == rpc.Engine.POSTGRESQL ? 'public' : 'busydata',
          table: 'installed_large_rows',
          path: csv,
          format: 'csv',
          delimiter: ',',
          nullMarker: r'\N',
          encoding: 'UTF-8',
          columns: ['id', 't'],
          batchRows: 32,
          importPolicy: rpc.ImportPolicy.ATOMIC_IMPORT,
        );
        checkpoint = 'large-source-preview';
        request.sourceSha256 = (await connection.client.previewImportAdmission(
          request,
        )).sourceSha256;
        checkpoint = 'large-import';
        final imported = await tool(request);
        require(
          imported.progressRows == Int64(rows),
          'Confined large import omitted rows',
        );
        checkpoint = 'large-durable-checksum';
        final checked = await execute(
          id,
          "SELECT COUNT(*),MIN(id),MAX(id),SUM(id),SUM(CASE WHEN LENGTH(t)=$payloadBytes AND MD5(t)=MD5(REPEAT('x',$payloadBytes)) THEN 1 ELSE 0 END) FROM installed_large_rows",
        );
        final values = (await page(checked)).rows.single.values;
        String exact(rpc.Value value) =>
            value.hasSignedInteger() ? value.signedInteger : value.decimal;
        require(
          values.map(exact).join(',') == '512,1,512,131328,512',
          'Confined large import durable IDs/lengths/checksums differ',
        );
        await dispose(checked);
        report['${engine.name}-largeTransfer'] = {
          'rows': rows,
          'payloadBytesPerRow': payloadBytes,
          'outputBytes': await File(csv).length(),
          'outputSha256': (await sha256.bind(File(csv).openRead()).first)
              .toString(),
          'allDurableValuesVerified': true,
        };
      });
      await stage(
        '${engine.name}-ssh-password-key-agent-native-backup',
        () async {
          final sshProfile = profile.deepCopy()
            ..ssh = rpc.Ssh(
              enabled: true,
              host: '127.0.0.1',
              port: fixture['sshPort'] as int,
              user: 'selected',
            );
          checkpoint = 'host-review';
          final review = await connection.client.reviewSshHost(
            rpc.SshTrustRequest(
              context: connection.context(),
              profile: sshProfile,
            ),
          );
          require(
            !review.known && !review.changed,
            'New host key review state is incorrect',
          );
          checkpoint = 'host-accept';
          final accepted = await connection.client.acceptSshHost(
            rpc.SshTrustRequest(
              context: connection.context(),
              profile: sshProfile,
              approvalToken: review.approvalToken,
              algorithm: review.algorithm,
              fingerprint: review.fingerprint,
            ),
          );
          sshProfile.ssh.trustRef = accepted.trustRef;
          reviewedSsh = sshProfile.deepCopy();
          for (final authentication in ['password', 'key', 'agent']) {
            checkpoint = '$authentication-connect';
            final selected = sshProfile.deepCopy();
            if (authentication == 'key') {
              selected.ssh.privateKey = selectedKey;
            }
            if (authentication == 'agent') {
              selected.ssh.agent = true;
              selected.ssh.agentSocket = '${root.path}/agent.sock';
              selected.ssh.agentKeyFingerprint =
                  fixture['selectedFingerprint'] as String;
            }
            final opened = await connection.client.openSession(
              rpc.OpenRequest(
                context: connection.context(),
                profile: selected,
                password: await databasePassword(),
                sshPassword: authentication == 'password'
                    ? 'installed-ssh-fixture'
                    : '',
              ),
            );
            final tunnelId = opened.sessionId;
            await connection.client.session(
              rpc.SessionRequest(
                context: connection.context(),
                sessionId: tunnelId,
                action: rpc.SessionAction.ADOPT_SESSION,
              ),
            );
            try {
              final query = await execute(
                tunnelId,
                'SELECT id,n,t FROM package_rows ORDER BY id',
              );
              require(
                (await page(query)).rows.first.values[2].text == '漢😀',
                'Tunneled certificate context differs',
              );
              await dispose(query);
              if (authentication == 'agent') {
                checkpoint = 'packaged-dump';
                final dump = await picker(
                  'save',
                  '${root.path}/${engine.name} backup 漢.sql',
                );
                await tool(
                  rpc.ToolRequest(
                    sessionId: tunnelId,
                    kind: rpc.ToolKind.DUMP,
                    path: dump,
                    nativeToolPath: packagedDatabaseTool(
                      engine,
                      restore: false,
                    )!,
                  ),
                );
                checkpoint = 'prepare-restore-target';
                await execute(
                  id,
                  'DROP TABLE IF EXISTS package_editor_values; '
                  'DROP TABLE package_rows; DROP TABLE imported_rows; '
                  'DROP TABLE installed_large_rows;',
                );
                checkpoint = 'packaged-restore';
                final selectedRestore = await picker('open', dump);
                await tool(
                  rpc.ToolRequest(
                    sessionId: tunnelId,
                    kind: rpc.ToolKind.RESTORE,
                    path: selectedRestore,
                    nativeToolPath: packagedDatabaseTool(
                      engine,
                      restore: true,
                    )!,
                  ),
                );
                final restored = await execute(
                  id,
                  'SELECT id,n,t FROM package_rows ORDER BY id',
                );
                require(
                  (await page(restored)).rows.first.values[1].decimal ==
                      '12345678901234567890.123456789',
                  'Restored schema/data differ',
                );
                await dispose(restored);
                final restoredLarge = await execute(
                  id,
                  "SELECT COUNT(*),SUM(CASE WHEN LENGTH(t)=65536 AND MD5(t)=MD5(REPEAT('x',65536)) THEN 1 ELSE 0 END) FROM installed_large_rows",
                );
                require(
                  (await page(restoredLarge)).rows.single.values.every(
                    (value) =>
                        (value.hasSignedInteger()
                            ? value.signedInteger
                            : value.decimal) ==
                        '512',
                  ),
                  'Native restore omitted or changed large-transfer rows',
                );
                await dispose(restoredLarge);
              }
            } finally {
              await disconnect(tunnelId);
            }
          }
        },
      );
      await stage('${engine.name}-retained-after-disconnect', () async {
        final result = await execute(
          id,
          'SELECT id,n,t FROM package_rows ORDER BY id',
        );
        await disconnect(id);
        session = null;
        final retainedPath = '${root.path}/${engine.name} retained.json';
        await tool(
          rpc.ToolRequest(
            sessionId: id,
            kind: rpc.ToolKind.EXPORT_RESULT,
            resultId: result.results.single.resultId,
            path: retainedPath,
            format: 'json',
            outputLimitBytes: Int64(1048576),
          ),
        );
        require(
          (await File(retainedPath).readAsString()).contains('漢😀'),
          'Export after source disconnect failed',
        );
        await dispose(result);
      });
      if (session != null) await disconnect(session!);
    }
    await stage('changed-ssh-key-review', () async {
      final profile = reviewedSsh;
      require(profile != null, 'No reviewed SSH session is available');
      final pinned = profile!;
      await File(
        '${root.path}/rotate-request',
      ).writeAsString('rotate-host-key\n');
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!await File('${root.path}/host-key-rotated').exists()) {
        require(
          DateTime.now().isBefore(deadline),
          'Fixture key rotation failed',
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      var rejected = false;
      try {
        final unexpected = await connection.client.openSession(
          rpc.OpenRequest(
            context: connection.context(),
            profile: pinned,
            password: await databasePassword(),
            sshPassword: 'installed-ssh-fixture',
          ),
        );
        await disconnect(unexpected.sessionId);
      } catch (_) {
        rejected = true;
      }
      require(rejected, 'Changed SSH host key was accepted without review');
      final review = await connection.client.reviewSshHost(
        rpc.SshTrustRequest(context: connection.context(), profile: pinned),
      );
      require(
        review.changed &&
            !review.known &&
            review.previousFingerprint.isNotEmpty,
        'Changed host key was not distinguished from new/known trust',
      );
      rejected = false;
      try {
        await connection.client.acceptSshHost(
          rpc.SshTrustRequest(
            context: connection.context(),
            profile: pinned,
            approvalToken: review.approvalToken,
            algorithm: review.algorithm,
            fingerprint: review.fingerprint,
          ),
        );
      } catch (_) {
        rejected = true;
      }
      require(rejected, 'Changed key replacement was not explicitly required');
      final fresh = await connection.client.reviewSshHost(
        rpc.SshTrustRequest(context: connection.context(), profile: pinned),
      );
      final accepted = await connection.client.acceptSshHost(
        rpc.SshTrustRequest(
          context: connection.context(),
          profile: pinned,
          approvalToken: fresh.approvalToken,
          algorithm: fresh.algorithm,
          fingerprint: fresh.fingerprint,
          replaceChangedKey: true,
        ),
      );
      pinned.ssh.trustRef = accepted.trustRef;
      final opened = await connection.client.openSession(
        rpc.OpenRequest(
          context: connection.context(),
          profile: pinned,
          password: await databasePassword(),
          sshPassword: 'installed-ssh-fixture',
        ),
      );
      await connection.client.session(
        rpc.SessionRequest(
          context: connection.context(),
          sessionId: opened.sessionId,
          action: rpc.SessionAction.ADOPT_SESSION,
        ),
      );
      try {
        final query = await execute(opened.sessionId, 'SELECT 7');
        require(
          (await page(query)).rows.single.values.single.signedInteger == '7',
          'Reviewed replacement connection failed',
        );
        await dispose(query);
      } finally {
        await disconnect(opened.sessionId);
      }
    });
    await stage('backend-lifecycle', () async {
      await connection.close();
      require(
        await connection.process.exitCode == 0,
        'Owned child did not shut down cleanly',
      );
      require(
        !await Directory('/proc/$processId').exists(),
        'Owned child remained alive',
      );
    });
    code = stages.values.every((entry) => (entry as Map)['passed'] == true)
        ? 0
        : 1;
    report['fullInstalledDatabaseFileSecretSshAcceptance'] = code == 0;
  } catch (error) {
    report['failureType'] = error.runtimeType.toString();
  } finally {
    try {
      await model?.backend?.close();
    } catch (error) {
      code = 1;
      report['cleanupFailureType'] = error.runtimeType.toString();
    }
    model?.dispose();
    report['exitCode'] = code;
    if (output != null) {
      await atomicWrite(output, utf8.encode(jsonEncode(report)));
      final digest = sha256.convert(await output.readAsBytes()).toString();
      stdout.writeln(
        jsonEncode({'report': output.path, 'sha256': digest, 'exitCode': code}),
      );
    }
    exit(code);
  }
}
