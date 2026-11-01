import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      for (final reconnectRecovery in [false, true]) {
        testWidgets(
          '${controls.runtimeType} Explorer ${reconnectRecovery ? 'restores selection after a new physical session' : 'pending refresh preserves newer keyboard selection'} at 200% $direction',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final root = (await tester.runAsync(
              () => Directory.systemTemp.createTemp('explorer-keyboard-'),
            ))!;
            final backend = TestBackend();
            final model = WorkbenchModel(root)
              ..draftRecovery = false
              ..backend = backend
              ..newDocument(text: '-- keep this unbound');
            final owner = model.activeOwner;
            final profile = rpc.Profile(
              id: 'p',
              name: 'Staging',
              engine: rpc.Engine.POSTGRESQL,
            );
            model.profiles.add(profile);
            model.explorerSessions['p'] = 'inspection';
            model.sessions['inspection'] = rpc.SessionInfo(
              metadataSourceIdentity: fixtureMetadataSourceIdentity,
              sessionId: 'inspection',
              profile: profile,
              currentCatalog: 'db',
            );
            backend.client.metadataAction = (request) async =>
                rpc.SchemaObjects(
                  complete: true,
                  objects: switch (request.kind) {
                    rpc.ObjectKind.SCHEMA => [
                      rpc.SchemaObject(name: 'public', kind: request.kind),
                    ],
                    rpc.ObjectKind.TABLE => [
                      for (var i = 0; i < 32; i++)
                        rpc.SchemaObject(
                          name: 'item_${i.toString().padLeft(2, '0')}',
                          schema: 'public',
                          kind: request.kind,
                        ),
                    ],
                    _ => [],
                  },
                );
            await tester.binding.setSurfaceSize(const Size(900, 1400));
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              model.dispose();
              await tester.binding.setSurfaceSize(null);
              await tester.runAsync(() => root.delete(recursive: true));
            });
            final view = MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Directionality(
                textDirection: direction,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 500,
                    child: DatabaseExplorer(
                      model: metadataFixture(model),
                      controls: controls,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpWidget(
              controls is WindowsControls
                  ? fluent.FluentApp(home: view)
                  : MaterialApp(home: Scaffold(body: view)),
            );
            await tester.pumpAndSettle();
            for (final name in ['Staging', 'public', 'Tables']) {
              final expand = find.bySemanticsLabel('Expand $name');
              await tester.scrollUntilVisible(
                expand,
                120,
                scrollable: find.descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(expand);
              await tester.pumpAndSettle();
            }
            final tables = find.bySemanticsLabel(RegExp('^Tables · level'));
            await tester.ensureVisible(tables);
            await tester.pumpAndSettle();
            final node = tester.getSemantics(tables);
            node.owner!.performAction(node.id, ui.SemanticsAction.focus);
            await tester.pumpAndSettle();
            int focusedNodes(SemanticsNode current) {
              var count =
                  current.getSemanticsData().flagsCollection.isFocused ==
                      ui.Tristate.isTrue
                  ? 1
                  : 0;
              current.visitChildren((child) {
                count += focusedNodes(child);
                return true;
              });
              return count;
            }

            void expectRowFocus(SemanticsNode row) {
              try {
                expect(
                  focusedNodes(row),
                  1,
                  reason:
                      'A tree row must announce one focused object with its '
                      'stable identity and tree role, without an anonymous focused '
                      'panel competing for the screen reader focus.',
                );
                final data = row.getSemanticsData();
                expect(data.identifier, startsWith('busydata.database.item.'));
                expect(data.hasAction(ui.SemanticsAction.focus), isTrue);
                expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
              } catch (_) {
                final states = tester
                    .widgetList<Semantics>(find.byType(Semantics))
                    .where(
                      (widget) =>
                          widget.properties.identifier?.startsWith(
                            'busydata.database.item.',
                          ) ==
                          true,
                    )
                    .take(64)
                    .map(
                      (widget) => (
                        widget.properties.label?.split(' · ').first,
                        widget.properties.focused,
                        widget.properties.selected,
                      ),
                    )
                    .toList();
                debugPrint('Fixture rows (name, focus, selection): $states');
                semantics.dispose();
                rethrow;
              }
            }

            expectRowFocus(node);
            if (reconnectRecovery) {
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await tester.pumpAndSettle();
              final destination = find.bySemanticsLabel(
                RegExp('^item_01 · level'),
              );
              expectRowFocus(tester.getSemantics(destination));
              await tester.pump(const Duration(milliseconds: 350));
              final savedSelection = model.explorerSelection;
              expect(savedSelection, isNotEmpty);
              final previous = model.sessions.remove('inspection')!;
              model.explorerSessions.clear();
              await tester.pumpWidget(const SizedBox.shrink());
              // Recreate the presentation before its replacement physical session
              // exists. Connecting selects the source while its saved branches load.
              await tester.pumpWidget(
                controls is WindowsControls
                    ? fluent.FluentApp(home: view)
                    : MaterialApp(home: Scaffold(body: view)),
              );
              await tester.pumpAndSettle();
              expect(
                find.bySemanticsLabel(RegExp('^item_01 · level')),
                findsNothing,
              );
              model.explorerSessions['p'] = 'replacement';
              model.sessions['replacement'] = previous.deepCopy()
                ..sessionId = 'replacement';
              model.updateStatus(
                'Fixture connected replacement physical session',
              );
              await tester.pumpAndSettle();
              final restored = tester
                  .getSemantics(
                    find.bySemanticsLabel(RegExp('^item_01 · level')),
                  )
                  .getSemanticsData();
              expect(restored.flagsCollection.isSelected, ui.Tristate.isTrue);
              expect(
                restored.flagsCollection.isFocused,
                isNot(ui.Tristate.isTrue),
              );
              expect(model.explorerSelection, savedSelection);
            } else {
              // Persist the old selection, then hold the structural reload while
              // the user moves to a newer row. No fake focus or delayed input.
              await tester.pump(const Duration(milliseconds: 350));
              final savedSelection = model.explorerSelection;
              expect(savedSelection, isNotEmpty);
              final delayed = Completer<rpc.SchemaObjects>();
              final original = backend.client.metadataAction!;
              rpc.ExploreRequest? pending;
              backend.client.metadataAction = (request) {
                if (request.kind == rpc.ObjectKind.TABLE && pending == null) {
                  pending = request.deepCopy();
                  return delayed.future;
                }
                return original(request);
              };
              tester
                  .widget<ListView>(find.byType(ListView))
                  .controller!
                  .jumpTo(0);
              await tester.pump();
              final source = tester.getSemantics(
                find.bySemanticsLabel(RegExp('^Staging · level')),
              );
              source.owner!.performAction(source.id, ui.SemanticsAction.focus);
              await tester.pump();
              await tester.tap(find.bySemanticsLabel('Refresh'));
              for (var frame = 0; frame < 8 && pending == null; frame++) {
                await tester.pump();
              }
              expect(pending, isNotNull);
              final currentTables = tester.getSemantics(
                find.bySemanticsLabel(RegExp('^Tables · level')),
              );
              currentTables.owner!.performAction(
                currentTables.id,
                ui.SemanticsAction.focus,
              );
              await tester.pump();
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await tester.pump();
              final first = find.bySemanticsLabel(RegExp('^item_00 · level'));
              expectRowFocus(tester.getSemantics(first));
              expect(model.explorerSelection, savedSelection);
              delayed.complete(await original(pending!));
              await tester.pump();
              await tester.pump();
              // A saved preference cannot supersede newer focus/selection.
              expectRowFocus(tester.getSemantics(first));
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await tester.pumpAndSettle();
              final destination = find.bySemanticsLabel(
                RegExp('^item_01 · level'),
              );
              expectRowFocus(tester.getSemantics(destination));
            }
            expect(model.activeOwner, same(owner));
            expect(model.document.sessionId, isNull);
            expect(model.document.editor.text, '-- keep this unbound');
            expect(backend.client.executions, isEmpty);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            semantics.dispose();
          },
        );
      }
    }
  }
}
