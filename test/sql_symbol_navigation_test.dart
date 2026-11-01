import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'support/fake_backend.dart';

// Fixed opaque backend-projection fixtures; never derived from UI names.
const _selectedRelationIdentity =
    'a40b4fc453ed19a1f0d49e1d40feb25655d512d387a14d13baecf3386fb29277';
const _wrongScopeRelationIdentity =
    'f6a691b59dcd504a23e32dc20c91e0a579b44aa2995e18a3116cc5337d52d41d';
const _lowerCaseRelationIdentity =
    '52e718b782be830a10b4ea5a023941fa95328005c56128d609df421287336168';
const _mixedCaseRelationIdentity =
    '263b6075344c7aebb067439a92c8512c22647e8b1f429336520b20483a4a891f';

void main() {
  for (final wrongScope in [false, true]) {
    testWidgets(
      'SQL reveal verifies physical database and profile without executing: wrong scope $wrongScope',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('sql-reveal-'),
        ))!;
        final backend = TestBackend();
        final profile = Profile(
          id: 'source',
          name: 'Source',
          engine: Engine.POSTGRESQL,
          database: 'saved_default',
        );
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..profiles.add(profile)
          ..newDocument(text: 'SELECT * FROM public.customers');
        final document = model.document;
        document.profileId = profile.id;
        document.sessionId = 'physical';
        document.selectOffsets(
          document.editor.text.indexOf('customers') + 3,
          document.editor.text.indexOf('customers') + 3,
        );
        model.sessions['physical'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'physical',
          profile: profile,
          currentCatalog: 'second',
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
        final operation = model.commands!.invoke(
          'object.reveal',
          model.commandContext,
        );
        final checked = expectLater(
          operation,
          wrongScope ? throwsStateError : completes,
        );
        final index = backend.client.analyses.indexWhere(
          (request) => request.operation == AnalysisOperation.SYMBOL_RESOLUTION,
        );
        expect(index, greaterThanOrEqualTo(0));
        final request = backend.client.analyses[index];
        expect(request.sessionId, 'physical');
        expect(request.sql, document.editor.text);
        backend.client.pendingAnalyses[index].complete(
          Analysis(
            documentId: request.documentId,
            documentVersion: request.documentVersion,
            backendInstance: request.context.instanceId,
            sessionId: request.sessionId,
            contextRevision: request.contextRevision,
            sessionRevision: request.sessionRevision,
            caretUtf16: request.caretUtf16,
            operation: request.operation,
            metadataSnapshotRevision: Int64(7),
            metadataConfigurationRevision: Int64(2),
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            symbol: ResolvedSymbol(
              profileId: profile.id,
              catalog: wrongScope ? 'saved_default' : 'second',
              schema: 'public',
              complete: true,
              availability: 'exact',
              span: Span(
                startUtf16: document.editor.text.indexOf('customers'),
                endUtf16: document.editor.text.length,
              ),
              candidates: [
                SchemaObject(
                  catalog: wrongScope ? 'saved_default' : 'second',
                  schema: 'public',
                  name: 'customers',
                  kind: ObjectKind.TABLE,
                  subtype: ObjectSubtype.ORDINARY_TABLE,
                  stableIdentity: wrongScope
                      ? _wrongScopeRelationIdentity
                      : _selectedRelationIdentity,
                  metadataSnapshotRevision: Int64(7),
                  introspectionLevel: 1,
                  metadataState: 'AVAILABLE',
                ),
              ],
            ),
          ),
        );
        await checked;
        if (wrongScope) {
          expect(model.explorerReveal, isNull);
        } else {
          expect(model.explorerReveal!.catalog, 'second');
          expect(model.explorerReveal!.name, 'customers');
        }
        expect(model.sessions['physical']!.currentCatalog, 'second');
        expect(document.sessionId, 'physical');
        expect(backend.client.executions, isEmpty);
        expect(backend.client.metadataRequests, isEmpty);
        expect(backend.client.schemaToolRequests, isEmpty);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
      },
    );
  }
  for (final choose in [true, false]) {
    testWidgets(
      'uncertain native case requires an explicit scoped choice; choose $choose',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('sql-choice-'),
        ))!;
        final backend = TestBackend();
        final profile = Profile(
          id: 'source',
          name: 'Source',
          engine: Engine.MYSQL,
        );
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..profiles.add(profile)
          ..newDocument(text: 'SELECT * FROM audit.CUSTOMERS');
        final document = model.document;
        document.profileId = profile.id;
        document.sessionId = 'physical';
        document.selectOffsets(
          document.editor.text.length - 2,
          document.editor.text.length - 2,
        );
        model.sessions['physical'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'physical',
          profile: profile,
          currentCatalog: 'first',
          currentSchema: 'first',
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
          'object.reveal',
          model.commandContext,
        );
        final index = backend.client.analyses.indexWhere(
          (r) => r.operation == AnalysisOperation.SYMBOL_RESOLUTION,
        );
        expect(index, greaterThanOrEqualTo(0));
        final request = backend.client.analyses[index];
        backend.client.pendingAnalyses[index].complete(
          Analysis(
            documentId: request.documentId,
            documentVersion: request.documentVersion,
            backendInstance: request.context.instanceId,
            sessionId: request.sessionId,
            contextRevision: request.contextRevision,
            sessionRevision: request.sessionRevision,
            caretUtf16: request.caretUtf16,
            operation: request.operation,
            metadataSnapshotRevision: Int64(7),
            metadataConfigurationRevision: Int64(2),
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            symbol: ResolvedSymbol(
              profileId: profile.id,
              catalog: 'audit',
              schema: 'audit',
              complete: true,
              availability: 'choose-native-case',
              span: Span(
                startUtf16: document.editor.text.indexOf('CUSTOMERS'),
                endUtf16: document.editor.text.length,
              ),
              candidates: [
                for (final candidate in const [
                  ('customers', _lowerCaseRelationIdentity),
                  ('Customers', _mixedCaseRelationIdentity),
                ])
                  SchemaObject(
                    catalog: 'audit',
                    schema: 'audit',
                    name: candidate.$1,
                    kind: ObjectKind.TABLE,
                    subtype: ObjectSubtype.ORDINARY_TABLE,
                    stableIdentity: candidate.$2,
                    metadataSnapshotRevision: Int64(7),
                    introspectionLevel: 1,
                    metadataState: 'AVAILABLE',
                  ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(model.explorerReveal, isNull);
        expect(find.text('Source / audit / Customers'), findsOneWidget);
        await tester.tap(
          find.text(choose ? 'Source / audit / Customers' : 'Cancel').last,
        );
        await tester.pumpAndSettle();
        await operation;
        expect(model.explorerReveal?.name, choose ? 'Customers' : null);
        expect(model.explorerReveal?.catalog, choose ? 'audit' : null);
        expect(model.sessions['physical']!.currentCatalog, 'first');
        expect(document.editor.text, 'SELECT * FROM audit.CUSTOMERS');
        expect(backend.client.executions, isEmpty);
      },
    );
  }
}
