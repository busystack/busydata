import 'dart:io';
import 'package:busydata/src/app/app_theme.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/busydata_surface_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  test(
    'shared roles preserve current reference Yaru geometry and control states',
    () {
      for (final brightness in Brightness.values) {
        for (final contrast in [false, true]) {
          final theme = _theme(brightness, contrast: contrast);
          final base = brightness == Brightness.dark
              ? createYaruDarkTheme(
                  primaryColor: theme.colorScheme.primary,
                  highContrast: contrast,
                )
              : createYaruLightTheme(primaryColor: theme.colorScheme.primary);
          final colors = theme.extension<BusyDataSurfaceColors>()!;
          for (final pair in [
            (theme.filledButtonTheme.style!, base.filledButtonTheme.style!),
            (theme.elevatedButtonTheme.style!, base.elevatedButtonTheme.style!),
            (theme.outlinedButtonTheme.style!, base.outlinedButtonTheme.style!),
            (theme.textButtonTheme.style!, base.textButtonTheme.style!),
          ]) {
            for (final states in <Set<WidgetState>>[
              {},
              {WidgetState.hovered},
              {WidgetState.pressed},
              {WidgetState.focused},
              {WidgetState.disabled},
            ]) {
              expect(
                pair.$1.padding?.resolve(states),
                pair.$2.padding?.resolve(states),
              );
              expect(
                pair.$1.minimumSize?.resolve(states),
                pair.$2.minimumSize?.resolve(states),
              );
              expect(
                pair.$1.shape?.resolve(states),
                pair.$2.shape?.resolve(states),
              );
              expect(
                pair.$1.overlayColor?.resolve(states),
                pair.$2.overlayColor?.resolve(states),
              );
            }
            expect(pair.$1.backgroundBuilder, pair.$2.backgroundBuilder);
            expect(
              pair.$1.textStyle?.resolve({})?.fontFamily ??
                  theme.textTheme.labelLarge?.fontFamily,
              pair.$2.textStyle?.resolve({})?.fontFamily ??
                  base.textTheme.labelLarge?.fontFamily,
            );
          }
          expect(
            theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
            colors.control,
          );
          expect(
            theme.filledButtonTheme.style!.backgroundColor!.resolve({
              WidgetState.selected,
            }),
            colors.controlActive,
          );
          expect(
            theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
            theme.colorScheme.primary,
          );
          for (final style in [
            theme.filledButtonTheme.style!,
            theme.elevatedButtonTheme.style!,
          ]) {
            expect(
              style.backgroundColor!.resolve({
                WidgetState.disabled,
                WidgetState.hovered,
              }),
              colors.disabledControl,
            );
            expect(
              style.foregroundColor!.resolve({WidgetState.disabled}),
              colors.disabledForeground,
            );
          }
        }
      }
    },
  );

  testWidgets(
    'destructive buttons use the reference dark red role and inherit Yaru states',
    (tester) async {
      for (final brightness in Brightness.values) {
        final theme = _theme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => BusyDataPushButton.destructive(
                context: context,
                onPressed: () {},
                child: const Text('Delete'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final style = button.style!.merge(theme.elevatedButtonTheme.style);
        expect(
          style.backgroundColor!.resolve({}),
          brightness == Brightness.dark
              ? const Color(0xFFC01C28)
              : theme.colorScheme.error,
        );
        expect(
          style.foregroundColor!.resolve({}),
          brightness == Brightness.dark
              ? Colors.white
              : theme.colorScheme.onError,
        );
        expect(
          style.padding!.resolve({}),
          theme.elevatedButtonTheme.style!.padding!.resolve({}),
        );
        expect(
          style.overlayColor?.resolve({WidgetState.hovered}),
          theme.elevatedButtonTheme.style!.overlayColor?.resolve({
            WidgetState.hovered,
          }),
        );
        expect(
          style.backgroundColor!.resolve({WidgetState.disabled}),
          theme.extension<BusyDataSurfaceColors>()!.disabledControl,
        );
      }
    },
  );

  testWidgets(
    'buttons retain state, keyboard activation and disabled scope across appearance changes',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final key = GlobalKey();
      var calls = 0;
      Widget app(Brightness brightness) => MaterialApp(
        theme: _theme(brightness),
        home: Scaffold(
          body: Row(
            children: [
              BusyDataPushButton.standard(
                key: key,
                focusNode: focus,
                onPressed: () => calls++,
                child: const Text('Apply'),
              ),
              BusyDataPushButton.standard(
                onPressed: null,
                child: const Text('Unavailable'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(app(Brightness.light));
      await tester.pumpAndSettle();
      final state = key.currentState;
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      expect(key.currentState, same(state));
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dialog actions remain reachable at 200 percent RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: BusyDataDialogShell(
          title: 'Review',
          actions: [
            BusyDataPushButton.standard(
              onPressed: () {},
              child: const Text('Cancel pending changes'),
            ),
            BusyDataPushButton.suggested(
              onPressed: () {},
              child: const Text('Save pending changes'),
            ),
          ],
          children: const [Text('Pending changes')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Save pending changes', 'Cancel pending changes']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
  });

  test('Linux business code does not bypass platform controls', () {
    for (final file in Directory(
      'lib/src/features',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      expect(
        RegExp(
          r'\b(?:FilledButton|ElevatedButton|OutlinedButton)\s*\(',
        ).hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });
}

ThemeData _theme(Brightness brightness, {bool contrast = false}) =>
    buildBusyDataTheme(
      brightness: brightness,
      accentColor: const Color(0xFF3584E4),

      highContrast: contrast,
    );
