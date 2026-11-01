import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/structure_presentation.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} definition leads exact metadata at $scale ${locale.languageCode}',
          (tester) async {
            final semantics = tester.ensureSemantics();
            await tester.binding.setSurfaceSize(const Size(624, 540));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            const ddl =
                'CREATE TABLE public."exact 漢😀" (\n'
                '  id bigint PRIMARY KEY,\n'
                '  note text DEFAULT \'unchanged\'\n'
                ');\n';
            final internal = {
              'catalogFingerprint': 'private-fingerprint',
              'nativeId': '16385',
              'parentNativeId': '16384',
              'nativeGeneration': '16385:16385',
              'nativeGenerationAvailability': 'AVAILABLE',
              'nativeTableId': 'native-table-id',
              'nativeColumnEpoch': '1',
              'nativeTypeId': '25',
              'editabilitySignature': 'private-signature',
              'baseTableVerified': 'true',
            };
            final comment = 'Exact retained comment 漢😀 ${'detail ' * 100}';
            final object = rpc.SchemaObject(
              kind: rpc.ObjectKind.TABLE,
              name: 'exact 漢😀',
              definition: ddl,
              properties: {
                ...internal,
                'comment': comment,
                'collation': 'C',
                'default': '',
              }.entries,
            );
            final original = object.deepCopy();
            try {
              final view = MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  highContrast: true,
                  disableAnimations: true,
                ),
                child: Directionality(
                  textDirection: locale.languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Column(
                    children: [
                      const SizedBox(height: 150),
                      Expanded(
                        child: SingleChildScrollView(
                          key: const ValueKey('definition-viewport'),
                          padding: const EdgeInsets.all(8),
                          child: SchemaObjectDetails(
                            controls: controls,
                            object: object,
                            nativeDefinition: true,
                            showName: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              await tester.pumpWidget(
                controls is WindowsControls
                    ? fluent.FluentApp(
                        locale: locale,
                        localizationsDelegates: const [
                          AppLocalizations.delegate,
                        ],
                        supportedLocales: AppLocalizations.supportedLocales,
                        home: view,
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
                        home: Scaffold(body: view),
                      ),
              );
              await tester.pumpAndSettle();
              final viewport = tester.getRect(
                find.byKey(const ValueKey('definition-viewport')),
              );
              final code = find.byType(WorkbenchCodeEvidence);
              final bounds = tester.getRect(code);
              expect(bounds.top, closeTo(viewport.top + 8, .01));
              expect(bounds.top, lessThan(viewport.bottom));
              final text = tester.widget<SelectableText>(
                find.descendant(
                  of: code,
                  matching: find.byType(SelectableText),
                ),
              );
              expect(text.data, ddl);
              expect(text.textDirection, TextDirection.ltr);
              for (final key in internal.keys) {
                expect(find.text(key), findsNothing);
              }
              final properties = tester.widgetList<WorkbenchReadOnlyProperty>(
                find.byType(WorkbenchReadOnlyProperty),
              );
              expect(properties, hasLength(3));
              expect(properties.map((property) => property.value), [
                comment,
                'C',
                '',
              ]);
              expect(object, original);
              for (final field in tester.widgetList<EditableText>(
                find.byType(EditableText),
              )) {
                expect(field.readOnly, isTrue);
              }
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
