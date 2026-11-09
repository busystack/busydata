import 'dart:async';
import 'dart:typed_data';

import 'package:busydata/src/ui/windows/windows_secret_field.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'native occlusion preserves complete tooltip text and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final message = List.generate(
        20,
        (i) => 'Long native field tooltip $i',
      ).join(' ');
      final span = WindowsSecretTooltipSpan(message);
      expect(span.toPlainText(), message);
      expect(span.toPlainText(includeSemanticsLabels: false), '\uFFFC');
      await tester.pumpWidget(
        FluentApp(
          home: Center(
            child: Tooltip(
              richMessage: span,
              child: Button(onPressed: () {}, child: const Text('Help')),
            ),
          ),
        ),
      );
      tester.state<TooltipState>(find.byType(Tooltip)).ensureTooltipVisible();
      await tester.pumpAndSettle();
      expect(find.text(message), findsWidgets);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(message).last,
      );
      // Selection boxes for trailing wrap whitespace can extend beyond the
      // paragraph. Check every actual visible glyph, without counting spaces.
      final boxes = [
        for (var i = 0; i < message.length; i++)
          if (message[i].trim().isNotEmpty)
            ...paragraph.getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            ),
      ];
      expect(boxes, isNotEmpty);
      expect(
        boxes.map((b) => b.bottom).reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(paragraph.size.height + .5),
      );
      expect(
        boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(paragraph.size.width + .5),
      );
      expect(find.bySemanticsLabel(message), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
  testWidgets(
    'native geometry and contrast refresh without resending the secret',
    (tester) async {
      const channel = MethodChannel(
        'org.busystack.busydata/windows_secret_input',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final configured = <Map>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'configure') configured.add(call.arguments as Map);
        return null;
      });
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: 'retained');
      var contrast = false;
      late StateSetter update;
      await tester.pumpWidget(
        FluentApp(
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(highContrast: contrast),
                child: Center(
                  child: SizedBox(
                    width: 320,
                    child: WindowsSecretField(
                      controller: controller,
                      label: 'Scaled password',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final baseline = configured.last;
      expect(baseline['highContrast'], isFalse);
      update(() => contrast = true);
      await tester.pumpAndSettle();
      expect(configured.last['highContrast'], isTrue);
      expect(configured.last.containsKey('utf16'), isFalse);
      tester.view
        ..physicalSize = const Size(1600, 1200)
        ..devicePixelRatio = 2;
      await tester.pumpAndSettle();
      final scaled = configured.last;
      for (final key in ['x', 'y', 'width', 'height', 'fontHeight']) {
        expect(scaled[key], (baseline[key] as int) * 2, reason: key);
      }
      expect(scaled['generation'], baseline['generation']);
      expect(scaled.containsKey('utf16'), isFalse);
      expect(controller.text, 'retained');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      controller.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
  testWidgets(
    'native fields own editing, reject stale owners, coalesce and dispose',
    (tester) async {
      const channel = MethodChannel(
        'org.busystack.busydata/windows_secret_input',
      );
      final calls = <MethodCall>[];
      Completer<void>? blocked;
      var reject = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'configure') {
          await blocked?.future;
          if (reject &&
              (call.arguments as Map)['utf16'] is Int32List &&
              ((call.arguments as Map)['utf16'] as Int32List).contains(0)) {
            throw PlatformException(code: 'unrepresentable_input');
          }
        }
        return null;
      });
      final first = TextEditingController(text: 'initial漢😀');
      final second = TextEditingController();
      final replacement = TextEditingController(text: 'replacement');
      final focus = FocusNode();
      var current = first, showFirst = true;
      late StateSetter update;
      await tester.pumpWidget(
        FluentApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return NavigationView(
                content: Column(
                  children: [
                    if (showFirst)
                      WindowsSecretField(
                        key: const ValueKey('first'),
                        controller: current,
                        label: 'First password',
                        focusNode: focus,
                      ),
                    WindowsSecretField(
                      key: const ValueKey('second'),
                      controller: second,
                      label: 'Second password',
                    ),
                    Button(onPressed: () {}, child: const Text('Next')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      var firstState =
          calls.where((c) => c.method == 'configure').first.arguments as Map;
      final owner = firstState['owner'];
      expect(owner, matches(RegExp(r'^[0-9a-f]{32}$')));
      // Initialization belongs to the isolate, not to each widget/test. A
      // previously mounted owner can already have initialized this endpoint.
      for (final call in calls.where((c) => c.method == 'initialize')) {
        expect((call.arguments as Map)['owner'], owner);
      }
      final id = firstState['id'];
      expect((firstState['utf16'] as Int32List), first.text.codeUnits);
      expect(firstState['label'], 'First password'.codeUnits);
      final editors = tester.widgetList<EditableText>(
        find.byType(EditableText),
      );
      expect(editors.length, 2);
      expect(
        editors.every(
          (e) => e.readOnly && e.obscureText && e.showCursor == false,
        ),
        isTrue,
      );

      Future<void> native(Map<String, Object?> event) async {
        final complete = Completer<void>();
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('editing', event),
          ),
          (_) => complete.complete(),
        );
        await complete.future;
      }

      Map<String, Object?> event(
        String sourceOwner,
        int generation,
        int serial,
        String text,
      ) => {
        'owner': sourceOwner,
        'id': id,
        'generation': generation,
        'serial': serial,
        'utf16': Int32List.fromList(text.codeUnits),
        'base': text.length,
        'extent': text.length,
      };
      await native(
        event(
          '00000000000000000000000000000000',
          firstState['generation'] as int,
          1,
          'wrong owner',
        ),
      );
      expect(first.text, 'initial漢😀');
      await native(
        event(owner as String, firstState['generation'] as int, 1, 'native漢😀'),
      );
      expect(first.text, 'native漢😀');
      expect(second.text, isEmpty);
      final oldGeneration = firstState['generation'] as int;
      update(() => current = replacement);
      await tester.pumpAndSettle();
      await native(event(owner, oldGeneration, 2, 'stale callback'));
      expect(replacement.text, 'replacement');
      first.text = 'detached';
      await tester.pumpAndSettle();
      firstState =
          calls
                  .lastWhere(
                    (c) =>
                        c.method == 'configure' &&
                        (c.arguments as Map)['id'] == id,
                  )
                  .arguments
              as Map;
      expect(firstState['utf16'], 'replacement'.codeUnits);

      // A slow native request cannot accumulate complete historical secrets.
      blocked = Completer<void>();
      replacement.text = 'blocked request';
      await tester.pump();
      final before = calls.length;
      for (var i = 0; i < 100; i++) {
        replacement.text = 'latest $i';
      }
      await tester.pump();
      expect(calls.length, before);
      blocked.complete();
      blocked = null;
      await tester.pumpAndSettle();
      final sent = calls
          .skip(before)
          .where((c) => c.method == 'configure')
          .toList();
      expect(sent.length, 1);
      expect((sent.single.arguments as Map)['utf16'], 'latest 99'.codeUnits);

      reject = true;
      replacement.text = 'a\u0000b';
      await tester.pumpAndSettle();
      expect(replacement.text.codeUnits, [97, 0, 98]);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .every((e) => e.readOnly && e.obscureText),
        isTrue,
      );
      reject = false;
      replacement.clear();
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNothing);
      update(() => showFirst = false);
      await tester.pumpAndSettle();
      expect(
        calls.any(
          (c) => c.method == 'dispose' && (c.arguments as Map)['id'] == id,
        ),
        isTrue,
      );
      await native(
        event(owner, (firstState['generation'] as int), 999, 'disposed'),
      );
      expect(replacement.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      first.dispose();
      second.dispose();
      replacement.dispose();
      focus.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
