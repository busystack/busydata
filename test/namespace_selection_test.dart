import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late namespace persistence acknowledgement cannot accept a replaced source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'namespace-late-write-',
      );
      var accepted = true, block = false;
      final entered = Completer<void>(), release = Completer<void>();
      final model = WorkbenchModel(
        directory,
        presentationWrite: (file, bytes) async {
          if (block) {
            block = false;
            entered.complete();
            await release.future;
          }
          await file.writeAsBytes(bytes);
        },
      )..profiles.add(Profile(id: 'p'));
      try {
        await model.selectNamespaces(
          'p',
          'db',
          NamespaceSelection(names: ['original']),
        );
        block = true;
        final write = model.selectNamespaces(
          'p',
          'db',
          NamespaceSelection(
            mode: NamespaceSelectionMode.all,
            excluded: ['other'],
          ),
          mayAdopt: () => accepted,
        );
        await entered.future;
        accepted = false;
        release.complete();
        await expectLater(write, throwsStateError);
        expect(model.namespaceSelection('p', 'db')!.names, {'original'});
        final stored =
            jsonDecode(
                  await File(
                    '${directory.path}/presentation.json',
                  ).readAsString(),
                )
                as Map;
        expect(stored['namespaceSelections']['p\u0000db']['names'], [
          'original',
        ]);
      } finally {
        model.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'namespace selection survives renaming and restart without acquiring sessions or executing SQL',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'namespace-restore-',
      );
      final backend = TestBackend();
      final profile = Profile(
        id: 'stable',
        name: 'Original',
        engine: Engine.POSTGRESQL,
      );
      backend.client.profileAction = (_) async =>
          ProfileList(profiles: [profile]);
      final model = WorkbenchModel(directory)
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT 42');
      final restored = WorkbenchModel(
        directory,
        launchBackend: (_) async => backend,
      );
      try {
        model.document.profileId = profile.id;
        model.document.connectionCatalog = 'first';
        model.document.connectionSchema = 'public';
        model.document.sessionId = 'query';
        model.sessions['query'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'query',
          profile: profile,
          currentCatalog: 'first',
          currentSchema: 'public',
          transaction: TransactionState.ACTIVE,
        );
        await model.selectNamespaces(
          profile.id,
          '',
          NamespaceSelection(names: ['first', 'second']),
        );
        await model.selectNamespaces(
          profile.id,
          'first',
          NamespaceSelection(names: ['public']),
        );
        await model.selectNamespaces(
          profile.id,
          'second',
          NamespaceSelection(
            mode: NamespaceSelectionMode.pattern,
            pattern: r'^(public|audit)$',
          ),
        );
        await model.selectNamespaces(
          profile.id,
          'third',
          NamespaceSelection(
            mode: NamespaceSelectionMode.all,
            excluded: ['namespace_000'],
          ),
        );
        profile.name = 'Renamed';
        await model.savePresentation();
        expect(model.document.connectionCatalog, 'first');
        expect(model.document.connectionSchema, 'public');
        expect(model.document.sessionId, 'query');
        expect(model.sessions['query']!.transaction, TransactionState.ACTIVE);
        expect(model.document.editor.text, 'SELECT 42');
        final stored = await File(
          '${directory.path}/presentation.json',
        ).readAsString();
        // The creation counter is presentation metadata. A live session and
        // SQL contents must still never enter namespace persistence.
        final presentation = jsonDecode(stored) as Map;
        expect(presentation['querySequence'], 1);
        expect(stored, isNot(contains('"query"')));
        expect(stored, isNot(contains('SELECT 42')));
        await restored.initialize();
        expect(restored.namespaceSelection('stable', '')!.names, {
          'first',
          'second',
        });
        expect(restored.namespaceSelection('stable', 'first')!.names, {
          'public',
        });
        expect(
          restored.namespaceSelection('stable', 'second')!.pattern,
          r'^(public|audit)$',
        );
        expect(
          restored.namespaceSelection('stable', 'third')!.mode,
          NamespaceSelectionMode.all,
        );
        expect(restored.namespaceSelection('stable', 'third')!.excluded, {
          'namespace_000',
        });
        expect(restored.explorerSessions, isEmpty);
        expect(restored.sessions, isEmpty);
        expect(backend.client.opened, isEmpty);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.metadataRequests, isEmpty);
      } finally {
        model.dispose();
        restored.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'failed persistence retains the previous accepted namespace selection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'namespace-write-',
      );
      var reject = false;
      final model = WorkbenchModel(
        directory,
        presentationWrite: (file, bytes) async {
          if (reject) throw const FileSystemException('Fixture write failure');
          await file.writeAsBytes(bytes);
        },
      )..profiles.add(Profile(id: 'source'));
      try {
        await model.selectNamespaces(
          'source',
          '',
          NamespaceSelection(names: ['first']),
        );
        reject = true;
        await expectLater(
          model.selectNamespaces(
            'source',
            '',
            NamespaceSelection(mode: NamespaceSelectionMode.all),
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(model.namespaceSelection('source', '')!.names, {'first'});
        expect(model.namespaceSelectionRevision, 1);
        final stored = jsonDecode(
          await File('${directory.path}/presentation.json').readAsString(),
        );
        expect(stored['namespaceSelections']['source\u0000']['mode'], 'names');
      } finally {
        model.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'namespace rules reject invalid expressions and retain bounded native names',
    () {
      expect(
        () => NamespaceSelection(
          mode: NamespaceSelectionMode.pattern,
          pattern: '(',
        ),
        throwsFormatException,
      );
      expect(
        () =>
            NamespaceSelection(names: List.generate(129, (index) => '$index')),
        throwsFormatException,
      );
      expect(
        () => NamespaceSelection(pattern: 'a' * 257),
        throwsFormatException,
      );
      expect(
        () => NamespaceSelection(
          mode: NamespaceSelectionMode.all,
          excluded: List.generate(129, (i) => '$i'),
        ),
        throwsFormatException,
      );
      expect(
        () => NamespaceSelection(excluded: ['unselected']),
        throwsFormatException,
      );
      final rule = NamespaceSelection(
        names: ['Public', 'public', 'a:b', 'a/b'],
      );
      expect(NamespaceSelection.fromJson(rule.toJson()).names, rule.names);
      expect(rule.names, hasLength(4));
    },
  );
  test(
    'object identity preserves subtype, parent, overload, source and actual database',
    () {
      DatabaseObjectIdentity object(
        String source,
        String database, {
        ObjectSubtype subtype = ObjectSubtype.ORDINARY_TABLE,
        String parent = '',
        String identifier = '',
      }) => DatabaseObjectIdentity(
        profileId: source,
        catalog: database,
        schema: 'public',
        kind: ObjectKind.TABLE,
        name: 'same',
        subtype: subtype,
        parent: parent,
        identifier: identifier,
      );
      final base = object('source', 'first');
      expect({
        base,
        object('other', 'first'),
        object('source', 'second'),
        object('source', 'first', subtype: ObjectSubtype.FOREIGN_TABLE),
        object('source', 'first', parent: 'parent'),
        object('source', 'first', identifier: 'same(integer)'),
      }, hasLength(6));
    },
  );
}
