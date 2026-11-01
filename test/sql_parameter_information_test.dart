import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/sql_parameter_information.dart';
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
    for (final availability in [
      'available',
      'limited',
      'partial-signatures',
      'incomplete-metadata',
    ]) {
      testWidgets(
        '${controls.runtimeType} parameter notice $availability precedes overloads',
        (tester) async {
          final model = WorkbenchModel(Directory('/unused'))
            ..draftRecovery = false
            ..backend = TestBackend()
            ..newDocument(text: 'SELECT routine(1, 2)');
          addTearDown(model.dispose);
          final binding = model.analysisBinding(model.document);
          model.acceptedParameterInformation = AcceptedAnalysis(
            binding,
            rpc.Analysis(
              operation: rpc.AnalysisOperation.PARAMETER_INFORMATION,
              parameterInformation: rpc.ParameterInformation(
                activeArgument: 1,
                availability: availability,
                overloads: [
                  for (var index = 0; index < 10; index++)
                    rpc.RoutineSignature(
                      signature: 'routine(argument_$index integer) → integer',
                    ),
                ],
              ),
            ),
          );
          final view = Center(
            child: SizedBox(
              width: 600,
              child: SqlParameterInformation(
                model: model,
                document: model.document,
                controls: controls,
              ),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
          expect(find.text('Active argument: 2'), findsOneWidget);
          final notice = switch (availability) {
            'limited' =>
              'More overloads exist; parameter information is limited.',
            'partial-signatures' ||
            'incomplete-metadata' => 'Parameter information · Partial',
            _ => null,
          };
          if (notice != null) {
            final label = find.text(notice);
            expect(label, findsOneWidget);
            final viewport = tester.getRect(find.byType(ListView));
            expect(
              viewport.contains(tester.getCenter(label)),
              isTrue,
              reason:
                  'Incomplete metadata must be visible without scrolling past ten overloads',
            );
          } else {
            expect(find.textContaining('· Partial'), findsNothing);
            expect(find.textContaining('More overloads exist'), findsNothing);
          }
          expect(find.text('partial-signatures'), findsNothing);
          expect(find.text('incomplete-metadata'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
