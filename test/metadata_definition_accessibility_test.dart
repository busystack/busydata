import 'dart:io';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        '${controls.runtimeType} integrated definition keeps exact read-only semantics in ${locale.languageCode}',
        (tester) async {
          if (controls is LinuxControls) installNativeWindowFixture(tester);
          final semantics = tester.ensureSemantics();
          var disposed = false;
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('definition-semantics-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 'SELECT unchanged_owner;');
          final original = model.document;
          final profile = rpc.Profile(
            id: 'p',
            name: 'Native fixture',
            engine: rpc.Engine.POSTGRESQL,
            host: '127.0.0.1',
            port: 5432,
            database: 'busydata',
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
            'native_atspi_fixture',
            object: const DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'busydata',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              name: 'native_atspi_fixture',
            ),
          );
          owner.view.subview = 'structure';
          owner.view.structureSection = rpc.ObjectKind.TABLE.value;
          const ddl =
              '-- Captured native definition\n'
              'CREATE TABLE public.native_atspi_fixture ("漢😀" integer, n text);';
          backend.client.schemaTools = (_) async => rpc.SchemaToolResult(
            definition: ddl,
            inspectedObject: rpc.SchemaObject(
              catalog: 'busydata',
              schema: 'public',
              name: 'native_atspi_fixture',
              kind: rpc.ObjectKind.TABLE,
            ),
          );
          await tester.binding.setSurfaceSize(const Size(1366, 768));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            if (!disposed) semantics.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = WorkbenchView(model: model, controls: controls);
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(
                    locale: locale,
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: view,
                  )
                : MaterialApp(
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Scaffold(body: view),
                  ),
          );
          await tester.pumpAndSettle();
          final evidence = find.byType(WorkbenchCodeEvidence);
          expect(evidence, findsOneWidget);
          final entry = find.descendant(
            of: evidence,
            matching: find.byType(EditableText),
          );
          final data = tester.getSemantics(entry).getSemanticsData();
          expect(data.label, isEmpty);
          expect(data.value, ddl);
          expect(data.flagsCollection.isTextField, isTrue);
          expect(data.flagsCollection.isReadOnly, isTrue);
          expect(data.textDirection, TextDirection.ltr);
          expect(backend.client.executions, isEmpty);
          expect(original.editor.text, 'SELECT unchanged_owner;');
          expect(original.sessionId, isNull);
          expect(owner.sessionId, isNull);
          expect(tester.takeException(), isNull);
          semantics.dispose();
          disposed = true;
        },
      );
    }
  }
}
