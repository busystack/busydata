import 'dart:io';
import 'package:busydata/l10n/generated/app_localizations_en.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_operations.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'support/fake_backend.dart';

class OperationClient extends TestClient {
  bool denied = false;
  int aggregateCalls = 0, relatedCalls = 0;
  @override
  ResponseFuture<rpc.ResultAggregateReply> resultAggregate(
    rpc.ResultAggregateRequest request, {
    CallOptions? options,
  }) {
    aggregateCalls++;
    return response(
      Future.value(
        rpc.ResultAggregateReply(
          resultId: request.resultId,
          viewId: request.viewId,
          columns: [
            for (final (index, availability) in [
              'available-ordinal-text-order',
              'incompatible-types',
              'secret unknown state',
            ].indexed)
              rpc.ColumnAggregate(
                ordinal: index + 1,
                availability: availability,
              ),
          ],
        ),
      ),
    );
  }

  @override
  ResponseFuture<rpc.RelatedRowsReply> relatedRows(
    rpc.RelatedRowsRequest request, {
    CallOptions? options,
  }) {
    relatedCalls++;
    return response(
      Future.value(
        rpc.RelatedRowsReply(
          resultId: request.resultId,
          sourceRow: request.sourceRow,
          backendInstance: request.context.instanceId,
          profileId: 'p',
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: request.sessionId,
          sessionRevision: request.expectedSessionRevision,
          contextRevision: request.expectedContextRevision,
          metadataConfigurationRevision: Int64.ONE,
          snapshotRevision: Int64.ONE,
          availability: denied ? 'denied' : 'available',
          relationships: denied
              ? []
              : [
                  for (final availability in [
                    'key-not-projected',
                    'null-key-component',
                    'secret unknown state',
                  ])
                    rpc.RelatedRelationship(
                      name: 'relationship $availability',
                      availability: availability,
                    ),
                ],
        ),
      ),
    );
  }
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'aggregate',
      'related',
      'denied',
      'offline aggregate',
      'offline related',
      'offline clone',
      'disconnected related',
    ]) {
      testWidgets(
        '${controls.runtimeType} localized retained operation states $scenario',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1100, 950));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final client = OperationClient()..denied = scenario == 'denied';
          final model = WorkbenchModel(Directory('/unused'))
            ..draftRecovery = false
            ..backend = TestBackend(client: client)
            ..newDocument();
          final profile = rpc.Profile(id: 'p', engine: rpc.Engine.POSTGRESQL);
          model.profiles.add(profile);
          model.document
            ..profileId = profile.id
            ..sessionId = 's';
          model.sessions['s'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 's',
            profile: profile,
            sessionRevision: Int64.ONE,
            contextRevision: Int64.ONE,
            transaction: rpc.TransactionState.IDLE,
            autoCommit: true,
          );
          addTearDown(model.dispose);
          final result = rpc.StatementResult(
            resultId: 'source',
            fetchedRows: Int64.ONE,
            complete: true,
            columns: [for (var i = 0; i < 3; i++) rpc.Column(name: 'field$i')],
          );
          final host = Builder(
            builder: (context) => Center(
              child: controls.button('Open operation', () {
                final operations = ResultOperations(
                  model: model,
                  controls: controls,
                  context: context,
                  owner: model.activeOwner,
                  result: result,
                  selectedRow: 0,
                  anchorRow: 0,
                  selectedColumn: 0,
                  anchorColumn: 2,
                  visibleColumns: [0, 1, 2],
                  current: () => true,
                );
                if (scenario.endsWith('aggregate')) {
                  operations.aggregate();
                } else if (scenario.endsWith('clone')) {
                  operations.clone();
                } else {
                  operations.related();
                }
              }),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: host)
                : MaterialApp(home: Scaffold(body: host)),
          );
          if (scenario.startsWith('offline')) model.backend = null;
          if (scenario == 'disconnected related') {
            model.document.sessionId = null;
          }
          await tester.tap(find.text('Open operation'));
          await tester.pumpAndSettle();
          if (scenario.startsWith('offline') ||
              scenario == 'disconnected related') {
            expect(
              model.status,
              scenario == 'disconnected related'
                  ? AppLocalizationsEn().relatedRowsUnavailable
                  : 'Retained data unavailable. Saved SQL and private recovery remain local.',
            );
            expect(client.aggregateCalls + client.relatedCalls, 0);
          } else if (scenario == 'aggregate') {
            expect(
              find.text(
                'Text minimum/maximum use retained UTF-16 ordinal order; database collation is not applied.',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                'The selected values have incompatible types. Select values with a common type.',
              ),
              findsOneWidget,
            );
            expect(find.text('available-ordinal-text-order'), findsNothing);
            expect(find.text('secret unknown state'), findsNothing);
          } else if (scenario == 'related') {
            expect(
              find.textContaining('Select all relationship key columns'),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                'A NULL relationship key has no matching related row.',
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                'relationship secret unknown state · Unavailable',
              ),
              findsOneWidget,
            );
          } else {
            expect(find.text('Permission denied'), findsOneWidget);
            expect(find.text('denied'), findsNothing);
          }
          expect(client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          if (!scenario.startsWith('offline') &&
              scenario != 'disconnected related') {
            await tester.tap(
              find.text(scenario == 'aggregate' ? 'Close' : 'Cancel'),
            );
          }
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
