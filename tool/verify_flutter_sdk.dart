import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  try {
    final options = _options(arguments);
    final flutterExecutable = _canonical(_required(options, 'flutter'));
    final dartExecutable = _canonical(_required(options, 'dart'));
    final baseline =
        jsonDecode(
              File(
                options['toolchain'] ?? 'config/toolchain.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final expectedFlutter = baseline['flutter'] as String;
    final expectedDart = baseline['dart'] as String;

    final flutterBin = File(flutterExecutable).parent;
    final flutterSdk = flutterBin.parent;
    final bundledDartBin = Directory(
      '${flutterBin.path}${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin',
    );
    if (!_samePath(File(dartExecutable).parent.path, bundledDartBin.path)) {
      throw StateError(
        'Dart must be the bundled executable from the selected Flutter SDK. '
        'Flutter: $flutterExecutable; Dart: $dartExecutable; expected Dart '
        'directory: ${bundledDartBin.path}.',
      );
    }

    final flutterResult = await _run(flutterExecutable, const [
      '--version',
      '--machine',
    ]);
    final flutterInfo = jsonDecode(flutterResult.stdout.trim());
    if (flutterInfo is! Map<String, Object?>) {
      throw const FormatException('Flutter version output is not an object.');
    }
    final flutterVersion = flutterInfo['frameworkVersion']?.toString();
    final flutterDartVersion = flutterInfo['dartSdkVersion']?.toString();
    if (!versionAtLeast(flutterVersion ?? '', expectedFlutter)) {
      throw StateError(
        'BusyData requires Flutter $expectedFlutter or newer; found $flutterVersion. Do not downgrade the installed SDK.',
      );
    }
    if (!versionAtLeast(flutterDartVersion ?? '', expectedDart)) {
      throw StateError(
        'Flutter must report Dart $expectedDart or newer; found '
        '$flutterDartVersion.',
      );
    }

    final dartResult = await _run(dartExecutable, const ['--version']);
    final dartOutput = '${dartResult.stdout}\n${dartResult.stderr}';
    final dartVersion = RegExp(
      r'Dart SDK version:\s+([^\s]+)',
    ).firstMatch(dartOutput)?.group(1);
    if (dartVersion != flutterDartVersion ||
        !versionAtLeast(dartVersion ?? '', expectedDart)) {
      throw StateError(
        'BusyData requires matching bundled Dart $expectedDart or newer; found $dartVersion.',
      );
    }

    stdout.writeln(
      jsonEncode({
        'flutterSdk': flutterSdk.path,
        'flutterExecutable': flutterExecutable,
        'flutterVersion': flutterVersion,
        'dartExecutable': dartExecutable,
        'dartVersion': dartVersion,
      }),
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

/// A newer stable or prerelease SDK is acceptable; a prerelease of the minimum
/// stable release is not. Tool output remains the authority for evidence.
bool versionAtLeast(String actual, String minimum) {
  final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-([^+]+))?(?:\+.*)?$');
  final found = pattern.firstMatch(actual),
      required = pattern.firstMatch(minimum);
  if (found == null || required == null) return false;
  for (int index = 1; index <= 3; index++) {
    final comparison = int.parse(
      found.group(index)!,
    ).compareTo(int.parse(required.group(index)!));
    if (comparison != 0) return comparison > 0;
  }
  return found.group(4) == null || required.group(4) != null;
}

Map<String, String> _options(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('Every option must have a value.');
  }
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final option = arguments[index];
    if (!option.startsWith('--')) {
      throw FormatException('Unexpected argument: $option');
    }
    options[option.substring(2)] = arguments[index + 1];
  }
  return options;
}

String _required(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) {
    throw FormatException('Missing --$name.');
  }
  return value;
}

String _canonical(String path) {
  final file = File(path).absolute;
  try {
    return file.resolveSymbolicLinksSync();
  } on FileSystemException {
    return file.path;
  }
}

bool _samePath(String left, String right) {
  final canonicalLeft = _canonical(left);
  final canonicalRight = _canonical(right);
  return Platform.isWindows
      ? canonicalLeft.toLowerCase() == canonicalRight.toLowerCase()
      : canonicalLeft == canonicalRight;
}

Future<({String stdout, String stderr})> _run(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(
    executable,
    arguments,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  return (stdout: result.stdout.toString(), stderr: result.stderr.toString());
}
