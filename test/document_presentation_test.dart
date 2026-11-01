import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/document_presentation.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  test(
    'creation-assigned query names survive close, reorder and bounded recovery',
    () async {
      final root = await Directory.systemTemp.createTemp('query-names-');
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument()
        ..newDocument()
        ..newDocument();
      WorkbenchModel? restored;
      try {
        final first = model.documents.first,
            second = model.documents[1],
            third = model.documents[2];
        final secondEditor = second.editor, thirdEditor = third.editor;
        expect(model.documents.map((d) => d.title), [
          'Query 1',
          'Query 2',
          'Query 3',
        ]);
        await model.closeDocument(first, reviewedRevision: first.version);
        model.documents
          ..clear()
          ..addAll([third, second]);
        model.select(1);
        model.select(0);
        expect(model.documents.map((d) => d.title), ['Query 3', 'Query 2']);
        expect(second.editor, same(secondEditor));
        expect(third.editor, same(thirdEditor));
        model.draftRecovery = true;
        await model.recoverNow();
        await model.savePresentation();
        restored = WorkbenchModel(root, launchBackend: (_) async => backend);
        await restored.initialize();
        expect(restored.documents.map((d) => (d.id, d.title)), [
          (third.id, 'Query 3'),
          (second.id, 'Query 2'),
        ]);
        restored.newDocument();
        expect(restored.document.title, 'Query 4');
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, isEmpty);
      } finally {
        model.dispose();
        restored?.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'header, tab and editor share the query name; Save As retains controller identity',
    (tester) async {
      installNativeWindowFixture(tester);
      final semantics = tester.ensureSemantics();
      var semanticsDisposed = false;
      addTearDown(() {
        if (!semanticsDisposed) semantics.dispose();
      });
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('query-name-header-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument()
        ..newDocument()
        ..newDocument();
      final document = model.document,
          controller = model.document.editor,
          owner = model.activeOwner;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Query 3'), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp('SQL editor Query 3')), findsWidgets);
      await tester.runAsync(
        () => document.save('${root.path}/customer_lookup.sql'),
      );
      model.updateStatus('Saved');
      await tester.pumpAndSettle();
      expect(find.text('customer_lookup.sql'), findsNWidgets(2));
      expect(find.text('Query 3'), findsNothing);
      expect(model.document.editor, same(controller));
      expect(model.activeOwner, same(owner));
      expect(document.id, owner.id);
      await tester.runAsync(
        () => document.save('${root.path}/customer_report.sql'),
      );
      model.updateStatus('Saved');
      await tester.pumpAndSettle();
      expect(find.text('customer_report.sql'), findsNWidgets(2));
      expect(find.text('customer_lookup.sql'), findsNothing);
      expect(model.document.editor, same(controller));
      expect(model.activeOwner, same(owner));
      semantics.dispose();
      semanticsDisposed = true;
    },
  );
  testWidgets(
    'tab qualifiers distinguish schemas, connections and independent instances in a short visible field',
    (tester) async {
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..newDocument();
      model.profiles.addAll([
        rpc.Profile(id: 'a', name: 'Development', host: 'dev'),
        rpc.Profile(id: 'b', name: 'Staging', host: 'stage'),
      ]);
      WorkbenchDocument table(String profile, String schema, String session) =>
          model.openTask(
            WorkbenchDocumentKind.table,
            'customers',
            reuse: false,
            object: DatabaseObjectIdentity(
              profileId: profile,
              catalog: 'db',
              schema: schema,
              kind: rpc.ObjectKind.TABLE,
              name: 'customers',
            ),
            profileId: profile,
          )..sessionId = session;
      final a = table('a', 'public', 'one'),
          b = table('a', 'audit', 'two'),
          c = table('b', 'public', 'three'),
          d = table('a', 'public', 'four');
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final labels = [
        for (final owner in [a, b, c, d])
          documentTabLabel(context, model, owner),
      ];
      expect(
        labels.map((p) => (p.qualifier, p.instance)).toSet(),
        hasLength(4),
      );
      expect(labels[1].qualifier, 'audit');
      expect(labels[2].qualifier, contains('Staging'));
      expect(labels.every((p) => p.qualifier.length < 32), isTrue);
      expect(labels[0].context, contains('dev:0/'));
      expect(labels[0].context, contains('one'));
      final retained = rpc.RetainedResult(
        result: rpc.StatementResult(resultId: 'retained'),
        target: rpc.Profile(
          id: 'old',
          name: 'Captured production',
          host: 'original',
          environment: rpc.Environment.PRODUCTION,
        ),
      );
      model.openRetainedResult(retained);
      final result = model.activeOwner;
      model.profiles.add(
        rpc.Profile(id: 'old', name: 'Replacement', host: 'new'),
      );
      expect(
        documentTabLabel(context, model, result).context,
        contains('Captured production'),
      );
      expect(
        documentTabLabel(context, model, result).context,
        isNot(contains('Replacement')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
}
