import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/verify_flutter_sdk.dart' as verifier;

void main() {
  test('F12 rejects a downgrade and accepts a newer installed SDK', () {
    final minimum =
        jsonDecode(File('config/toolchain.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      verifier.versionAtLeast('3.47.4', minimum['flutter'] as String),
      isFalse,
    );
    expect(
      verifier.versionAtLeast('3.13.3', minimum['dart'] as String),
      isFalse,
    );
    expect(
      verifier.versionAtLeast('3.47.5', minimum['flutter'] as String),
      isTrue,
    );
    expect(
      verifier.versionAtLeast('3.48.0', minimum['flutter'] as String),
      isTrue,
    );
    expect(
      verifier.versionAtLeast('3.48.0-1.0.pre', minimum['flutter'] as String),
      isTrue,
    );
    expect(
      verifier.versionAtLeast('3.47.5-1.0.pre', minimum['flutter'] as String),
      isFalse,
    );
    expect(
      verifier.versionAtLeast('unknown', minimum['flutter'] as String),
      isFalse,
    );
  });
  test('F12 CI and packaging use the approved common baseline', () {
    final result = Process.runSync('python3', ['tool/check_toolchain.py']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
