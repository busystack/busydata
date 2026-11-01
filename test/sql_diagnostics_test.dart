import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/sql_diagnostics.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

const source =
    "SELECT '😀';\r\nSELECT name FROM table_a a JOIN table_b b ON a.id=b.id;\r\n";

AcceptedAnalysis diagnostics(WorkbenchModel model, {int count = 1}) {
  final binding = model.analysisBinding(model.document);
  final start = source.indexOf('name');
  final accepted = AcceptedAnalysis(
    binding,
    rpc.Analysis(
      operation: rpc.AnalysisOperation.DIAGNOSTICS,
      documentId: binding.document.id,
      documentVersion: Int64(binding.version),
      backendInstance: binding.instance,
      sessionId: binding.session,
      contextRevision: Int64(binding.contextRevision),
      sessionRevision: Int64(binding.sessionRevision),
      caretUtf16: binding.caret,
      metadataSnapshotRevision: Int64.ONE,
      metadataConfigurationRevision: Int64.ONE,
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      availability: 'available',
      diagnostics: List.generate(
        count,
        (index) => rpc.Diagnostic(
          code: 'binding.ambiguous-column',
          source: 'binder',
          severity: 'error',
          engine: rpc.Engine.POSTGRESQL,
          startUtf16: start,
          endUtf16: start + 4,
          message: 'REMOTE PRIVATE MESSAGE MUST NOT BE DISPLAYED',
          fixes: [
            for (final qualifier in ['a', 'b'])
              rpc.QuickFix(
                label: 'REMOTE ENGLISH LABEL',
                startUtf16: start,
                endUtf16: start + 4,
                replacement: '$qualifier.name',
              ),
          ],
        ),
      ),
    ),
  );
  model.acceptMetadataSnapshotRevision(
    'owned',
    1,
    1,
    sourceIdentity: fixtureMetadataSourceIdentity,
  );
  model.acceptedDiagnostics = accepted;
  return accepted;
}

WorkbenchModel workspace(TestBackend backend) {
  final model = WorkbenchModel(Directory('/unused'))
    ..draftRecovery = false
    ..backend = backend
    ..newDocument(text: source);
  model.document.sessionId = 'owned';
  model.sessions['owned'] = rpc.SessionInfo(
    metadataSourceIdentity: fixtureMetadataSourceIdentity,
    sessionId: 'owned',
    contextRevision: Int64.ONE,
    sessionRevision: Int64(7),
    profile: rpc.Profile(engine: rpc.Engine.POSTGRESQL),
  );
  return model;
}

