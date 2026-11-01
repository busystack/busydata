import 'dart:ui' as ui;

import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/linux_accessibility_test_binding.dart';

void main() {
  final binding = LinuxAccessibilityTestBinding.ensureInitialized();

  test('owned startup accepts the same explicit output binding repeatedly', () {
    expect(LinuxAccessibilityBinding.ensureInitialized(), same(binding));
    expect(LinuxAccessibilityBinding.ensureInitialized(), same(binding));
    expect(
      binding.createSemanticsUpdateBuilder(),
      isA<LinuxAccessibilityUpdateBuilder>(),
    );
  });

  test(
    'builder produces a genuine one-use native update without retaining input',
    () {
      final builder = LinuxAccessibilityUpdateBuilder();
      builder.updateCustomAction(
        id: 9,
        label: 'Owned action',
        hint: 'Run action',
      );
      final update = builder.build();
      // FlutterView performs the engine's concrete native-update type check.
      // This verifies that build did not return a fabricated opaque wrapper.
      ui.PlatformDispatcher.instance.implicitView!.updateSemantics(update);
      update.dispose();
      expect(builder.build, throwsStateError);
      expect(() => builder.updateCustomAction(id: 10), throwsStateError);
    },
  );

  test(
    'native output routing leaves full owner nodes, listeners and actions live',
    () {
      var updates = 0;
      var notifications = 0;
      var taps = 0;
      var customActions = 0;
      String? replacement;
      final owner = SemanticsOwner(
        onSemanticsUpdate: (update) {
          updates++;
          ui.PlatformDispatcher.instance.implicitView!.updateSemantics(update);
          update.dispose();
        },
      );
      owner.addListener(() => notifications++);
      final root = SemanticsNode.root(owner: owner)
        ..rect = const Rect.fromLTWH(0, 0, 400, 300);
      final search = SemanticsNode()..rect = const Rect.fromLTWH(0, 0, 100, 20);
      search.updateWith(
        config: SemanticsConfiguration()
          ..textDirection = TextDirection.ltr
          ..label = 'Search actions',
      );
      final action = CustomSemanticsAction(label: 'Owned action');
      final field = SemanticsNode()..rect = const Rect.fromLTWH(0, 30, 200, 30);
      field.updateWith(
        config: SemanticsConfiguration()
          ..textDirection = TextDirection.ltr
          ..identifier = 'owned-field'
          ..isTextField = true
          ..value = '日😀'
          ..onTap = () {
            taps++;
          }
          ..onSetText = (text) {
            replacement = text;
          }
          ..customSemanticsActions = {action: () => customActions++},
      );
      void publish(List<SemanticsNode> children) {
        root.updateWith(
          config: SemanticsConfiguration()..textDirection = TextDirection.ltr,
          childrenInInversePaintOrder: children.reversed.toList(),
        );
        owner.sendSemanticsUpdate();
      }

      try {
        publish([search, field]);
        expect(updates, 1);
        expect(notifications, 1);
        expect(owner.getSemanticsNode(search.id), same(search));
        expect(owner.getSemanticsNode(field.id), same(field));
        expect(field.getSemanticsData().value, '日😀');
        owner.performAction(field.id, ui.SemanticsAction.tap);
        owner.performAction(field.id, ui.SemanticsAction.setText, '日本🧪');
        owner.performAction(
          field.id,
          ui.SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(action),
        );
        expect(taps, 1);
        expect(replacement, '日本🧪');
        expect(customActions, 1);
        publish([field]);
        expect(updates, 2);
        expect(notifications, 2);
        expect(owner.getSemanticsNode(search.id), isNull);
        expect(owner.getSemanticsNode(field.id), same(field));
        final projected = LinuxAccessibilityProjection.capture(
          owner: owner,
          root: root,
          bridgeEpoch: 1,
          viewId: 0,
          ownerEpoch: 1,
          revision: 2,
          viewSize: const Size(400, 300),
        ).message;
        final nodes = (projected['nodes']! as List).cast<Map>();
        expect(nodes.any((node) => node['label'] == 'Search actions'), isFalse);
        final current = nodes.singleWhere(
          (node) => node['identifier'] == 'owned-field',
        );
        expect(current['value'], '日😀');
        expect(current['actions'], containsAll(['tap', 'setText']));
      } finally {
        owner.dispose();
      }
    },
  );

  testWidgets(
    'bridge still publishes full rendered presentation and dispatches its exact action',
    (tester) async {
      const channel = MethodChannel('io.busystack.busydata/accessibility');
      final messages = <MethodCall>[];
      String? replacement;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        messages.add(call);
        return {'version': 1, 'status': 'ok', 'bridgeEpoch': 1};
      });
      final bridge = LinuxAccessibilityBridge();
      try {
        bridge.start();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Semantics(
              identifier: 'owned-field',
              textField: true,
              value: '日😀',
              onSetText: (value) => replacement = value,
              child: const SizedBox(width: 300, height: 100),
            ),
          ),
        );
        await tester.pump();
        await bridge.synchronize();
        final snapshot =
            messages.lastWhere((call) => call.method == 'publish').arguments
                as Map;
        final node = (snapshot['nodes'] as List).cast<Map>().singleWhere(
          (node) => node['identifier'] == 'owned-field',
        );
        expect(node['value'], '日😀');
        expect(node['actions'], contains('setText'));
        final reply = await bridge.dispatchAction({
          for (final key in [
            'version',
            'bridgeEpoch',
            'viewId',
            'ownerEpoch',
            'revision',
          ])
            key: snapshot[key],
          'nodeId': node['id'],
          'action': 'setText',
          'args': '日本🧪',
        });
        expect(reply['status'], 'ok');
        expect(replacement, '日本🧪');
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      } finally {
        bridge.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      }
    },
  );
}
