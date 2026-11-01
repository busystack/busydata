import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  late Directory root;
  late TestBackend backend;
  late WorkbenchModel model;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('busydata-design-recovery-');
    backend = TestBackend();
    backend.client.profileAction = (_) async => ProfileList(
      profiles: [Profile(id: 'p', name: 'Staging')],
    );
    model = WorkbenchModel(root, launchBackend: (_) async => backend)
      ..newDocument();
    model.backend = backend;
    model.profiles.add(Profile(id: 'p', name: 'Staging'));
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  DatabaseObjectIdentity identity(String name) => DatabaseObjectIdentity(
    profileId: 'p',
    catalog: 'db',
    schema: 'public',
    kind: ObjectKind.TABLE,
    name: name,
  );
  test(
    'native routine reopen hints retain exact overload without sessions or execution',
    () async {
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'same(x integer)',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: ObjectKind.ROUTINE,
          name: 'same',
          identifier: 'same(x integer)',
        ),
      );
      await model.savePresentation();
      final restoredBackend = TestBackend()
        ..client.profileAction = backend.client.profileAction;
      final restored = WorkbenchModel(
        root,
        launchBackend: (_) async => restoredBackend,
      );
      try {
        await restored.initialize();
        final hint = restored.taskDocuments.single;
        expect(hint.id, owner.id);
        expect(hint.object!.identifier, 'same(x integer)');
        expect(hint.sessionId, isNull);
        expect(hint.view.subview, 'structure');
        expect(restoredBackend.client.opened, isEmpty);
        expect(restoredBackend.client.executions, isEmpty);
        expect(restoredBackend.client.metadataRequests, isEmpty);
      } finally {
        restored.dispose();
      }
    },
  );
  test(
    'SQL, captured evidence and design intentions share one aggregate budget',
    () async {
      final bounded =
          WorkbenchModel(root, documentBudget: DocumentBudget(maxUnits: 20000))
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 's' * 1000);
      try {
        final plan = bounded.openTask(WorkbenchDocumentKind.plan, 'Plan');
        final diagram = bounded.openTask(
          WorkbenchDocumentKind.diagram,
          'Diagram',
        );
        final start = bounded.documentBudget.units;
        bounded.reserveDocumentEvidence(plan, 9000);
        bounded.reserveDocumentEvidence(diagram, 8000);
        expect(
          bounded.documentBudget.units,
          start +
              17000 +
              (plan.designDraft.bytes + diagram.designDraft.bytes) * 2,
        );
        final previous = diagram.evidenceUnits;
        expect(
          () => bounded.reserveDocumentEvidence(diagram, 19000),
          throwsA(isA<DocumentResourceLimit>()),
        );
        expect(diagram.evidenceUnits, previous);
        bounded.document.editor.text = 's' * 5000;
        expect(bounded.document.editor.text, 's' * 1000);
        await bounded.closeTask(plan);
        expect(
          bounded.documentBudget.units,
          start + 8000 + diagram.designDraft.bytes * 2,
        );
        bounded.reserveDocumentEvidence(diagram, 16000);
        final draft = ObjectDesignerDraft()..dirty = true;
        draft.fields['definition'] = 'x' * 3000;
        expect(bounded.admitDesignDraft(diagram, draft), isFalse);
        expect(diagram.evidenceUnits, 16000);
        expect(
          () => bounded.reserveDocumentEvidence(plan, 1),
          throwsStateError,
        );
      } finally {
        bounded.dispose();
      }
    },
  );
  test(
    'typed task references restore without live handles or backend work',
    () async {
      final owners = <WorkbenchDocument>[];
      for (final kind in [
        WorkbenchDocumentKind.comparison,
        WorkbenchDocumentKind.diagram,
        WorkbenchDocumentKind.administration,
        WorkbenchDocumentKind.transfer,
        WorkbenchDocumentKind.plan,
        WorkbenchDocumentKind.result,
      ]) {
        owners.add(
          model.openTask(kind, kind.name, profileId: 'p', reuse: false)
            ..reopenCommandId = 'view.results',
        );
      }
      await model.savePresentation();
      final restoredBackend = TestBackend();
      restoredBackend.client.profileAction = backend.client.profileAction;
      final restored = WorkbenchModel(
        root,
        launchBackend: (_) async => restoredBackend,
      );
      try {
        await restored.initialize();
        expect(
          restored.taskDocuments.map((d) => d.id),
          owners.map((d) => d.id),
        );
        expect(
          restored.taskDocuments.every(
            (d) => d.sessionId == null && d.payload is RestoredTaskReference,
          ),
          isTrue,
        );
        expect(restoredBackend.client.opened, isEmpty);
        expect(restoredBackend.client.executions, isEmpty);
        expect(restoredBackend.client.metadataRequests, isEmpty);
        expect(restoredBackend.client.browseRequests, isEmpty);
      } finally {
        restored.dispose();
      }
    },
  );
  test(
    'design recovery preserves typed identity and fields without any database operation',
    () async {
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'Design',
        object: identity('items'),
        purpose: 'design',
      );
      owner.view.structureSection = ObjectKind.INDEX.value;
      final draft = ObjectDesignerDraft()..dirty = true;
      draft.fields.addAll({
        'name': 'Quoted, name',
        'definition': 'SELECT 漢😀',
        'operation': 'view',
      });
      draft.columns.add(
        DesignedColumn(name: 'id', type: 'integer', nullable: false),
      );
      expect(model.admitDesignDraft(owner, draft), isTrue);
      owner.designDraft.replace(draft);
      owner.contentDirty = true;
      await model.recoverNow();
      final restoredBackend = TestBackend();
      restoredBackend.client.profileAction = backend.client.profileAction;
      final restored = WorkbenchModel(
        root,
        launchBackend: (_) async => restoredBackend,
      );
      try {
        await restored.initialize();
        final recovered = restored.taskDocuments.single;
        expect(recovered.id, owner.id);
        expect(recovered.sql, isNull);
        expect(recovered.sessionId, isNull);
        expect(recovered.purpose, 'design');
        expect(recovered.view.structureSection, ObjectKind.INDEX.value);
        expect(recovered.designDraft.fields, draft.fields);
        expect(recovered.designDraft.columns.single.name, 'id');
        expect(recovered.dirty, isTrue);
        expect(restoredBackend.client.opened, isEmpty);
        expect(restoredBackend.client.executions, isEmpty);
        expect(restoredBackend.client.browseRequests, isEmpty);
        expect(restoredBackend.client.metadataRequests, isEmpty);
        final presentation =
            jsonDecode(
                  await File('${root.path}/presentation.json').readAsString(),
                )
                as Map;
        expect(presentation['version'], 1);
        expect(jsonEncode(presentation), isNot(contains('SELECT 漢')));
      } finally {
        restored.dispose();
      }
    },
  );
  test(
    'multiple designs share one budget and release their text charge on close',
    () async {
      final a = model.openTask(
        WorkbenchDocumentKind.structure,
        'A',
        object: identity('a'),
        purpose: 'design',
      );
      final b = model.openTask(
        WorkbenchDocumentKind.structure,
        'B',
        object: identity('b'),
        purpose: 'design',
      );
      final draft = ObjectDesignerDraft()..dirty = true;
      draft.fields['definition'] = 'x' * 600000;
      expect(model.admitDesignDraft(a, draft), isTrue);
      a.designDraft.replace(draft);
      final charge = model.documentBudget.units;
      expect(model.admitDesignDraft(b, draft), isFalse);
      expect(b.designDraft.dirty, isFalse);
      await model.closeTask(a);
      expect(model.documentBudget.units, lessThan(charge));
      expect(model.admitDesignDraft(b, draft), isTrue);
    },
  );
  test(
    'recovery failure remains visible and disabled privacy retains no design text',
    () async {
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'Design',
        object: identity('items'),
        purpose: 'design',
      );
      owner.designDraft.fields['definition'] = 'private SQL';
      owner.designDraft.dirty = true;
      await model.recoverNow();
      model.draftRecovery = false;
      await model.saveObjectDesigns();
      expect(
        await File('${root.path}/object-designs.json').readAsString(),
        isNot(contains('private SQL')),
      );
      final broken = WorkbenchModel(
        root,
        recoveryWrite: (_, _) async =>
            throw const FileSystemException('unavailable'),
      );
      try {
        await expectLater(
          broken.saveObjectDesigns(),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        broken.dispose();
      }
    },
  );
}
