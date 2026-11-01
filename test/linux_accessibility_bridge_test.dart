import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold, TextField;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/linux_accessibility_test_binding.dart';
import 'support/sql_editor_fixture.dart';

final _bridges = <LinuxAccessibilityBridge>{};
LinuxAccessibilityBridge _newBridge() {
  final bridge = LinuxAccessibilityBridge();
  _bridges.add(bridge);
  return bridge;
}

void _testWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final bridge in _bridges) {
        bridge.dispose();
      }
      _bridges.clear();
      await tester.pump();
    }
  });
}

class _Tree {
  _Tree() {
    owner = SemanticsOwner(onSemanticsUpdate: (update) => update.dispose());
    root = SemanticsNode.root(owner: owner)
      ..rect = const Rect.fromLTWH(0, 0, 400, 300);
  }
  late final SemanticsOwner owner;
  late final SemanticsNode root;
  SemanticsNode child(
    SemanticsConfiguration config, {
    List<SemanticsNode> children = const [],
  }) {
    final node = SemanticsNode()..rect = const Rect.fromLTWH(3, 5, 40, 20);
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: children.reversed.toList(),
    );
    return node;
  }

  void children(List<SemanticsNode> nodes) {
    root.updateWith(
      config: SemanticsConfiguration()..textDirection = TextDirection.ltr,
      childrenInInversePaintOrder: nodes.reversed.toList(),
    );
  }

  Map<String, Object?> capture() => LinuxAccessibilityProjection.capture(
    owner: owner,
    root: root,
    bridgeEpoch: 7,
    viewId: 0,
    ownerEpoch: 1,
    revision: 1,
    viewSize: const Size(400, 300),
  ).message;
  void dispose() => owner.dispose();
}

class _Native {
  final channel = const MethodChannel('io.busystack.busydata/accessibility');
  final messages = <MethodCall>[];
  var epoch = 6;
  Completer<Map<String, Object?>>? delayedPublish;
  Future<void> Function(Map snapshot)? beforePublishAck;
  String publishStatus = 'ok';
  bool failPublish = false;
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          messages.add(call);
          if (call.method == 'attach') ++epoch;
          if (call.method == 'publish') {
            if (failPublish) {
              throw PlatformException(code: 'unavailable');
            }
            await beforePublishAck?.call(call.arguments as Map);
            if (publishStatus != 'ok') {
              return {
                'version': 1,
                'status': publishStatus,
                'bridgeEpoch': epoch,
              };
            }
          }
          if (call.method == 'publish' && delayedPublish != null) {
            return delayedPublish!.future;
          }
          return {'version': 1, 'status': 'ok', 'bridgeEpoch': epoch};
        });
  }

  void dispose() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
  Map get snapshot =>
      messages.lastWhere((call) => call.method == 'publish').arguments as Map;
  Map request(Map node, String action, [Object? args]) => {
    for (final key in [
      'version',
      'bridgeEpoch',
      'viewId',
      'ownerEpoch',
      'revision',
    ])
      key: snapshot[key],
    'nodeId': node['id'],
    'action': action,
    'args': args,
  };
  Map node(String identifier) => (snapshot['nodes'] as List)
      .cast<Map>()
      .singleWhere((node) => node['identifier'] == identifier);
}

class _SelectionSemantics extends SingleChildRenderObjectWidget {
  const _SelectionSemantics({
    super.key,
    required this.properties,
    required this.selection,
    required super.child,
  });
  final SemanticsProperties properties;
  final TextSelection selection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SelectionSemanticsRender(
        properties,
        selection,
        Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _SelectionSemanticsRender render,
  ) {
    render
      ..properties = properties
      ..textDirection = Directionality.of(context);
    render.updateSelection(selection);
  }
}

class _SelectionSemanticsRender extends RenderSemanticsAnnotations {
  _SelectionSemanticsRender(
    SemanticsProperties properties,
    this._selection,
    TextDirection direction,
  ) : super(properties: properties, textDirection: direction, container: true);
  TextSelection _selection;

  void updateSelection(TextSelection selection) {
    if (_selection == selection) return;
    _selection = selection;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.textSelection = _selection;
  }
}

Future<void> _settle(
  WidgetTester tester,
  LinuxAccessibilityBridge bridge,
) async {
  await tester.pump();
  await bridge.synchronize();
  await tester.pump();
  await bridge.synchronize();
}

