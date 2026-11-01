import 'dart:io';

const _linuxOnlyPackages = <String>[
  'package:yaru/',
  'package:ubuntu_localizations/',
  'package:dbus/',
  'package:desktop_notifications/',
  'package:xdg_status_notifier_item/',
  'package:posix/',
];

const _fluentPackages = <String>[
  'package:fluent_ui/',
  'package:fluentui_system_icons/',
];

final _importPattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  final root = Directory.current;
  final failures = findPlatformBoundaryViolations(root);
  if (failures.isNotEmpty) {
    stderr.writeln('BusyData platform boundary violations:');
    for (final failure in failures) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('BusyData platform boundaries are valid.');
}

List<String> findPlatformBoundaryViolations(Directory root) {
  final lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) {
    return ['BusyData lib directory not found at ${lib.path}.'];
  }
  final failures = <String>[];
  final dartFiles = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final file in dartFiles) {
    final relative = _relative(root.path, file.path);
    final source = file.readAsStringSync();
    final isWindows =
        relative == 'lib/main_windows.dart' || relative.contains('/windows/');
    final isCommonPlatform =
        relative.contains('/app/common/') ||
        relative.contains('/ui/common/') ||
        relative.contains('/platform/common/');
    final isLinux =
        relative == 'lib/main_linux.dart' ||
        relative.contains('/linux/') ||
        _isLegacyLinuxPresentation(relative);
    final isSharedBusiness =
        relative.startsWith('lib/src/') &&
        !isWindows &&
        !isLinux &&
        !relative.contains('/presentation/');

    for (final match in _importPattern.allMatches(source)) {
      final import = match.group(1)!;
      if ((isWindows || isCommonPlatform) &&
          _linuxOnlyPackages.any(import.startsWith)) {
        failures.add('$relative imports Linux-only $import');
      }
      if ((isCommonPlatform || isSharedBusiness || isLinux) &&
          _fluentPackages.any(import.startsWith)) {
        failures.add('$relative imports Windows-only $import');
      }
      if (isWindows && _isLinuxSourceImport(import)) {
        failures.add('$relative imports Linux source $import');
      }
    }
  }

  failures.addAll(findWorkbenchPresentationViolations(root));
  _checkWindowsReachability(root, failures);
  _checkNativePluginIsolation(root, failures);
  failures.sort();
  return failures;
}

/// Static guardrails complement production rendering and interaction coverage.
/// Material/TextField/Dialog and themed push buttons remain intentional.
List<String> findWorkbenchPresentationViolations(Directory root) {
  final failures = <String>[];
  final files = <File>[
    for (final path in ['ui/common', 'ui/linux', 'app/linux'])
      if (Directory('${root.path}/lib/src/$path').existsSync())
        ...Directory('${root.path}/lib/src/$path')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
  ];
  for (final file in files) {
    final relative = _relative(root.path, file.path);
    // Print/export styling has its own neutral, portable representation.
    if (relative.endsWith('/er_diagram_export.dart')) continue;
    // These adapters resolve semantic roles, including syntax and state layers.
    // Their role constants are verified by theme/component rendering tests.
    if (relative.endsWith('/linux_appearance.dart')) continue;
    final source = file.readAsStringSync();
    if (RegExp(
      r'(?<![\w.])(?:PopupMenuButton|AlertDialog|showMenu)\s*(?:<[^>]+>)?\s*\(',
    ).hasMatch(source)) {
      failures.add('$relative bypasses platform menu/dialog presentation');
    }
    if (!relative.startsWith('lib/src/app/linux/') &&
        (RegExp(r'withValues\s*\(\s*alpha:').hasMatch(source) ||
            RegExp(
              r'Color\(0x(?!00000000)[0-9a-fA-F]{8}\)',
            ).hasMatch(source))) {
      failures.add(
        '$relative defines feature-level decorative colors; use DesktopAppearance',
      );
    }
    if (RegExp(r'''fontFamily:\s*['"]''').hasMatch(source) ||
        RegExp(r'fontSize:\s*[0-9]').hasMatch(source)) {
      failures.add(
        '$relative defines feature-level fonts; use shared text roles',
      );
    }
  }
  return failures;
}

void _checkNativePluginIsolation(Directory root, List<String> failures) {
  final linuxPlugins = File(
    '${root.path}/linux/flutter/generated_plugins.cmake',
  );
  if (linuxPlugins.existsSync()) {
    final source = linuxPlugins.readAsStringSync();
    if (source.contains('tray_manager')) {
      failures.add(
        'Linux plugin graph registers tray_manager instead of the existing '
        'DBus/XDG tray adapter.',
      );
    }
    if (source.contains('flutter_timezone')) {
      failures.add(
        'Linux plugin graph registers flutter_timezone instead of the '
        'existing Linux timezone source.',
      );
    }
  }
  final windowsPlugins = File(
    '${root.path}/windows/flutter/generated_plugins.cmake',
  );
  if (!windowsPlugins.existsSync()) {
    failures.add('Windows generated plugin graph is missing.');
    return;
  }
  final windowsSource = windowsPlugins.readAsStringSync();
  if (windowsSource.contains('yaru_window')) {
    failures.add(
      'Windows must not register the Linux-only yaru_window plugin.',
    );
  }
}

void _checkWindowsReachability(Directory root, List<String> failures) {
  final entrypoint = File('${root.path}/lib/main_windows.dart');
  final queue = <File>[entrypoint];
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!visited.add(file.path) || !file.existsSync()) continue;
    final relative = _relative(root.path, file.path);
    for (final match in _importPattern.allMatches(file.readAsStringSync())) {
      final import = match.group(1)!;
      if (_linuxOnlyPackages.any(import.startsWith) ||
          _isLinuxSourceImport(import)) {
        failures.add('Windows graph: $relative reaches $import');
      }
      final resolved = _resolveLocalImport(root, file, import);
      if (resolved != null) queue.add(resolved);
    }
  }
}

File? _resolveLocalImport(Directory root, File source, String import) {
  if (import.startsWith('package:busydata/')) {
    return File(
      '${root.path}/lib/${import.substring('package:busydata/'.length)}',
    );
  }
  if (import.startsWith('dart:') || import.startsWith('package:')) return null;
  return File(Uri.file(source.path).resolve(import).toFilePath());
}

bool _isLinuxSourceImport(String import) {
  final normalized = import.replaceAll('\\', '/').toLowerCase();
  return normalized.contains('/linux/') ||
      normalized.contains('linux_') ||
      normalized.contains('/gtk_') ||
      normalized.contains('gtk_');
}

bool _isLegacyLinuxPresentation(String relative) {
  // Existing Yaru feature widgets remain the Linux presentation while the
  // Windows entrypoint uses lib/src/ui/windows exclusively.
  return relative.contains('/presentation/') &&
      !relative.contains('/ui/windows/');
}

String _relative(String root, String path) {
  final normalizedRoot = root
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceAll('\\', '/');
  final prefix = '$normalizedRoot/';
  return normalizedPath.startsWith(prefix)
      ? normalizedPath.substring(prefix.length)
      : normalizedPath;
}
