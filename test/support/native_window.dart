import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests exercise the dialog, while the native acceptance suite owns
/// actual window integration. Keep its services installed until disposal.
void installNativeWindowFixture(WidgetTester tester) {
  const channel = MethodChannel('yaru_window');
  const events = MethodChannel('yaru_window/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'state') {
      return <String, Object>{
        'active': true,
        'visible': true,
        'closable': true,
        'maximized': false,
        'fullscreen': false,
        'title': 'BusyData',
      };
    }
    return null;
  });
  messenger.setMockMethodCallHandler(events, (_) async => null);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });
}
