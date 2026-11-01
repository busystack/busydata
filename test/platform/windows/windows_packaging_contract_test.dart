// Adapted from BusyMax's Windows packaging contract at bf98600229d803f24ca5295e408379d1537aad08.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  final source = File(
    'tool/windows/AppxManifest.xml.template',
  ).readAsStringSync();
  final manifest = XmlDocument.parse(source);
  Iterable<XmlElement> elements(String name) => manifest.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == name);
  test('MSIX preserves the Windows 11 24H2 x64 native launcher target', () {
    expect(
      elements('Identity').single.getAttribute('ProcessorArchitecture'),
      'x64',
    );
    expect(
      elements('TargetDeviceFamily').single.getAttribute('MinVersion'),
      '10.0.26100.0',
    );
    expect(
      elements('TargetDeviceFamily').single.getAttribute('Name'),
      'Windows.Desktop',
    );
    final application = elements('Application').single;
    expect(application.getAttribute('Id'), 'BusyData');
    expect(application.getAttribute('Executable'), 'busydata.exe');
    expect(
      application.getAttribute('EntryPoint'),
      'Windows.FullTrustApplication',
    );
  });
  test(
    'package identity and artwork remain owner inputs without calendar activation',
    () {
      expect(
        elements('Identity').single.getAttribute('Name'),
        '@@IDENTITY_NAME@@',
      );
      expect(
        elements('Identity').single.getAttribute('Publisher'),
        '@@PUBLISHER@@',
      );
      expect(elements('Extension'), isEmpty);
      expect(elements('StartupTask'), isEmpty);
      expect(elements('Protocol'), isEmpty);
      expect(elements('FileType'), isEmpty);
      expect(elements('ToastNotificationActivation'), isEmpty);
      final capabilities = elements('Capabilities').single.childElements
          .map((element) => element.getAttribute('Name'))
          .toSet();
      expect(capabilities, {'internetClient', 'runFullTrust'});
      final packager = File(
        'tool/windows/package_store.ps1',
      ).readAsStringSync();
      expect(packager, contains('backend/runtime/bin/java.exe'));
      expect(packager, contains('SHA256'));
      expect(packager, contains('Exact MSIX differs from staging inventory'));
    },
  );
  test('runner retains native DPI and acknowledged SID-scoped IPC', () {
    final executable = File(
      'windows/runner/runner.exe.manifest',
    ).readAsStringSync();
    final instance = File(
      'windows/runner/single_instance.cpp',
    ).readAsStringSync();
    expect(executable, contains('PerMonitorV2'));
    expect(executable, contains('<requestedExecutionLevel level="asInvoker"'));
    expect(instance, contains('CurrentUserSid()'));
    expect(instance, contains('PIPE_REJECT_REMOTE_CLIENTS'));
    expect(instance, contains('acknowledgment == 1'));
    expect(instance, contains('D:P(A;;GA;;;'));
    expect(instance, contains('BusyData-SingleInstance-'));
  });
}
