import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart' as rpc;
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/l10n/generated/app_localizations_en.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'support/fake_backend.dart';

class _AssessmentClient extends TestClient {
  final requests =
      <({rpc.ChangeRequest request, Completer<rpc.Editability> reply})>[];

  @override
  ResponseFuture<rpc.Editability> assessEditability(
    rpc.ChangeRequest request, {
    CallOptions? options,
  }) {
    final reply = Completer<rpc.Editability>();
    requests.add((request: request.deepCopy(), reply: reply));
    return response(reply.future);
  }
}

rpc.Editability _editable() =>
    rpc.Editability(editable: true, editableColumns: [1]);

class _GridFixture {
  _GridFixture(this.tester, this.controls) {
    clients.add(client);
    backend = TestBackend(client: client);
    model = WorkbenchModel(Directory('/unused-editability-owner'))
      ..draftRecovery = false
      ..backend = backend
      ..newDocument();
    model.activeOwner.sessionId = 'physical';
    model.sessions['physical'] = rpc.SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'physical',
      autoCommit: true,
      transaction: rpc.TransactionState.IDLE,
    );
  }

  final WidgetTester tester;
  final DesktopControls controls;
  final client = _AssessmentClient();
  final clients = <_AssessmentClient>[];
  late final TestBackend backend;
  late final WorkbenchModel model;
  String source = '';

  Future<void> show(String id) async {
    source = id;
    final result = rpc.StatementResult(
      resultId: id,
      complete: true,
      fetchedRows: Int64.ONE,
      columns: [
        rpc.Column(
          name: 'n',
          baseColumn: 'n',
          ordinal: 1,
          jdbcType: 12,
          typeName: 'TEXT',
          table: 'items',
          schema: 'public',
          provenanceKnown: true,
        ),
      ],
    );
    model.track(
      rpc.JobInfo(
        jobId: 'job-$id',
        executionId: 'execution-$id',
        sessionId: 'physical',
        state: rpc.JobState.COMPLETED,
        results: [result],
      ),
      documentId: model.activeOwner.id,
    );
    model.cache['$id:0'] = rpc.Row(values: [rpc.Value(text: id)]);
    final grid = ResultGrid(
      key: const ValueKey('owned-result-grid'),
      model: model,
      controls: controls,
      result: result,
    );
    await tester.pumpWidget(
      controls is WindowsControls
          ? fluent.FluentApp(home: grid)
          : MaterialApp(home: Scaffold(body: grid)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> assess() async {
    await model.resultActions[model.activeOwner.id]!['result.assess']!();
  }

  _AssessmentClient replaceBackend() {
    final replacement = _AssessmentClient();
    clients.add(replacement);
    // Reuse the fixture's IDs so only the backend instance establishes which
    // outstanding assessment is allowed to publish its reply.
    model.backend = TestBackend(
      instanceId: 'replacement-instance',
      client: replacement,
    );
    return replacement;
  }

  void expectEditable(bool editable) {
    final hint = tester
        .getSemantics(find.bySemanticsLabel('Row 1, n: $source'))
        .hint;
    expect(hint, contains(editable ? 'Editable cell' : 'Read-only cell'));
    for (final client in clients) {
      expect(client.executions, isEmpty);
    }
  }

  Future<void> expectReadonlyInspector() async {
    await model.resultActions[model.activeOwner.id]!['result.inspect']!();
    await tester.pumpAndSettle();
    expect(find.byType(ResultValueEditor), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultValueEditor),
        matching: find.text('Edit cell'),
      ),
      findsNothing,
    );
    expect(client.executions, isEmpty);
  }

  Future<void> expectEditableInspector() async {
    await model.resultActions[model.activeOwner.id]!['result.inspect']!();
    await tester.pumpAndSettle();
    final editor = tester.widget<ResultValueEditor>(
      find.byType(ResultValueEditor),
    );
    expect(editor.stage, isNotNull);
    expect(editor.stageNull, isNotNull);
    expect(editor.stageDefault, isNotNull);
    expect(client.executions, isEmpty);
  }

  Future<void> expectReadonlyReason(String expected) async {
    expectEditable(false);
    await model.resultActions[model.activeOwner.id]!['result.record']!();
    await tester.pumpAndSettle();
    final tooltips = tester.widgetList(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip || widget is fluent.Tooltip,
      ),
    );
    final messages = tooltips
        .map(
          (widget) => widget is Tooltip
              ? widget.message
              : (widget as fluent.Tooltip).message,
        )
        .whereType<String>();
    expect(messages, contains(expected));
    expect(messages.any((message) => message.contains('private SQL')), isFalse);
  }
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'refreshed source ignores an older failure',
      'refreshed source ignores an older success',
      'automatic and explicit assessment share pending completion',
      'SQL draft typing preserves the pending retained assessment',
      'new session epoch success ignores an older failure',
      'new context epoch denial ignores an older success',
      'new physical source ignores an older success',
      'new shared metadata snapshot does not share pending completion',
      'changed owner rejects pending assessment without replacement',
      'failed assessment permits a new manual assessment',
      'current assessment failure keeps editing unavailable',
      'replacement backend ignores a retired assessment failure',
      'disposed grid ignores its outstanding assessment',
    ]) {
      testWidgets('${controls.runtimeType} $scenario', (tester) async {
        final semantics = tester.ensureSemantics();
        final fixture = _GridFixture(tester, controls);
        try {
          if (scenario ==
              'new shared metadata snapshot does not share pending completion') {
            expect(
              fixture.model.acceptMetadataSnapshotRevision(
                'physical',
                1,
                1,
                sourceIdentity: fixtureMetadataSourceIdentity,
              ),
              isTrue,
            );
          }
          await fixture.show('original');
          expect(fixture.client.requests, hasLength(1));
          final initialState = tester.state(find.byType(ResultGrid));
          final original = fixture.client.requests.single;
          expect(original.request.resultId, 'original');
          expect(original.request.sessionId, 'physical');
          if (scenario.startsWith('refreshed source')) {
            await fixture.show('fresh');
            expect(tester.state(find.byType(ResultGrid)), same(initialState));
            expect(fixture.client.requests, hasLength(2));
            expect(fixture.client.requests.last.request.resultId, 'fresh');
            final failedOld = scenario.endsWith('failure');
            fixture.client.requests.last.reply.complete(
              failedOld ? _editable() : rpc.Editability(reasonCode: 'denied'),
            );
            await tester.pumpAndSettle();
            fixture.expectEditable(failedOld);
            if (failedOld) {
              original.reply.completeError(StateError('Retired source failed'));
            } else {
              original.reply.complete(_editable());
            }
            await tester.pumpAndSettle();
            fixture.expectEditable(failedOld);
          } else if (scenario ==
              'automatic and explicit assessment share pending completion') {
            final dynamic state = tester.state(find.byType(ResultGrid));
            final revision = state.assessmentRevision;
            final first = state.assess() as Future<void>;
            final second = state.assess() as Future<void>;
            final explicit = fixture.assess();
            expect(identical(first, second), isTrue);
            expect(state.assessmentRevision, revision);
            expect(fixture.client.requests, hasLength(1));
            original.reply.complete(_editable());
            await Future.wait([first, second, explicit]);
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            await fixture.expectEditableInspector();
          } else if (scenario ==
              'SQL draft typing preserves the pending retained assessment') {
            final beforeVersion = fixture.model.activeOwner.version;
            fixture.model.document.editor.text = 'SELECT a_new_draft';
            expect(
              fixture.model.activeOwner.version,
              greaterThan(beforeVersion),
            );
            final latest = fixture.assess();
            expect(fixture.client.requests, hasLength(1));
            original.reply.complete(_editable());
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            await fixture.expectEditableInspector();
          } else if (scenario ==
              'new session epoch success ignores an older failure') {
            fixture.model.sessions['physical']!.sessionRevision = Int64.ONE;
            final latest = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            fixture.client.requests.last.reply.complete(_editable());
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            original.reply.completeError(StateError('Older request failed'));
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
          } else if (scenario ==
              'new context epoch denial ignores an older success') {
            fixture.model.sessions['physical']!.contextRevision = Int64.ONE;
            final latest = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            fixture.client.requests.last.reply.complete(
              rpc.Editability(reasonCode: 'denied'),
            );
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            original.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            await fixture.expectReadonlyInspector();
          } else if (scenario ==
              'new physical source ignores an older success') {
            fixture.model.sessions['physical']!.metadataSourceIdentity =
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
            final latest = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            original.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            fixture.client.requests.last.reply.complete(
              rpc.Editability(reasonCode: 'denied'),
            );
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
          } else if (scenario ==
              'new shared metadata snapshot does not share pending completion') {
            expect(
              fixture.model.acceptMetadataSnapshotRevision(
                'physical',
                2,
                1,
                sourceIdentity: fixtureMetadataSourceIdentity,
              ),
              isTrue,
            );
            final latest = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            original.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            fixture.client.requests.last.reply.complete(_editable());
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
          } else if (scenario ==
              'changed owner rejects pending assessment without replacement') {
            fixture.model.sessions['physical']!.contextRevision = Int64.ONE;
            original.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            final dynamic state = tester.state(find.byType(ResultGrid));
            expect(state.assessment, isNull);
            expect(state.assessedTarget, isNull);
            expect(fixture.client.requests, hasLength(1));
          } else if (scenario ==
              'failed assessment permits a new manual assessment') {
            original.reply.complete(
              rpc.Editability(reasonCode: 'session_busy'),
            );
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            final latest = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            fixture.client.requests.last.reply.complete(_editable());
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            await fixture.expectEditableInspector();
          } else if (scenario ==
              'replacement backend ignores a retired assessment failure') {
            final replacement = fixture.replaceBackend();
            final latest = fixture.assess();
            expect(replacement.requests, hasLength(1));
            expect(
              replacement.requests.single.request.context.instanceId,
              'replacement-instance',
            );
            replacement.requests.single.reply.complete(_editable());
            await latest;
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            original.reply.completeError(StateError('Retired backend failed'));
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
          } else if (scenario ==
              'disposed grid ignores its outstanding assessment') {
            original.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            final pending = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            await tester.pumpWidget(const SizedBox.shrink());
            fixture.model.dispose();
            fixture.client.requests.last.reply.completeError(
              StateError('Disposed owner failed'),
            );
            await pending;
            await tester.pump();
            expect(fixture.client.executions, isEmpty);
          } else {
            original.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            final current = fixture.assess();
            expect(fixture.client.requests, hasLength(2));
            fixture.client.requests.last.reply.completeError(
              StateError('Current central assessment failed'),
            );
            await current;
            await tester.pumpAndSettle();
            fixture.expectEditable(false);
            await fixture.expectReadonlyInspector();
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          for (final client in fixture.clients) {
            for (final pending in client.requests) {
              if (!pending.reply.isCompleted) {
                pending.reply.completeError(StateError('Disposed test owner'));
              }
            }
          }
          await tester.pump();
          if (!fixture.model.isDisposed) fixture.model.dispose();
          semantics.dispose();
        }
      });
    }
    final locale = AppLocalizationsEn();
    final failures = [
      for (final reason in [
        WorkbenchFailureReason.denied,
        WorkbenchFailureReason.cancelled,
        WorkbenchFailureReason.incompleteMetadata,
        WorkbenchFailureReason.timedOut,
      ])
        (
          name: reason.wire,
          error: GrpcError.custom(
            reason.statusCode,
            'private SQL',
            null,
            null,
            {'busydata-workbench-reason': reason.wire},
          ),
          expected: reason.localized(locale),
        ),
      (
        name: 'mismatched typed status',
        error: GrpcError.custom(
          StatusCode.internal,
          'private SQL',
          null,
          null,
          {'busydata-workbench-reason': 'denied'},
        ),
        expected: locale.editAssessmentUnavailable,
      ),
      (
        name: 'untyped permission error',
        error: const GrpcError.permissionDenied('private SQL: denied'),
        expected: locale.editAssessmentUnavailable,
      ),
    ];
    for (final failure in failures) {
      testWidgets(
        '${controls.runtimeType} assessment explains ${failure.name} without exposing server text',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final fixture = _GridFixture(tester, controls);
          try {
            await fixture.show('typed-failure');
            fixture.client.requests.single.reply.complete(_editable());
            await tester.pumpAndSettle();
            fixture.expectEditable(true);
            final assessment = fixture.assess();
            fixture.client.requests.last.reply.completeError(failure.error);
            await assessment;
            await tester.pumpAndSettle();
            await fixture.expectReadonlyReason(failure.expected);
            await fixture.expectReadonlyInspector();
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            fixture.model.dispose();
            semantics.dispose();
          }
        },
      );
    }
  }
}
