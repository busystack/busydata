import 'dart:async';
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/capabilities_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in ['states', 'context', 'backend', 'retry']) {
      testWidgets('${controls.runtimeType} capability inspection $scenario', (
        tester,
      ) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-capability-ui-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..backend = backend
          ..draftRecovery = false
          ..newDocument();
        model.document.sessionId = 'source';
        model.sessions['source'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'source',
          contextRevision: Int64(1),
          sessionRevision: Int64(3),
        );
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final gate = Completer<CapabilityList>();
        backend.client.capabilityAction = (request) => scenario == 'retry'
            ? Future.error(StateError('Controlled inspection failure'))
            : scenario == 'states'
            ? Future.value(report(request))
            : gate.future;
        final inspector = SizedBox(
          width: 750,
          height: 550,
          child: CapabilitiesView(
            model: model,
            target: model.captureTarget(),
            controls: controls,
          ),
        );
        // The production shell listens to owned-request admission. Initial
        // inspection must not notify that ancestor while it is building.
        final view = ListenableBuilder(
          listenable: model,
          builder: (_, _) => inspector,
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        final request = backend.client.capabilityRequests.single;
        expect(request.sessionId, 'source');
        expect(request.contextRevision, Int64(1));
        expect(request.sessionRevision, Int64(3));
        if (scenario == 'context' || scenario == 'backend') {
          if (scenario == 'context') {
            model.sessions['source'] = model.sessions['source']!.deepCopy()
              ..contextRevision = Int64(2);
          } else {
            model.backend = TestBackend(instanceId: 'replacement');
          }
          gate.complete(report(request));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('execution context changed'),
            findsOneWidget,
          );
          expect(find.textContaining('Explain:'), findsNothing);
        } else {
          if (scenario == 'retry') {
            expect(
              find.textContaining('Controlled inspection failure'),
              findsOneWidget,
            );
            expect(backend.client.capabilityRequests, hasLength(1));
            backend.client.capabilityAction = (request) async =>
                report(request);
            await tester.tap(find.text('Refresh capabilities'));
            await tester.pumpAndSettle();
            expect(backend.client.capabilityRequests, hasLength(2));
          }
          for (final (name, value) in [
            ('Explain', 'Available · empty data'),
            ('Users and roles', 'Permission denied'),
            ('Statistics', 'Unavailable'),
            ('Schema', 'Disabled by profile'),
            ('Objects', 'Unsupported'),
            ('Grants', 'Limited visibility or scope'),
          ]) {
            expect(find.text(name), findsOneWidget);
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is SelectableText && widget.data?.trim() == value,
              ),
              findsOneWidget,
            );
          }
        }
        expect(model.pendingOperations, 0);
        expect(
          backend.client.toolRequests,
          isEmpty,
          reason: 'Read inspection must not create execution jobs',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

CapabilityList report(CapabilityRequest request) => CapabilityList(
  backendInstance: request.context.instanceId,
  sessionId: request.sessionId,
  contextRevision: request.contextRevision,
  sessionRevision: request.sessionRevision,
  product: 'Disposable UI fixture',
  version: 'fixture version',
  availability: 'Scoped read probes; modifying actions still require review.',
  entries: [
    Capability(
      id: 'plans',
      label: 'Plans',
      state: CapabilityState.CAPABILITY_AVAILABLE,
      dataChecked: true,
      empty: true,
    ),
    Capability(
      id: 'principals',
      label: 'Roles',
      state: CapabilityState.CAPABILITY_DENIED,
    ),
    Capability(
      id: 'statistics',
      label: 'Statistics',
      state: CapabilityState.CAPABILITY_UNAVAILABLE,
    ),
    Capability(
      id: 'schema',
      label: 'Schema',
      state: CapabilityState.CAPABILITY_DISABLED,
    ),
    Capability(
      id: 'objects',
      label: 'Objects',
      state: CapabilityState.CAPABILITY_UNSUPPORTED,
    ),
    Capability(
      id: 'grants',
      label: 'Grants',
      state: CapabilityState.CAPABILITY_LIMITED,
    ),
  ],
);
