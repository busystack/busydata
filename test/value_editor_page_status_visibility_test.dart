import 'dart:convert';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'value_editor_test_actions.dart';

void expectVisiblePage(WidgetTester tester, String caption) {
  final RenderView view = tester.binding.renderViews.single;
  final owner = view.owner!.semanticsOwner!;
  final projection = LinuxAccessibilityProjection.capture(
    owner: owner,
    root: owner.rootSemanticsNode!,
    bridgeEpoch: 1,
    viewId: view.flutterView.viewId,
    ownerEpoch: 1,
    revision: 1,
    viewSize: view.size,
    devicePixelRatio: view.flutterView.devicePixelRatio,
  ).message;
  final nodes = (projection['nodes'] as List).cast<Map>();
  final page = nodes.singleWhere((node) => node['label'] == caption);
  final index = {for (final node in nodes) node['id']: node};
  Map? current = page;
  while (current != null) {
    expect(
      (current['flags'] as Map)['hidden'],
      isFalse,
      reason: '$caption must remain visible while its editor has focus',
    );
    current = index[current['parentId']];
  }
  final rect = (page['rect'] as List).cast<num>();
  expect(rect[2], greaterThan(0));
  expect(rect[3], greaterThan(0));
  expect(rect[1], greaterThanOrEqualTo(0));
  expect(rect[1] + rect[3], lessThanOrEqualTo(view.size.height));
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final locale in const [Locale('de'), Locale('ar')]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} value page remains visible with exact export actions $locale $scale',
          (tester) async {
            final semantics = tester.ensureSemantics();
            await tester.binding.setSurfaceSize(const Size(1366, 768));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final exact = '漢' * 30000;
            final bytes = utf8.encode(exact), offsets = <int>[];
            var exports = 0;
            rpc.Value? staged;
            final value = rpc.Value(
              text: '漢' * 1024,
              valueId: 'owned-value',
              truncated: true,
              originalBytes: Int64(bytes.length),
            );
            final original = value.writeToBuffer();
            final body = Builder(
              builder: (context) => controls.button('Open value', () {
                final l = AppLocalizations.of(context)!;
                controls.dialog<void>(
                  context,
                  'body · text',
                  ResultValueEditor(
                    controls: controls,
                    value: value,
                    column: rpc.Column(name: 'body', typeName: 'text'),
                    readChunk: (offset) async {
                      offsets.add(offset);
                      final end = (offset + 65536).clamp(0, bytes.length);
                      return rpc.ValueChunk(
                        data: bytes.sublist(offset, end),
                        totalBytes: Int64(bytes.length),
                        complete: end == bytes.length,
                      );
                    },
                    retainDraft: (_, _) {},
                    cancelRead: () {},
                    stage: (value) async {
                      staged = value;
                    },
                  ),
                  [
                    controls.button(
                      '${l.exportFullValue} (${l.bytesCount('${bytes.length}')})',
                      () => exports++,
                    ),
                    controls.button(l.close, () => Navigator.of(context).pop()),
                  ],
                  bodyScrolls: true,
                );
              }),
            );
            Widget builder(BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            );
            try {
              await tester.pumpWidget(
                controls is WindowsControls
                    ? fluent.FluentApp(
                        locale: locale,
                        localizationsDelegates: const [
                          AppLocalizations.delegate,
                        ],
                        supportedLocales: AppLocalizations.supportedLocales,
                        builder: builder,
                        home: body,
                      )
                    : MaterialApp(
                        locale: locale,
                        localizationsDelegates:
                            AppLocalizations.localizationsDelegates,
                        supportedLocales: AppLocalizations.supportedLocales,
                        theme: BusyDataYaruTheme.build(
                          brightness: Brightness.light,
                          accentColor: Colors.orange,
                        ),
                        builder: builder,
                        home: Scaffold(body: body),
                      ),
              );
              await tester.tap(find.text('Open value'));
              await tester.pumpAndSettle();
              await valueEditorAction(tester, controls, 'Edit complete value');
              expect(offsets, [0, 65536]);
              final input = find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              );
              for (var page = 0; page < 2; page++) {
                await tester.tap(input);
                await tester.pumpAndSettle();
                expectVisiblePage(tester, 'Text page ${page + 1} of 2');
                expect(
                  tester.widget<EditableText>(input).controller.text,
                  page == 0 ? '漢' * 16384 : '漢' * 13616,
                );
                if (page == 0) {
                  await tester.tap(find.text('Next text page'));
                  await tester.pumpAndSettle();
                }
              }
              final changed = '${'漢' * 13615}末';
              await tester.enterText(input, changed);
              final l = AppLocalizations.of(tester.element(input))!;
              await tester.tap(find.text(l.stageChange));
              await tester.pumpAndSettle();
              expect(staged!.text, '${'漢' * 16384}$changed');
              expect(staged!.truncated, isFalse);
              expect(value.writeToBuffer(), orderedEquals(original));
              expect(exports, 0);
              expect(offsets, [0, 65536]);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
