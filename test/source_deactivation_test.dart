import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final confirm in [false, true]) {
    testWidgets(
      'source deactivation reviews all exact clients and preserves another source; confirm $confirm',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('source-deactivate-'),
        ))!;
        final backend = TestBackend();
        final source = Profile(
          id: 'selected-source',
          name: 'Selected source',
          engine: Engine.POSTGRESQL,
        );
        final other = Profile(
          id: 'other-source',
          name: 'Other source',
          engine: Engine.POSTGRESQL,
        );
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..profiles.addAll([source, other])
          ..newDocument(text: 'SELECT original_draft');
        final original = model.document
          ..profileId = source.id
          ..sessionId = 'query';
        model.newDocument(text: 'SELECT other_draft');
        final unrelated = model.document
          ..profileId = other.id
          ..sessionId = 'other';
        model.connectionOwner(source).sessionId = 'metadata';
        model.explorerSessions[source.id] = 'metadata';
        for (final id in ['query', 'metadata', 'other']) {
          model.sessions[id] = SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: id,
            profile: id == 'other' ? other : source,
            currentCatalog: id == 'query'
                ? 'second_database'
                : 'first_database',
            currentSchema: 'public',
            transaction: TransactionState.IDLE,
          );
        }
        backend.client.sessionCommand = (request) async => SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: request.sessionId,
          profile: model.sessions[request.sessionId]!.profile,
          transaction: TransactionState.DISCONNECTED,
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
        const target = WorkbenchCommandContext(
          profileId: 'selected-source',
          sessionId: 'metadata',
        );
        final action = model.commands!.command('connection.deactivate');
        expect(action.disabledReason!(target), isNull);
        model.sessions['query']!.transaction = TransactionState.ACTIVE;
        expect(
          action.disabledReason!(target),
          contains(RegExp('transaction', caseSensitive: false)),
        );
        model.sessions['query']!.transaction =
            TransactionState.UNKNOWN_TRANSACTION;
        expect(action.disabledReason!(target), contains('Outcome unknown'));
        model.sessions['query']!.transaction = TransactionState.IDLE;
        final operation = model.commands!.invoke(
          'connection.deactivate',
          target,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('second_database'), findsOneWidget);
        expect(backend.client.sessionCommands, isEmpty);
        await tester.tap(
          find.text(confirm ? 'Deactivate source' : 'Cancel').last,
        );
        await tester.pumpAndSettle();
        await operation;
        expect(
          backend.client.sessionCommands.map((r) => r.sessionId).toSet(),
          confirm ? {'query', 'metadata'} : <String>{},
        );
        expect(unrelated.sessionId, 'other');
        expect(model.sessions.containsKey('other'), isTrue);
        expect(original.sessionId, confirm ? null : 'query');
        expect(original.editor.text, 'SELECT original_draft');
        expect(unrelated.editor.text, 'SELECT other_draft');
        expect(model.profiles.length, 2);
        expect(backend.client.executions, isEmpty);
      },
    );
  }
}
