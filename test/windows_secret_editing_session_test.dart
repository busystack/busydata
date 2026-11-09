import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busydata/src/ui/windows/windows_secret_editing_session.dart';

void main() {
  test(
    'old field/generation/serial cannot overwrite newer controller state',
    () {
      final controller = TextEditingController(text: 'initial');
      final sent = <WindowsSecretEditingSnapshot>[];
      final session = WindowsSecretEditingSession(
        id: 41,
        controller: controller,
        send: sent.add,
      );
      session.synchronize();
      final old = session.generation;
      controller.text = 'new application intent';
      expect(
        session.acceptNative(
          fieldId: 41,
          generation: old,
          serial: 1,
          utf16: 'stale'.codeUnits,
          selectionBase: 5,
          selectionExtent: 5,
        ),
        isFalse,
      );
      expect(
        session.acceptNative(
          fieldId: 42,
          generation: session.generation,
          serial: 1,
          utf16: 'other'.codeUnits,
          selectionBase: 5,
          selectionExtent: 5,
        ),
        isFalse,
      );
      expect(controller.text, 'new application intent');
      final generation = session.generation;
      expect(
        session.acceptNative(
          fieldId: 41,
          generation: generation,
          serial: 2,
          utf16: 'native'.codeUnits,
          selectionBase: 1,
          selectionExtent: 4,
        ),
        isTrue,
      );
      expect(
        controller.value,
        const TextEditingValue(
          text: 'native',
          selection: TextSelection(baseOffset: 1, extentOffset: 4),
        ),
      );
      expect(session.generation, generation);
      expect(
        session.acceptNative(
          fieldId: 41,
          generation: generation,
          serial: 1,
          utf16: 'late'.codeUnits,
          selectionBase: 4,
          selectionExtent: 4,
        ),
        isFalse,
      );
      session.dispose();
      controller.dispose();
    },
  );
  test('controller replacement and disposal reject queued updates', () {
    final first = TextEditingController(text: 'first');
    final second = TextEditingController(text: 'second');
    final sent = <WindowsSecretEditingSnapshot>[];
    final session = WindowsSecretEditingSession(
      id: 9,
      controller: first,
      send: sent.add,
    );
    session.synchronize();
    final old = session.generation;
    session.replaceController(second);
    first.text = 'old detached controller';
    expect(sent.length, 2);
    expect(
      session.acceptNative(
        fieldId: 9,
        generation: old,
        serial: 1,
        utf16: 'old native'.codeUnits,
        selectionBase: 0,
        selectionExtent: 0,
      ),
      isFalse,
    );
    expect(second.text, 'second');
    final last = session.generation;
    session.dispose();
    session.dispose();
    second.clear();
    expect(sent.length, 2);
    expect(
      session.acceptNative(
        fieldId: 9,
        generation: last,
        serial: 1,
        utf16: [120],
        selectionBase: 1,
        selectionExtent: 1,
      ),
      isFalse,
    );
    first.dispose();
    second.dispose();
  });
  test(
    'disabled admission rejects in-flight edit; reenable has a new generation',
    () {
      final controller = TextEditingController(text: 'kept');
      final sent = <WindowsSecretEditingSnapshot>[];
      final session = WindowsSecretEditingSession(
        id: 1,
        controller: controller,
        send: sent.add,
      );
      session.synchronize();
      final old = session.generation;
      session.setAdmission(false);
      expect(sent.last.acceptsInput, isFalse);
      expect(
        session.acceptNative(
          fieldId: 1,
          generation: old,
          serial: 1,
          utf16: [120],
          selectionBase: 1,
          selectionExtent: 1,
        ),
        isFalse,
      );
      expect(
        session.acceptNative(
          fieldId: 1,
          generation: session.generation,
          serial: 1,
          utf16: [120],
          selectionBase: 1,
          selectionExtent: 1,
        ),
        isFalse,
      );
      session.setAdmission(true);
      expect(controller.text, 'kept');
      expect(session.generation, greaterThan(old));
      session.dispose();
      controller.dispose();
    },
  );
  test('UTF16 and selection are exact, including non-BMP and NUL payloads', () {
    final controller = TextEditingController();
    final sent = <WindowsSecretEditingSnapshot>[];
    final session = WindowsSecretEditingSession(
      id: 1,
      controller: controller,
      send: sent.add,
    );
    session.synchronize();
    final value = '漢😀\u0000tail';
    expect(
      session.acceptNative(
        fieldId: 1,
        generation: session.generation,
        serial: 1,
        utf16: value.codeUnits,
        selectionBase: 1,
        selectionExtent: 3,
      ),
      isTrue,
    );
    expect(controller.text.codeUnits, value.codeUnits);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 1, extentOffset: 3),
    );
    controller.text = value;
    expect(sent.last.utf16, value.codeUnits);
    expect(() => sent.last.utf16[0] = 0, throwsUnsupportedError);
    session.dispose();
    controller.dispose();
  });
  test('invalid state fails without echoing or changing secret', () {
    final controller = TextEditingController(text: 'kept');
    final session = WindowsSecretEditingSession(
      id: 1,
      controller: controller,
      send: (_) {},
    );
    for (final units in [
      [-1],
      [0x10000],
    ]) {
      expect(
        () => session.acceptNative(
          fieldId: 1,
          generation: session.generation,
          serial: 1,
          utf16: units,
          selectionBase: 0,
          selectionExtent: 0,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'redacted error',
            'Invalid native editing state',
          ),
        ),
      );
    }
    expect(
      () => session.acceptNative(
        fieldId: 1,
        generation: session.generation,
        serial: 1,
        utf16: [97],
        selectionBase: 2,
        selectionExtent: 2,
      ),
      throwsFormatException,
    );
    expect(controller.text, 'kept');
    session.dispose();
    controller.dispose();
  });
  test(
    'parent normalization during native notification is synchronized back',
    () {
      final controller = TextEditingController();
      final sent = <WindowsSecretEditingSnapshot>[];
      final session = WindowsSecretEditingSession(
        id: 1,
        controller: controller,
        send: sent.add,
      );
      controller.addListener(() {
        if (controller.text == 'native') controller.text = 'parent normalized';
      });
      final generation = session.generation;
      expect(
        session.acceptNative(
          fieldId: 1,
          generation: generation,
          serial: 1,
          utf16: 'native'.codeUnits,
          selectionBase: 6,
          selectionExtent: 6,
        ),
        isTrue,
      );
      expect(controller.text, 'parent normalized');
      expect(sent.length, 1);
      expect(String.fromCharCodes(sent.single.utf16), 'parent normalized');
      expect(session.generation, greaterThan(generation));
      session.dispose();
      controller.dispose();
    },
  );
}
