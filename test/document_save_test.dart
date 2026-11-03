import 'dart:io';
import 'dart:async';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/platform/common/output_commit.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'F2 overlapping delayed saves preserve captured bytes and completion order',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-save-overlap-',
      );
      final io = GatedIo();
      final document = SqlDocument(text: 'SELECT 1;', io: io);
      try {
        final target = '${root.path}/query.sql';
        final first = document.save(target);
        await io.entered.future;
        document.editor.selectAll();
        document.editor.replaceSelection('SELECT 2;');
        final second = document.save(target);
        expect(document.saving, isTrue);
        expect(io.writes, 1);
        io.release.complete();
        await first;
        await second;
        expect(await File(target).readAsString(), 'SELECT 2;');
        expect(document.savedText, 'SELECT 2;');
        expect(document.savedVersion, document.version);
        expect(document.dirty, isFalse);
        expect(document.saving, isFalse);
        expect(io.writes, 2);
      } finally {
        document.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'F2 malformed Unicode cannot replace SQL or clear a queued failure',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-save-unicode-',
      );
      final io = GatedIo();
      final document = SqlDocument(text: "SELECT '😀漢';", io: io);
      final file = File('${root.path}/query.sql');
      try {
        final first = document.save(file.path);
        await io.entered.future;
        document.editor.selectAll();
        final malformed = String.fromCharCodes([0x53, 0xd800]);
        document.editor.replaceSelection(malformed);
        final failed = expectLater(
          document.save(file.path),
          throwsFormatException,
        );
        io.release.complete();
        await first;
        await failed;
        expect(await file.readAsString(), "SELECT '😀漢';");
        expect(document.savedText, "SELECT '😀漢';");
        expect(document.editor.text, malformed);
        expect(document.dirty, isTrue);
        expect(io.writes, 1);
        await expectLater(document.savesFinished, throwsFormatException);
        final store = DraftStore(root);
        await store.save([document], 0);
        final recovered = await store.load();
        expect(recovered.single.editor.text, malformed);
        expect(recovered.single.dirty, isTrue);
        recovered.single.dispose();
        document.editor.selectAll();
        document.editor.replaceSelection("SELECT 'fixed 😀';");
        await document.save(file.path);
        expect(await file.readAsString(), "SELECT 'fixed 😀';");
        expect(document.dirty, isFalse);
      } finally {
        document.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'F2 Save As captures its own destination while newer edits remain dirty',
    () async {
      final root = await Directory.systemTemp.createTemp('busydata-save-as-');
      final original = File('${root.path}/original.sql'),
          target = File('${root.path}/new.sql');
      await original.writeAsString('SELECT 1;');
      await target.writeAsString('previous destination');
      final io = GatedIo();
      final document = SqlDocument(
        text: 'SELECT 1;',
        path: original.path,
        io: io,
      )..diskHash = sha256.convert(utf8.encode('SELECT 1;')).toString();
      try {
        final save = document.save(target.path);
        await io.entered.future;
        document.editor.selectAll();
        document.editor.replaceSelection('SELECT 3;');
        io.release.complete();
        await save;
        expect(await original.readAsString(), 'SELECT 1;');
        expect(await target.readAsString(), 'SELECT 1;');
        expect(document.path, p.normalize(target.path));
        expect(document.savedText, 'SELECT 1;');
        expect(document.dirty, isTrue);
      } finally {
        document.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  for (final duringWrite in [false, true]) {
    test(
      'F2 detects external changes ${duringWrite ? 'during' : 'before'} replacement',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'busydata-save-external-',
        );
        final target = File('${root.path}/query.sql');
        await target.writeAsString('SELECT 1;');
        final io = GatedIo();
        final document = SqlDocument(
          text: 'SELECT 1;',
          path: target.path,
          io: io,
        )..diskHash = sha256.convert(utf8.encode('SELECT 1;')).toString();
        document.editor.selectAll();
        document.editor.replaceSelection('SELECT 2;');
        try {
          if (!duringWrite) await target.writeAsString('external SQL');
          final save = document.save(target.path);
          final failed = expectLater(save, throwsStateError);
          if (duringWrite) {
            await io.entered.future;
            await target.writeAsString('external SQL');
            io.release.complete();
          }
          await failed;
          expect(await target.readAsString(), 'external SQL');
          expect(document.savedText, 'SELECT 1;');
          expect(document.dirty, isTrue);
        } finally {
          document.dispose();
          await root.delete(recursive: true);
        }
      },
    );
  }
  for (final stage in ['write', 'rename']) {
    test(
      'F2 $stage failure preserves disk and dirty state and permits retry',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'busydata-save-failure-',
        );
        final target = File('${root.path}/query.sql');
        await target.writeAsString('SELECT 1;');
        final io = FailingIo(stage);
        final document = SqlDocument(
          text: 'SELECT 1;',
          path: target.path,
          io: io,
        )..diskHash = sha256.convert(utf8.encode('SELECT 1;')).toString();
        document.editor.selectAll();
        document.editor.replaceSelection('SELECT 2;');
        try {
          await expectLater(
            document.save(target.path),
            throwsA(isA<FileSystemException>()),
          );
          expect(await target.readAsString(), 'SELECT 1;');
          expect(document.savedText, 'SELECT 1;');
          expect(document.dirty, isTrue);
          expect(
            await root.list().where((f) => f.path.endsWith('.tmp')).isEmpty,
            isTrue,
          );
          io.fail = false;
          await document.save(target.path);
          expect(document.dirty, isFalse);
          expect(await target.readAsString(), 'SELECT 2;');
        } finally {
          document.dispose();
          await root.delete(recursive: true);
        }
      },
    );
  }
  test('F2 edits during saving remain dirty and recoverable', () async {
    final root = await Directory.systemTemp.createTemp('busydata-save-race-');
    final document = SqlDocument(text: 'SELECT 1;');
    try {
      final file = File('${root.path}/query.sql');
      final save = document.save(file.path);
      document.editor.selectAll();
      document.editor.replaceSelection("SELECT '😀漢';");
      await save;
      expect(await file.readAsString(), 'SELECT 1;');
      expect(document.savedText, 'SELECT 1;');
      expect(
        document.diskHash,
        sha256.convert(utf8.encode('SELECT 1;')).toString(),
      );
      expect(document.dirty, isTrue);
      final store = DraftStore(root);
      await store.save([document], 0);
      final recovered = await store.load();
      expect(recovered.single.editor.text, "SELECT '😀漢';");
      expect(recovered.single.dirty, isTrue);
      recovered.single.dispose();
    } finally {
      document.dispose();
      await root.delete(recursive: true);
    }
  });
}

class GatedIo extends DocumentIo {
  final entered = Completer<void>(), release = Completer<void>();
  int writes = 0;
  @override
  Future<void> write(
    File file,
    List<int> bytes, {
    required Future<void> Function() beforeReplace,
    OutputDestination? destination,
  }) async {
    if (writes++ == 0) {
      entered.complete();
      await release.future;
    }
    await super.write(
      file,
      bytes,
      beforeReplace: beforeReplace,
      destination: destination,
    );
  }
}

class FailingIo extends DocumentIo {
  FailingIo(this.stage);
  final String stage;
  bool fail = true;
  @override
  Future<void> write(
    File file,
    List<int> bytes, {
    required Future<void> Function() beforeReplace,
    OutputDestination? destination,
  }) async {
    if (fail && stage == 'write') {
      throw FileSystemException('Injected write failure', file.path);
    }
    await super.write(
      file,
      bytes,
      destination: destination,
      beforeReplace: () async {
        await beforeReplace();
      },
    );
  }

  @override
  Future<void> replace(File temporary, File destination) async {
    if (fail && stage == 'rename') {
      throw FileSystemException('Injected rename failure', destination.path);
    }
    await super.replace(temporary, destination);
  }
}
