// Relevant BusyMax audit contracts adapted for BusyData. Apache-2.0.
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one Handy window and Flutter view own the Linux desktop', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();
    final activate = source.substring(
      source.indexOf(
        'static void my_application_activate(GApplication* application)',
      ),
      source.indexOf(
        'static void my_application_startup(GApplication* application)',
      ),
    );
    expect(activate, contains('hdy_application_window_new('));
    expect(activate, isNot(contains('gtk_window_set_titlebar(')));
    expect(RegExp(r'fl_view_new\(').allMatches(activate), hasLength(1));
    expect(
      File('lib/src/ui/linux/linux_workbench_frame.dart').readAsStringSync(),
      contains('LinuxPageFrame('),
    );
    expect(
      File('linux/runner/CMakeLists.txt').readAsStringSync(),
      contains('PkgConfig::HANDY'),
    );
    expect(
      File('.github/workflows/verify.yml').readAsStringSync(),
      contains('libhandy-1-dev'),
    );
    expect(
      File('snap/snapcraft.yaml').readAsStringSync(),
      contains('libhandy-1-0'),
    );
  });
  test(
    'Windows retains native caption controls and separate Fluent composition',
    () {
      final source = File(
        'lib/src/app/windows/windows_busydata_app.dart',
      ).readAsStringSync();
      expect(source, contains('FluentApp.router('));
      expect(source, contains('NavigationView('));
      expect(source, isNot(contains('YaruWindowTitleBar')));
      expect(
        File('windows/runner/flutter_window.cpp').readAsStringSync(),
        contains('"requestClose"'),
      );
      expect(
        File('windows/runner/main.cpp').readAsStringSync(),
        contains('BusyDataInstanceState::kSecondary'),
      );
    },
  );
  test(
    'official Yaru platform delegation retains separate desktop composition',
    () {
      final configuration = File('.dart_tool/package_config.json');
      final packages =
          (jsonDecode(configuration.readAsStringSync()) as Map)['packages']
              as List;
      final yaru = packages.cast<Map>().singleWhere(
        (item) => item['name'] == 'yaru_window',
      );
      final root = configuration.absolute.uri.resolve(
        yaru['rootUri'] as String,
      );
      final source = File.fromUri(
        Directory.fromUri(root).uri.resolve('pubspec.yaml'),
      ).readAsStringSync();
      expect(source, contains('default_package: yaru_window_linux'));
      expect(source, contains('default_package: yaru_window_manager'));
      final windows = File(
        'windows/flutter/generated_plugins.cmake',
      ).readAsStringSync();
      expect(windows, isNot(contains('yaru_window_linux')));
      expect(windows, contains('window_manager'));
    },
  );
}
