import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const window = MethodChannel('yaru_window');
  const events = EventChannel('yaru_window/events');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      window,
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(window, null);
    messenger.setMockStreamHandler(events, null);
  });
  testWidgets(
    'Save and connect captures credentials and blocks closing through persistence acknowledgement',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('connection-save-capture-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument(text: '-- unrelated query');
      final saved = Completer<ProfileList>();
      backend.client.profileAction = (_) => saved.future;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final opened = model.commands!.invoke(
        'connection.new',
        model.commandContext,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('connection-user')),
          matching: find.byType(TextField),
        ),
        'postgres',
      );
      final password = find.descendant(
        of: find.byKey(const ValueKey('connection-password')),
        matching: find.byType(TextField),
      );
      await tester.enterText(password, 'captured private value');
      await tester.ensureVisible(find.text('Save & connect'));
      await tester.tap(find.text('Save & connect'));
      await tester.pump();
      expect(model.pendingOperations, greaterThan(0));
      final captured = backend.client.profileRequests.single.profile.deepCopy();
      await tester.ensureVisible(password);
      await tester.enterText(password, 'later private value');
      saved.complete(ProfileList(profiles: [captured]));
      await tester.pumpAndSettle();
      expect(model.pendingOperations, 0);
      expect(
        find.textContaining('Connection fields changed while saving'),
        findsOneWidget,
      );
      expect(backend.client.opened, isEmpty);
      expect(model.document.sessionId, isNull);
      expect(model.profiles.single, captured);
      expect(
        tester.widget<TextField>(password).controller!.text,
        'later private value',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await opened;
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'connection test is cancellable, preserves fields, never saves or adopts',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('connection-dialog-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument(text: '-- unbound SQL');
      final reply = Completer<ConnectionInfo>();
      backend.client.connectionTest = (_) => reply.future;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final opened = model.commands!.invoke(
        'connection.new',
        model.commandContext,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(TextField),
        ),
        'Entered staging connection',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('connection-database')),
          matching: find.byType(TextField),
        ),
        'staging',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('connection-password')),
          matching: find.byType(TextField),
        ),
        'private-test-value',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('connection-user')),
          matching: find.byType(TextField),
        ),
        'postgres',
      );
      final test = find.text('Test connection');
      await tester.ensureVisible(test);
      await tester.tap(test);
      await tester.pump();
      expect(find.text('Testing connection…'), findsOneWidget);
      expect(
        backend.client.connectionTests.single.profile.name,
        'Entered staging connection',
      );
      expect(
        backend.client.connectionTests.single.password,
        'private-test-value',
      );
      await tester.tap(find.text('Cancel test'));
      await tester.pump();
      expect(backend.client.cancelledConnectionTests, 1);
      expect(find.text('Cancelled'), findsOneWidget);
      reply.complete(
        ConnectionInfo(product: 'Late reply must be ignored', version: '1'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Late reply must be ignored'), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('connection-name')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'Entered staging connection',
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('connection-password')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'private-test-value',
      );
      expect(backend.client.profileRequests, isEmpty);
      expect(backend.client.opened, isEmpty);
      expect(model.document.sessionId, isNull);
      expect(model.explorerSessions, isEmpty);
      expect(model.document.editor.text, '-- unbound SQL');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await opened;
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
