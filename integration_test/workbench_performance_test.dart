import 'package:busydata/src/ui/common/presentation_diagnostics.dart';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/main_linux.dart' as application;
import 'package:busydata/src/app/linux/linux_busydata_app.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/backend/backend_process.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'debug_memory_diagnostics.dart';
import 'presentation_environment.dart';
import 'linux_accessibility_test_binding.dart';

Future<Map<String, int>> residentMemory(int process) async {
  final status = await File('/proc/$process/status').readAsString();
  return {
    for (final match in RegExp(
      r'^(VmRSS|VmHWM|RssAnon|RssFile|RssShmem|VmData|VmSwap):\s+(\d+) kB$',
      multiLine: true,
    ).allMatches(status))
      '${match.group(1)}Bytes': int.parse(match.group(2)!) * 1024,
  };
}

void main() {
  LinuxAccessibilityIntegrationTestBinding.ensureInitialized();
  testWidgets(
    'million-row desktop execution measures Flutter and JVM residency',
    (tester) async {
      final port = int.parse(Platform.environment['BUSYDATA_TEST_PORT'] ?? '0');
      expect(
        port,
        greaterThan(0),
        reason: 'A missing real fixture is a failed required stage.',
      );
      final memoryDiagnostics =
          Platform.environment['BUSYDATA_MEMORY_DIAGNOSTICS'] == '1';
      final startupPhases = <Map<String, Object?>>[];
      Future<void> startupPhase(
        String name, {
        BackendConnection? ownedBackend,
      }) async {
        if (startupPhases.length >= 3) {
          throw StateError('Startup diagnostic snapshot budget exceeded');
        }
        final snapshot = <String, Object?>{
          'phase': name,
          'flutterProcess': await processIdentity(pid),
          'flutter': await residentMemory(pid),
          'flutterMappings': await mappedMemoryDiagnostics(pid),
          'flutterHeap': await debugMemoryDiagnostics(),
          'flutterNativeAllocator': nativeAllocatorDiagnostics(),
          'java': {
            'available': false,
            'reason': 'application.main has not started the owned backend',
          },
        };
        if (ownedBackend != null) {
          final identity = await processIdentity(ownedBackend.process.pid);
          if (identity['parentPid'] != pid) {
            throw StateError(
              'Startup diagnostic Java is not this Flutter child',
            );
          }
          final memory = await ownedBackend.client.runtimeStats(
            ownedBackend.context(),
          );
          snapshot['java'] = {
            'available': true,
            'process': identity,
            'residency': await residentMemory(ownedBackend.process.pid),
            'mappings': await mappedMemoryDiagnostics(ownedBackend.process.pid),
            'heapUsedBytes': memory.heapUsedBytes.toInt(),
            'heapCommittedBytes': memory.heapCommittedBytes.toInt(),
            'directBufferBytes': memory.directBufferBytes.toInt(),
            'mappedBufferBytes': memory.mappedBufferBytes.toInt(),
          };
        }
        snapshot['flutterAllocationProfile'] =
            await debugAllocationProfileDiagnostics();
        startupPhases.add(snapshot);
      }

      if (memoryDiagnostics) {
        await tester.runAsync(() => startupPhase('before-application-main'));
      }
      await application.main();
      await tester.pumpAndSettle();
      final model = ProviderScope.containerOf(
        tester.element(find.byType(LinuxBusyDataApp)),
      ).read(workbenchProvider);
      expect(model.backend, isNotNull, reason: model.status);
      final backend = model.backend!;
      addTearDown(() async {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          await tester.runAsync(() async {
            final closing = backend.close();
            try {
              if (!model.isDisposed) model.dispose();
            } finally {
              await closing;
            }
          });
        }
      });
      final processOwnership = await tester.runAsync(
        () async => {
          'flutter': await processIdentity(pid),
          'java': await processIdentity(backend.process.pid),
        },
      );
      expect(
        processOwnership!['java']!['parentPid'],
        pid,
        reason: 'Sample this Flutter launch and its own Java child.',
      );
      if (memoryDiagnostics) {
        await tester.runAsync(
          () => startupPhase('after-main-first-paint', ownedBackend: backend),
        );
      }
      final profile = rpc.Profile(
        id: 'performance-ui',
        name: 'Disposable desktop performance fixture',
        engine: rpc.Engine.POSTGRESQL,
        host: '127.0.0.1',
        port: port,
        database: 'postgres',
        user: 'postgres',
        tls: rpc.Tls(mode: rpc.TlsMode.DISABLED),
        connectTimeoutSeconds: 10,
        queryTimeoutSeconds: 120,
      );
      await tester.runAsync(
        () => model.connect(profile, 'busydata-ui-fixture'),
      );
      if (memoryDiagnostics) {
        await tester.runAsync(
          () => startupPhase('after-connect', ownedBackend: backend),
        );
      }
      model.rowLimit = 1000000;
      model.streaming = true;
      model.document.editor.text =
          "SELECT n, repeat('x',64) AS text FROM generate_series(1,1000000) n";
      await tester.pump();
      final initialPresentation = presentationEnvironment();
      final watch = Stopwatch()..start();
      final frames = <int>[];
      final builds = <int>[], rasters = <int>[];
      final slowFrames = <Map<String, Object>>[];
      final loadAtStart = await File('/proc/loadavg').readAsString();
      void timings(List<FrameTiming> values) {
        for (final timing in values) {
          if (frames.length < 10000) {
            frames.add(
              (timing.buildDuration + timing.rasterDuration).inMicroseconds,
            );
            builds.add(timing.buildDuration.inMicroseconds);
            rasters.add(timing.rasterDuration.inMicroseconds);
            if (timing.buildDuration + timing.rasterDuration >
                    const Duration(milliseconds: 100) &&
                slowFrames.length < 100) {
              slowFrames.add({
                'buildUs': timing.buildDuration.inMicroseconds,
                'rasterUs': timing.rasterDuration.inMicroseconds,
                'atMs': watch.elapsedMilliseconds,
              });
            }
          }
        }
      }

      SchedulerBinding.instance.addTimingsCallback(timings);
      var timingsAttached = true;
      addTearDown(() {
        if (timingsAttached) {
          SchedulerBinding.instance.removeTimingsCallback(timings);
        }
      });
      var peakCombined = 0, peakFlutter = 0, peakJava = 0, first = 0;
      var combinedPeakAtMs = 0;
      final initialResidency = await tester.runAsync(
        () async => {
          'flutter': await residentMemory(pid),
          'java': await residentMemory(backend.process.pid),
        },
      );
      final initialFlutterHeap = await tester.runAsync(debugMemoryDiagnostics);
      final initialJavaMemory = await tester.runAsync(
        () => backend.client.runtimeStats(backend.context()),
      );
      final initialNativeAllocator = nativeAllocatorDiagnostics();
      final phases = <Map<String, Object?>>[];
      Future<void> phase(String name) async {
        if (Platform.environment['BUSYDATA_MEMORY_DIAGNOSTICS'] != '1') return;
        final flutterHeap = await debugMemoryDiagnostics();
        final javaHeap = await backend.client.runtimeStats(backend.context());
        final snapshot = <String, Object?>{
          'phase': name,
          'presentation': PresentationDiagnostics.snapshot(),
          'atMs': watch.elapsedMilliseconds,
          'flutter': await residentMemory(pid),
          'java': await residentMemory(backend.process.pid),
          'flutterMappings': await mappedMemoryDiagnostics(pid),
          'javaMappings': await mappedMemoryDiagnostics(backend.process.pid),
          'flutterHeap': flutterHeap,
          'flutterNativeAllocator': nativeAllocatorDiagnostics(),
          'inspectorOverride': WidgetsBinding
              .instance
              .debugShowWidgetInspectorOverrideNotifier
              .value,
          'javaHeapUsedBytes': javaHeap.heapUsedBytes.toInt(),
          'javaHeapCommittedBytes': javaHeap.heapCommittedBytes.toInt(),
          'cacheRows': model.cache.length,
          'cacheBytes': model.cacheBytes,
          'jobs': model.jobs.length,
          'retainedResults': model.retainedResults.length,
          'loadedRows': model.currentResult?.fetchedRows.toInt(),
        };
        if (name == 'before-execution' || name == 'completion') {
          snapshot['flutterAllocationProfile'] =
              await debugAllocationProfileDiagnostics();
        }
        phases.add(snapshot);
      }

      await tester.runAsync(() => phase('before-execution'));
      expect(
        initialJavaMemory!.garbageCollectors.toSet(),
        {'Copy', 'MarkSweepCompact'},
        reason:
            'Measure the actual owned JVM collector, not a launcher constant.',
      );
      Map<String, Map<String, int>>? combinedPeakResidency;
      Map<String, int>? combinedPeakNativeAllocator;
      var residencyReads = 0;
      var growthRecorded = false;
      await tester.runAsync(() async {
        final request = model.execution(rpc.ExecutionMode.SCRIPT);
        request.approvalToken = (await backend.client.review(request)).token;
        await model.submit(request);
      });
      while (watch.elapsedMilliseconds < 120000) {
        await tester.runAsync(() async {
          await model.poll();
          final result = model.currentResult;
          if (result != null && result.fetchedRows.toInt() > 0) {
            model.row(result.resultId, 0);
          }
          final flutterMemory = await residentMemory(pid),
              javaMemory = await residentMemory(backend.process.pid);
          residencyReads += 2;
          final flutter = flutterMemory['VmRSSBytes']!,
              java = javaMemory['VmRSSBytes']!;
          if (flutter > peakFlutter) peakFlutter = flutter;
          if (java > peakJava) peakJava = java;
          if (flutter + java > peakCombined) {
            peakCombined = flutter + java;
            combinedPeakAtMs = watch.elapsedMilliseconds;
            combinedPeakResidency = {
              'flutter': flutterMemory,
              'java': javaMemory,
            };
            combinedPeakNativeAllocator = nativeAllocatorDiagnostics();
          }
          if (!growthRecorded &&
              flutterMemory['RssAnonBytes']! >
                  initialResidency!['flutter']!['RssAnonBytes']! +
                      48 * 1024 * 1024) {
            growthRecorded = true;
            await phase('anonymous-growth-over-48MiB');
          }
        });
        await tester.pump();
        if (first == 0 &&
            find
                .descendant(
                  of: find.byType(TableView),
                  matching: find.text('1'),
                )
                .evaluate()
                .isNotEmpty) {
          first = watch.elapsedMilliseconds;
          await tester.runAsync(() => phase('first-visible-rows'));
        }
        if ([
          'COMPLETED',
          'FAILED',
          'CANCELLED',
          'INTERRUPTED',
          'UNKNOWN_OUTCOME',
        ].contains(model.currentJob?.state.name)) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
      }
      final queryState = model.currentJob?.state,
          queryRows = model.currentResult?.fetchedRows.toInt();
      final gridVisible = find.byType(ResultGrid).evaluate().length == 1;
      final queryCacheBytes = model.cacheBytes;
      final elapsed = watch.elapsedMilliseconds;
      await tester.runAsync(() => phase('completion'));
      SchedulerBinding.instance.removeTimingsCallback(timings);
      timingsAttached = false;
      frames.sort();
      builds.sort();
      rasters.sort();
      double? percentile(List<int> values) => values.isEmpty
          ? null
          : values[(values.length * .95).floor().clamp(0, values.length - 1)] /
                1000;
      final p95 = frames.isEmpty
          ? null
          : frames[(frames.length * .95).floor().clamp(0, frames.length - 1)] /
                1000;
      model.streaming = false;
      model.document.editor.text = 'SELECT pg_sleep(30)';
      await tester.runAsync(() async {
        final request = model.execution(rpc.ExecutionMode.SCRIPT);
        request.approvalToken = (await backend.client.review(request)).token;
        await model.submit(request);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (model.currentJob?.state == rpc.JobState.QUEUED &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await model.poll();
        }
      });
      final cancel = Stopwatch()..start();
      await tester.runAsync(() async {
        await backend.client.cancel(
          rpc.JobRequest(
            context: backend.context(),
            jobId: model.currentJob!.jobId,
          ),
        );
        while (cancel.elapsedMilliseconds < 5000) {
          await model.poll();
          if (model.currentJob?.state == rpc.JobState.CANCELLED) break;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.runAsync(() async {
        await phase('after-cancellation');
        final flutterHeap = await debugMemoryDiagnostics();
        final javaMemory = await backend.client.runtimeStats(backend.context());
        await File('build/performance-linux-ui.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'fixture': 'postgres:17.11',
            'diagnosticStartupPhases': startupPhases,
            'diagnosticPhases': phases,
            'initialPresentation': initialPresentation,
            'completedPresentation': presentationEnvironment(),
            'combinedPeakNativeAllocator': combinedPeakNativeAllocator,
            'initialNativeAllocator': initialNativeAllocator,
            'completedNativeAllocator': nativeAllocatorDiagnostics(),
            'allocatorCounterScope':
                'glibc bookkeeping at existing sample points; '
                'peak counters follow the RSS read and are not resident totals',
            'residencyReads': residencyReads,
            'mode': 'Flutter debug / Java ordinary bytecode',
            'javaMaxHeapMiB': BackendProcess.javaMaxHeapMiB,
            'javaMaxDirectMemoryMiB': BackendProcess.javaMaxDirectMemoryMiB,
            'javaCollectorPolicy': BackendProcess.javaGarbageCollector,
            'javaGarbageCollectors': javaMemory.garbageCollectors,
            'os': Platform.operatingSystem,
            'logicalProcessors': Platform.numberOfProcessors,
            'rows': 1000000,
            'fetchSize': 256,
            'firstVisibleResultMs': first,
            'durationMs': elapsed,
            'peakCombinedResidentBytes': peakCombined,
            'peakFlutterResidentBytes': peakFlutter,
            'peakJavaResidentBytes': peakJava,
            'processIds': {'flutter': pid, 'java': backend.process.pid},
            'processOwnership': processOwnership,
            'combinedPeakAtMs': combinedPeakAtMs,
            'initialResidency': initialResidency,
            'combinedPeakResidency': combinedPeakResidency,
            'initialFlutterHeap': initialFlutterHeap,
            'completedFlutterHeap': flutterHeap,
            'heapCounterPhases': {
              'initial': 'before-execution',
              'completed': 'after-cancellation',
            },
            'initialJavaMemory': {
              'heapUsedBytes': initialJavaMemory.heapUsedBytes.toInt(),
              'heapCommittedBytes': initialJavaMemory.heapCommittedBytes
                  .toInt(),
              'directBufferBytes': initialJavaMemory.directBufferBytes.toInt(),
              'mappedBufferBytes': initialJavaMemory.mappedBufferBytes.toInt(),
            },
            'completedJavaMemory': {
              'heapUsedBytes': javaMemory.heapUsedBytes.toInt(),
              'heapCommittedBytes': javaMemory.heapCommittedBytes.toInt(),
              'directBufferBytes': javaMemory.directBufferBytes.toInt(),
              'mappedBufferBytes': javaMemory.mappedBufferBytes.toInt(),
            },
            'clientCacheBytes': queryCacheBytes,
            'queryState': queryState?.name,
            'queryRows': queryRows,
            'cancellationMs': cancel.elapsedMilliseconds,
            'cancellationState': model.currentJob?.state.name,
            'cancellationErrorCode': model.currentJob?.errorCode,
            'sampleIntervalMinimumMs': 25,
            'frameSamples': frames.length,
            'frameBuildAndRasterP95Ms': p95,
            'frameBuildP95Ms': percentile(builds),
            'frameRasterP95Ms': percentile(rasters),
            'slowFrames': slowFrames,
            'hostLoadAverageAtStart': loadAtStart.trim(),
            'hostLoadAverageAtEnd': (await File(
              '/proc/loadavg',
            ).readAsString()).trim(),
            'cpuModel': RegExp(
              r'^model name\s*:\s*(.*)$',
              multiLine: true,
            ).firstMatch(await File('/proc/cpuinfo').readAsString())?.group(1),
            'hostMemoryTotalKiB': int.parse(
              RegExp(r'^MemTotal:\s+(\d+) kB$', multiLine: true)
                  .firstMatch(await File('/proc/meminfo').readAsString())!
                  .group(1)!,
            ),
            'budgets': {
              'combinedResidentBytes': 768 * 1024 * 1024,
              'firstVisibleResultMs': 5000,
              'completionMs': 120000,
              'frameBuildAndRasterP95Ms': 100,
              'cancellationMs': 5000,
            },
            'releaseModeMeasured': false,
            'individualMultiGiBCellMeasured': false,
          }),
        );
      });
      expect(queryState, rpc.JobState.COMPLETED);
      expect(queryRows, 1000000);
      expect(gridVisible, isTrue);
      expect(first, inInclusiveRange(1, 5000));
      expect(
        peakCombined,
        lessThan(768 * 1024 * 1024),
        reason:
            'Debug desktop combined RSS budget is 768MiB, including native/driver allocations.',
      );
      expect(queryCacheBytes, lessThanOrEqualTo(2 * 1024 * 1024));
      expect(
        queryCacheBytes,
        greaterThan(0),
        reason: 'Visible typed rows must actually be decoded and rendered',
      );
      expect(p95, isNotNull, reason: 'UI responsiveness must be measured');
      expect(
        p95,
        lessThan(100),
        reason: 'Debug frame build+raster p95 budget is 100ms',
      );
      expect(model.currentJob?.state, rpc.JobState.CANCELLED);
      expect(cancel.elapsedMilliseconds, lessThan(5000));
      await tester.runAsync(backend.close);
      final backendExitCode = await tester.runAsync(
        () => backend.process.exitCode,
      );
      expect(
        backendExitCode,
        0,
        reason: 'Normal disposal exits the owned backend.',
      );
      await tester.runAsync(() async {
        final output = File('build/performance-linux-ui.json');
        final report =
            jsonDecode(await output.readAsString()) as Map<String, dynamic>;
        report['ownedBackendDisposal'] = {
          'pid': backend.process.pid,
          'exitCode': backendExitCode,
        };
        await output.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
