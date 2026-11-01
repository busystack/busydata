import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/installed_snap_linux.dart' as installed;

void main() {
  test(
    'fixture bootstrap decodes split Unicode only after bounded admission',
    () async {
      final bytes = utf8.encode('{"version":1,"path":"Ω"}\nignored');
      final value = await installed.readFixture(
        Stream.fromIterable([bytes.sublist(0, 23), bytes.sublist(23)]),
      );
      expect(value['path'], 'Ω');
    },
  );
  test(
    'fixture bootstrap rejects byte overflow before decoding JSON',
    () async {
      await expectLater(
        installed.readFixture(Stream.value(List.filled(16385, 120))),
        throwsStateError,
      );
      await expectLater(
        installed.readFixture(
          Stream.fromIterable([List.filled(8192, 120), List.filled(8193, 120)]),
        ),
        throwsStateError,
      );
      await expectLater(
        installed.readFixture(Stream.value([123])),
        throwsStateError,
      );
    },
  );
}
