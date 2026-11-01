import 'dart:async';

import 'package:busydata/src/app/busydata_dialogs.dart';
import 'package:busydata/src/app/busydata_window_close.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('close is allowed when no transient surface owns a handler', () async {
    final coordinator = BusyDataWindowCloseCoordinator();

    expect(await coordinator.requestClose(), isTrue);
    expect(coordinator.hasActiveHandler, isFalse);
  });

  testWidgets('the topmost mounted surface owns the close decision', (
    tester,
  ) async {
    final coordinator = BusyDataWindowCloseCoordinator();
    var outerCalls = 0;
    var innerCalls = 0;

    await tester.pumpWidget(
      BusyDataWindowCloseScope(
        coordinator: coordinator,
        child: BusyDataWindowCloseGuard(
          onCloseRequested: () {
            outerCalls += 1;
            return true;
          },
          child: BusyDataWindowCloseGuard(
            onCloseRequested: () {
              innerCalls += 1;
              return false;
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );

    expect(coordinator.hasActiveHandler, isTrue);
    expect(await coordinator.requestClose(), isFalse);
    expect(innerCalls, 1);
    expect(outerCalls, 0);
  });

  testWidgets('concurrent close requests share one active resolution', (
    tester,
  ) async {
    final coordinator = BusyDataWindowCloseCoordinator();
    final resolution = Completer<bool>();
    var calls = 0;

    await tester.pumpWidget(
      BusyDataWindowCloseScope(
        coordinator: coordinator,
        child: BusyDataWindowCloseGuard(
          onCloseRequested: () {
            calls += 1;
            return resolution.future;
          },
          child: const SizedBox(),
        ),
      ),
    );

    final first = coordinator.requestClose();
    final second = coordinator.requestClose();
    expect(calls, 1);

    resolution.complete(false);
    expect(await first, isFalse);
    expect(await second, isFalse);
    expect(calls, 1);
  });

  testWidgets('unmounted surfaces no longer participate in close requests', (
    tester,
  ) async {
    final coordinator = BusyDataWindowCloseCoordinator();
    await tester.pumpWidget(
      BusyDataWindowCloseScope(
        coordinator: coordinator,
        child: BusyDataWindowCloseGuard(
          onCloseRequested: () => false,
          child: const SizedBox(),
        ),
      ),
    );
    expect(coordinator.hasActiveHandler, isTrue);

    await tester.pumpWidget(
      BusyDataWindowCloseScope(
        coordinator: coordinator,
        child: const SizedBox(),
      ),
    );

    expect(coordinator.hasActiveHandler, isFalse);
    expect(await coordinator.requestClose(), isTrue);
  });

  testWidgets('an active application dialog blocks top-level termination', (
    tester,
  ) async {
    final coordinator = BusyDataWindowCloseCoordinator();
    await tester.pumpWidget(
      BusyDataWindowCloseScope(
        coordinator: coordinator,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showBusyDataModalDialog<void>(
                  context,
                  builder: (_) =>
                      const AlertDialog(content: Text('Protected modal')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Protected modal'), findsOneWidget);
    expect(coordinator.hasActiveHandler, isTrue);
    expect(await coordinator.requestClose(), isFalse);

    Navigator.of(tester.element(find.text('Protected modal'))).pop();
    await tester.pumpAndSettle();
    expect(coordinator.hasActiveHandler, isFalse);
  });
}
