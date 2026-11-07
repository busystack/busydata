import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/verify_flutter_sdk.dart' as verifier;

void main() {
  test('F12 canonicalizes official Dart beta build metadata', () {
    const versions = <String, String?>{
      '3.13.4': '3.13.4',
      '3.14.0-315.3.beta': '3.14.0-315.3.beta',
      '3.14.0 (build 3.14.0-315.3.beta)': '3.14.0-315.3.beta',
      '3.14.0 (build 3.13.0-315.3.beta)': null,
      '3.14.0 (build unknown)': null,
      '3.14.0 (build 3.14.0-315.3.beta) trailing': null,
      'unknown': null,
    };
    for (final entry in versions.entries) {
      expect(
        verifier.canonicalDartVersion(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });
  test('F12 rejects a downgrade and accepts a newer installed SDK', () {
    // A stable policy fixture; the selected CI/packaging pin is checked below.
    const minimum = <String, String>{'flutter': '3.47.5', 'dart': '3.13.4'};
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
    final result = Process.runSync(Platform.isWindows ? 'python' : 'python3', [
      'tool/check_toolchain.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
