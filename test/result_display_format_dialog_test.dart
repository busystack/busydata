import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_display_format_dialog.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} validates native custom temporal pattern and persists exact stable identity',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Map<String, dynamic>? saved;
        final model = WorkbenchModel(
          Directory('/unused'),
          presentationWrite: (file, bytes) async {
            saved = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          },
        )..newDocument();
        addTearDown(model.dispose);
        final column = rpc.Column(
          name: 'timestamp',
          typeName: 'timestamp',
          provenanceKnown: true,
          metadataIdentity: 'native-column',
          metadataSnapshotRevision: Int64.ONE,
        );
        ResultDisplayChoice? accepted;
        final body = Builder(
          builder: (context) => Center(
            child: controls.button('Open', () async {
              accepted = await controls.dialog<ResultDisplayChoice>(
                context,
                'Display format',
                ResultDisplayFormatDialog(
                  controls: controls,
                  columns: [column],
                  initialColumn: 0,
                  formats: {0: ColumnDisplayFormat.temporalPattern},
                  patterns: {
                    0: TemporalDisplayPattern(
                      'yyyy-MM-dd',
                      TemporalDisplayZone.utc,
                    ),
                  },
                  names: {
                    ColumnDisplayFormat.temporalPattern:
                        'Temporal · custom pattern',
                  },
                ),
                [],
              );
              if (accepted != null) {
                await model.setResultDisplayFormat(
                  rpc.Profile(id: 'profile'),
                  column,
                  accepted!.pattern!.stored,
                );
              }
            }),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: body)
              : MaterialApp(home: Scaffold(body: body)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) => widget is EditableText && !widget.readOnly,
          ),
          'yyyy z',
        );
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(accepted, isNull);
        expect(find.textContaining('Use a pattern of 1–128'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find.byWidgetPredicate(
                  (widget) => widget is EditableText && !widget.readOnly,
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) => widget is EditableText && !widget.readOnly,
          ),
          'dd/MM/yyyy HH:mm:ss.SSSSSS',
        );
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(accepted!.pattern!.zone, TemporalDisplayZone.utc);
        expect(accepted!.pattern!.pattern, 'dd/MM/yyyy HH:mm:ss.SSSSSS');
        final key = resultColumnPreferenceKey('profile', column)!;
        expect(
          (saved!['resultDisplayFormats'] as Map)[key],
          accepted!.pattern!.stored,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
