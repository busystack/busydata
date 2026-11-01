import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/ui/common/object_designer.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/designer_focus_linux.dart';

void main() {
  for (final variant in ['A', 'B']) {
    testWidgets(
      'designer focus $variant has bounded actual form and stable field',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          fluent.FluentApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [AppLocalizations.delegate],
            home: DesignerFocusLinuxFixture(variant: variant),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final form = find.byType(ObjectDesignerForm);
        expect(form, findsOneWidget);
        final formState = tester.state(form);
        final frame = tester.widget<WorkbenchForm>(find.byType(WorkbenchForm));
        expect(frame.footer, isNotNull);
        final bounds = tester.getRect(form);
        final footer = tester.getRect(find.byWidget(frame.footer!));
        for (final coordinate in [
          bounds.left,
          bounds.top,
          bounds.right,
          bounds.bottom,
          footer.bottom,
        ]) {
          expect(coordinate.isFinite, isTrue);
        }
        expect(bounds.width, greaterThan(100));
        expect(bounds.height, greaterThan(100));
        expect(footer.bottom, lessThanOrEqualTo(bounds.bottom + .1));

        final target = find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Object / column name',
          ),
          matching: find.byType(EditableText),
        );
        expect(target, findsOneWidget);
        final original = tester.widget<EditableText>(target);
        final choose = find.byWidgetPredicate(
          (widget) => widget is fluent.ComboBox<String> && widget.value == '',
        );
        expect(choose, findsOneWidget);
        await tester.tap(choose);
        await tester.pumpAndSettle();
        await tester.tap(find.text('n').last);
        await tester.pumpAndSettle();
        expect(original.controller.text, 'n');
        expect(original.focusNode.hasFocus, isFalse);
        final normalSelection = original.controller.selection;

        await tester.tap(find.text('Prepare focus baseline'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Focus baseline prepared'), findsOneWidget);
        expect(tester.state(form), same(formState));
        final prepared = tester.widget<EditableText>(target);
        expect(prepared.controller, same(original.controller));
        expect(prepared.focusNode, same(original.focusNode));
        expect(prepared.focusNode.hasFocus, isFalse);
        expect(prepared.controller.text, 'n');
        expect(
          prepared.controller.selection,
          variant == 'B'
              ? const TextSelection.collapsed(offset: 1)
              : normalSelection,
        );
        expect(tester.getRect(target).overlaps(bounds), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
