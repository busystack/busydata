import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/structure_presentation.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'support/metadata_fixture.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        '${controls.runtimeType} integrated structure properties remain reachable at native 200% ${locale.languageCode}',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final labels = await AppLocalizations.delegate.load(locale);
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('structure-viewport-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 'SELECT unchanged_owner');
          final originalSql = model.document;
          final profile = rpc.Profile(
            id: 'p',
            name: 'Long production connection with explicit target details',
            engine: rpc.Engine.POSTGRESQL,
            host: '127.0.0.1',
            port: 5432,
            database: 'busydata',
            environment: rpc.Environment.PRODUCTION,
          );
          model.profiles.add(profile);
          model.sessions['inspection'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'inspection',
            profile: profile,
            currentCatalog: 'busydata',
            currentSchema: 'public',
            transaction: rpc.TransactionState.IDLE,
            autoCommit: true,
          );
          model.connectionOwner(profile).sessionId = 'inspection';
          model.explorerSessions['p'] = 'inspection';
          final owner = model.openTask(
            WorkbenchDocumentKind.table,
            'Data · native_atspi_fixture',
            object: const DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'busydata',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              name: 'native_atspi_fixture',
            ),
          );
          owner.view.subview = 'structure';
          owner.view.structureSection = rpc.ObjectKind.INDEX.value;
          var metadataReads = 0;
          metadataFixture(model);
          backend.client.metadataAction = (_) async {
            metadataReads++;
            return rpc.SchemaObjects(
              complete: true,
              availability: 'available',
              objects: [
                rpc.SchemaObject(
                  name: 'exact_key',
                  kind: rpc.ObjectKind.INDEX,
                  properties: {
                    'column': 'quoted column',
                    'ordinal': '2',
                    'nonUnique': 'f',
                  }.entries,
                ),
              ],
            );
          };
          await tester.binding.setSurfaceSize(const Size(624, 540));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              highContrast: true,
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: WorkbenchView(model: model, controls: controls),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(
                    locale: locale,
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: fluent.FluentThemeData(
                      typography:
                          fluent.Typography.fromBrightness(
                            brightness: Brightness.light,
                          ).merge(
                            const fluent.Typography.raw(
                              body: TextStyle(
                                fontSize: 14,
                                height: 1.9,
                                color: Colors.black,
                              ),
                            ),
                          ),
                    ),
                    home: view,
                  )
                : MaterialApp(
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme:
                        BusyDataYaruTheme.build(
                          brightness: Brightness.light,
                          accentColor: Colors.orange,
                        ).copyWith(
                          textTheme: ThemeData().textTheme.copyWith(
                            bodyMedium: const TextStyle(
                              fontSize: 14,
                              height: 1.9,
                            ),
                          ),
                        ),
                    home: Scaffold(body: view),
                  ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final environment = tester.getRect(
            find.descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is FocusScope &&
                    widget.focusNode == model.targetFocus,
              ),
              matching: find.text(labels.production),
            ),
          );
          expect(environment.left, greaterThanOrEqualTo(0));
          expect(environment.right, lessThanOrEqualTo(624));
          // The selected detail viewport is distinct from the compact,
          // virtualized overview. Verify full properties in their own region.
          final scrollable = find
              .descendant(
                of: find.byKey(
                  ValueKey(
                    'schema-details:${owner.view.structureSelections[rpc.ObjectKind.INDEX.value]}',
                  ),
                ),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                ),
              )
              .first;
          expect(scrollable, findsOneWidget);
          final viewport = tester.getRect(scrollable);
          expect(viewport.height, greaterThanOrEqualTo(96));
          await tester.scrollUntilVisible(
            find.descendant(
              of: find.byType(SchemaObjectDetails),
              matching: find.text('quoted column'),
            ),
            70,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          final property = tester.getRect(
            find.descendant(
              of: find.byType(SchemaObjectDetails),
              matching: find.text('quoted column'),
            ),
          );
          expect(property.top, greaterThanOrEqualTo(viewport.top));
          expect(property.bottom, lessThanOrEqualTo(viewport.bottom));
          // The actual metadata builder must associate each read-only name
          // with its selectable value at both stacked and column allocations.
          TextEditingController? retainedValue;
          TextSelection? retainedSelection;
          for (final size in [const Size(624, 540), const Size(1500, 900)]) {
            await tester.binding.setSurfaceSize(size);
            await tester.pumpAndSettle();
            for (final (name, value) in [
              (labels.metadataColumn, 'quoted column'),
              (labels.metadataPosition, '2'),
              (labels.metadataUnique, labels.yes),
            ]) {
              final row = find.byWidgetPredicate(
                (widget) =>
                    widget is WorkbenchProperty &&
                    widget.readOnly &&
                    widget.label == name,
              );
              await tester.scrollUntilVisible(row, 70, scrollable: scrollable);
              await tester.pumpAndSettle();
              final property = tester.getSemantics(
                find
                    .descendant(of: row, matching: find.byType(SelectableText))
                    .first,
              );
              final semantic = property.getSemanticsData();
              final output = '${semantic.label}\n${semantic.value}';
              expect(name.allMatches(output), hasLength(1));
              expect(value.allMatches(output), hasLength(1));
              expect(semantic.hasAction(ui.SemanticsAction.focus), isTrue);
              if (name == labels.metadataColumn) {
                final field = find.descendant(
                  of: row,
                  matching: find.byType(EditableText),
                );
                final entry = tester.widget<EditableText>(field);
                if (retainedValue != null) {
                  expect(entry.controller, same(retainedValue));
                  expect(entry.controller.selection, retainedSelection);
                }
                tester.binding.performSemanticsAction(
                  ui.SemanticsActionEvent(
                    viewId: tester.view.viewId,
                    nodeId: property.id,
                    type: ui.SemanticsAction.focus,
                  ),
                );
                await tester.pump();
                expect(entry.focusNode.hasFocus, isTrue);
                entry.controller.selection = const TextSelection(
                  baseOffset: 0,
                  extentOffset: 6,
                );
                retainedValue = entry.controller;
                retainedSelection = entry.controller.selection;
              }
            }
          }
          expect(metadataReads, 1);
          expect(backend.client.executions, isEmpty);
          expect(originalSql.editor.text, 'SELECT unchanged_owner');
          expect(originalSql.sessionId, isNull);
          expect(owner.sessionId, isNull);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
