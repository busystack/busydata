import 'support/windows_secret_input.dart';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/connection_widgets.dart';
import 'support/serialized_semantics_test_binding.dart';

void main() {
  setUpWindowsSecretInputFixture();
  SerializedSemanticsTestBinding();
  for (final longName in [false, true]) {
    testWidgets(
      'connection tooltip ownership and full text survive profile/page changes: long=$longName',
      (tester) async {
        final mysqlName = longName
            ? List.generate(20, (i) => 'long database name $i').join(' ')
            : 'Fixture MYSQL';
        SerializedSemanticsTestBinding.resetRecorder();
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await tester.binding.setSurfaceSize(const Size(1024, 720));
        final semantics = tester.ensureSemantics();
        final model =
            WorkbenchModel(
                Directory('/unused-connection-serialized-diagnostic'),
              )
              ..draftRecovery = false
              ..backend = TestBackend()
              ..newDocument();
        model.profiles.addAll([
          for (final engine in [
            rpc.Engine.POSTGRESQL,
            rpc.Engine.MARIADB,
            rpc.Engine.MYSQL,
          ])
            rpc.Profile(
              id: engine.name,
              name: engine == rpc.Engine.MYSQL
                  ? mysqlName
                  : 'Fixture ${engine.name}',
              engine: engine,
              host: 'localhost',
              port: engine == rpc.Engine.POSTGRESQL ? 5432 : 3306,
              user: 'fixture',
              database: 'busydata',
            ),
        ]);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(10, 10));
        Future<void> frames(String phase) async {
          SerializedSemanticsTestBinding.phase = phase;
          for (final ms in [16, 16, 75, 150, 500]) {
            await tester.pump(Duration(milliseconds: ms));
          }
        }

        try {
          await tester.pumpWidget(
            fluent.FluentApp(
              home: WorkbenchView(
                model: model,
                controls: const WindowsControls(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          SerializedSemanticsTestBinding.phase = 'open-new-connection';
          final opened = model.commands!.invoke(
            'connection.new',
            model.commandContext,
          );
          await tester.pumpAndSettle();
          final source = find.byKey(const ValueKey('MYSQL')).hitTestable();
          expect(source, findsOneWidget);
          final visibleBefore = find.text(mysqlName).evaluate().length;
          await mouse.moveTo(tester.getCenter(source));
          await frames('hover-mysql-profile');
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(
            find.text(mysqlName).evaluate().length,
            greaterThan(visibleBefore),
            reason:
                'The actual tooltip must remain visible; an absent tooltip is not a correction',
          );
          if (longName) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(mysqlName).last,
            );
            final glyphs = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: mysqlName.length),
            );
            final bottom = glyphs
                .map((box) => box.bottom)
                .fold<double>(0, (a, b) => a > b ? a : b);
            final right = glyphs
                .map((box) => box.right)
                .fold<double>(0, (a, b) => a > b ? a : b);
            expect(
              bottom,
              lessThanOrEqualTo(paragraph.size.height + .5),
              reason: 'A semantics correction must not clip long hover text',
            );
            expect(right, lessThanOrEqualTo(paragraph.size.width + .5));
            final origin = paragraph.localToGlobal(Offset.zero);
            expect(origin.dx, greaterThanOrEqualTo(0));
            expect(origin.dy, greaterThanOrEqualTo(0));
            expect(origin.dx + paragraph.size.width, lessThanOrEqualTo(1024));
            expect(origin.dy + paragraph.size.height, lessThanOrEqualTo(720));
          }
          await tester.tap(source);
          await frames('select-mysql-profile');
          for (final key in ['port', 'password']) {
            final field = find.descendant(
              of: find.byKey(ValueKey('connection-$key')),
              matching: find.byType(EditableText),
            );
            await tester.ensureVisible(field);
            await tester.tap(field);
            await frames('focus-$key');
            await enterDesktopText(
              tester,
              field,
              key == 'port' ? '32899' : 'synthetic-fixture-secret',
            );
            await frames('edit-$key');
          }
          SerializedSemanticsTestBinding.phase = 'select-ssh-page';
          await selectConnectionPage(tester, 'SSH/SSL');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel').last.hitTestable());
          await tester.pumpAndSettle();
          if (find.text('Discard').hitTestable().evaluate().isNotEmpty) {
            await tester.tap(find.text('Discard').last.hitTestable());
            await tester.pumpAndSettle();
          }
          await opened;
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          semantics.dispose();
          await mouse.removePointer();
          await tester.binding.setSurfaceSize(null);
          debugDefaultTargetPlatformOverride = null;
        }
        expect(SerializedSemanticsTestBinding.batches, isNotEmpty);
        expect(
          SerializedSemanticsTestBinding.orphanBatches,
          isEmpty,
          reason:
              'A serialized tooltip node must remain reachable from the engine root while it appears, retires or its form changes',
        );
      },
    );
  }
}
