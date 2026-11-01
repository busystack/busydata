import 'package:busydata/src/ui/linux/linux_appearance.dart';
import 'dart:io';
import 'package:busydata/src/ui/common/object_designer.dart';
import 'dart:math' as math;
import 'dart:ui' show SemanticsAction, Tristate;
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'support/presentation_fonts.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/schema_tools_view.dart';
import 'package:busydata/src/ui/common/snippet_view.dart';
import 'package:busydata/src/ui/common/transfer_document.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

const controls = LinuxControls();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPresentationFonts);

  testWidgets(
    'Linux selector button names include the field and selected value',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const nativeMenus = MethodChannel(nativeMenuChannelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        nativeMenus,
        (call) async => call.method == 'show' ? 1 : false,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeMenus,
          null,
        );
      });
      var engine = 0;
      await tester.pumpWidget(
        presentationHost(
          StatefulBuilder(
            builder: (context, set) => Column(
              children: [
                controls.choice(
                  engine,
                  {0: 'PostgreSQL', 1: 'MySQL'},
                  (value) => set(() => engine = value),
                  label: 'Driver',
                ),
                controls.comboRow('Environment', 'Development', {
                  'Development': 'Development',
                  'Production': 'Production',
                }, (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Driver: PostgreSQL', 'Environment: Development']) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.value, isEmpty);
      }
      final selector = tester.getSemantics(
        find.bySemanticsLabel('Driver: PostgreSQL'),
      );
      selector.owner!.performAction(selector.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Driver: MySQL'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Driver:')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'code evidence remains readable in selected ${brightness.name} high contrast records',
      (tester) async {
        for (final focused in [true, false]) {
          await tester.pumpWidget(
            presentationHost(
              WorkbenchRowSurface(
                controls: controls,
                selected: true,
                focused: focused,
                child: const WorkbenchCodeEvidence(
                  controls: controls,
                  text: 'SELECT 42;',
                ),
              ),
              brightness: brightness,
              contrast: true,
            ),
          );
          await tester.pumpAndSettle();
          final foreground = tester
              .widget<EditableText>(find.byType(EditableText))
              .style
              .color!;
          final box = tester.widget<Container>(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Container && widget.decoration is BoxDecoration,
                )
                .first,
          );
          final background = (box.decoration! as BoxDecoration).color!;
          final a = foreground.computeLuminance();
          final b = background.computeLuminance();
          expect(
            (math.max(a, b) + .05) / (math.min(a, b) + .05),
            greaterThanOrEqualTo(4.5),
          );
        }
      },
    );
  }

  testWidgets(
    'read-only code keeps punctuation order and exact copying in an RTL interface across appearance changes',
    (tester) async {
      const captured = '{"columns":{"معرّف":1}}';
      final key = GlobalKey();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      Widget body() => Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 700,
            child: WorkbenchCodeEvidence(
              key: key,
              controls: controls,
              text: captured,
            ),
          ),
        ),
      );
      await tester.pumpWidget(presentationHost(body()));
      await tester.pumpAndSettle();
      final input = find.byType(EditableText);
      final controller = tester.widget<EditableText>(input).controller;
      void verifyPunctuation() {
        final RenderEditable render = tester
            .state<EditableTextState>(input)
            .renderEditable;
        final opening = render.getLocalRectForCaret(
          const TextPosition(offset: 0),
        );
        final closing = render.getLocalRectForCaret(
          TextPosition(offset: captured.length),
        );
        expect(opening.left, lessThan(closing.left));
        expect(controller.text, captured);
      }

      verifyPunctuation();
      await tester.tap(find.byType(SelectableText));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, captured);
      final selection = controller.selection;
      expect(selection.start, 0);
      expect(selection.end, captured.length);
      await tester.pumpWidget(
        presentationHost(
          body(),
          brightness: Brightness.dark,
          fontSize: 20,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(input).controller, same(controller));
      expect(controller.selection, selection);
      verifyPunctuation();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'captured definition follows live technical typography without replacing its captured value',
    (tester) async {
      const captured = 'CREATE VIEW 漢 AS SELECT 42;';
      final inspected = rpc.SchemaToolResult(
        definition: captured,
        snapshot:
            '{"engine":"POSTGRESQL","tables":{},"views":{},"routines":{}}',
      );
      final form = ObjectDesignerForm(
        controls: controls,
        inspected: inspected,
        target: rpc.SchemaToolRequest(),
        generate: (_) async =>
            throw StateError('Read-only evidence must not generate SQL'),
        openSql: (_) => fail('Read-only evidence must not open an editor'),
      );
      await tester.pumpWidget(presentationHost(form));
      await tester.tap(find.text('Inspect captured definition'));
      await tester.pumpAndSettle();
      final evidence = find.widgetWithText(SelectableText, captured);
      final field = tester.widget<EditableText>(
        find.descendant(of: evidence, matching: find.byType(EditableText)),
      );
      final controller = field.controller;
      final oldStyle = tester.widget<SelectableText>(evidence).style!;
      inspected.definition = 'Other mutable metadata';
      await tester.pumpWidget(
        presentationHost(form, brightness: Brightness.dark, fontSize: 20),
      );
      await tester.pumpAndSettle();
      final style = tester.widget<SelectableText>(evidence).style!;
      expect(style.fontFamily, 'Ubuntu Mono');
      expect(style.fontSize, greaterThan(oldStyle.fontSize!));
      expect(style.color, isNot(oldStyle.color));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: evidence,
                matching: find.byType(EditableText),
              ),
            )
            .controller,
        same(controller),
      );
      expect(controller.text, captured);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'scoped appearance retains native metrics across progress and refreshes effective typography',
    (tester) async {
      final progress = ValueNotifier(0);
      addTearDown(progress.dispose);
      DesktopAppearance? first, last;
      Widget content() => LinuxAppearanceScope(
        child: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, _, _) {
            last = controls.appearance(context);
            first ??= last;
            return Text('Ag国 العربية', style: last!.body);
          },
        ),
      );
      await tester.pumpWidget(presentationHost(content()));
      final initialHeight = last!.lineHeight(
        tester.element(find.text('Ag国 العربية')),
      );
      for (var i = 1; i < 4; i++) {
        progress.value = i;
        await tester.pump();
        expect(last, same(first));
      }
      await tester.pumpWidget(
        presentationHost(
          content(),
          fontSize: 20,
          scale: 2,
          brightness: Brightness.dark,
          contrast: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(last, isNot(same(first)));
      expect(last!.lineExtent, greaterThan(initialHeight));
      expect(last!.highContrast, isTrue);
      expect(last!.body.fontSize, greaterThan(first!.body.fontSize!));
      expect(last!.foreground, isNot(first!.foreground));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native selections pair readable foregrounds with distinct focused and unfocused surfaces',
    (tester) async {
      double ratio(Color foreground, Color background) {
        final a = Color.alphaBlend(foreground, background).computeLuminance();
        final b = background.computeLuminance();
        return (math.max(a, b) + .05) / (math.min(a, b) + .05);
      }

      for (final brightness in Brightness.values) {
        for (final contrast in [false, true]) {
          late DesktopAppearance look;
          await tester.pumpWidget(
            presentationHost(
              Builder(
                builder: (context) {
                  look = controls.appearance(context);
                  return const SizedBox();
                },
              ),
              brightness: brightness,
              contrast: contrast,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            ratio(look.selectedForeground, look.selected),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            ratio(look.unfocusedSelectionForeground, look.unfocusedSelection),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            ratio(look.foreground, look.textSelection),
            greaterThanOrEqualTo(4.5),
          );
          expect(look.unfocusedSelection, isNot(look.view));
          expect(look.selected, isNot(look.unfocusedSelection));
        }
      }
    },
  );

  testWidgets(
    'ordinary search clear notifies once, keeps owner focus and preserves composition on appearance changes',
    (tester) async {
      final query = TextEditingController(text: '日本語');
      final focus = FocusNode();
      final semantics = tester.ensureSemantics();
      var changes = 0;
      query.addListener(() => changes++);
      addTearDown(query.dispose);
      addTearDown(focus.dispose);
      Widget entry() => Padding(
        padding: const EdgeInsets.all(12),
        child: controls.filterField(query, 'Filter objects', focusNode: focus),
      );
      await tester.pumpWidget(presentationHost(entry()));
      focus.requestFocus();
      query.value = const TextEditingValue(
        text: '日本語',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      final original = query.value;
      await tester.pumpWidget(
        presentationHost(entry(), brightness: Brightness.dark, scale: 2),
      );
      await tester.pumpAndSettle();
      expect(query.value, original);
      expect(focus.hasFocus, isTrue);
      final clear = tester.getSemantics(find.bySemanticsLabel('Clear text'));
      expect(clear.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        clear.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isTrue,
      );
      for (
        var ancestor = clear.parent;
        ancestor != null;
        ancestor = ancestor.parent
      ) {
        expect(
          ancestor.getSemanticsData().flagsCollection.isTextField,
          isFalse,
          reason: 'GTK editable text is a leaf; clear must be a sibling action',
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        clear.getSemanticsData().flagsCollection.isFocused,
        Tristate.isTrue,
      );
      expect(query.text, original.text);
      expect(query.selection, original.selection);
      changes = 0;
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pumpAndSettle();
      expect(query.text, isEmpty);
      expect(changes, 1);
      semantics.dispose();
      expect(focus.hasFocus, isTrue);
      query.text = 'orders';
      changes = 0;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(query.text, isEmpty);
      expect(changes, 1);
    },
  );

  testWidgets(
    'persistent connection field names are announced once in either layout',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final value = TextEditingController(text: 'db.example.test');
      addTearDown(value.dispose);
      for (final width in [280.0, 700.0]) {
        await tester.pumpWidget(
          presentationHost(
            Center(
              child: SizedBox(
                width: width,
                child: controls.field(value, 'Host'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.bySemanticsLabel('Host'));
        expect(node.getSemanticsData().value, 'db.example.test');
        expect(find.bySemanticsLabel(RegExp('Host')), findsOneWidget);
        expect(node.getSemanticsData().flagsCollection.isTextField, isTrue);
      }
      semantics.dispose();
    },
  );

  testWidgets('protected form suffix remains a separate native action', (
    tester,
  ) async {
    final value = TextEditingController(text: 'kept-secret');
    addTearDown(value.dispose);
    final semantics = tester.ensureSemantics();
    var invocations = 0;
    await tester.pumpWidget(
      presentationHost(
        controls.field(
          value,
          'Password',
          secret: true,
          trailing: controls.iconButton(
            DesktopIcon.folder,
            'Browse credential',
            () => invocations++,
          ),
        ),
      ),
    );
    final action = tester.getSemantics(
      find.bySemanticsLabel('Browse credential'),
    );
    for (
      var ancestor = action.parent;
      ancestor != null;
      ancestor = ancestor.parent
    ) {
      expect(ancestor.getSemanticsData().flagsCollection.isTextField, isFalse);
    }
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Password'))
          .getSemanticsData()
          .flagsCollection
          .isObscured,
      isTrue,
    );
    await tester.tap(find.byTooltip('Browse credential'));
    expect(invocations, 1);
    expect(value.text, 'kept-secret');
    semantics.dispose();
  });

  testWidgets(
    'checkbox label and selected record keyboard activation each invoke once',
    (tester) async {
      var checked = false, checks = 0, actions = 0;
      await tester.pumpWidget(
        presentationHost(
          StatefulBuilder(
            builder: (context, set) => Column(
              children: [
                controls.checkbox(
                  'Use SSL',
                  checked,
                  (value) => set(() {
                    checked = value;
                    checks++;
                  }),
                ),
                WorkbenchRecord(
                  controls: controls,
                  label: 'orders — 注文',
                  selected: true,
                  onPressed: () => actions++,
                  child: const Text('orders — 注文'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Use SSL'));
      await tester.pumpAndSettle();
      expect(checked, isTrue);
      expect(checks, 1);
      await tester.tap(find.text('orders — 注文'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(actions, 2);
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('orders — 注文'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'inline entry fits measured cell at native fonts and 200 percent text without a floating label',
    (tester) async {
      final editor = TextEditingController(text: '42');
      final focus = FocusNode();
      addTearDown(editor.dispose);
      addTearDown(focus.dispose);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          presentationHost(
            Builder(
              builder: (context) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: const ValueKey('cell'),
                  width: 180,
                  height: controls.appearance(context).rowHeight(context),
                  child: controls.inlineField(
                    editor,
                    'exact cell value',
                    focusNode: focus,
                  ),
                ),
              ),
            ),
            scale: scale,
            fontSize: 18,
          ),
        );
        await tester.pumpAndSettle();
        final cell = tester.getRect(find.byKey(const ValueKey('cell')));
        final entry = tester.getRect(find.byType(EditableText));
        expect(cell.contains(entry.topLeft), isTrue);
        expect(
          cell.contains(entry.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .decoration
              ?.labelText,
          isNull,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'snippet editor follows effective theme while retaining controller, SQL and selection',
    (tester) async {
      Widget snippet() => SnippetView(
        controls: controls,
        snippets: const {},
        save: (_, _, {remove = false}) async {},
        insert: (_) {},
      );
      await tester.pumpWidget(presentationHost(snippet()));
      final before = tester.widget<CodeEditor>(find.byType(CodeEditor));
      before.controller!.text = 'select 名称 from 注文;';
      final value = before.controller!.value;
      await tester.pumpWidget(
        presentationHost(snippet(), brightness: Brightness.dark, fontSize: 18),
      );
      await tester.pumpAndSettle();
      final after = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(after.controller, same(before.controller));
      expect(after.controller!.value, value);
      expect(after.style!.backgroundColor!.computeLuminance(), lessThan(.5));
      expect(after.style!.textColor!.computeLuminance(), greaterThan(.5));
      expect(after.style!.codeTheme, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retained diagram edges repaint for theme, geometry and changed node names',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('presentation-graph-'),
      ))!;
      final model = WorkbenchModel(root)..draftRecovery = false;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      final tables = [
        rpc.SchemaObject(name: 'orders'),
        rpc.SchemaObject(name: 'customers'),
      ];
      final edges = [
        rpc.SchemaObject(
          table: 'orders',
          properties: {'referencedTable': 'customers'}.entries,
        ),
      ];
      Widget graph() => DiagramDocumentView(
        model: model,
        tables: tables,
        edges: edges,
        ui: controls,
      );
      CustomPainter painter() => tester
          .widget<CustomPaint>(
            find.byWidgetPredicate(
              (widget) => widget is CustomPaint && widget.size.width > 500,
            ),
          )
          .painter!;
      await tester.pumpWidget(presentationHost(graph()));
      await tester.pumpAndSettle();
      final light = painter();
      final viewer = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController;
      await tester.pumpWidget(
        presentationHost(graph(), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      final dark = painter();
      expect(dark.shouldRepaint(light), isTrue);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController,
        same(viewer),
      );
      await tester.pumpWidget(
        presentationHost(graph(), brightness: Brightness.dark, scale: 2),
      );
      await tester.pumpAndSettle();
      final scaled = painter();
      expect(scaled.shouldRepaint(dark), isTrue);
      tables[1].name = 'renamed';
      await tester.pumpWidget(
        presentationHost(graph(), brightness: Brightness.dark, scale: 2),
      );
      await tester.pumpAndSettle();
      expect(painter().shouldRepaint(scaled), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'import preview rows fit the actual native font at 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('preview-font-'),
      ))!;
      final backend = TestBackend();
      final model = metadataFixture(
        WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(),
      );
      final source = model.activeOwner;
      final profile = rpc.Profile(
        id: 'fixture',
        name: 'Fixture',
        engine: rpc.Engine.POSTGRESQL,
      );
      source.profileId = profile.id;
      source.sessionId = 'physical';
      model.profiles.add(profile);
      model.sessions['physical'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'physical',
        profile: profile,
        autoCommit: true,
        currentCatalog: 'fixture',
        currentSchema: 'public',
      );
      backend.client.metadataAction = (request) async => rpc.SchemaObjects(
        complete: true,
        objects: [
          rpc.SchemaObject(
            kind: rpc.ObjectKind.COLUMN,
            name: 'customer_name',
            properties: {'ordinal': '1'}.entries,
          ),
        ],
      );
      final data =
          TransferDocumentData(
              model.captureTarget(owner: source),
              rpc.ToolKind.IMPORT_CSV,
              path: 'fixture.csv',
              schema: 'public',
              table: 'orders',
            )
            ..preview = rpc.ImportPreview(
              sourceColumns: ['customer_name'],
              sourceSha256: 'a' * 64,
              rows: [
                rpc.Row(values: [rpc.Value(text: 'Ada Lovelace')]),
              ],
            );
      final owner = model.openTask(
        WorkbenchDocumentKind.transfer,
        'Import preview',
        profileId: profile.id,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        presentationHost(
          TransferDocument(
            model: model,
            owner: owner,
            data: data,
            controls: controls,
          ),
          fontSize: 20,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TableView),
        300,
        scrollable: find
            .descendant(
              of: find.byType(WorkbenchFormList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final header = find.descendant(
        of: find.byType(TableView),
        matching: find.text('customer_name'),
      );
      final table = tester.widget<TableView>(find.byType(TableView));
      final span =
          (table.delegate as TableCellBuilderDelegate).buildRow(0)!.extent
              as FixedTableSpanExtent;
      expect(span.pixels, greaterThan(tester.getSize(header.first).height));
      expect(
        find.descendant(
          of: find.byType(TableView),
          matching: find.text('Ada Lovelace'),
        ),
        findsOneWidget,
      );
      expect(backend.client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
