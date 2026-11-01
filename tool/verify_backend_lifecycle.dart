import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/backend_process.dart';

Future<void> main() async {
  final support = await Directory.systemTemp.createTemp('busydata-lifecycle-');
  BackendProcess? backend;
  final watch = Stopwatch()..start();
  try {
    backend = await BackendProcess.start(support);
    final startupMs = watch.elapsedMilliseconds;
    await backend.client.ping(backend.context());
    final stats = await backend.client.runtimeStats(backend.context());
    if (stats.instanceId != backend.instanceId ||
        !stats.javaVersion.startsWith('25.') ||
        stats.garbageCollectors.toSet().length != 2 ||
        !stats.garbageCollectors.toSet().containsAll({
          'Copy',
          'MarkSweepCompact',
        })) {
      throw StateError('Owned backend runtime/collector verification failed');
    }
    final close = Stopwatch()..start();
    await backend.close();
    if (await backend.process.exitCode != 0 ||
        close.elapsedMilliseconds > 15000) {
      throw StateError('Owned backend failed clean bounded shutdown');
    }
    final report = File('build/backend-lifecycle.json');
    await report.parent.create(recursive: true);
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'startupMs': startupMs,
        'shutdownMs': close.elapsedMilliseconds,
        'ownedChildExitCode': 0,
        'authenticatedPinnedRpc': true,
        'javaRuntime': stats.javaVersion,
        'javaGarbageCollectors': stats.garbageCollectors.toList(),
        'javaCollectorPolicy': BackendProcess.javaGarbageCollector,
      }),
    );
    stdout.writeln(report.path);
  } finally {
    await backend?.close();
    await support.delete(recursive: true);
  }
}
