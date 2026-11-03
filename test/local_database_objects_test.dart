import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busydata/src/features/workspace/documents.dart'
    show atomicWrite;
import 'support/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late TestBackend backend;
  late WorkbenchModel model;
  final profile = Profile(
    id: 'stable-source',
    name: 'Original',
    engine: Engine.POSTGRESQL,
  );
  const first = DatabaseCreationScope(
    profileId: 'stable-source',
    catalog: 'first',
    schema: 'public',
  );
  const second = DatabaseCreationScope(
    profileId: 'stable-source',
    catalog: 'second',
    schema: 'public',
  );
  VirtualViewDefinition view(
    String id,
    DatabaseCreationScope scope, {
    String name = 'Customers',
    String sql = 'SELECT * FROM public.customers',
  }) => VirtualViewDefinition(id: id, name: name, scope: scope, sql: sql);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('local-explorer-');
    backend = TestBackend();
    backend.client.profileAction = (_) async =>
        ProfileList(profiles: [profile]);
    model = WorkbenchModel(directory)
      ..backend = backend
      ..profiles.add(profile)
      ..newDocument(text: 'SELECT 71;');
  });
  tearDown(() async {
    model.dispose();
    await model.recoverNow();
    await directory.delete(recursive: true);
  });
  void noServerWork() {
    expect(backend.client.opened, isEmpty);
    expect(backend.client.executions, isEmpty);
    expect(backend.client.reviews, isEmpty);
    expect(backend.client.metadataRequests, isEmpty);
  }

  test(
    'nested folder move, reorder, rename and restart preserve stable sources without server work',
    () async {
      await model.createSourceFolderPath('QA/Quick', '');
      final qa = model.sourceFolders.values.singleWhere((f) => f.name == 'QA');
      final quick = model.sourceFolders.values.singleWhere(
        (f) => f.name == 'Quick',
      );
      expect(quick.parentId, qa.id);
      await model.moveSourceToFolder(profile.id, quick.id);
      await model.saveSourceFolder(qa.id, 'Staging', '');
      expect(model.folderPath(quick.id), 'Staging / Quick');
      expect(model.sourceFolderMembership[profile.id], quick.id);
      await expectLater(
        model.saveSourceFolder(qa.id, 'Cycle', quick.id),
        throwsFormatException,
      );
      await expectLater(model.removeSourceFolder(quick.id), throwsStateError);
      expect(model.sourceFolders[qa.id]!.name, 'Staging');
      await model.moveSourceToFolder(profile.id, '');
      model.explorerPreferences['comments'] = true;
      model.explorerPreferences['virtual'] = false;
      model.explorerObjectKinds.remove(ObjectKind.SEQUENCE);
      model.explorerExpanded.add('stable-source');
      model.explorerSelection = 'stable-source';
      model.explorerNameFilter = 'customer';
      await model.reorderExplorer('s:${profile.id}', -1);
      expect(model.explorerSiblings('').first, 's:${profile.id}');
      final restored = WorkbenchModel(
        directory,
        launchBackend: (_) async => backend,
      );
      try {
        await restored.initialize();
        expect(restored.folderPath(quick.id), 'Staging / Quick');
        expect(restored.sourceFolderMembership, isEmpty);
        expect(restored.explorerSiblings('').first, 's:${profile.id}');
        expect(restored.profiles.single.id, profile.id);
        expect(restored.sessions, isEmpty);
        expect(restored.explorerPreferences['comments'], isTrue);
        expect(restored.explorerPreferences['virtual'], isFalse);
        expect(
          restored.explorerObjectKinds,
          isNot(contains(ObjectKind.SEQUENCE)),
        );
        expect(restored.explorerExpanded, {'stable-source'});
        expect(restored.explorerSelection, 'stable-source');
        expect(restored.explorerNameFilter, 'customer');
        noServerWork();
      } finally {
        restored.dispose();
        await restored.recoverNow();
      }
    },
  );

  test(
    'old group labels migrate once; deleting an empty folder keeps source profiles',
    () async {
      await File('${directory.path}/presentation.json').writeAsString(
        jsonEncode({
          'version': 1,
          'rowLimit': 10000,
          'profileGroups': {profile.id: 'QA'},
        }),
      );
      final restored = WorkbenchModel(
        directory,
        launchBackend: (_) async => backend,
      );
      try {
        await restored.initialize();
        final folder = restored.sourceFolders.values.single;
        expect(folder.name, 'QA');
        expect(restored.sourceFolderMembership[profile.id], folder.id);
        await restored.moveSourceToFolder(profile.id, '');
        await restored.removeSourceFolder(folder.id);
        expect(restored.profiles.single.id, profile.id);
        final saved =
            jsonDecode(
                  await File(
                    '${directory.path}/presentation.json',
                  ).readAsString(),
                )
                as Map;
        expect(saved.containsKey('profileGroups'), isFalse);
        expect(saved['sourceFolders'], isEmpty);
        noServerWork();
      } finally {
        restored.dispose();
        await restored.recoverNow();
      }
    },
  );

  test(
    'virtual definitions remain distinct by database and restore unbound after source deletion without execution',
    () async {
      await model.saveVirtualView(view('one', first));
      await model.saveVirtualView(view('two', second));
      await expectLater(
        model.saveVirtualView(view('duplicate', first)),
        throwsFormatException,
      );
      profile.name = 'Renamed';
      await model.savePresentation();
      backend.client.profileAction = (_) async => ProfileList();
      final restored = WorkbenchModel(
        directory,
        launchBackend: (_) async => backend,
      );
      try {
        await restored.initialize();
        expect(restored.virtualViews.length, 2);
        expect(restored.virtualViews['one']!.scope, first);
        expect(restored.virtualViews['two']!.scope, second);
        expect(() => restored.openVirtualView('one'), throwsStateError);
        restored.profiles.add(
          Profile(
            id: 'different-source',
            name: 'Renamed',
            engine: Engine.POSTGRESQL,
          ),
        );
        expect(() => restored.openVirtualView('one'), throwsStateError);
        await restored.saveVirtualView(
          view(
            'one',
            const DatabaseCreationScope(
              profileId: 'different-source',
              catalog: 'third',
              schema: 'public',
            ),
          ),
        );
        final console = restored.openVirtualView('one');
        expect(console.profileId, 'different-source');
        expect(console.connectionCatalog, 'third');
        expect(console.sessionId, isNull);
        await restored.removeVirtualView('two');
        expect(restored.virtualViews.containsKey('two'), isFalse);
        noServerWork();
      } finally {
        restored.dispose();
        await restored.recoverNow();
      }
    },
  );

  test(
    'opening and editing virtual SQL preserves existing document targets, drafts and transaction ownership',
    () async {
      final original = model.document;
      original.profileId = profile.id;
      original.sessionId = 'original-transaction';
      original.connectionCatalog = 'first';
      original.connectionSchema = 'public';
      model.sessions['original-transaction'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'original-transaction',
        profile: profile,
        currentCatalog: 'first',
        currentSchema: 'public',
        transaction: TransactionState.ACTIVE,
      );
      await model.saveVirtualView(
        view('one', second, sql: 'DELETE FROM public.customers'),
      );
      final opened = model.openVirtualView('one');
      expect(opened, isNot(same(original)));
      expect(opened.connectionCatalog, 'second');
      expect(opened.sessionId, isNull);
      expect(opened.editor.text, 'DELETE FROM public.customers');
      expect(model.openVirtualView('one'), same(opened));
      opened.editor.text = 'SELECT unsaved_console_text';
      await model.saveVirtualView(
        view('one', second, sql: 'SELECT changed_definition'),
      );
      final updated = model.openVirtualView('one');
      expect(updated, isNot(same(opened)));
      expect(updated.editor.text, 'SELECT changed_definition');
      expect(opened.editor.text, 'SELECT unsaved_console_text');
      expect(original.editor.text, 'SELECT 71;');
      expect(original.sessionId, 'original-transaction');
      expect(
        model.sessions['original-transaction']!.transaction,
        TransactionState.ACTIVE,
      );
      await model.removeVirtualView('one');
      expect(model.documents, containsAll([original, opened, updated]));
      noServerWork();
    },
  );

  for (final change in ['host', 'production', 'read-only']) {
    test(
      'virtual Run cannot reuse a session after its saved source changes $change',
      () async {
        await model.saveVirtualView(view('one', second));
        final opened = model.openVirtualView('one');
        opened.sessionId = 'original-transaction';
        model.sessions['original-transaction'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'original-transaction',
          profile: profile.deepCopy(),
          currentCatalog: 'second',
          currentSchema: 'public',
          transaction: TransactionState.ACTIVE,
        );
        model.profiles[0] = profile.deepCopy()..name = 'Renamed';
        expect(model.openVirtualView('one'), same(opened));
        final changed = model.profiles.single.deepCopy();
        switch (change) {
          case 'host':
            changed.host = 'another-host';
          case 'production':
            changed.environment = Environment.PRODUCTION;
          case 'read-only':
            changed.readOnly = true;
        }
        model.profiles[0] = changed;
        final current = model.openVirtualView('one');
        expect(current, isNot(same(opened)));
        expect(current.sessionId, isNull);
        expect(current.connectionCatalog, 'second');
        expect(current.connectionSchema, 'public');
        expect(opened.sessionId, 'original-transaction');
        expect(
          model.sessions['original-transaction']!.transaction,
          TransactionState.ACTIVE,
        );
        expect(opened.editor.text, 'SELECT * FROM public.customers');
        noServerWork();
      },
    );
  }

  test(
    'renaming a local definition survives reopening with the same identity, SQL and scope',
    () async {
      await model.saveVirtualView(view('one', second));
      await model.saveVirtualView(view('one', second, name: 'Renamed report'));
      final restored = WorkbenchModel(
        directory,
        launchBackend: (_) async => backend,
      );
      try {
        await restored.initialize();
        final saved = restored.virtualViews['one']!;
        expect(saved.name, 'Renamed report');
        expect(saved.sql, 'SELECT * FROM public.customers');
        expect(saved.scope, second);
        expect(restored.sessions, isEmpty);
        noServerWork();
      } finally {
        restored.dispose();
        await restored.recoverNow();
      }
    },
  );

  test(
    'failed local writes roll back definitions and folders; definitions and nesting stay bounded',
    () async {
      final failing = WorkbenchModel(
        directory,
        presentationWrite: (_, _) async {
          throw const FileSystemException('fixture');
        },
      )..profiles.add(profile);
      try {
        await expectLater(
          failing.createSourceFolderPath('Parent/Child', ''),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          failing.saveVirtualView(view('one', first)),
          throwsA(isA<FileSystemException>()),
        );
        expect(failing.sourceFolders, isEmpty);
        expect(failing.virtualViews, isEmpty);
      } finally {
        failing.dispose();
        await failing.recoverNow();
      }
      await expectLater(
        model.createSourceFolderPath('a/b/c/d/e/f/g/h/i', ''),
        throwsFormatException,
      );
      expect(model.sourceFolders, isEmpty);
      expect(() => view('one', first, sql: 'x' * 16385), throwsFormatException);
      noServerWork();
    },
  );
  test(
    'disposed local recovery releases its parent guard only after draining',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'local-explorer-drain-',
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      var commits = 0;
      final traced = WorkbenchModel(
        root,
        recoveryWrite: (file, bytes) => atomicWrite(
          file,
          bytes,
          commitHook: (phase) async {
            if (phase == 'before-finalization' && commits++ == 0) {
              entered.complete();
              await release.future;
            }
          },
        ),
      )..newDocument(text: 'SELECT 71;');
      final saving = traced.recoverNow();
      final destination = Directory('${root.path}-moved');
      var moved = false;
      try {
        await entered.future;
        traced.dispose();
        if (Platform.isWindows) {
          FileSystemException? blocked;
          try {
            await root.rename(destination.path);
            moved = true;
          } on FileSystemException catch (error) {
            blocked = error;
          }
          expect(
            moved,
            isFalse,
            reason:
                'The disposed model still owns its actual native parent guard',
          );
          expect(blocked?.osError?.errorCode, 32);
        }
        var drained = false;
        final draining = traced.recoverNow().then((_) => drained = true);
        await Future<void>.delayed(Duration.zero);
        expect(
          drained,
          isFalse,
          reason: 'Cleanup must wait for the real held commit',
        );
        release.complete();
        await saving;
        await draining;
        final completed = commits;
        await traced.recoverNow();
        expect(
          commits,
          completed,
          reason: 'Disposed drain starts no new write',
        );
        expect(await File('${root.path}/drafts.json').exists(), isTrue);
        await root.rename(destination.path);
        moved = true;
      } finally {
        if (!release.isCompleted) release.complete();
        if (!traced.isDisposed) traced.dispose();
        try {
          await saving;
        } finally {
          try {
            await traced.recoverNow();
          } finally {
            if (moved && await destination.exists()) {
              await destination.delete(recursive: true);
            }
            if (await root.exists()) await root.delete(recursive: true);
          }
        }
      }
    },
  );
}