void main() {
  test(
    'caret changes notify presentation when only diagnostics or parameters exist',
    () {
      for (final parameters in [false, true]) {
        final model = workspace(TestBackend());
        final accepted = diagnostics(model);
        if (parameters) {
          model.acceptedDiagnostics = null;
          model.acceptedParameterInformation = accepted;
        }
        var notified = 0;
        model.addListener(() => notified++);
        model.document.selectOffsets(1, 1);
        expect(notified, greaterThan(0));
        expect(model.acceptedDiagnostics, isNull);
        expect(model.acceptedParameterInformation, isNull);
        model.dispose();
      }
    },
  );

  test('correction and navigation reject forged indexes and UTF-16 spans', () {
    final model = workspace(TestBackend());
    addTearDown(model.dispose);
    final accepted = diagnostics(model),
        action = SqlDiagnosticActions(model, accepted);
    expect(action.apply(-1, 0), isFalse);
    expect(action.apply(1, 0), isFalse);
    expect(action.apply(0, -1), isFalse);
    expect(action.apply(0, 2), isFalse);
    expect(action.select(64), isFalse);
    final emoji = source.indexOf('😀');
    accepted.result.diagnostics.first.fixes.first
      ..startUtf16 = emoji + 1
      ..endUtf16 = emoji + 2;
    expect(action.apply(0, 0), isFalse);
    final crlf = source.indexOf('\r\n') + 1;
    accepted.result.diagnostics.first.fixes.first
      ..startUtf16 = crlf
      ..endUtf16 = crlf;
    expect(action.apply(0, 0), isFalse);
    accepted.result.diagnostics.first
      ..startUtf16 = source.length + 2
      ..endUtf16 = source.length + 1;
    expect(action.select(0), isFalse);
    expect(model.document.editor.text, source);
  });

  test(
    'incomplete diagnostics and oversized or malformed corrections cannot edit',
    () {
      final model = workspace(TestBackend());
      addTearDown(model.dispose);
      final accepted = diagnostics(model),
          action = SqlDiagnosticActions(model, accepted);
      accepted.result.diagnostics.first.incomplete = true;
      expect(action.apply(0, 0), isFalse);
      accepted.result.diagnostics.first.incomplete = false;
      accepted.result.diagnostics.first.fixes.first.replacement = 'x' * 8193;
      expect(action.apply(0, 0), isFalse);
      accepted.result.diagnostics.first.fixes.first.replacement = '\ud800';
      expect(action.apply(0, 0), isFalse);
      expect(model.document.editor.text, source);
    },
  );

  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'apply',
      'go',
      'owner',
      'revision',
      'metadata',
      'backend',
      'all64',
    ]) {
      testWidgets(
        '${controls.runtimeType} diagnostics $scenario preserves exact owner',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1100, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final backend = TestBackend(), model = workspace(TestBackend());
          model.backend = backend;
          final target = model.document;
          final accepted = diagnostics(
            model,
            count: scenario == 'all64' ? 64 : 1,
          );
          addTearDown(model.dispose);
          final host = Builder(
            builder: (context) => Center(
              child: controls.button(
                'Open inspections',
                () => showSqlDiagnostics(context, controls, model, target),
              ),
            ),
          );
          Widget appearance(BuildContext context, Widget? child) =>
              Directionality(
                textDirection: scenario == 'all64'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      scenario == 'all64'
                          ? 2
                          : scenario == 'apply'
                          ? 1.5
                          : 1,
                    ),
                    highContrast: true,
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(builder: appearance, home: host)
                : MaterialApp(
                    builder: appearance,
                    home: Scaffold(body: host),
                  ),
          );
          await tester.tap(find.text('Open inspections'));
          await tester.pumpAndSettle();
          expect(
            find.text('REMOTE PRIVATE MESSAGE MUST NOT BE DISPLAYED'),
            findsNothing,
          );
          expect(find.text('REMOTE ENGLISH LABEL'), findsNothing);
          expect(find.text('Ambiguous column'), findsOneWidget);
          expect(
            find.textContaining(
              'UTF-16 ${source.indexOf('name')}–${source.indexOf('name') + 4}',
            ),
            findsWidgets,
          );
          if (scenario == 'owner') model.newDocument(text: 'SELECT other;');
          if (scenario == 'revision') target.editor.text = 'SELECT changed;';
          if (scenario == 'metadata') {
            model.acceptMetadataSnapshotRevision(
              'owned',
              2,
              1,
              sourceIdentity: fixtureMetadataSourceIdentity,
            );
          }
          if (scenario == 'backend') {
            model.backend = TestBackend(instanceId: 'replacement');
            model.updateStatus('Backend changed');
          }
          await tester.pumpAndSettle();
          switch (scenario) {
            case 'apply':
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('sql-diagnostic-fix-0-1')),
                150,
                scrollable: find
                    .descendant(
                      of: find.byType(SqlDiagnostics),
                      matching: find.byType(Scrollable),
                    )
                    .last,
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(
                find.byKey(const ValueKey('sql-diagnostic-fix-0-1')),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(const ValueKey('sql-diagnostic-fix-0-1')),
              );
              await tester.pumpAndSettle();
              expect(target.editor.text, source.replaceFirst('name', 'b.name'));
              target.editor.undo();
              expect(target.editor.text, source);
            case 'go':
              await tester.tap(find.text('Go to SQL span'));
              await tester.pumpAndSettle();
              expect(target.selectionUtf16, (
                source.indexOf('name'),
                source.indexOf('name') + 4,
              ));
              expect(target.editor.selectedText, 'name');
              expect(target.editor.text, source);
            case 'all64':
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('sql-diagnostic-63')),
                300,
                scrollable: find
                    .descendant(
                      of: find.byType(SqlDiagnostics),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await tester.tap(find.byKey(const ValueKey('sql-diagnostic-63')));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('sql-diagnostic-fix-63-1')),
                150,
                scrollable: find
                    .descendant(
                      of: find.byType(SqlDiagnostics),
                      matching: find.byType(Scrollable),
                    )
                    .last,
              );
              expect(
                find.byKey(const ValueKey('sql-diagnostic-fix-63-1')),
                findsOneWidget,
              );
              await tester.tap(find.text('Close'));
              await tester.pumpAndSettle();
            default:
              expect(
                find.text(
                  'SQL inspection context changed. Request inspections again.',
                ),
                findsOneWidget,
              );
              await tester.tap(
                find.byKey(const ValueKey('sql-diagnostic-fix-0-1')),
              );
              await tester.pumpAndSettle();
              expect(find.byType(SqlDiagnostics), findsOneWidget);
              expect(
                target.editor.text,
                scenario == 'revision' ? 'SELECT changed;' : source,
              );
              expect(SqlDiagnosticActions(model, accepted).select(0), isFalse);
              if (scenario == 'owner') {
                expect(model.document.editor.text, 'SELECT other;');
              }
              await tester.tap(find.text('Close'));
              await tester.pumpAndSettle();
          }
          model.invalidateAnalysis();
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
