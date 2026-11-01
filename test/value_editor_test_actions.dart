import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget hosts have no GTK window. Exercise the real menu trigger and its
/// serialized host entries; genuine AT-SPI acceptance selects the GTK items.
Future<List<String>> valueEditorAction(
  WidgetTester tester,
  DesktopControls controls,
  String? label,
) async {
  if (controls is! LinuxControls) {
    await tester.tap(find.text('Value actions'));
    await tester.pumpAndSettle();
    if (label != null) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    return [];
  }
  const channel = MethodChannel(nativeMenuChannelName);
  List<String>? labels;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method != 'show') return null;
    final entries = (call.arguments as Map)['entries'] as List;
    labels = [for (final entry in entries) (entry as Map)['label'] as String];
    if (label == null) return null;
    final index = labels!.indexOf(label);
    expect(index, greaterThanOrEqualTo(0));
    expect((entries[index] as Map)['enabled'], isTrue);
    return index;
  });
  try {
    await tester.tap(find.text('Value actions'));
    await tester.pumpAndSettle();
    expect(
      labels,
      isNotNull,
      reason: 'The native menu trigger must reach the host bridge',
    );
    return labels!;
  } finally {
    messenger.setMockMethodCallHandler(channel, null);
  }
}
