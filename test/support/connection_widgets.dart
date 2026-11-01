import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectConnectionPage(WidgetTester tester, String page) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('connection-page-selector')),
  );
  final selector = find
      .descendant(
        of: find.byKey(const ValueKey('connection-page-selector')),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true,
        ),
      )
      .hitTestable();
  await tester.tap(selector.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(page).last);
  await tester.pumpAndSettle();
}

List<Map> flattenNativeMenu(List entries) => [
  for (final entry in entries) ...[
    entry as Map,
    if (entry['children'] != null)
      ...flattenNativeMenu(entry['children'] as List),
  ],
];
