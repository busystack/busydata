import 'support/fake_backend.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_tabs.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Linux native tab activation fires once and close gestures retain their captured owner',
    (tester) async {
      final model = _TabModel()
        ..draftRecovery = false
        ..newDocument()
        ..newDocument();
      final first = model.workbenchDocuments.first, second = model.activeOwner;
      final closed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: model,
              builder: (_, _) => WorkbenchTabs(
                model: model,
                controls: const LinuxControls(),
                close: (o) => closed.add(o.id),
              ),
            ),
          ),
        ),
      );
      final firstTab = find.byKey(ValueKey('document-tab:${first.id}'));
      await tester.tap(firstTab);
      await tester.pumpAndSettle();
      expect(model.activations, 1);
      expect(model.activeOwner, same(first));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(model.activations, 2);
      final ink = tester.widget<InkWell>(
        find.descendant(of: firstTab, matching: find.byType(InkWell)).first,
      );
      expect(ink.focusNode, isNotNull);
      expect(
        find.descendant(
          of: firstTab,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.foregroundDecoration != null,
          ),
        ),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Close tab Query 2'));
      await tester.pumpAndSettle();
      expect(closed, [second.id]);
      expect(model.activations, 2);
      await tester.tap(firstTab, buttons: kMiddleMouseButton);
      await tester.pumpAndSettle();
      expect(closed, [second.id, first.id]);
      expect(model.activations, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} long targets keep production and unknown badges outside title truncation in the minimum content allocation',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final model = WorkbenchModel(Directory('/unused'))
          ..draftRecovery = false
          ..newDocument()
          ..newDocument();
        final owner = model.activeOwner..sessionId = 'long-target-session';
        model.sessions['long-target-session'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'long-target-session',
          transaction: rpc.TransactionState.UNKNOWN_TRANSACTION,
          profile: rpc.Profile(
            name: 'Long original target ' * 20,
            environment: rpc.Environment.PRODUCTION,
          ),
        );
        await tester.binding.setSurfaceSize(const Size(624, 540));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final tabs = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: WorkbenchTabs(model: model, controls: controls, close: (_) {}),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: tabs)
              : MaterialApp(home: Scaffold(body: tabs)),
        );
        await tester.pumpAndSettle();
        final badges = find.text('Production · Outcome unknown');
        expect(badges, findsOneWidget);
        expect(tester.widget<Text>(badges).overflow, isNull);
        expect(
          tester.getRect(badges).left,
          greaterThanOrEqualTo(0),
          reason:
              'Tab ${tester.getRect(find.byKey(ValueKey('document-tab:${owner.id}')))}; badge ${tester.getRect(badges)}; viewport ${tester.getRect(find.byType(SingleChildScrollView))}',
        );
        expect(
          tester.getRect(badges).right,
          lessThanOrEqualTo(624),
          reason:
              'Tab ${tester.getRect(find.byKey(ValueKey('document-tab:${owner.id}')))}; badge ${tester.getRect(badges)}; viewport ${tester.getRect(find.byType(SingleChildScrollView))}',
        );
        expect(
          tester
              .getSemantics(find.byKey(ValueKey('document-tab:${owner.id}')))
              .label,
          contains('Production · Outcome unknown'),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        model.dispose();
      },
    );
    testWidgets(
      '${controls.runtimeType} activating an offscreen tab reveals it without stealing focus',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 300));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final model = WorkbenchModel(Directory('/unused'))
          ..draftRecovery = false;
        for (var i = 0; i < 15; i++) {
          model.newDocument();
        }
        model.select(0);
        final field = FocusNode();
        final tabs = ListenableBuilder(
          listenable: model,
          builder: (_, _) =>
              WorkbenchTabs(model: model, controls: controls, close: (_) {}),
        );
        final content = Column(
          children: [
            tabs,
            Focus(
              focusNode: field,
              child: const Text('Surviving document content'),
            ),
          ],
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: content))
              : MaterialApp(home: Scaffold(body: content)),
        );
        await tester.pump();
        field.requestFocus();
        await tester.pump();
        model.select(14);
        await tester.pump();
        await tester.pump();
        final last = find.text('Query 15');
        final box = tester.getRect(last);
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(500));
        expect(field.hasFocus, isTrue);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scrollable.position.jumpTo(0);
        model.updateStatus('Background completion');
        await tester.pump();
        await tester.pump();
        expect(scrollable.position.pixels, 0);
        expect(field.hasFocus, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        field.dispose();
        model.dispose();
      },
    );
    testWidgets(
      '${controls.runtimeType} tabs expose native activation and focus without implicit selection',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final model = WorkbenchModel(Directory('/unused'))
          ..draftRecovery = false
          ..newDocument()
          ..newDocument();
        final second = model.activeOwner;
        model.select(0);
        final first = model.activeOwner;
        final tabs = ListenableBuilder(
          listenable: model,
          builder: (_, _) =>
              WorkbenchTabs(model: model, controls: controls, close: (_) {}),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: tabs)
              : MaterialApp(home: Scaffold(body: tabs)),
        );
        final node = tester.getSemantics(find.bySemanticsLabel('Query 2'));
        expect(
          node.getSemanticsData().flagsCollection.isEnabled,
          ui.Tristate.isTrue,
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: ui.SemanticsAction.focus,
          ),
        );
        await tester.pump();
        expect(
          node.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        expect(model.activeOwner, same(first));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(model.activeOwner, same(second));
        expect(
          node.getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        model.dispose();
      },
    );
  }
}

class _TabModel extends WorkbenchModel {
  _TabModel() : super(Directory('/unused'));
  int activations = 0;
  @override
  void activateOwner(String id) {
    activations++;
    super.activateOwner(id);
  }
}
