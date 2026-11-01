import 'dart:async';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_operations.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/related_revision_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Related Rows rejects a high-bit wire revision without a watermark',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client, observedMetadata: false);
      addTearDown(model.dispose);
      expect(model.metadataRevisionForSession('s'), isNull);
      final pending = model.relatedRows(relatedRequest());
      final checked = expectLater(
        pending,
        throwsA(relatedFailure(WorkbenchFailureReason.malformedRequest)),
      );
      final malformed = rpc.RelatedRowsReply.fromBuffer(
        relatedReply(snapshot: -1).writeToBuffer(),
      );
      expect(malformed.snapshotRevision.isNegative, isTrue);
      client.pending.complete(malformed);
      await checked;
      expect(model.metadataRevisionForSession('s'), isNull);
      expect(client.browseReviews, isEmpty);
      expect(client.browseRequests, isEmpty);
    },
  );

  test(
    'zero unavailable Related Rows remains usable without a watermark',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client, observedMetadata: false);
      addTearDown(model.dispose);
      final pending = model.relatedRows(relatedRequest());
      final unavailable = relatedReply(snapshot: 0)
        ..relationships.clear()
        ..availability = 'incomplete-metadata';
      client.pending.complete(unavailable);
      expect(await pending, unavailable);
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 0,
        configuration: 2,
      ));
      expect(client.browseReviews, isEmpty);
      expect(client.browseRequests, isEmpty);
    },
  );

  for (final snapshot in [9, 10, 11]) {
    test(
      'current Related Rows accepts equal/newer snapshot $snapshot',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final pending = model.relatedRows(relatedRequest());
        final checked = snapshot < 10
            ? expectLater(
                pending,
                throwsA(relatedFailure(WorkbenchFailureReason.stale)),
              )
            : expectLater(pending, completes);
        client.pending.complete(relatedReply(snapshot: snapshot));
        await checked;
        expect(model.metadataRevisionForSession('s'), (
          snapshot: snapshot > 10 ? snapshot : 10,
          configuration: 2,
        ));
        expect(client.browseReviews, isEmpty);
        expect(client.browseRequests, isEmpty);
      },
    );
  }

  test(
    'delayed Related Rows cannot precede an accepted newer snapshot',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final pending = model.relatedRows(relatedRequest());
      final checked = expectLater(
        pending,
        throwsA(relatedFailure(WorkbenchFailureReason.stale)),
      );
      expect(
        model.acceptMetadataSnapshotRevision(
          's',
          11,
          2,
          sourceIdentity: fixtureMetadataSourceIdentity,
        ),
        isTrue,
      );
      client.pending.complete(relatedReply());
      await checked;
      expect(client.browseReviews, isEmpty);
      expect(client.browseRequests, isEmpty);
    },
  );

  for (final snapshot in [9, 10, 11]) {
    test(
      'explicit Related Rows snapshot remains exact for reply $snapshot',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final pending = model.relatedRows(relatedRequest(snapshot: 10));
        final checked = snapshot == 10
            ? expectLater(pending, completes)
            : expectLater(
                pending,
                throwsA(relatedFailure(WorkbenchFailureReason.invalidRevision)),
              );
        client.pending.complete(relatedReply(snapshot: snapshot));
        await checked;
        expect(client.requests.single.snapshotRevision, Int64(10));
      },
    );
  }

  for (final changed in ['backend', 'result', 'row', 'disposed']) {
    test('Related Rows still rejects a changed $changed owner', () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final pending = model.relatedRows(relatedRequest());
      final checked = expectLater(
        pending,
        changed == 'backend'
            ? throwsA(relatedFailure(WorkbenchFailureReason.backendRestarted))
            : throwsStateError,
      );
      final reply = relatedReply();
      switch (changed) {
        case 'backend':
          model.backend = TestBackend();
        case 'result':
          reply.resultId = 'foreign-source';
        case 'row':
          reply.sourceRow = Int64(2);
        case 'disposed':
          model.disposedResults.add('source');
      }
      client.pending.complete(reply);
      await checked;
    });
  }

  test(
    'Related Rows checks its submitted request rather than later mutations',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final request = relatedRequest();
      final pending = model.relatedRows(request);
      request
        ..resultId = 'different-request'
        ..sourceRow = Int64(2)
        ..snapshotRevision = Int64(99);
      client.pending.complete(relatedReply());
      await expectLater(pending, completes);
      expect(client.requests.single.resultId, 'source');
      expect(client.requests.single.sourceRow, Int64.ONE);
      expect(client.requests.single.snapshotRevision, Int64.ZERO);
    },
  );

  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'delayed older',
      'equal',
      'newer',
      'relationship dialog superseded',
      'review pending superseded',
      'review dialog superseded',
      'backend changed',
      'session changed',
      'context changed',
      'row changed',
      'selection changed',
      'owner detached',
      'result disposed',
    ]) {
      testWidgets('${controls.runtimeType} Related Rows fences $scenario', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1100, 950));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        final owner = model.activeOwner;
        final result = rpc.StatementResult(
          resultId: 'source',
          fetchedRows: Int64(2),
          complete: true,
          columns: [rpc.Column(name: 'id')],
        );
        final review = Completer<rpc.Approval>();
        if (scenario == 'review pending superseded') {
          client.browseReview = (_) => review.future;
        }
        var selectedRow = 1, selectedColumn = 0;
        Future<Object?>? completion;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        });
        final host = Builder(
          builder: (context) => Center(
            child: controls.button('Open operation', () {
              final operations = ResultOperations(
                model: model,
                controls: controls,
                context: context,
                owner: owner,
                result: result,
                selectedRow: 1,
                anchorRow: 1,
                selectedColumn: 0,
                anchorColumn: 0,
                visibleColumns: [0],
                current: () => selectedRow == 1 && selectedColumn == 0,
              );
              completion = operations.related().then<Object?>(
                (_) => null,
                onError: (Object error, StackTrace stack) => error,
              );
            }),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: host)
              : MaterialApp(home: Scaffold(body: host)),
        );
        await tester.tap(find.text('Open operation'));
        await tester.pump();
        expect(client.requests, hasLength(1));
        expect(client.requests.single.sessionId, 's');
        expect(client.requests.single.sourceRow, Int64.ONE);
        expect(client.requests.single.snapshotRevision, Int64.ZERO);
        final changedBeforeReply =
            scenario == 'delayed older' ||
            scenario.endsWith('changed') ||
            scenario == 'owner detached' ||
            scenario == 'result disposed';
        if (changedBeforeReply) {
          switch (scenario) {
            case 'delayed older':
              model.acceptMetadataSnapshotRevision(
                's',
                11,
                2,
                sourceIdentity: fixtureMetadataSourceIdentity,
              );
            case 'backend changed':
              model.backend = TestBackend();
            case 'session changed':
              model.sessions['s'] = model.sessions['s']!.deepCopy()
                ..sessionRevision = Int64(8);
            case 'context changed':
              model.sessions['s'] = model.sessions['s']!.deepCopy()
                ..contextRevision = Int64(2);
            case 'row changed':
              selectedRow = 2;
            case 'selection changed':
              selectedColumn = 1;
            case 'owner detached':
              owner.sessionId = 'other-session';
            case 'result disposed':
              model.disposedResults.add('source');
          }
        }
        client.pending.complete(
          relatedReply(snapshot: scenario == 'newer' ? 11 : 10),
        );
        await tester.pumpAndSettle();
        final relationship = find.text('fk_fixture · → db.public.target');
        if (changedBeforeReply) {
          expect(await completion!, switch (scenario) {
            'delayed older' => relatedFailure(WorkbenchFailureReason.stale),
            'backend changed' => relatedFailure(
              WorkbenchFailureReason.backendRestarted,
            ),
            'session changed' || 'context changed' => relatedFailure(
              WorkbenchFailureReason.invalidRevision,
            ),
            _ => isA<StateError>(),
          });
          expect(relationship, findsNothing);
          expect(client.browseReviews, isEmpty);
        } else if (scenario == 'equal' || scenario == 'newer') {
          expect(relationship, findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(await completion!, isNull);
          expect(client.browseReviews, isEmpty);
        } else {
          expect(relationship, findsOneWidget);
          if (scenario == 'relationship dialog superseded') {
            model.acceptMetadataSnapshotRevision(
              's',
              11,
              2,
              sourceIdentity: fixtureMetadataSourceIdentity,
            );
          }
          await tester.tap(relationship);
          await tester.pumpAndSettle();
          if (scenario == 'relationship dialog superseded') {
            expect(client.browseReviews, isEmpty);
          } else if (scenario == 'review pending superseded') {
            expect(client.browseReviews, hasLength(1));
            model.acceptMetadataSnapshotRevision(
              's',
              11,
              2,
              sourceIdentity: fixtureMetadataSourceIdentity,
            );
            review.complete(rpc.Approval(token: 'owned-review'));
            await tester.pumpAndSettle();
            expect(find.text('Open data'), findsNothing);
          } else {
            expect(client.browseReviews, hasLength(1));
            expect(find.text('Open data'), findsOneWidget);
            model.acceptMetadataSnapshotRevision(
              's',
              11,
              2,
              sourceIdentity: fixtureMetadataSourceIdentity,
            );
            await tester.tap(find.text('Open data'));
            await tester.pumpAndSettle();
          }
          expect(
            await completion!,
            relatedFailure(WorkbenchFailureReason.stale),
          );
        }
        expect(client.browseRequests, isEmpty);
        expect(client.executions, isEmpty);
        expect(model.operationOwners, [owner]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
