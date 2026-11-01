import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every literal separator is admitted before editor allocation and recovery quotas preserve files',
    () async {
      for (final separator in ['\r', '\n', '\r\n']) {
        expect(
          () => SqlDocument(text: 'x$separator' * 100000),
          throwsA(isA<DocumentResourceLimit>()),
        );
      }
      final root = await Directory.systemTemp.createTemp(
        'busydata-separator-quota-',
      );
      final file = File('${root.path}/drafts.json');
      try {
        final body = jsonEncode({
          'version': 1,
          'documents': [
            {'id': 'safe-document', 'text': 'x\r' * 100000, 'savedText': ''},
          ],
        });
        await file.writeAsString(body);
        final store = DraftStore(root);
        expect(
          await store.load(),
          isEmpty,
          reason: 'The over-budget editor must never be allocated',
        );
        expect(store.unadoptedRecords, hasLength(1));
        expect(
          store.unadoptedRecords.single,
          jsonDecode(body)['documents'].single,
        );
        expect(await file.readAsString(), body);
        expect(await root.list().length, 1);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'Unicode SQL saves and reopens within the same UTF-16 and byte policy',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-unicode-file-',
      );
      final text = '漢' * 3000000;
      final document = SqlDocument(text: text, profileId: 'saved-profile')
        ..connectionCatalog = 'exact_database'
        ..connectionSchema = 'audit';
      final workspace = File('${root.path}/workspace.json');
      final sql = File('${root.path}/unicode.sql');
      final loaded = <SqlDocument>[];
      try {
        await document.save(sql.path);
        expect(await sql.length(), 9000000);
        await PortableWorkspace.save(workspace, [document]);
        loaded.addAll(await PortableWorkspace.load(workspace));
        expect(loaded.single.editor.text, text);
        expect(loaded.single.dirty, isFalse);
        expect(loaded.single.diskHash, document.diskHash);
        expect(loaded.single.profileId, 'saved-profile');
        expect(loaded.single.connectionCatalog, 'exact_database');
        expect(loaded.single.connectionSchema, 'audit');
        expect(loaded.single.sessionId, isNull);
      } finally {
        document.dispose();
        for (final document in loaded) {
          document.dispose();
        }
        await root.delete(recursive: true);
      }
    },
  );
  test('SQL UTF-8 admission counts exact bytes before protocol encoding', () {
    for (final text in ['ASCII', '漢😀\r\n', 'é']) {
      expect(validateSqlUnicode(text), utf8.encode(text).length);
      expect(
        () => validateSqlUnicode(
          text,
          maxUtf8Bytes: utf8.encode(text).length - 1,
        ),
        throwsA(isA<DocumentResourceLimit>()),
      );
    }
  });

  test(
    'bounded workspace reads reject sparse oversized files before decoding',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-workspace-quota-',
      );
      final large = File('${root.path}/large.sql');
      final workspace = File('${root.path}/workspace.json');
      try {
        final handle = await large.open(mode: FileMode.write);
        await handle.truncate(2147483648);
        await handle.close();
        await workspace.writeAsString(
          jsonEncode({
            'version': 1,
            'documents': [
              {'path': 'large.sql', 'profileId': 'safe-reference'},
            ],
          }),
        );
        await expectLater(
          PortableWorkspace.load(workspace),
          throwsA(isA<DocumentResourceLimit>()),
        );
        expect(await large.length(), 2147483648);
        expect(await workspace.exists(), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'recovery quota failures preserve the previous recovery file and dirty document',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-draft-quota-',
      );
      final store = DraftStore(root), document = SqlDocument(text: 'SELECT 1;');
      try {
        await store.save([document], 0);
        final file = File('${root.path}/drafts.json'),
            before = await File('${root.path}/drafts.json').readAsString();
        document.editor.text = '\u0000' * 6000000;
        await expectLater(
          store.save([document], 0),
          throwsA(isA<DocumentResourceLimit>()),
        );
        expect(await file.readAsString(), before);
        expect(document.dirty, isTrue);
        final handle = await file.open(mode: FileMode.write);
        await handle.truncate(33554433);
        await handle.close();
        await expectLater(store.load(), throwsA(isA<DocumentResourceLimit>()));
        expect(
          await file.exists(),
          isTrue,
          reason:
              'Resource failures do not rename valid user recovery as corruption',
        );
      } finally {
        document.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'JSON quota counts escaped strings and rejects deep structure before decoding',
    () {
      for (final value in ['漢😀\n"\\', '\u0000\t\r', 'ordinary SQL']) {
        expect(jsonStringBytes(value), utf8.encode(jsonEncode(value)).length);
      }
      expect(
        () => checkJsonNesting('${'[' * 33}0${']' * 33}'),
        throwsA(isA<DocumentResourceLimit>()),
      );
      expect(
        () => checkJsonNesting(
          jsonEncode({'text': '${'[' * 100}"\\${']' * 100}'}),
        ),
        returnsNormally,
      );
    },
  );
  test(
    'atomic save retains the primary replacement failure and cleanup failure',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-write-cleanup-',
      );
      final target = File('${root.path}/query.sql');
      try {
        await target.writeAsString('original');
        final primary = FileSystemException('injected rename failure');
        final cleanup = FileSystemException('injected cleanup failure');
        await expectLater(
          atomicWrite(
            target,
            utf8.encode('new'),
            replaceFile: (_, _) async => throw primary,
            removeTemporary: (_) async => throw cleanup,
          ),
          throwsA(
            isA<FileWriteFailure>()
                .having((e) => e.primary, 'primary', same(primary))
                .having((e) => e.cleanup, 'cleanup', same(cleanup)),
          ),
        );
        expect(await target.readAsString(), 'original');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
