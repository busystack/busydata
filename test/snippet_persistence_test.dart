import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test(
    'overlapping snippet saves retain both updates and restore without execution',
    () async {
      final root = await Directory.systemTemp.createTemp('busydata-snippets-'),
          entered = Completer<void>(),
          gate = Completer<void>();
      var writes = 0;
      final model = WorkbenchModel(
        root,
        presentationWrite: (file, bytes) async {
          if (++writes == 1) {
            entered.complete();
            await gate.future;
          }
          await file.writeAsBytes(bytes, flush: true);
        },
      );
      final backend = TestBackend(),
          restored = WorkbenchModel(root, launchBackend: (_) async => backend);
      try {
        final first = model.saveSnippet('quoted 漢', 'SELECT \'😀\';\r\n');
        await entered.future;
        final second = model.saveSnippet('transaction', 'BEGIN;\nROLLBACK;');
        gate.complete();
        await Future.wait([first, second]);
        final data = jsonDecode(
          await File('${root.path}/presentation.json').readAsString(),
        );
        expect(data['snippets']['quoted 漢'], 'SELECT \'😀\';\r\n');
        expect(data['snippets']['transaction'], 'BEGIN;\nROLLBACK;');
        await restored.initialize();
        expect(restored.snippets['quoted 漢'], 'SELECT \'😀\';\r\n');
        expect(restored.sessions, isEmpty);
        expect(backend.client.opened, isEmpty);
      } finally {
        model.dispose();
        restored.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'failed snippet persistence restores the prior values and permits a later save',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-snippet-failure-',
      );
      var fail = true;
      final model = WorkbenchModel(
        root,
        presentationWrite: (file, bytes) async {
          if (fail) throw FileSystemException('injected write denial');
          await file.writeAsBytes(bytes, flush: true);
        },
      );
      try {
        final before = Map<String, String>.of(model.snippets);
        await expectLater(
          model.saveSnippet('failed', 'SELECT 0;'),
          throwsA(isA<FileSystemException>()),
        );
        expect(model.snippets, before);
        fail = false;
        await model.saveSnippet('successful', 'SELECT 1;');
        expect(model.snippets['successful'], 'SELECT 1;');
        expect(model.snippets.containsKey('failed'), isFalse);
        await expectLater(
          model.saveSnippet('oversized', 'x' * 4097),
          throwsStateError,
        );
        expect(model.snippets.containsKey('oversized'), isFalse);
      } finally {
        model.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
