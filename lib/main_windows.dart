import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:system_theme/system_theme.dart';
import 'src/app/windows/windows_busydata_app.dart';
import 'src/features/workspace/workbench_model.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  await SystemTheme.accentColor.load();
  final support = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'busydata'),
  );
  await support.create(recursive: true);
  final model = WorkbenchModel(support);
  await model.initialize();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [workbenchProvider.overrideWithValue(model)],
      child: const WindowsBusyDataApp(),
    ),
  );
  binding.allowFirstFrame();
}