void main() {
  LinuxAccessibilityTestBinding.ensureInitialized();
  _testWidgets('offscreen fields reveal before focus or exact text changes', (
    tester,
  ) async {
    final native = _Native()..install();
    final bridge = _newBridge();
    final scroll = ScrollController();
    final focus = FocusNode();
    final text = TextEditingController(text: 'original');
    addTearDown(() {
      native.dispose();
      scroll.dispose();
      focus.dispose();
      text.dispose();
    });
    bridge.start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 120,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const SizedBox(height: 600),
                    Semantics(
                      identifier: 'offscreen-field',
                      child: TextField(controller: text, focusNode: focus),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester, bridge);
    final hidden = native.node('offscreen-field');
    expect((hidden['flags'] as Map)['hidden'], isTrue);
    expect(hidden['actions'], contains('showOnScreen'));
    expect(hidden['actions'], isNot(contains('focus')));
    expect(hidden['actions'], isNot(contains('setText')));
    final reveal = native.request(hidden, 'showOnScreen');
    expect(
      (await bridge.dispatchAction(native.request(hidden, 'focus')))['status'],
      'unavailable',
    );
    expect(
      (await bridge.dispatchAction(
        native.request(hidden, 'setText', 'wrong'),
      ))['status'],
      'unavailable',
    );
    expect(text.text, 'original');
    expect(focus.hasFocus, isFalse);
    expect((await bridge.dispatchAction(reveal))['status'], 'ok');
    await _settle(tester, bridge);
    expect(scroll.offset, greaterThan(0));
    final visible = native.node('offscreen-field');
    expect((visible['flags'] as Map)['hidden'], isFalse);
    expect((await bridge.dispatchAction(reveal))['status'], 'stale');
    expect(
      (await bridge.dispatchAction(native.request(visible, 'focus')))['status'],
      'ok',
    );
    await _settle(tester, bridge);
    expect(focus.hasFocus, isTrue);
    expect(text.text, 'original');
  });

  test('disabled hidden controls do not acquire reveal or edit permission', () {
    final tree = _Tree();
    addTearDown(tree.dispose);
    tree.children([
      tree.child(
        SemanticsConfiguration()
          ..identifier = 'disabled-hidden'
          ..isHidden = true
          ..isEnabled = false
          ..isTextField = true
          ..onSetText = (_) {},
      ),
    ]);
    final node = (tree.capture()['nodes'] as List).cast<Map>().singleWhere(
      (node) => node['identifier'] == 'disabled-hidden',
    );
    expect(node['actions'], isNot(contains('showOnScreen')));
    expect(node['actions'], isNot(contains('setText')));
  });

  test(
    'projection preserves exact UTF16 and owns immutable presentation only',
    () {
      final tree = _Tree();
      addTearDown(tree.dispose);
      final config = SemanticsConfiguration()
        ..textDirection = TextDirection.ltr
        ..isTextField = true
        ..value = '😀日\r\n'
        ..textSelection = const TextSelection(baseOffset: 2, extentOffset: 3)
        ..onSetSelection = (_) {};
      final child = tree.child(config);
      tree.children([child]);
      final message = tree.capture(), nodes = tree.capture()['nodes'] as List;
      final node = nodes.cast<Map>().singleWhere((n) => n['id'] == child.id);
      expect(node['value'], '😀日\r\n');
      expect(node['selectionBase'], 2);
      expect(node['selectionExtent'], 3);
      expect(node['rect'], [3.0, 5.0, 40.0, 20.0]);
      expect(() => message['revision'] = 99, throwsUnsupportedError);
      expect(() => node['value'] = 'changed', throwsUnsupportedError);
      expect(() => (node['children'] as List).add(99), throwsUnsupportedError);
    },
  );

  test(
    'public obscured presentation is always masked and cannot advertise copy or cut',
    () {
      final tree = _Tree();
      addTearDown(tree.dispose);
      final config = SemanticsConfiguration()
        ..textDirection = TextDirection.ltr
        ..identifier = 'password'
        ..isTextField = true
        ..isObscured = true
        ..value = 'private😀'
        ..onCopy = () {}
        ..onCut = () {}
        ..onPaste = () {}
        ..onSetText = (_) {};
      tree.children([tree.child(config)]);
      final message = tree.capture();
      final node = (message['nodes'] as List).cast<Map>().singleWhere(
        (n) => n['identifier'] == 'password',
      );
      expect(node['value'], '•' * 'private😀'.length);
      expect(jsonEncode(message), isNot(contains('private😀')));
      expect(node['actions'], containsAll(['paste', 'setText']));
      expect(node['actions'], isNot(contains('copy')));
      expect(node['actions'], isNot(contains('cut')));
    },
  );

  for (final (value, status) in [
    ('a\u0000b', 'unavailable-nul'),
    (String.fromCharCode(0xd800), 'unavailable-encoding'),
  ]) {
    test(
      'nonrepresentable semantics is explicitly $status without changing UI text',
      () {
        final tree = _Tree();
        addTearDown(tree.dispose);
        final node = tree.child(
          SemanticsConfiguration()
            ..textDirection = TextDirection.ltr
            ..isTextField = true
            ..value = value
            ..onSetText = (_) {},
        );
        tree.children([node]);
        final projected = (tree.capture()['nodes'] as List)
            .cast<Map>()
            .singleWhere((n) => n['id'] == node.id);
        expect(projected['textStatus'], status);
        expect(projected['value'], '');
        expect(projected['actions'], isNot(contains('setText')));
        expect(node.getSemanticsData().value, value);
      },
    );
  }

  test(
    'exact text limit is admitted and larger text is refused before serialization',
    () {
      final tree = _Tree();
      addTearDown(tree.dispose);
      final node = tree.child(
        SemanticsConfiguration()
          ..textDirection = TextDirection.ltr
          ..value = 'a' * LinuxAccessibilityBridge.maxTextUnits,
      );
      tree.children([node]);
      expect((tree.capture()['nodes'] as List).length, 2);
      node.updateWith(
        config: SemanticsConfiguration()
          ..textDirection = TextDirection.ltr
          ..value = 'a' * (LinuxAccessibilityBridge.maxTextUnits + 1),
      );
      expect(tree.capture, throwsA(isA<Exception>()));
    },
  );

  test(
    'depth and total node admission are bounded before building projected records',
    () {
      final tree = _Tree();
      addTearDown(tree.dispose);
      var node = tree.child(SemanticsConfiguration());
      for (var i = 0; i < LinuxAccessibilityBridge.maxDepth; ++i) {
        node = tree.child(SemanticsConfiguration(), children: [node]);
      }
      tree.children([node]);
      expect(tree.capture, throwsA(isA<Exception>()));
      tree.children([
        for (var i = 0; i < LinuxAccessibilityBridge.maxNodes; ++i)
          tree.child(SemanticsConfiguration()),
      ]);
      expect(tree.capture, throwsA(isA<Exception>()));
    },
  );

  test(
    'merged public semantics is exposed once with no duplicate descendant nodes',
    () {
      final tree = _Tree();
      addTearDown(tree.dispose);
      final leaf = tree.child(
        SemanticsConfiguration()
          ..textDirection = TextDirection.ltr
          ..label = 'child',
      );
      final parent = tree.child(
        SemanticsConfiguration()
          ..textDirection = TextDirection.ltr
          ..isSemanticBoundary = true
          ..isMergingSemanticsOfDescendants = true
          ..label = 'parent',
        children: [leaf],
      );
      tree.children([parent]);
      tree.owner.sendSemanticsUpdate();
      final nodes = tree.capture()['nodes'] as List;
      expect(nodes.length, 2);
      expect(
        nodes.cast<Map>().singleWhere((n) => n['id'] == parent.id)['label'],
        contains('child'),
      );
      expect(nodes.cast<Map>().any((n) => n['id'] == leaf.id), isFalse);
    },
  );

  _testWidgets(
    'native actions require exact current bridge, owner, revision and node',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var taps = 0;
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'button',
            button: true,
            onTap: () => ++taps,
            child: const SizedBox(width: 40, height: 20),
          ),
        ),
      );
      await _settle(tester, bridge);
      final node = native.node('button'),
          request = native.request(native.node('button'), 'tap');
      for (final key in [
        'bridgeEpoch',
        'viewId',
        'ownerEpoch',
        'revision',
        'nodeId',
      ]) {
        final stale = {...request, key: (request[key] as int) + 100};
        expect((await bridge.dispatchAction(stale))['status'], 'stale');
      }
      expect(taps, 0);
      expect(
        (await bridge.dispatchAction(native.request(node, 'tap')))['status'],
        'ok',
      );
      expect(taps, 1);
      expect(
        (await bridge.dispatchAction({...request, 'version': 2}))['status'],
        'malformed',
      );
      expect(
        (await bridge.dispatchAction({...request, 'version': 1.0}))['status'],
        'malformed',
      );
      expect(
        (await bridge.dispatchAction(
          native.request(node, 'unknown'),
        ))['status'],
        'malformed',
      );
      expect(
        (await bridge.dispatchAction({...request, 'viewId': 0.0}))['status'],
        'malformed',
      );
    },
  );

  _testWidgets(
    'retired semantics identity cannot invoke replacement callbacks',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var old = 0, fresh = 0;
      bridge.start();
      Widget view(Key key, VoidCallback action) => Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(
          key: key,
          identifier: 'target',
          onTap: action,
          child: const SizedBox(width: 20, height: 20),
        ),
      );
      await tester.pumpWidget(view(const ValueKey('a'), () => ++old));
      await _settle(tester, bridge);
      final request = native.request(native.node('target'), 'tap');
      await tester.pumpWidget(view(const ValueKey('b'), () => ++fresh));
      await _settle(tester, bridge);
      expect((await bridge.dispatchAction(request))['status'], 'stale');
      expect(old, 0);
      expect(fresh, 0);
    },
  );

  _testWidgets(
    'Unicode insertion follows explicit UTF16 intent and guarded public callbacks',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var text = '😀日',
          selection = const TextSelection.collapsed(offset: 2),
          edits = 0;
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, update) => Semantics(
              identifier: 'edit',
              textField: true,
              value: text,
              onSetText: (value) => update(() {
                text = value;
                ++edits;
              }),
              onSetSelection: (range) => update(() => selection = range),
              child: const SizedBox(width: 100, height: 20),
            ),
          ),
        ),
      );
      await _settle(tester, bridge);
      final request = native.request(native.node('edit'), 'insertText', {
        'start': 2,
        'end': 2,
        'text': '🧪',
      });
      final result = bridge.dispatchAction(request);
      await tester.pump();
      await _settle(tester, bridge);
      expect((await result)['status'], 'ok');
      expect(text, '😀🧪日');
      expect(selection.extentOffset, 4);
      expect(edits, 1);
    },
  );

  _testWidgets(
    'production SQL insertion and deletion preserve identity through changing caret labels',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      final editor = SqlEditorController.fromText('😀日');
      editor.selectOffsets(2, 2);
      addTearDown(() {
        bridge.dispose();
        native.dispose();
        editor.dispose();
      });
      const title = 'SQL editor Query 1';
      bridge.start();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 300,
              child: SqlEditorTestView(
                controller: editor,
                semanticLabel: title,
                autofocus: false,
              ),
            ),
          ),
        ),
      );
      await _settle(tester, bridge);
      Map field() => (native.snapshot['nodes'] as List).cast<Map>().singleWhere(
        (node) => (node['label'] as String).startsWith('$title\n'),
      );
      final original = field();
      final insert = bridge.dispatchAction(
        native.request(original, 'insertText', {
          'start': 2,
          'end': 2,
          'text': '🧪',
        }),
      );
      await _settle(tester, bridge);
      expect((await insert)['status'], 'ok');
      await _settle(tester, bridge);
      expect(editor.text, '😀🧪日');
      expect(editor.offsetForPosition(editor.selection.extent), 4);
      final inserted = field();
      expect(inserted['id'], original['id']);
      expect(inserted['label'], isNot(original['label']));
      final l = strings(tester.element(find.byType(WorkbenchSqlEditor)));
      expect(inserted['label'], '$title\n${l.sqlVisibleLine(1, 1, 5)}');
      final delete = bridge.dispatchAction(
        native.request(inserted, 'deleteRange', {
          'start': 0,
          'end': 2,
          'text': '',
        }),
      );
      await _settle(tester, bridge);
      expect((await delete)['status'], 'ok');
      await _settle(tester, bridge);
      expect(editor.text, '🧪日');
      expect(editor.offsetForPosition(editor.selection.extent), 0);
      expect(field()['id'], original['id']);
      expect(field()['label'], '$title\n${l.sqlVisibleLine(1, 1, 1)}');
      editor.undo();
      expect(editor.text, '😀🧪日');
      editor.undo();
      expect(editor.text, '😀日');
      expect(editor.offsetForPosition(editor.selection.extent), 2);
      expect(editor.canUndo, isFalse);
    },
  );

  for (final action in ['copyRange', 'cutRange', 'pasteAt']) {
    _testWidgets(
      'clipboard $action permits its expected selection label change',
      (tester) async {
        final native = _Native()..install();
        final bridge = _newBridge();
        addTearDown(() {
          bridge.dispose();
          native.dispose();
        });
        var value = '😀日';
        var selection = const TextSelection.collapsed(offset: 0);
        var selections = 0, operations = 0;
        String? labelAtOperation, clipboard;
        bridge.start();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, update) {
                String label() =>
                    'SQL editor Clipboard\n${strings(context).sqlVisibleLine(1, 1, selection.extentOffset + 1)}';
                void record() {
                  operations++;
                  labelAtOperation = label();
                }

                return _SelectionSemantics(
                  selection: selection,
                  properties: SemanticsProperties(
                    identifier: 'clipboard',
                    textField: true,
                    enabled: true,
                    value: value,
                    label: label(),
                    onSetSelection: (range) => update(() {
                      selections++;
                      selection = range;
                    }),
                    onCopy: () {
                      record();
                      clipboard = value.substring(
                        selection.start,
                        selection.end,
                      );
                    },
                    onCut: () => update(() {
                      record();
                      clipboard = value.substring(
                        selection.start,
                        selection.end,
                      );
                      value = value.replaceRange(
                        selection.start,
                        selection.end,
                        '',
                      );
                      selection = TextSelection.collapsed(
                        offset: selection.start,
                      );
                    }),
                    onPaste: () => update(() {
                      record();
                      value = value.replaceRange(
                        selection.start,
                        selection.end,
                        '🧪',
                      );
                      selection = TextSelection.collapsed(
                        offset: selection.start + 2,
                      );
                    }),
                  ),
                  child: const SizedBox(width: 300, height: 40),
                );
              },
            ),
          ),
        );
        await _settle(tester, bridge);
        final before = native.node('clipboard');
        final result = bridge.dispatchAction(
          native.request(before, action, {
            'start': action == 'pasteAt' ? 2 : 0,
            'end': 2,
            'text': '',
          }),
        );
        await _settle(tester, bridge);
        expect((await result)['status'], 'ok');
        expect(selections, 1);
        expect(operations, 1);
        expect(labelAtOperation, isNot(before['label']));
        expect(
          value,
          action == 'cutRange'
              ? '日'
              : action == 'pasteAt'
              ? '😀🧪日'
              : '😀日',
        );
        expect(clipboard, action == 'pasteAt' ? isNull : '😀');
      },
    );
  }

  for (final mutation in [
    'replacement',
    'identifier',
    'role',
    'value',
    'protected',
    'permission',
  ]) {
    _testWidgets(
      'compound selection rejects a changed $mutation before copying',
      (tester) async {
        final native = _Native()..install();
        final bridge = _newBridge();
        addTearDown(() {
          bridge.dispose();
          native.dispose();
        });
        var changed = false, copied = 0;
        var selection = const TextSelection.collapsed(offset: 0);
        bridge.start();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, update) => _SelectionSemantics(
                key: ValueKey(changed && mutation == 'replacement'),
                selection: selection,
                properties: SemanticsProperties(
                  identifier: changed && mutation == 'identifier'
                      ? 'replacement'
                      : 'edit',
                  role: changed && mutation == 'role'
                      ? ui.SemanticsRole.form
                      : ui.SemanticsRole.none,
                  textField: true,
                  enabled: true,
                  obscured: changed && mutation == 'protected',
                  value: changed && mutation == 'value' ? 'unexpected' : '😀日',
                  label: 'SQL selection ${selection.extentOffset}',
                  onSetSelection: (range) => update(() {
                    selection = range;
                    changed = true;
                  }),
                  onCopy: changed && mutation == 'permission'
                      ? null
                      : () => copied++,
                ),
                child: const SizedBox(width: 300, height: 40),
              ),
            ),
          ),
        );
        await _settle(tester, bridge);
        final result = bridge.dispatchAction(
          native.request(native.node('edit'), 'copyRange', {
            'start': 0,
            'end': 2,
            'text': '',
          }),
        );
        await _settle(tester, bridge);
        expect(
          (await result)['status'],
          mutation == 'protected' || mutation == 'permission'
              ? 'unavailable'
              : 'stale',
        );
        await tester.pump(const Duration(seconds: 3));
        expect(copied, 0);
      },
    );
  }

  _testWidgets(
    'capture overflow retires the previous available native presentation',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      bridge.start();
      Widget view(String value) => Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(
          identifier: 'text',
          value: value,
          child: const SizedBox(width: 30, height: 20),
        ),
      );
      await tester.pumpWidget(view('short'));
      await _settle(tester, bridge);
      final previous = native.request(native.node('text'), 'tap');
      await tester.pumpWidget(
        view('x' * (LinuxAccessibilityBridge.maxTextUnits + 1)),
      );
      await _settle(tester, bridge);
      expect(native.snapshot['status'], 'limited');
      expect(native.snapshot['rootId'], -1);
      expect(native.snapshot['nodes'], isEmpty);
      expect((await bridge.dispatchAction(previous))['status'], 'stale');
    },
  );

  _testWidgets(
    'disposed bridge rejects actions and sends an epoch-owned detach',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'text',
            child: SizedBox(width: 30, height: 20),
          ),
        ),
      );
      await _settle(tester, bridge);
      final request = native.request(native.node('text'), 'tap');
      bridge.dispose();
      await tester.pump();
      expect((await bridge.dispatchAction(request))['status'], 'disposed');
      expect(native.messages.last.method, 'detach');
      expect((native.messages.last.arguments as Map)['bridgeEpoch'], 7);
    },
  );

  _testWidgets(
    'bounded pending actions retire without executing after owner disposal',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var copied = 0;
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'edit',
            textField: true,
            value: 'ab',
            onSetSelection: (_) {},
            onCopy: () => ++copied,
            child: const SizedBox(width: 100, height: 20),
          ),
        ),
      );
      await _settle(tester, bridge);
      final request = native.request(native.node('edit'), 'copyRange', {
        'start': 0,
        'end': 1,
        'text': '',
      });
      expect(
        (await bridge.dispatchAction(
          native.request(native.node('edit'), 'copyRange', {
            'start': 1,
            'end': 1,
            'text': '',
          }),
        ))['status'],
        'unavailable',
      );
      final pending = [
        for (var i = 0; i < LinuxAccessibilityBridge.maxPendingActions; ++i)
          bridge.dispatchAction(request),
      ];
      expect((await bridge.dispatchAction(request))['status'], 'limited');
      expect(copied, 0);
      bridge.dispose();
      expect(
        (await Future.wait(
          pending,
        )).every((reply) => reply['status'] == 'disposed'),
        isTrue,
      );
      expect(copied, 0);
    },
  );

  _testWidgets(
    'missing native bridge remains explicitly unavailable with original widget state',
    (tester) async {
      const channel = MethodChannel('io.busystack.busydata/accessibility');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw MissingPluginException(),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final bridge = _newBridge();
      addTearDown(bridge.dispose);
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'draft',
            value: 'retained draft',
            child: SizedBox(width: 50, height: 20),
          ),
        ),
      );
      await _settle(tester, bridge);
      expect(bridge.status, 'unavailable');
      final node = tester.getSemantics(find.bySemanticsIdentifier('draft'));
      expect(node.getSemanticsData().value, 'retained draft');
      expect((await bridge.dispatchAction({}))['status'], 'malformed');
    },
  );

  _testWidgets(
    'native version mismatch cannot publish or fall back to upstream accessibility',
    (tester) async {
      const channel = MethodChannel('io.busystack.busydata/accessibility');
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            return {'version': 2, 'status': 'ok', 'bridgeEpoch': 7};
          });
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'draft',
            value: 'retained',
            child: SizedBox(width: 30, height: 20),
          ),
        ),
      );
      await _settle(tester, bridge);
      expect(bridge.status, 'unavailable');
      expect(methods, ['attach']);
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('draft'))
            .getSemanticsData()
            .value,
        'retained',
      );
    },
  );

  _testWidgets(
    'physical semantics transforms are normalized to logical view geometry',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      bridge.start();
      const target = ValueKey('bounds');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 12,
                top: 20,
                child: Semantics(
                  key: target,
                  identifier: 'bounds',
                  container: true,
                  child: const SizedBox(width: 100, height: 30),
                ),
              ),
            ],
          ),
        ),
      );
      await _settle(tester, bridge);
      final rect = tester.getRect(find.byKey(target));
      expect(native.node('bounds')['rect'], [
        rect.left,
        rect.top,
        rect.width,
        rect.height,
      ]);
      expect(native.snapshot['viewWidth'], 400);
      expect(native.snapshot['viewHeight'], 300);
    },
  );

  _testWidgets(
    'scope replacement retires the old epoch while the new channel owner remains callable',
    (tester) async {
      final native = _Native()..install();
      addTearDown(native.dispose);
      var tapped = 0;
      Widget scope(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: LinuxAccessibilityBridgeScope(
          key: ValueKey(key),
          child: Semantics(
            identifier: 'draft',
            value: 'draft retained',
            onTap: () => ++tapped,
            child: const SizedBox(width: 100, height: 20),
          ),
        ),
      );
      await tester.pumpWidget(scope('a'));
      await tester.pump();
      await tester.pump();
      final old = native.snapshot['bridgeEpoch'];
      await tester.pumpWidget(scope('b'));
      await tester.pump();
      await tester.pump();
      expect(native.snapshot['bridgeEpoch'], greaterThan(old as int));
      expect(native.node('draft')['value'], 'draft retained');
      expect(
        native.messages.any(
          (call) =>
              call.method == 'detach' &&
              (call.arguments as Map)['bridgeEpoch'] == old,
        ),
        isTrue,
      );
      final request = native.request(native.node('draft'), 'tap');
      final reply = await tester.runAsync(() async {
        final result = Completer<Object?>();
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          native.channel.name,
          native.channel.codec.encodeMethodCall(MethodCall('action', request)),
          (data) => result.complete(
            data == null ? null : native.channel.codec.decodeEnvelope(data),
          ),
        );
        return result.future.timeout(const Duration(seconds: 2));
      });
      expect((reply as Map)['status'], 'ok');
      expect(tapped, 1);
    },
  );

  _testWidgets(
    'expired selection sequencing never executes its later copy action',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var copied = 0;
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'edit',
            textField: true,
            value: 'ab',
            onSetSelection: (_) {},
            onCopy: () => ++copied,
            child: const SizedBox(width: 100, height: 20),
          ),
        ),
      );
      await _settle(tester, bridge);
      final result = bridge.dispatchAction(
        native.request(native.node('edit'), 'copyRange', {
          'start': 0,
          'end': 1,
          'text': '',
        }),
      );
      await tester.pump(const Duration(seconds: 3));
      expect((await result)['status'], 'cancelled');
      await tester.pump();
      expect(copied, 0);
    },
  );

  _testWidgets(
    'a pending compound action rechecks newly hidden field permissions',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var copied = 0, hidden = false;
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, update) => Semantics(
              identifier: 'edit',
              textField: true,
              value: 'ab',
              hidden: hidden,
              onSetSelection: (_) => update(() => hidden = true),
              onCopy: () => ++copied,
              child: const SizedBox(width: 100, height: 20),
            ),
          ),
        ),
      );
      await _settle(tester, bridge);
      Map<String, Object?>? outcome;
      final result = bridge.dispatchAction(
        native.request(native.node('edit'), 'copyRange', {
          'start': 0,
          'end': 1,
          'text': '',
        }),
      );
      unawaited(result.then((reply) => outcome = reply));
      await tester.pump();
      expect(
        outcome,
        isNotNull,
        reason:
            'Retired permissions must be rejected without waiting for the action deadline',
      );
      expect(outcome!['status'], anyOf('stale', 'unavailable'));
      await tester.pump(const Duration(seconds: 3));
      expect(copied, 0);
    },
  );

  _testWidgets(
    'native-installed candidate dispatches once before acknowledgment without obsolete guards',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var oldTaps = 0, freshTaps = 0;
      bridge.start();
      Widget view(String key, VoidCallback tap) => Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(
          key: ValueKey(key),
          identifier: 'target',
          value: key,
          onTap: tap,
          child: const SizedBox(width: 100, height: 20),
        ),
      );
      await tester.pumpWidget(view('old', () => ++oldTaps));
      await _settle(tester, bridge);
      expect(bridge.currentNodeCount, greaterThan(0));
      final stale = native.request(native.node('target'), 'tap');
      final acknowledgment = Completer<Map<String, Object?>>();
      native.delayedPublish = acknowledgment;
      Map<String, Object?>? admitted;
      native.beforePublishAck = (snapshot) async {
        expect(snapshot['status'], 'ok');
        admitted = await bridge.dispatchAction(
          native.request(native.node('target'), 'tap'),
        );
      };
      await tester.pumpWidget(view('fresh', () => ++freshTaps));
      await tester.pump();
      expect(
        bridge.currentNodeCount,
        0,
        reason:
            'Old node callback guards must retire when the public tree changes, before native acknowledgment',
      );
      expect((await bridge.dispatchAction(stale))['status'], 'stale');
      expect(admitted?['status'], 'ok');
      expect(oldTaps, 0);
      expect(freshTaps, 1);
      native.beforePublishAck = null;
      native.delayedPublish = null;
      acknowledgment.complete({
        'version': 1,
        'status': 'ok',
        'bridgeEpoch': native.epoch,
      });
      await _settle(tester, bridge);
      expect(bridge.currentNodeCount, greaterThan(0));
      expect(freshTaps, 1);
      expect(oldTaps, 0);
    },
  );

  _testWidgets(
    'semantic changes retire an issued candidate before its acknowledgment',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      var previous = 0, latest = 0;
      bridge.start();
      Widget view(String name, VoidCallback action) => Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(
          key: ValueKey(name),
          identifier: 'target',
          value: name,
          onTap: action,
          child: const SizedBox(width: 100, height: 20),
        ),
      );
      await tester.pumpWidget(view('first', () => ++previous));
      await _settle(tester, bridge);
      final ack = Completer<Map<String, Object?>>();
      native.delayedPublish = ack;
      await tester.pumpWidget(view('issued', () => ++previous));
      await tester.pump();
      final obsolete = native.request(native.node('target'), 'tap');
      await tester.pumpWidget(view('latest', () => ++latest));
      await tester.pump();
      expect((await bridge.dispatchAction(obsolete))['status'], 'stale');
      expect(previous, 0);
      native.delayedPublish = null;
      ack.complete({'version': 1, 'status': 'ok', 'bridgeEpoch': native.epoch});
      await _settle(tester, bridge);
      expect(
        (await bridge.dispatchAction(
          native.request(native.node('target'), 'tap'),
        ))['status'],
        'ok',
      );
      expect(latest, 1);
      expect(previous, 0);
    },
  );

  for (final failed in [false, true]) {
    _testWidgets(
      'a ${failed ? 'failed' : 'denied'} publication cannot authorize later native actions',
      (tester) async {
        final native = _Native()
          ..publishStatus = (failed ? 'ok' : 'malformed')
          ..failPublish = failed
          ..install();
        final bridge = _newBridge();
        addTearDown(() {
          bridge.dispose();
          native.dispose();
        });
        var tapped = 0;
        bridge.start();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Semantics(
              identifier: 'target',
              onTap: () => ++tapped,
              child: const SizedBox(width: 100, height: 20),
            ),
          ),
        );
        await _settle(tester, bridge);
        expect(bridge.status, 'unavailable');
        expect(bridge.currentNodeCount, 0);
        expect(
          (await bridge.dispatchAction(
            native.request(native.node('target'), 'tap'),
          ))['status'],
          'stale',
        );
        expect(tapped, 0);
      },
    );
  }

  _testWidgets(
    'native exact Unicode setText dispatches once before the publication reply',
    (tester) async {
      final native = _Native()..install();
      final bridge = _newBridge();
      addTearDown(() {
        bridge.dispose();
        native.dispose();
      });
      const replacement = '😀日\r\n🧪';
      var text = 'original', edits = 0, injected = false;
      Map<String, Object?>? dispatched;
      final reply = Completer<Map<String, Object?>>();
      native.beforePublishAck = (snapshot) async {
        if (injected || snapshot['status'] != 'ok') return;
        final nodes = (snapshot['nodes'] as List).cast<Map>().where(
          (node) => node['identifier'] == 'edit',
        );
        if (nodes.isEmpty) return;
        injected = true;
        native.delayedPublish = reply;
        dispatched = await bridge.dispatchAction(
          native.request(nodes.single, 'setText', replacement),
        );
      };
      bridge.start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, update) => Semantics(
              identifier: 'edit',
              textField: true,
              multiline: true,
              enabled: true,
              value: text,
              onSetText: (value) => update(() {
                text = value;
                ++edits;
              }),
              child: const SizedBox(width: 100, height: 20),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(dispatched?['status'], 'ok');
      expect(text, replacement);
      expect(edits, 1);
      expect(bridge.currentNodeCount, 0);
      native.delayedPublish = null;
      reply.complete({
        'version': 1,
        'status': 'ok',
        'bridgeEpoch': native.epoch,
      });
      await _settle(tester, bridge);
      expect(native.node('edit')['value'], replacement);
      expect(
        edits,
        1,
        reason: 'Publication acknowledgment must never replay an edit',
      );
    },
  );
}
