import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'document_save_test.dart' show GatedIo;

void main() {
  test('live document quotas reject edits without losing undo or caret', () {
    final budget = DocumentBudget(maxDocuments: 2, maxUnits: 12);
    final model = WorkbenchModel(Directory('/unused'), documentBudget: budget)
      ..draftRecovery = false;
    try {
      model.newDocument(text: 'abcdefgh');
      final a = model.document;
      model.newDocument(text: '1234');
      final b = model.document;
      expect(() => model.newDocument(), throwsA(isA<DocumentResourceLimit>()));
      a.editor.selectAll();
      a.editor.replaceSelection('abcd');
      b.editor.selectAll();
      b.editor.replaceSelection('12345678');
      final before = a.editor.value;
      a.editor.undo();
      expect(model.status, contains('Workspace text budget'));
      expect(a.editor.value, before);
      expect(a.editor.canUndo, isTrue);
      b.editor.selectAll();
      b.editor.replaceSelection('1234');
      a.editor.undo();
      expect(a.editor.text, 'abcdefgh');
      expect(budget.units, 12);
      expect(a.dirty, isTrue);
    } finally {
      model.dispose();
    }
    expect(budget.units, 0);
    expect(budget.count, 0);
  });

  test(
    'workspace cohort admission is atomic and releases unused editors',
    () async {
      final budget = DocumentBudget(maxDocuments: 3, maxUnits: 12);
      final model = WorkbenchModel(Directory('/unused'), documentBudget: budget)
        ..draftRecovery = false
        ..newDocument(text: 'original');
      final old = model.document;
      final incoming = [SqlDocument(text: '123'), SqlDocument(text: '456')];
      try {
        expect(
          () => model.adoptDocuments(incoming),
          throwsA(isA<DocumentResourceLimit>()),
        );
        expect(model.documents, [old]);
        expect(model.document, same(old));
        expect(budget.units, 8);
        await expectLater(incoming.first.save('/unused'), throwsStateError);
        model.adoptDocuments([SqlDocument(text: '1234')]);
        expect(model.documents.length, 2);
        expect(budget.units, 12);
      } finally {
        model.dispose();
      }
    },
  );

  test('captured canonical text stays reserved while saves run', () async {
    final root = await Directory.systemTemp.createTemp(
      'busydata-save-admission-',
    );
    final budget = DocumentBudget(maxUnits: 12),
        captures = SaveCaptureBudget(maxBytes: 24, maxOperations: 1);
    final io = GatedIo();
    final document = SqlDocument(text: 'abcdef', io: io, saveBudget: captures);
    final other = SqlDocument();
    budget.attachAll([document, other]);
    try {
      final saved = document.save('${root.path}/query.sql');
      await io.entered.future;
      final encodedBytes = utf8.encode(document.editor.text).length;
      final capturedTextBytes = document.editor.text.length * 2;
      expect(captures.bytes, encodedBytes + encodedBytes + capturedTextBytes);
      expect(
        () => other.editor.text = 'x',
        throwsA(isA<DocumentResourceLimit>()),
      );
      await expectLater(
        document.save('${root.path}/other.sql'),
        throwsA(isA<DocumentResourceLimit>()),
      );
      io.release.complete();
      await saved;
      expect(await File('${root.path}/query.sql').readAsString(), 'abcdef');
      expect(document.savedText, 'abcdef');
      expect(captures.bytes, 0);
      expect(captures.operations, 0);
      await expectLater(
        document.savesFinished,
        throwsA(isA<DocumentResourceLimit>()),
      );
      document.editor.text = 'abc';
      other.editor.text = '123';
      await document.save('${root.path}/query.sql');
      expect(document.lastSaveError, isNull);
      expect(await File('${root.path}/query.sql').readAsString(), 'abc');
      expect(budget.units, 9);
    } finally {
      document.dispose();
      other.dispose();
      await root.delete(recursive: true);
    }
    expect(budget.units, 0);
  });
}
