import 'dart:io';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:re_editor/re_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'support/fake_backend.dart';

void main() {
  late Directory root;
  late WorkbenchModel model;
  late TestBackend backend;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('busydata-analysis-');
    backend = TestBackend();
    model =
        WorkbenchModel(
            root,
            launchBackend: (_) =>
                Future.value(TestBackend(instanceId: 'new-instance')),
          )
          ..draftRecovery = false
          ..newDocument(text: "select '😀漢';\r\nselect 2;")
          ..backend = backend;
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  test(
    'symbol lookup waits for rejected read-only analysis admission',
    () async {
      final pending = model.analyze(model.document, resolveSymbol: true);
      final outcome = expectLater(
        pending,
        completion(
          isA<Analysis>().having(
            (value) => value.symbol.complete,
            'symbol',
            isTrue,
          ),
        ),
      );
      backend.client.pendingAnalyses.single.completeError(
        GrpcError.custom(8, 'RPC concurrency limit reached', null, null, {
          'busydata-rpc-rejection': 'concurrency',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(backend.client.analyses, hasLength(2));
      expect(await model.analyze(model.document), isNull);
      final deadlines = backend.client.analysisOptions;
      expect(
        deadlines.first!.timeout,
        lessThanOrEqualTo(const Duration(seconds: 30)),
      );
      expect(deadlines.last!.timeout, lessThan(deadlines.first!.timeout!));
      backend.client.completeAnalysis(
        1,
        symbol: ResolvedSymbol(complete: true),
      );
      await outcome;
      expect(model.acceptedAnalysis, isNull);
      expect(backend.client.executions, isEmpty);
    },
  );
  test('symbol admission delay cannot follow a replaced document', () async {
    final pending = model.analyze(model.document, resolveSymbol: true);
    final outcome = expectLater(pending, completion(isNull));
    backend.client.pendingAnalyses.single.completeError(
      GrpcError.custom(8, 'RPC concurrency limit reached', null, null, {
        'busydata-rpc-rejection': 'concurrency',
      }),
    );
    model.newDocument(text: 'SELECT replacement');
    await outcome;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(backend.client.analyses, hasLength(1));
    expect(model.document.editor.text, 'SELECT replacement');
    expect(backend.client.executions, isEmpty);
  });
  test('other analysis resource failures are not retried', () async {
    final failure = GrpcError.resourceExhausted('Analysis byte budget');
    final pending = model.analyze(model.document, resolveSymbol: true);
    final outcome = expectLater(pending, throwsA(same(failure)));
    backend.client.pendingAnalyses.single.completeError(failure);
    await outcome;
    expect(backend.client.analyses, hasLength(1));
    expect(backend.client.executions, isEmpty);
  });
  test('symbol admission attempts remain bounded', () async {
    final failure = GrpcError.custom(
      8,
      'RPC concurrency limit reached',
      null,
      null,
      {'busydata-rpc-rejection': 'concurrency'},
    );
    final pending = model.analyze(model.document, resolveSymbol: true);
    final outcome = expectLater(pending, throwsA(same(failure)));
    for (var attempt = 0; attempt < 6; attempt++) {
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (backend.client.pendingAnalyses.length <= attempt &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(backend.client.pendingAnalyses, hasLength(attempt + 1));
      backend.client.pendingAnalyses[attempt].completeError(failure);
    }
    await outcome;
    expect(backend.client.analyses, hasLength(6));
    expect(backend.client.executions, isEmpty);
  });
  test(
    'explicit symbol lookup cancels background analysis without a competing completion request',
    () async {
      final background = model.analyze(model.document);
      final symbol = model.analyze(model.document, resolveSymbol: true);
      await Future<void>.delayed(Duration.zero);
      expect(backend.client.cancelledAnalyses, 1);
      expect(backend.client.analyses, hasLength(2));
      expect(await model.analyze(model.document), isNull);
      expect(backend.client.analyses, hasLength(2));
      backend.client.completeAnalysis(0, formatted: 'SELECT stale;');
      expect(await background, isNull);
      backend.client.completeAnalysis(
        1,
        symbol: ResolvedSymbol(complete: true),
      );
      expect((await symbol)?.symbol.complete, isTrue);
      expect(model.acceptedAnalysis, isNull);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'explicit symbol failure retains its actual scoped backend error',
    () async {
      final failure = StateError('Metadata connection limit reached');
      final pending = model.analyze(model.document, resolveSymbol: true);
      final expectation = expectLater(pending, throwsA(same(failure)));
      backend.client.pendingAnalyses.single.completeError(failure);
      await expectation;
      expect(backend.client.analyses, hasLength(1));
      expect(model.acceptedAnalysis, isNull);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'superseded symbol errors cannot replace another document state',
    () async {
      final pending = model.analyze(model.document, resolveSymbol: true);
      model.newDocument(text: 'other document');
      backend.client.pendingAnalyses.single.completeError(
        StateError('stale failure'),
      );
      expect(await pending, isNull);
      expect(model.document.editor.text, 'other document');
      expect(model.acceptedAnalysis, isNull);
    },
  );
  for (final engine in [Engine.POSTGRESQL, Engine.MYSQL, Engine.MARIADB]) {
    test(
      'unconnected $engine uses its captured dialect and profile revision',
      () async {
        model.profiles.add(
          Profile(id: 'native', engine: engine, host: 'first'),
        );
        model.bindUnconnectedProfile(model.activeOwner, 'native');
        final pending = model.analyze(model.document);
        expect(backend.client.analyses.single.engine, engine);
        model.profiles.single.host = 'replacement';
        backend.client.completeAnalysis(0, formatted: 'SELECT stale;');
        expect(await pending, isNull);
        expect(model.acceptedAnalysis, isNull);
        expect(backend.client.executions, isEmpty);
      },
    );
  }
  test('unconnected profile changes reject late dialect analysis', () async {
    model.profiles.addAll([
      Profile(id: 'pg', engine: Engine.POSTGRESQL),
      Profile(id: 'mysql', engine: Engine.MYSQL),
    ]);
    model.bindUnconnectedProfile(model.activeOwner, 'pg');
    final pending = model.analyze(model.document);
    model.bindUnconnectedProfile(model.activeOwner, 'mysql');
    backend.client.completeAnalysis(0, formatted: 'SELECT stale;');
    expect(await pending, isNull);
    expect(model.acceptedAnalysis, isNull);
    expect(backend.client.opened, isEmpty);
    expect(backend.client.executions, isEmpty);
  });
  test(
    'malformed UTF-16 cannot be reinterpreted by SQL execution or analysis',
    () async {
      model.document.editor.text = String.fromCharCodes([0x53, 0xd800]);
      expect(
        () => model.execution(ExecutionMode.SCRIPT),
        throwsFormatException,
      );
      expect(await model.analyze(model.document), isNull);
      model.document.editor.text = "SELECT '😀';";
      model.document.selectOffsets(8, 9);
      expect(
        () => model.execution(ExecutionMode.SELECTION),
        throwsFormatException,
      );
      expect(model.document.editor.text, "SELECT '😀';");
      model.document.selectOffsets(8, 10);
      expect(model.execution(ExecutionMode.SELECTION).sql, '😀');
    },
  );

  test(
    'formatting preserves mixed newlines inside literal SQL tokens',
    () async {
      const source = "select 'first\nsecond\r\nthird';\r\nselect 2;";
      model.document.editor.text = source;
      final pending = model.analyze(model.document);
      const formatted = "select 'first\nsecond\r\nthird';\r\n\r\nselect 2;";
      backend.client.completeAnalysis(0, formatted: formatted);
      await pending;
      expect(model.applyFormatting(model.acceptedAnalysis!), isTrue);
      expect(model.document.editor.text, formatted);
      model.document.editor.undo();
      expect(model.document.editor.text, source);
      model.document.selectOffsets(source.indexOf('select 2'), source.length);
      expect(model.document.caret, source.length);
      expect(model.execution(ExecutionMode.SELECTION).sql, 'select 2;');
    },
  );
  for (final change in [
    'edit',
    'switch',
    'close',
    'backend',
    'context',
    'metadata',
    'caret',
    'secondary',
  ]) {
    test('F3 $change during analysis rejects the stale result', () async {
      final target = model.document;
      target.sessionId = 'session';
      model.sessions['session'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'session',
        contextRevision: Int64(1),
      );
      final pending = model.analyze(target);
      mutate(change, model);
      backend.client.completeAnalysis(0);
      expect(await pending, isNull);
      expect(model.analysis, isNull);
    });
    test(
      'F3 $change during formatting confirmation preserves the bound documents',
      () async {
        final target = model.document;
        target.sessionId = 'session';
        model.sessions['session'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'session',
          contextRevision: Int64(1),
        );
        final pending = model.analyze(target);
        backend.client.completeAnalysis(
          0,
          formatted: "SELECT '😀漢';\r\n\r\nSELECT 2;",
        );
        await pending;
        final accepted = model.acceptedAnalysis!;
        mutate(change, model);
        final text = model.documents.map((d) => d.editor.text).toList();
        expect(model.applyFormatting(accepted), isFalse);
        expect(model.documents.map((d) => d.editor.text).toList(), text);
      },
    );
  }
  test(
    'F3 formatting is undoable, preserves CRLF and retains Unicode offsets',
    () async {
      final target = model.document, original = model.document.editor.text;
      target.selectOffsets(8, 11);
      final selection = target.editor.selection;
      final pending = model.analyze(target);
      backend.client.completeAnalysis(
        0,
        formatted: "SELECT '😀漢';\r\n\r\nSELECT 2;",
      );
      await pending;
      expect(model.applyFormatting(model.acceptedAnalysis!), isTrue);
      expect(target.editor.text, "SELECT '😀漢';\r\n\r\nSELECT 2;");
      expect(target.editor.selection, selection);
      expect(target.dirty, isTrue);
      target.editor.undo();
      expect(target.editor.text, original);
    },
  );
  test(
    'F3 completion cannot apply after its cursor or context changes',
    () async {
      final target = model.document;
      target.selectOffsets(0, 0);
      final pending = model.analyze(target);
      final completion = Completion(
        startUtf16: 0,
        endUtf16: 6,
        insertText: 'SELECT',
        label: 'SELECT',
      );
      backend.client.completeAnalysis(0, completions: [completion]);
      await pending;
      final accepted = model.acceptedAnalysis!;
      target.selectOffsets(2, 2);
      expect(model.applyCompletion(accepted, completion), isFalse);
      expect(target.editor.text.startsWith('select'), isTrue);
    },
  );
  test(
    'formatting maps every caret to its token and undo restores all selections',
    () async {
      const source = "select  '😀 x'; select 2;";
      const formatted = "select '😀 x';\nselect 2;";
      final target = model.document;
      target.editor.text = source;
      target.selectOffsets(source.indexOf('select 2'), source.length);
      target.editor.setExtraSelections([
        const CodeLineSelection(
          baseIndex: 0,
          baseOffset: 9,
          extentIndex: 0,
          extentOffset: 13,
        ),
      ]);
      final original = target.editor.value;
      final pending = model.analyze(target);
      backend.client.completeAnalysis(0, formatted: formatted);
      await pending;
      expect(model.applyFormatting(model.acceptedAnalysis!), isTrue);
      expect(target.editor.selectedText, 'select 2;');
      expect(target.editor.selection.baseIndex, 1);
      expect(
        target.editor.value.secondarySelections.single,
        const CodeLineSelection(
          baseIndex: 0,
          baseOffset: 8,
          extentIndex: 0,
          extentOffset: 12,
        ),
      );
      target.editor.undo();
      expect(target.editor.text, source);
      expect(target.editor.selection, original.selection);
      expect(
        target.editor.value.secondarySelections,
        original.secondarySelections,
      );
    },
  );
  test(
    'completion rejects a half-surrogate replacement and unaccepted action',
    () async {
      final target = model.document;
      const source = "SELECT '😀';";
      target.editor.text = source;
      final broken = Completion(startUtf16: 8, endUtf16: 9, insertText: 'x');
      final pending = model.analyze(target);
      backend.client.completeAnalysis(0, formatted: '', completions: [broken]);
      await pending;
      expect(model.applyCompletion(model.acceptedAnalysis!, broken), isFalse);
      expect(
        model.applyCompletion(
          model.acceptedAnalysis!,
          Completion(startUtf16: 0, endUtf16: 6, insertText: 'DROP'),
        ),
        isFalse,
      );
      expect(target.editor.text, source);
    },
  );
}

void mutate(String change, WorkbenchModel model) {
  switch (change) {
    case 'edit':
      model.document.editor.selectAll();
      model.document.editor.replaceSelection('new original SQL');
    case 'switch':
      model.newDocument(text: 'other document');
    case 'close':
      final target = model.document;
      model.newDocument(text: 'other document');
      model.documents.remove(target);
      model.selected = 0;
      target.dispose();
    case 'backend':
      model.backend = TestBackend(instanceId: 'replacement');
    case 'context':
      model.sessions['session'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'session',
        contextRevision: Int64(2),
      );
    case 'metadata':
      model.sessions['session'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'session',
        contextRevision: Int64(1),
        sessionRevision: Int64(2),
      );
    case 'caret':
      model.document.selectOffsets(3, 3);
    case 'secondary':
      model.document.editor.value = model.document.editor.value.copyWith(
        secondarySelections: [
          const CodeLineSelection.collapsed(index: 1, offset: 2),
        ],
      );
  }
}
