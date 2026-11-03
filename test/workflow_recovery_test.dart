import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busydata/src/features/workspace/documents.dart'
    show atomicWrite;
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test(
    'one malformed draft cannot drop other drafts or overwrite its recoverable record',
    () async {
      final root = await Directory.systemTemp.createTemp('partial-recovery-');
      final record = {'id': 'bad', 'text': 42, 'savedText': '', 'path': null};
      await File('${root.path}/drafts.json').writeAsString(
        jsonEncode({
          'version': 1,
          'documents': [
            record,
            {'id': 'good', 'text': 'SELECT 42;', 'savedText': '', 'path': null},
          ],
        }),
      );
      final model = WorkbenchModel(
        root,
        launchBackend: (_) async => TestBackend(),
      );
      try {
        await model.initialize();
        expect(model.documents.single.id, 'good');
        await model.recoverNow();
        final saved = jsonDecode(
          await File('${root.path}/drafts.json').readAsString(),
        );
        expect(saved['documents'], contains(equals(record)));
        expect(saved['documents'], hasLength(2));
      } finally {
        model.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  for (final intentional in [false, true]) {
    test(
      'normal close preserves ${intentional ? 'intentional blank' : 'internal startup scratch'} role',
      () async {
        final root = await Directory.systemTemp.createTemp('scratch-role-');
        final model = WorkbenchModel(
          root,
          launchBackend: (_) async => TestBackend(),
        );
        final restored = WorkbenchModel(
          root,
          launchBackend: (_) async => TestBackend(),
        );
        try {
          await model.initialize();
          if (intentional) model.newQuery();
          await model.recoverNow();
          await model.savePresentation();
          await restored.initialize();
          expect(restored.documents.single.editor.text, '');
          expect(
            restored.showStartSurface,
            isFalse,
            reason: 'Every restored blank SQL document is retained user work',
          );
          expect(restored.documents.single.id, model.documents.single.id);
        } finally {
          model.dispose();
          restored.dispose();
          await root.delete(recursive: true);
        }
      },
    );
  }
  test(
    'a table then 32 SQL drafts restore disconnected without lowering SQL capacity',
    () async {
      final root = await Directory.systemTemp.createTemp('mixed-tabs-');
      final backend = TestBackend()
        ..client.profileAction = (_) async =>
            ProfileList(profiles: [Profile(id: 'p')]);
      final model = WorkbenchModel(root)
        ..backend = backend
        ..profiles.add(Profile(id: 'p'));
      final restored = WorkbenchModel(
        root,
        launchBackend: (_) async => backend,
      );
      try {
        model.openTask(
          WorkbenchDocumentKind.table,
          'items',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'db',
            schema: 'one',
            name: 'items',
            kind: ObjectKind.TABLE,
          ),
        );
        for (var i = 0; i < 32; i++) {
          model.newDocument(text: 'SELECT $i;');
        }
        await model.recoverNow();
        await model.savePresentation();
        await restored.initialize();
        expect(restored.documents, hasLength(32));
        expect(restored.taskDocuments.single.object!.schema, 'one');
        expect(restored.documents.every((d) => d.sessionId == null), isTrue);
        expect(backend.client.opened, isEmpty);
        expect(backend.client.executions, isEmpty);
      } finally {
        model.dispose();
        restored.dispose();
        await model.recoverNow();
        await restored.recoverNow();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'new-object intentions restore a creation scope and unadopted designs survive saving',
    () async {
      final root = await Directory.systemTemp.createTemp('creation-scope-');
      final backend = TestBackend()
        ..client.profileAction = (_) async =>
            ProfileList(profiles: [Profile(id: 'p')]);
      final model = WorkbenchModel(root)
        ..backend = backend
        ..profiles.add(Profile(id: 'p'))
        ..newDocument();
      final restored = WorkbenchModel(
        root,
        launchBackend: (_) async => backend,
      );
      try {
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'New object',
          profileId: 'p',
          purpose: 'design',
          creationScope: const DatabaseCreationScope(
            profileId: 'p',
            catalog: 'db',
            schema: 'two',
          ),
        );
        owner.designDraft
          ..dirty = true
          ..fields['newTableName'] = 'planned';
        await model.recoverNow();
        final file = File('${root.path}/object-designs.json');
        final records =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        (records['documents'] as Map)['unadopted'] = {
          'fields': {'name': 'private intention'},
          'flags': {},
          'columns': [],
          'dirty': true,
        };
        await file.writeAsString(jsonEncode(records));
        await restored.initialize();
        final design = restored.taskDocuments.single;
        expect(design.object, isNull);
        expect(design.creationScope!.schema, 'two');
        expect(design.designDraft.fields['newTableName'], 'planned');
        expect(design.sessionId, isNull);
        await restored.recoverNow();
        expect(
          (jsonDecode(await file.readAsString()) as Map)['documents'],
          contains('unadopted'),
        );
      } finally {
        model.dispose();
        restored.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'disposed recovery queue drains an already open fixture write',
    () async {
      final root = await Directory.systemTemp.createTemp('recovery-drain-');
      final entered = Completer<void>();
      final release = Completer<void>();
      var writes = 0;
      final model = WorkbenchModel(
        root,
        recoveryWrite: (file, bytes) async {
          writes++;
          if (writes != 1) {
            await atomicWrite(file, bytes);
            return;
          }
          final output = await file.open(mode: FileMode.write);
          entered.complete();
          try {
            await release.future;
            await output.writeFrom(bytes);
          } finally {
            await output.close();
          }
        },
      )..newDocument(text: 'SELECT 42;');
      final saving = model.recoverNow();
      try {
        await entered.future;
        model.dispose();
        var drained = false;
        final draining = model.recoverNow().then((_) => drained = true);
        await Future<void>.delayed(Duration.zero);
        expect(drained, isFalse, reason: 'The owned file is still open');
        release.complete();
        await saving;
        await draining;
        expect(drained, isTrue);
        final completedWrites = writes;
        await model.recoverNow();
        expect(
          writes,
          completedWrites,
          reason: 'Disposed models start no new recovery',
        );
        expect(await File('${root.path}/drafts.json').exists(), isTrue);
      } finally {
        if (!release.isCompleted) release.complete();
        if (!model.isDisposed) model.dispose();
        await saving;
        await model.recoverNow();
        await root.delete(recursive: true);
      }
    },
  );
}
