import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  for (final change in [
    'endpoint',
    'production',
    'readonly',
    'rename',
    'default database',
    'unchanged',
  ]) {
    testWidgets('category console checks its physical source after $change', (
      tester,
    ) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('category-console-source-'),
      ))!;
      final backend = TestBackend();
      final original = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
        host: 'original.example',
        database: 'initial_default',
      );
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..backend = backend
        ..draftRecovery = false
        ..profiles.add(original.deepCopy())
        ..newDocument(text: 'SELECT preserved');
      final originalDocument = model.document;
      model.explorerSessions['p'] = 'metadata';
      model.sessions['metadata'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'metadata',
        profile: original,
        currentCatalog: 'initial_default',
        currentSchema: 'public',
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
      final context = WorkbenchCommandContext(
        profileId: 'p',
        sessionId: 'metadata',
        metadataInstance: backend.instanceId,
        metadataSources: const {
          'p': (sessionId: 'metadata', contextRevision: 0, sessionRevision: 0),
        },
        creationScope: const DatabaseCreationScope(
          profileId: 'p',
          catalog: 'target_database',
          schema: 'public',
        ),
      );
      final saved = original.deepCopy();
      switch (change) {
        case 'endpoint':
          saved.host = 'replacement.example';
        case 'production':
          saved.environment = rpc.Environment.PRODUCTION;
        case 'readonly':
          saved.readOnly = true;
        case 'rename':
          saved.name = 'Renamed source';
        case 'default database':
          saved.database = 'future_default';
      }
      model.profiles[0] = saved;
      final operation = model.commands!.invoke('file.new', context);
      if (['endpoint', 'production', 'readonly'].contains(change)) {
        await expectLater(operation, throwsStateError);
        expect(model.documents, [originalDocument]);
      } else {
        await operation;
        expect(model.documents, hasLength(2));
        expect(model.document.profileId, 'p');
        expect(model.document.connectionCatalog, 'target_database');
        expect(model.document.connectionSchema, 'public');
        expect(model.document.sessionId, isNull);
        expect(model.activeOwner.evidenceProfile, saved);
        expect(model.activeOwner.evidenceProfile, isNot(same(saved)));
      }
      expect(originalDocument.editor.text, 'SELECT preserved');
      expect(backend.client.opened, isEmpty);
      expect(backend.client.reviews, isEmpty);
      expect(backend.client.executions, isEmpty);
    });
  }
}
