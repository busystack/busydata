import 'support/fake_backend.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' show SemanticsRole, Tristate;
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/platform/common/output_commit.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_close.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windowChannel = MethodChannel('yaru_window');
  const windowEvents = EventChannel('yaru_window/events');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      windowChannel,
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockStreamHandler(
      windowEvents,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockStreamHandler(windowEvents, null);
  });
  test(
    'close summary covers transactions and uncertain operations across tabs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-close-',
      );
      final model = WorkbenchModel(directory)
        ..newDocument(text: 'SELECT 1;')
        ..newDocument();
      try {
        model.documents.first.sessionId = 'other-tab';
        model.sessions['other-tab'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'other-tab',
          transaction: rpc.TransactionState.ACTIVE,
        );
        model.sessions['uncertain'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'uncertain',
          transaction: rpc.TransactionState.UNKNOWN_TRANSACTION,
        );
        model.jobs['fetch'] = rpc.JobInfo(state: rpc.JobState.FETCHING);
        model.jobs['unknown'] = rpc.JobInfo(
          state: rpc.JobState.UNKNOWN_OUTCOME,
        );
        model.jobs['done'] = rpc.JobInfo(state: rpc.JobState.COMPLETED);
        final pending = PendingWorkbenchWork(model);
        expect(
          pending.documents,
          1,
          reason: 'An unsaved populated SQL document requires review',
        );
        expect(pending.jobs, 1);
        expect(pending.transactions, 1);
        expect(pending.uncertain, 1);
        expect(pending.uncertainSessions, 1);
        expect(pending.pending, isTrue);
      } finally {
        model.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'F2 close waits for a pending save and preserves edits made during it',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-close-saving-'),
      ))!;
      final io = (await tester.runAsync(() async => CloseSaveIo()))!;
      final document = (await tester.runAsync(
        () async => SqlDocument(text: 'SELECT 1;', io: io),
      ))!;
      final model = (await tester.runAsync(
        () async => WorkbenchModel(directory)..documents.add(document),
      ))!;
      Future<bool>? attempt;
      addTearDown(() async {
        model.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      await tester.pumpWidget(const MaterialApp(home: Text('Workbench')));
      await tester.runAsync(() async {
        final save = document.save('${directory.path}/query.sql');
        await io.entered.future;
        document.editor.selectAll();
        document.editor.replaceSelection('SELECT 2;');
        attempt = requestWorkbenchClose(
          tester.element(find.text('Workbench')),
          model,
          const LinuxControls(),
        );
        expect(PendingWorkbenchWork(model).saves, 1);
        io.release.complete();
        await save;
      });
      await tester.pumpAndSettle();
      expect(find.text('Close BusyData'), findsOneWidget);
      await tester.tap(find.text('Save drafts and close'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => attempt!), isTrue);
      final disk = (await tester.runAsync(
        () => File('${directory.path}/query.sql').readAsString(),
      ))!;
      expect(disk, 'SELECT 1;');
      expect(document.dirty, isTrue);
      final recovered = (await tester.runAsync(
        () => DraftStore(directory).load(),
      ))!;
      expect(recovered.single.editor.text, 'SELECT 2;');
      expect(recovered.single.dirty, isTrue);
      recovered.single.dispose();
    },
  );

  testWidgets('F2 failed SQL save cannot authorize closing', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('busydata-close-save-failure-'),
    ))!;
    final document = (await tester.runAsync(
      () async => SqlDocument(text: 'SELECT 1;'),
    ))!;
    final model = (await tester.runAsync(
      () async => WorkbenchModel(directory)..documents.add(document),
    ))!;
    addTearDown(() async {
      model.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    });
    await tester.pumpWidget(const MaterialApp(home: Text('Workbench')));
    Future<bool>? attempt;
    await tester.runAsync(() async {
      // Renaming a regular temporary file over a directory is an actual rename failure.
      final destination = Directory('${directory.path}/directory.sql');
      await destination.create();
      await expectLater(
        document.save(destination.path),
        throwsA(isA<FileSystemException>()),
      );
      attempt = requestWorkbenchClose(
        tester.element(find.text('Workbench')),
        model,
        const LinuxControls(),
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('SQL save failed · Close BusyData'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => attempt!), isFalse);
    expect(model.status, contains('SQL save failed'));
    expect(document.dirty, isTrue);
  });

  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} close review preserves work or saves recovery',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-close-ui-'),
        ))!;
        final model = (await tester.runAsync(
          () async => WorkbenchModel(directory)..newDocument(text: 'SELECT 1;'),
        ))!;
        Future<bool>? attempt;
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => directory.delete(recursive: true));
        });
        const home = Center(child: Text('Workbench'));
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: home)
              : MaterialApp(home: home),
        );
        await tester.runAsync(() async {
          attempt = requestWorkbenchClose(
            tester.element(find.text('Workbench')),
            model,
            controls,
          );
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('Unsaved documents: 1'), findsOneWidget);
        expect(find.textContaining('Active jobs: 0'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        if (controls is WindowsControls) {
          final title = tester
              .getSemantics(find.text('Close BusyData'))
              .getSemanticsData();
          expect(title.label, 'Close BusyData');
          expect(title.flagsCollection.isHeader, isTrue);
          var ancestor = tester.getSemantics(find.text('Stay')).parent;
          var foundDialog = false;
          while (ancestor != null) {
            final data = ancestor.getSemanticsData();
            if (data.role == SemanticsRole.dialog &&
                data.label == 'Close BusyData') {
              foundDialog = true;
              expect(data.flagsCollection.scopesRoute, isTrue);
              expect(data.flagsCollection.namesRoute, isTrue);
              break;
            }
            ancestor = ancestor.parent;
          }
          expect(foundDialog, isTrue);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Stay'), findsOneWidget);
        var reachedStay = false;
        for (var step = 0; step < 8; step++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          if (tester
                  .getSemantics(find.text('Stay'))
                  .getSemanticsData()
                  .flagsCollection
                  .isFocused ==
              Tristate.isTrue) {
            reachedStay = true;
            break;
          }
        }
        expect(
          reachedStay,
          isTrue,
          reason: 'Close review is keyboard operable',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        semantics.dispose();
        expect(await tester.runAsync(() => attempt!), isFalse);
        expect(model.document.editor.text, 'SELECT 1;');
        // Stay preserves the document; normal background draft recovery may
        // already have saved it independently of the close decision.
        if ((await tester.runAsync(
          () => File('${directory.path}/drafts.json').exists(),
        ))!) {
          expect(
            await tester.runAsync(
              () => File('${directory.path}/drafts.json').readAsString(),
            ),
            contains('SELECT 1;'),
          );
        }
        await tester.runAsync(() async {
          attempt = requestWorkbenchClose(
            tester.element(find.text('Workbench')),
            model,
            controls,
          );
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save drafts and close'));
        await tester.pumpAndSettle();
        final closed = await tester.runAsync(() => attempt!);
        await tester.pumpAndSettle();
        expect(closed, isTrue);
        expect(
          await tester.runAsync(
            () => File('${directory.path}/drafts.json').exists(),
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed draft save keeps the application open', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('busydata-close-denied-'),
    ))!;
    final recovery = File('${directory.path}/drafts.json');
    await tester.runAsync(() => recovery.writeAsString('previous recovery'));
    final entered = Completer<void>(), fail = Completer<void>();
    final model =
        WorkbenchModel(
            directory,
            presentationWrite: (file, bytes) async {},
            recoveryWrite: (file, bytes) async {
              if (!entered.isCompleted) entered.complete();
              await fail.future;
              throw FileSystemException(
                'Injected denied replacement',
                file.path,
              );
            },
          )
          ..draftRecovery = false
          ..newDocument(text: 'SELECT 1;');
    model.draftRecovery = true;
    Future<bool>? attempt;
    addTearDown(() async {
      if (!fail.isCompleted) fail.complete();
      model.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    });
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: Text('Workbench'))),
    );
    attempt = requestWorkbenchClose(
      tester.element(find.text('Workbench')),
      model,
      const LinuxControls(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save drafts and close'));
    await tester.pumpAndSettle();
    expect(entered.isCompleted, isTrue);
    fail.complete();
    await tester.pumpAndSettle();
    expect(find.text('Recovery failed'), findsOneWidget);
    expect(model.document.dirty, isTrue);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(await attempt, isFalse);
    expect(model.status, contains('BusyData remains open'));
    expect(await tester.runAsync(recovery.readAsString), 'previous recovery');
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed workbench rejects a late recovery-close completion', (
    tester,
  ) async {
    final entered = Completer<void>(), fail = Completer<void>();
    final model = WorkbenchModel(
      Directory.systemTemp,
      presentationWrite: (file, bytes) async {
        entered.complete();
        await fail.future;
        throw const FileSystemException('Injected late write failure');
      },
    )..draftRecovery = false;
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: Text('Workbench'))),
    );
    late final Future<bool> attempt;
    attempt = requestWorkbenchClose(
      tester.element(find.text('Workbench')),
      model,
      const LinuxControls(),
    );
    await tester.pumpAndSettle();
    expect(entered.isCompleted, isTrue);
    model.dispose();
    fail.complete();
    await tester.pumpAndSettle();
    expect(await attempt, isFalse);
    expect(find.text('Recovery failed'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class CloseSaveIo extends DocumentIo {
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(
    File file,
    List<int> bytes, {
    required Future<void> Function() beforeReplace,
    OutputDestination? destination,
  }) async {
    entered.complete();
    await release.future;
    await super.write(
      file,
      bytes,
      beforeReplace: beforeReplace,
      destination: destination,
    );
  }
}
