import 'dart:io';
import 'package:busydata/src/app/linux/linux_busydata_app.dart';
import 'package:busydata/src/app/windows/windows_busydata_app.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const window = MethodChannel('yaru_window');
  const events = EventChannel('yaru_window/events');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      window,
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(window, null);
    messenger.setMockStreamHandler(events, null);
  });
  for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
    for (final (requested, expected) in [
      (const Locale('C'), const Locale('en')),
      (const Locale('ar'), const Locale('ar')),
      (
        const Locale('zh', 'TW'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      (const Locale('pt', 'BR'), const Locale('en')),
    ]) {
      testWidgets(
        '$platform resolves $requested in its actual desktop composition',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('busydata-locale-'),
          ))!;
          final model = WorkbenchModel(root)..draftRecovery = false;
          model.newDocument();
          tester.platformDispatcher.localesTestValue = [requested];
          await tester.binding.setSurfaceSize(const Size(1280, 960));
          addTearDown(() async {
            tester.platformDispatcher.clearLocalesTestValue();
            await tester.binding.setSurfaceSize(null);
            model.dispose();
            await tester.runAsync(() => root.delete(recursive: true));
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [workbenchProvider.overrideWithValue(model)],
              child: platform == TargetPlatform.windows
                  ? const WindowsBusyDataApp()
                  : const LinuxBusyDataApp(),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(WorkbenchView));
          expect(Localizations.localeOf(context), expected);
          expect(
            Directionality.of(context),
            expected.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
