import 'dart:convert';

import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map> _projection(WidgetTester tester) {
  final RenderView view = tester.binding.renderViews.single;
  final owner = view.owner!.semanticsOwner!;
  final message = LinuxAccessibilityProjection.capture(
    owner: owner,
    root: owner.rootSemanticsNode!,
    bridgeEpoch: 1,
    viewId: view.flutterView.viewId,
    ownerEpoch: 1,
    revision: 1,
    viewSize: view.size,
    devicePixelRatio: view.flutterView.devicePixelRatio,
  ).message;
  return (message['nodes'] as List).cast<Map>();
}

void main() {
  testWidgets(
    'Fluent value popup retires the dialog projection while preserving the same editor state',
    (tester) async {
      const controls = WindowsControls();
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      try {
        final bytes = utf8.encode('漢' * 30000);
        final offsets = <int>[];
        var staged = 0;
        await tester.pumpWidget(
          fluent.FluentApp(
            home: Builder(
              builder: (context) => Center(
                child: controls.button('Inspect exact record', () async {
                  await controls.dialog<void>(
                    context,
                    'body · text',
                    ResultValueEditor(
                      controls: controls,
                      value: rpc.Value(
                        text: '漢' * 1024,
                        truncated: true,
                        valueId: 'retained-value',
                        originalBytes: Int64(bytes.length),
                      ),
                      column: rpc.Column(name: 'body', typeName: 'text'),
                      cancelRead: () {},
                      retainDraft: (_, _) {},
                      readChunk: (offset) async {
                        offsets.add(offset);
                        final end = (offset + 65536).clamp(0, bytes.length);
                        return rpc.ValueChunk(
                          data: bytes.sublist(offset, end),
                          totalBytes: Int64(bytes.length),
                          complete: end == bytes.length,
                        );
                      },
                      stage: (_) async {
                        staged++;
                      },
                    ),
                    [
                      controls.button(
                        'Close',
                        () => Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Inspect exact record'));
        await tester.pumpAndSettle();
        final editorState = tester.state(find.byType(ResultValueEditor));
        final original = _projection(tester).singleWhere(
          (node) => node['role'] == 'dialog' && node['label'] == 'body · text',
        );
        final instance = _projection(tester).singleWhere(
          (node) => (node['identifier'] as String).startsWith(
            'busydata.value.editor.v1.',
          ),
        )['identifier'];
        expect(
          instance,
          matches(
            r'^busydata\.value\.editor\.v1\.[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        );
        expect(offsets, isEmpty);
        await tester.tap(find.text('Value actions'));
        await tester.pumpAndSettle();
        final popup = _projection(tester);
        expect(
          popup.any((node) => node['id'] == original['id']),
          isFalse,
          reason: 'A blocked background cannot preserve its native handle.',
        );
        expect(tester.state(find.byType(ResultValueEditor)), same(editorState));
        expect(popup.any((node) => node['identifier'] == instance), isFalse);
        expect(offsets, isEmpty);
        await tester.tap(find.text('Edit complete value'));
        await tester.pumpAndSettle();
        final restored = _projection(tester);
        expect(
          restored.where(
            (node) =>
                node['role'] == 'dialog' && node['label'] == 'body · text',
          ),
          hasLength(1),
        );
        expect(tester.state(find.byType(ResultValueEditor)), same(editorState));
        expect(
          restored.where((node) => node['identifier'] == instance),
          hasLength(1),
        );
        expect(find.text('Text page 1 of 2'), findsOneWidget);
        final input = tester.widget<EditableText>(
          find.byWidgetPredicate(
            (widget) => widget is EditableText && !widget.readOnly,
          ),
        );
        expect(input.controller.text, '漢' * 16384);
        expect(offsets, [0, 65536]);
        expect(staged, 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspect exact record'));
        await tester.pumpAndSettle();
        final replacement = _projection(tester).singleWhere(
          (node) => (node['identifier'] as String).startsWith(
            'busydata.value.editor.v1.',
          ),
        )['identifier'];
        expect(replacement, isNot(instance));
        expect(
          tester.state(find.byType(ResultValueEditor)),
          isNot(same(editorState)),
        );
        expect(offsets, [0, 65536]);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      }
    },
  );
}
