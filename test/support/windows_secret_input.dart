import 'dart:async';
import 'dart:typed_data';

import 'package:busydata/src/ui/windows/windows_secret_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('org.busystack.busydata/windows_secret_input');
final _fields = <int, Map<Object?, Object?>>{};
int? _focused;

/// A widget-test platform endpoint, not an accessibility provider. Actual HWND
/// protection, reader behavior and native input remain native acceptance gates.
void setUpWindowsSecretInputFixture() {
  setUp(() {
    _fields.clear();
    _focused = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      final data = Map<Object?, Object?>.from(call.arguments as Map);
      switch (call.method) {
        case 'initialize':
          _fields.clear();
        case 'configure':
          final id = data['id'] as int;
          _fields[id] = {...?_fields[id], ...data};
        case 'dispose':
          _fields.remove(data['id']);
        case 'focus':
          _focused = data['id'] as int;
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    _fields.clear();
  });
}

Map<Object?, Object?> nativeSecretFieldState(String label) =>
    _fields.values.singleWhere(
      (state) => String.fromCharCodes(state['label'] as Int32List) == label,
    );
bool nativeSecretFieldHasFocus(String label) =>
    nativeSecretFieldState(label)['id'] == _focused;

Future<void> enterDesktopText(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  final native = find.ancestor(
    of: finder,
    matching: find.byType(WindowsSecretField),
  );
  if (native.evaluate().isEmpty) {
    await tester.enterText(finder, text);
    return;
  }
  final widget = tester.widget<WindowsSecretField>(native);
  await tester.pumpAndSettle();
  final state = nativeSecretFieldState(widget.label);
  expect(state['enabled'], isTrue);
  expect(state['visible'], isTrue);
  expect(state['readOnly'], isFalse);
  final complete = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('editing', {
            'owner': state['owner'],
            'id': state['id'],
            'generation': state['generation'],
            'serial': (state['testSerial'] as int? ?? 0) + 1,
            'utf16': Int32List.fromList(text.codeUnits),
            'base': text.length,
            'extent': text.length,
          }),
        ),
        (_) => complete.complete(),
      );
  state['testSerial'] = (state['testSerial'] as int? ?? 0) + 1;
  await complete.future;
  expect(widget.controller.text, text);
}
