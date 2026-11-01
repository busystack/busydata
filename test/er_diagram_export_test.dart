import 'dart:io';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/schema_tools_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/er_diagram_export.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'support/native_window.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} focused diagram exposes actual relationships at 200%',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        tester.view.physicalSize = const Size(900, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('diagram-details-'),
        ))!;
        final model = WorkbenchModel(root)..draftRecovery = false;
        final child = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: DiagramDocumentView(
              model: model,
              ui: controls,
              tables: [
                rpc.SchemaObject(name: 'child'),
                rpc.SchemaObject(name: 'parent'),
              ],
              edges: [
                rpc.SchemaObject(
                  name: 'fk_child',
                  table: 'child',
                  properties: {
                    'column': 'parent_id',
                    'referencedSchema': 'public',
                    'referencedTable': 'parent',
                    'referencedColumn': 'id',
                  }.entries,
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: child)
              : MaterialApp(home: Scaffold(body: child)),
        );
        await tester.enterText(
          find.byWidgetPredicate((w) => w is EditableText && !w.readOnly).first,
          'child',
        );
        await tester.tap(find.text('Focus'));
        await tester.pumpAndSettle();
        expect(
          find.text('fk_child: child.parent_id → public.parent.id'),
          findsOneWidget,
        );
        expect(find.text('Foreign keys · child'), findsOneWidget);
        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        final transform = viewer.transformationController!;
        final centered = transform.value.entry(0, 3);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(transform.value.entry(0, 3), centered + 40);
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pump();
        expect(transform.value.getMaxScaleOnAxis(), closeTo(1.2, 0.001));
        final oldViewport = tester.getSize(find.byType(InteractiveViewer));
        final oldCenter = transform.toScene(
          Offset(oldViewport.width / 2, oldViewport.height / 2),
        );
        tester.view.physicalSize = const Size(624, 540);
        await tester.pumpAndSettle();
        final newViewport = tester.getSize(find.byType(InteractiveViewer));
        final newCenter = transform.toScene(
          Offset(newViewport.width / 2, newViewport.height / 2),
        );
        expect(newCenter.dx, closeTo(oldCenter.dx, 0.001));
        expect(newCenter.dy, closeTo(oldCenter.dy, 0.001));
        expect(transform.value.getMaxScaleOnAxis(), closeTo(1.2, 0.001));
        tester.view.physicalSize = const Size(624, 340);
        await tester.pumpAndSettle();
        final smallViewport = tester.getRect(find.byType(InteractiveViewer));
        final childTable = find.descendant(
          of: find.byType(InteractiveViewer),
          matching: find.text('child'),
        );
        expect(smallViewport.height, greaterThanOrEqualTo(88));
        expect(smallViewport.contains(tester.getCenter(childTable)), isTrue);
        if (controls is LinuxControls) {
          const channel = MethodChannel(nativeMenuChannelName);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method != 'show') return null;
                final entries = (call.arguments as Map)['entries'] as List;
                return entries.indexWhere(
                  (entry) => (entry as Map)['label'] == 'Foreign keys',
                );
              });
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null);
          });
        }
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        if (controls is WindowsControls) {
          await tester.tap(find.text('Foreign keys'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text('fk_child: child.parent_id → public.parent.id'),
          findsOneWidget,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Focus'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(transform.value, Matrix4.identity());
        await tester.tap(
          find.byWidgetPredicate((w) => w is EditableText && !w.readOnly).first,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(transform.value, Matrix4.identity());
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
  testWidgets(
    'ER image contains tables, foreign keys and Unicode notes outside the viewport',
    (tester) async {
      final data = await tester.runAsync(
        () => renderErDiagramPng(
          tables: [
            rpc.SchemaObject(name: 'orders'),
            rpc.SchemaObject(name: '顧客'),
          ],
          edges: [
            rpc.SchemaObject(
              table: 'orders',
              properties: {'referencedTable': '顧客'}.entries,
            ),
          ],
          notes: '漢😀 notes',
          foreground: const Color(0xFF000000),
          background: const Color(0xFFFFFFFF),
          style: const TextStyle(fontFamily: 'monospace'),
          direction: TextDirection.ltr,
        ),
      );
      final decoded = image.decodePng(data!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1700);
      expect(decoded.height, 580);
      expect(decoded.getPixel(420, 90).r, lessThan(50));
      expect(decoded.getPixel(400, 90).r, lessThan(50));
      expect(decoded.getPixel(1690, 570).r, greaterThan(250));
      expect(decoded.getPixel(30, 50).r, lessThan(50));
      var notePixels = 0;
      for (var y = 290; y < 450; y++) {
        for (var x = 30; x < 800; x++) {
          if (decoded.getPixel(x, y).r < 200) notePixels++;
        }
      }
      expect(notePixels, greaterThan(10));
    },
  );
  testWidgets('large ER raster requests fail before allocating an image', (
    tester,
  ) async {
    await expectLater(
      renderErDiagramPng(
        tables: List.generate(1000, (i) => rpc.SchemaObject(name: 'table$i')),
        edges: [],
        notes: '',
        foreground: const Color(0xFF000000),
        background: const Color(0xFFFFFFFF),
        style: const TextStyle(),
        direction: TextDirection.ltr,
      ),
      throwsStateError,
    );
  });
}
