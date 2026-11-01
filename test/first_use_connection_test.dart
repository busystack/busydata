import 'dart:io';
import 'profile_credentials_test.dart' show Secrets;
import 'package:busydata/src/backend/generated/busydata.pb.dart' hide Row;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/browse_selection_fixture.dart';
import 'support/native_window.dart';

void main() {
  testWidgets(
    'virtual Run acquires an exact independent target and preserves mutation review cancellation',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('virtual-first-run-'),
      ))!;
      final backend = TestBackend();
      final profile = Profile(
        id: 'p',
        name: 'Production',
        host: 'localhost',
        user: 'postgres',
        engine: Engine.POSTGRESQL,
        environment: Environment.PRODUCTION,
      );
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT preserved');
      final original = model.document;
      await model.saveVirtualView(
        VirtualViewDefinition(
          id: 'local',
          name: 'Named mutation',
          scope: const DatabaseCreationScope(
            profileId: 'p',
            catalog: 'second',
            schema: 'audit',
          ),
          sql: 'DELETE FROM audit.customers;',
        ),
      );
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'virtual-owned',
        profile: request.profile,
        currentCatalog: request.catalog,
        currentSchema: request.schema,
        transaction: TransactionState.IDLE,
      );
      backend.client.sessionCommand = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: request.sessionId,
        profile: profile,
        currentCatalog: 'second',
        currentSchema: 'audit',
        transaction: TransactionState.IDLE,
      );
      backend.client.sqlReview = (_) async => Approval(
        token: 'review',
        risks: ['Production mutation requires review'],
        statements: ['DELETE FROM audit.customers;'],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final operation = model.commands!.invoke(
        'virtual.run',
        WorkbenchCommandContext(
          virtualViewId: 'local',
          profileId: 'p',
          virtualView: model.virtualViews['local'],
          virtualSource: profile.deepCopy(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.bySemanticsLabel('Password'),
          matching: find.byType(EditableText),
        ),
        '',
      );
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Production mutation requires review'),
        findsOneWidget,
      );
      expect(backend.client.reviews.single.sql, 'DELETE FROM audit.customers;');
      expect(backend.client.reviews.single.sessionId, 'virtual-owned');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await operation;
      expect(backend.client.opened.single.catalog, 'second');
      expect(backend.client.opened.single.schema, 'audit');
      expect(backend.client.executions, isEmpty);
      expect(original.editor.text, 'SELECT preserved');
      expect(original.sessionId, isNull);
      expect(model.document.connectionCatalog, 'second');
      expect(model.document.connectionSchema, 'audit');
    },
  );
  testWidgets(
    'explicit restored table-hint Open Data connects once and prepares exact browse authority',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('first-table-'),
      ))!;
      final backend = TestBackend();
      final profile = Profile(
        id: 'p',
        name: 'Local',
        engine: Engine.POSTGRESQL,
      );
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument();
      final scratch = model.document;
      model.explorerSessions['p'] = 'explorer';
      model.sessions['explorer'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'explorer',
        profile: profile,
        currentCatalog: 'db',
      );
      model.connectionOwner(profile)
        ..sessionId = 'explorer'
        ..evidenceProfile = profile.deepCopy();
      backend.client.metadataAction = (request) async => SchemaObjects(
        complete: true,
        objects: switch (request.kind) {
          ObjectKind.SCHEMA => [
            SchemaObject(kind: ObjectKind.SCHEMA, name: 'public'),
          ],
          ObjectKind.TABLE => [
            SchemaObject(
              kind: ObjectKind.TABLE,
              catalog: 'db',
              schema: 'public',
              name: 'fixture',
            ),
          ],
          _ => [],
        },
      );
      PreparedBrowseFixture(
        relation: SchemaObject(
          kind: ObjectKind.TABLE,
          name: 'fixture',
          catalog: 'db',
          schema: 'public',
          stableIdentity: 'prepared-first-table',
        ),
        columns: [
          SchemaObject(
            kind: ObjectKind.COLUMN,
            name: 'id',
            table: 'fixture',
            catalog: 'db',
            schema: 'public',
            stableIdentity: 'prepared-first-id',
            parentIdentity: 'prepared-first-table',
          ),
        ],
      ).install(model, backend);
      final restored = model.openTask(
        WorkbenchDocumentKind.table,
        'fixture',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          name: 'fixture',
          kind: ObjectKind.TABLE,
        ),
      );
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'table-owned',
        profile: request.profile,
        transaction: TransactionState.IDLE,
      );
      backend.client.sessionCommand = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: request.sessionId,
        profile: profile,
        transaction: TransactionState.IDLE,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchView(
              model: metadataFixture(model),
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      final operation = model.commands!.invoke(
        'object.data',
        WorkbenchCommandContext(
          owner: restored,
          object: restored.object,
          profileId: 'p',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect · Local'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.bySemanticsLabel('Password'),
          matching: find.byType(EditableText),
        ),
        ' supplied ',
      );
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();
      await operation;
      expect(backend.client.opened, hasLength(1));
      expect(backend.client.browseRequests, hasLength(1));
      final browse = backend.client.browseRequests.single;
      expect(browse.sessionId, 'table-owned');
      expect(browse.catalog, 'db');
      expect(browse.schema, 'public');
      expect(browse.table, 'fixture');
      expect(browse.metadataObjectIdentity, 'prepared-first-table');
      expect(browse.metadataSnapshotRevision.toInt(), 11);
      expect(model.activeOwner.kind, WorkbenchDocumentKind.table);
      expect(model.documents.single, same(scratch));
      expect(scratch.sessionId, isNull);
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
  testWidgets('first Run acquires its independent session and submits once', (
    tester,
  ) async {
    installNativeWindowFixture(tester);
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('first-run-'),
    ))!;
    final backend = TestBackend();
    final profile = Profile(
      id: 'p',
      name: 'Local',
      host: 'localhost',
      port: 5432,
      user: 'postgres',
      engine: Engine.POSTGRESQL,
    );
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = backend
      ..profiles.add(profile)
      ..newDocument(text: 'SELECT 42;');
    final document = model.document;
    model.bindUnconnectedProfile(model.activeOwner, profile.id);
    backend.client.opening = (request) async => SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'independent',
      profile: request.profile,
      transaction: TransactionState.IDLE,
    );
    backend.client.sessionCommand = (request) async => SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: request.sessionId,
      profile: profile,
      transaction: TransactionState.IDLE,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchView(model: model, controls: const LinuxControls()),
      ),
    );
    expect(
      model.commands!.command('sql.run').disabledReason!(model.commandContext),
      isNull,
    );
    final operation = model.commands!.invoke('sql.run', model.commandContext);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.bySemanticsLabel('Password'),
        matching: find.byType(EditableText),
      ),
      '',
    );
    await tester.tap(find.text('Connect').last);
    await tester.pumpAndSettle();
    await operation;
    expect(backend.client.opened, hasLength(1));
    expect(backend.client.opened.single.password, '');
    expect(document.sessionId, 'independent');
    expect(backend.client.executions, hasLength(1));
    expect(backend.client.executions.single.sql, 'SELECT 42;');
    expect(backend.client.executions.single.documentId, document.id);
    expect(backend.client.executions.single.sessionId, 'independent');
    model.track(
      JobInfo(
        jobId: 'lost',
        executionId: 'uncertain',
        state: JobState.UNKNOWN_OUTCOME,
      ),
      documentId: document.id,
    );
    document.sessionId = null;
    expect(
      model.commands!.command('sql.run').disabledReason!(model.commandContext),
      contains('Outcome unknown'),
    );
    await expectLater(
      model.commands!.invoke('sql.run', model.commandContext),
      throwsStateError,
    );
    expect(backend.client.opened, hasLength(1));
    expect(backend.client.executions, hasLength(1));
  });
  for (final method in [
    'password',
    'key',
    'agent',
    'tls-key',
    'tls-stored',
    'tls-disabled',
  ]) {
    testWidgets(
      'first Run with stored database password supplies only selected $method credentials',
      (tester) async {
        installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('first-run-ssh-'),
        ))!;
        final backend = TestBackend();
        final secrets = Secrets()
          ..values['tls-binding'] = 'stored TLS key secret';
        final profile = Profile(
          id: 'p',
          name: 'Selected SSH',
          credentialRef: 'working',
          tls: Tls(
            mode: method == 'tls-disabled'
                ? TlsMode.DISABLED
                : TlsMode.VERIFY_FULL,
            clientKey: method.startsWith('tls-') ? '/selected/tls-key.pem' : '',
            keyCredentialRef: method == 'tls-stored' ? 'tls-binding' : '',
          ),
          ssh: Ssh(
            enabled: ['password', 'key', 'agent'].contains(method),
            privateKey: method == 'key' ? '/selected/key' : '',
            agent: method == 'agent',
            agentSocket: method == 'agent' ? '/selected/socket' : '',
            agentKeyFingerprint: method == 'agent' ? 'selected' : '',
          ),
        );
        final model = WorkbenchModel(root, secrets: secrets)
          ..draftRecovery = false
          ..backend = backend
          ..profiles.add(profile)
          ..newDocument(text: 'SELECT 42;');
        model.bindUnconnectedProfile(model.activeOwner, profile.id);
        backend.client.opening = (r) async => SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'owned',
          profile: r.profile,
          transaction: TransactionState.IDLE,
        );
        backend.client.sessionCommand = (r) async => SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: r.sessionId,
          profile: profile,
          transaction: TransactionState.IDLE,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.pumpWidget(
          MaterialApp(
            home: WorkbenchView(model: model, controls: const LinuxControls()),
          ),
        );
        final action = model.commands!.invoke('sql.run', model.commandContext);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.bySemanticsLabel('Password'),
            matching: find.byType(EditableText),
          ),
          findsNothing,
        );
        if (!['agent', 'tls-stored', 'tls-disabled'].contains(method)) {
          final label = method == 'tls-key'
              ? 'Client key password'
              : method == 'key'
              ? 'Private-key passphrase'
              : 'SSH password';
          final fields = find
              .byType(EditableText)
              .evaluate()
              .map((e) => e.widget as EditableText)
              .where((w) => w.obscureText)
              .toList();
          expect(
            fields,
            hasLength(1),
            reason: 'Only the selected missing secret is requested: $label',
          );
          fields.single.controller.text = ' secret with spaces ';
          await tester.tap(find.text('Connect').last);
          await tester.pumpAndSettle();
        }
        await action;
        expect(backend.client.opened, hasLength(1));
        expect(backend.client.executions, hasLength(1));
        final request = backend.client.opened.single;
        expect(request.password, 'working-secret');
        expect(
          request.sshPassword,
          method == 'password' ? ' secret with spaces ' : '',
        );
        expect(
          request.keyPassphrase,
          method == 'key' ? ' secret with spaces ' : '',
        );
        expect(
          request.tlsKeyPassword,
          method == 'tls-key'
              ? ' secret with spaces '
              : method == 'tls-stored'
              ? 'stored TLS key secret'
              : '',
        );
        expect(secrets.deleted, isEmpty);
      },
    );
  }
  testWidgets(
    'cancel and rebound owner fence the original Run; repeated Run cannot duplicate acquisition',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('first-run-fence-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..profiles.addAll([
          Profile(id: 'p', name: 'First'),
          Profile(id: 'q', name: 'Second'),
        ])
        ..newDocument(text: 'SELECT 42;');
      model.bindUnconnectedProfile(model.activeOwner, 'p');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final first = model.commands!.invoke('sql.run', model.commandContext);
      await tester.pumpAndSettle();
      await expectLater(
        model.commands!.invoke('sql.run', model.commandContext),
        throwsStateError,
      );
      expect(find.text('Connect · First'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await first;
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT 42;');
      final second = model.commands!.invoke('sql.run', model.commandContext);
      await tester.pumpAndSettle();
      model.bindUnconnectedProfile(model.activeOwner, 'q');
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();
      await second;
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(model.document.profileId, 'q');
      model.document.connectionCatalog = 'original';
      final third = model.commands!.invoke('sql.run', model.commandContext);
      await tester.pumpAndSettle();
      model.document.connectionCatalog = 'changed during authentication';
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();
      await third;
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
}
