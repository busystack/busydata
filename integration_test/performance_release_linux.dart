import 'package:busydata/src/backend/tool_admission_requests.dart';
// Internal acceptance executable; never bundled as BusyData's product entrypoint.
import 'dart:async';
import 'dart:ui' as ui;
import 'release_frame_samples.dart';
import 'release_transfer_rows.dart';
import 'presentation_environment.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:busydata/main_linux.dart' as application;
import 'package:busydata/src/backend/backend_process.dart';
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show ButtonStyleButton, SelectableText;
import 'package:busydata/src/app/busydata_design.dart'
    show BusyDataPopupSelector, BusyDataCheckbox, BusyDataMenuButton;
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:busydata/src/features/results/value_document.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show GrpcError;

bool terminal(rpc.JobState state) => const {
  rpc.JobState.COMPLETED,
  rpc.JobState.FAILED,
  rpc.JobState.CANCELLED,
  rpc.JobState.INTERRUPTED,
  rpc.JobState.UNKNOWN_OUTCOME,
}.contains(state);
void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<int> residentBytes(int process) async {
  final text = await File('/proc/$process/status').readAsString();
  return int.parse(
        RegExp(
          r'^VmRSS:\s+(\d+) kB$',
          multiLine: true,
        ).firstMatch(text)!.group(1)!,
      ) *
      1024;
}

Future<void> main() async {
  final report = <String, Object?>{
    'mode': 'Flutter release / bundled Java ordinary bytecode',
    'releaseModeMeasured': kReleaseMode,
    'javaMaxHeapMiB': BackendProcess.javaMaxHeapMiB,
    'javaMaxDirectMemoryMiB': BackendProcess.javaMaxDirectMemoryMiB,
    'fixture': 'postgres:17.11',
    'rows': 1000000,
    'sampleIntervalMinimumMs': 50,
    'displayEnvironment': {
      for (final key in [
        'DISPLAY',
        'WAYLAND_DISPLAY',
        'GDK_BACKEND',
        'XDG_SESSION_TYPE',
      ])
        key: Platform.environment[key],
    },
    'budgets': {
      'combinedResidentBytes': 768 * 1024 * 1024,
      'firstVisibleResultMs': 5000,
      'completionMs': 120000,
      'frameBuildAndRasterP95Ms': 100,
      'runningCancellationMs': 5000,
      'queuedCancellationMs': 1000,
      'clientCacheBytes': 2 * 1024 * 1024,
      'editorPhaseFlutterGrowthBytes': 64 * 1024 * 1024,
      'editorPhaseCombinedGrowthBytes': 96 * 1024 * 1024,
    },
  };
  WorkbenchModel? model;
  BackendConnection? backend;
  var exitStatus = 1, sampling = false;
  Future<void>? sampler;
  final frames = <int>[];
  final slowFrames = <Map<String, Object?>>[];
  var deliveredFrameSamples = 0, slowFrameSamples = 0;
  final spanWatch = Stopwatch()..start();
  final phases = <Map<String, Object?>>[];
  ReleaseFrameSamples? physicalFrames;
  var observingPhysicalFrames = false;
  var frameOwner = const ReleaseFrameOwner('initial');
  void ownPhysicalFrame(Duration _) {
    if (observingPhysicalFrames) {
      physicalFrames!.ownFrame(
        ui.PlatformDispatcher.instance.frameData.frameNumber,
        frameOwner,
      );
    }
  }

  Map<String, Object?> legacyP95(int firstFrame) {
    final measured = frames.sublist(firstFrame)..sort();
    return {
      'available':
          measured.length >= 4 && deliveredFrameSamples == frames.length,
      'limited': deliveredFrameSamples > frames.length,
      'scope': 'Legacy callback-delivery slice; diagnostic only',
      'count': measured.length,
      'p95Us': measured.isEmpty
          ? null
          : measured[(measured.length * .95).floor().clamp(
              0,
              measured.length - 1,
            )],
    };
  }

  Future<double> finishPhaseFrames(
    ReleaseFrameMeasurement measurement,
    int legacyFirstFrame,
  ) async {
    // Capture the old diagnostic before waiting. It cannot authorize acceptance.
    final legacy = legacyP95(legacyFirstFrame);
    final measured = await physicalFrames!.finish(measurement);
    report['physicalFrameMeasurements'] = physicalFrames!.toJson();
    final metrics =
        (report['phaseFrameMetrics'] ??= <String, Object?>{})
            as Map<String, Object?>;
    metrics[measurement.name] = {...measured, 'legacyDeliveryIndex': legacy};
    require(
      measured['available'] == true,
      'Release physical frame ownership/delivery is incomplete',
    );
    return (measured['p95Us']! as int) / 1000;
  }

  void phase(String name) {
    report['stage'] = name;
    frameOwner = ReleaseFrameOwner(name);
    phases.add({
      'phase': name,
      'atMs': spanWatch.elapsedMilliseconds,
      'frameSamples': frames.length,
    });
  }

  T exactlyOne<T>(Iterable<T> values, String scope) {
    final matches = values.toList(growable: false);
    report['lastExactMatch'] = {'scope': scope, 'count': matches.length};
    require(
      matches.length == 1,
      'Expected one $scope; observed ${matches.length}',
    );
    return matches.single;
  }

  final residentPeaksByPhase = <String, Map<String, int>>{};
  Map<String, Object?>? combinedPeak;
  var peakAtMs = 0;

  var peakCombined = 0,
      peakFlutter = 0,
      peakJava = 0,
      peakDirect = 0,
      peakHeap = 0,
      peakSpool = 0,
      samples = 0;
  void timings(List<FrameTiming> values) {
    for (final value in values) {
      deliveredFrameSamples++;
      if ((value.buildDuration + value.rasterDuration).inMicroseconds >=
          100000) {
        slowFrameSamples++;
      }
      physicalFrames?.addTiming(
        ReleaseFrameTiming(
          frameNumber: value.frameNumber,
          vsyncStartUs: value.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          buildStartUs: value.timestampInMicroseconds(ui.FramePhase.buildStart),
          buildFinishUs: value.timestampInMicroseconds(
            ui.FramePhase.buildFinish,
          ),
          rasterStartUs: value.timestampInMicroseconds(
            ui.FramePhase.rasterStart,
          ),
          rasterFinishUs: value.timestampInMicroseconds(
            ui.FramePhase.rasterFinish,
          ),
          rasterFinishWallUs: value.timestampInMicroseconds(
            ui.FramePhase.rasterFinishWallTime,
          ),
          deliveredAtUs: spanWatch.elapsedMicroseconds,
        ),
      );
      if (frames.length < 20000) {
        frames.add((value.buildDuration + value.rasterDuration).inMicroseconds);
        if (frames.last >= 100000 && slowFrames.length < 100) {
          final owner = physicalFrames?.ownerForFrame(value.frameNumber);
          slowFrames.add({
            'frameNumber': value.frameNumber,
            'atMs': spanWatch.elapsedMilliseconds,
            'phase': owner?.phase,
            'physicalOwner': owner?.toJson(),
            'ownerAvailable': owner != null,
            'callbackPhase': report['stage'],
            'buildUs': value.buildDuration.inMicroseconds,
            'rasterUs': value.rasterDuration.inMicroseconds,
          });
        }
      }
    }
  }

  try {
    require(
      kReleaseMode,
      'This required benchmark must use an actual release executable',
    );
    require(
      Platform.environment['GDK_BACKEND'] == 'x11' &&
          Platform.environment['XDG_SESSION_TYPE'] == 'x11' &&
          !Platform.environment.containsKey('WAYLAND_DISPLAY') &&
          (Platform.environment['DISPLAY']?.isNotEmpty ?? false),
      'The release benchmark requires its isolated X11 display',
    );
    final port = int.parse(Platform.environment['BUSYDATA_TEST_PORT'] ?? '0');
    require(port > 0, 'A real disposable PostgreSQL fixture is required');
    model = await application.startLinux();
    backend = model.backend;
    require(backend != null, model.status);
    final active = model, connection = backend!;
    report['inputs'] = jsonDecode(
      await File(
        Platform.environment['BUSYDATA_PERFORMANCE_INPUTS']!,
      ).readAsString(),
    );
    report['cpuModel'] = RegExp(
      r'^model name\s*:\s*(.*)$',
      multiLine: true,
    ).firstMatch(await File('/proc/cpuinfo').readAsString())?.group(1);
    report['logicalProcessors'] = Platform.numberOfProcessors;
    report['hostLoadAverageAtStart'] = (await File(
      '/proc/loadavg',
    ).readAsString()).trim();
    final profile = rpc.Profile(
      id: 'release-performance',
      name: 'Disposable release performance fixture',
      engine: rpc.Engine.POSTGRESQL,
      host: '127.0.0.1',
      port: port,
      database: 'postgres',
      user: 'postgres',
      tls: rpc.Tls(mode: rpc.TlsMode.DISABLED),
      connectTimeoutSeconds: 10,
      queryTimeoutSeconds: 120,
    );
    await active.connect(profile, 'busydata-ui-fixture');
    require(active.session != null, active.status);
    report['initialPresentation'] = presentationEnvironment();
    sampling = true;
    sampler = () async {
      while (sampling) {
        final flutter = await residentBytes(pid),
            java = await residentBytes(connection.process.pid);
        final phasePeaks = residentPeaksByPhase.putIfAbsent(
          report['stage'] as String? ?? 'initial',
          () => {'flutter': flutter, 'combined': flutter + java},
        );
        phasePeaks['flutter'] = math.max(phasePeaks['flutter']!, flutter);
        phasePeaks['combined'] = math.max(
          phasePeaks['combined']!,
          flutter + java,
        );
        peakFlutter = math.max(peakFlutter, flutter);
        peakJava = math.max(peakJava, java);
        if (flutter + java > peakCombined) {
          peakCombined = flutter + java;
          peakAtMs = spanWatch.elapsedMilliseconds;
          combinedPeak = {
            'flutterResidentBytes': flutter,
            'javaResidentBytes': java,
            'phase': report['stage'],
            'atMs': peakAtMs,
          };
        }
        samples++;
        if (samples % 4 == 0) {
          final stats = await connection.client.runtimeStats(
            connection.context(),
          );
          require(
            stats.instanceId == connection.instanceId,
            'Metrics belong to a stale backend',
          );
          peakDirect = math.max(peakDirect, stats.directBufferBytes.toInt());
          peakHeap = math.max(peakHeap, stats.heapUsedBytes.toInt());
          peakSpool = math.max(peakSpool, stats.retainedBytes.toInt());
          report['javaRuntime'] = stats.javaVersion;
          report['javaGarbageCollectors'] = stats.garbageCollectors.toList();
          require(
            stats.garbageCollectors.toSet().containsAll({
              'Copy',
              'MarkSweepCompact',
            }),
            'Owned JVM did not start the selected Serial collector',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }();
    physicalFrames = ReleaseFrameSamples(
      observationStartFrame:
          ui.PlatformDispatcher.instance.frameData.frameNumber,
    );
    observingPhysicalFrames = true;
    // Persistent callbacks run in drawFrame, after the engine updates FrameData.
    SchedulerBinding.instance.addPersistentFrameCallback(ownPhysicalFrame);
    SchedulerBinding.instance.addTimingsCallback(timings);
    Future<rpc.JobInfo> wait(
      String id, [
      Duration timeout = const Duration(seconds: 120),
    ]) async {
      final limit = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(limit)) {
        await active.poll();
        final job = active.jobs[id];
        if (job != null && terminal(job.state)) return job;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      throw StateError('Job completion deadline exceeded');
    }

    Future<rpc.JobInfo> submit(
      String sql, {
      bool streaming = true,
      int rows = 1000000,
    }) async {
      active.streaming = streaming;
      active.rowLimit = rows;
      active.document.editor.text = sql;
      final request = active.execution(rpc.ExecutionMode.SCRIPT);
      report['lastSubmission'] = {
        'mode': request.mode.name,
        'streamingRead': request.streamingRead,
        'rowLimit': request.rowLimit.toInt(),
        'sqlUnits': request.sql.length,
      };
      request.approvalToken = (await connection.client.review(request)).token;
      await active.submit(request);
      await active.poll();
      return exactlyOne(
        active.jobs.values.where(
          (job) => job.executionId == request.executionId,
        ),
        'submitted execution job',
      );
    }

    Future<void> dispose(rpc.JobInfo job) async {
      for (final result in job.results.where(
        (result) => result.resultId.isNotEmpty,
      )) {
        await active.disposeRetainedResult(result.resultId);
      }
      await active.poll();
    }

    List<Element> elements({Element? below}) {
      final out = <Element>[];
      void visit(Element element) {
        if (out.length >= 20000) {
          throw StateError('Rendered acceptance element budget exceeded');
        }
        out.add(element);
        element.visitChildElements(visit);
      }

      final root = below ?? WidgetsBinding.instance.rootElement;
      if (root != null) visit(root);
      return out;
    }

    Future<void> renderedFrame() async {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    Future<void> visibleUntil(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        await renderedFrame();
        if (ready()) return;
      }
      throw StateError('Production result presentation was not acknowledged');
    }

    Future<void> renderedButton(String label, {Element? below}) async {
      final buttons = <Element>{};
      for (final element in elements(below: below)) {
        if (element.widget case Text(data: final data) when data == label) {
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget is ButtonStyleButton) {
              buttons.add(ancestor);
              return false;
            }
            return true;
          });
        }
      }
      require(
        buttons.length == 1,
        'One rendered result-editor action is required',
      );
      final button = buttons.single.widget as ButtonStyleButton;
      require(
        button.onPressed != null,
        'Rendered result-editor action is disabled',
      );
      await Scrollable.ensureVisible(buttons.single);
      button.onPressed!();
      await renderedFrame();
    }

    Future<void> renderedValueMenuAction(Element editor, String label) async {
      final menus = elements(below: editor)
          .where(
            (element) =>
                element.widget is BusyDataMenuButton<int> &&
                (element.widget as BusyDataMenuButton<int>).tooltip ==
                    strings(editor).valueEditorActions,
          )
          .toList();
      require(
        menus.length == 1,
        'One rendered native value-action menu is required',
      );
      final menu = menus.single.widget as BusyDataMenuButton<int>;
      final entries = menu.entries
          .where((entry) => entry.label == label)
          .toList();
      require(
        menu.enabled && entries.length == 1 && entries.single.enabled,
        'Rendered native value action is missing or disabled',
      );
      await Scrollable.ensureVisible(menus.single);
      // This is a release component workload, like renderedButton above. The
      // ordinary AT-SPI tour separately activates the actual GTK popup entries.
      menu.onSelected(entries.single.value);
      await renderedFrame();
    }

    var first = 0;
    final watch = Stopwatch()..start();
    active.visibleCellObserver = (id, row, column, value) {
      if (first == 0 &&
          id == active.currentResult?.resultId &&
          row == 0 &&
          column == 0 &&
          value.signedInteger == '1') {
        first = watch.elapsedMilliseconds;
      }
    };
    phase('million-row query');
    final initial = await submit(
      "SELECT n, repeat('x',64) AS text FROM generate_series(1,1000000) n",
    );
    final completed = await wait(initial.jobId);
    final elapsed = watch.elapsedMilliseconds;
    await SchedulerBinding.instance.endOfFrame;
    require(
      completed.state == rpc.JobState.COMPLETED &&
          completed.results.single.fetchedRows.toInt() == 1000000,
      'The full million-row execution failed',
    );
    require(
      first > 0 && first <= 5000,
      'First visibly decoded cell exceeded 5s or was never displayed',
    );
    require(
      active.cacheBytes > 0 && active.cacheBytes <= 2 * 1024 * 1024,
      'The grid must render real bounded decoded rows',
    );
    report.addAll({
      'firstVisibleResultMs': first,
      'durationMs': elapsed,
      'queryRows': completed.results.single.fetchedRows.toInt(),
      'clientCacheBytes': active.cacheBytes,
    });
    phase('retained presentation switching');
    final presentationOwner = active.activeOwner;
    final presentationResult = completed.results.single;
    await visibleUntil(
      () =>
          active.resultActionSources[presentationOwner.id] ==
          presentationResult.resultId,
    );
    final jobsBeforePresentation = active.jobs.keys.toSet();
    final beforePresentationStats = await connection.client.runtimeStats(
      connection.context(),
    );
    final presentationFlutterBefore = await residentBytes(pid);
    final presentationCombinedBefore =
        presentationFlutterBefore + await residentBytes(connection.process.pid);
    final firstPresentationFrame = frames.length;
    final presentationFrames = physicalFrames.begin(
      'retained presentation switching',
    );
    final presentationView = active.resultView(
      presentationResult.resultId,
      owner: presentationOwner,
    );
    final originalSelection = (
      presentationView.selectedRow,
      presentationView.selectedColumn,
    );
    final timingsByMode = <String, int>{};
    report['resultPresentationAttempt'] = {
      'retainedRows': 1000000,
      'repetitions': 3,
      'modes': timingsByMode,
      'modeTimingScope':
          'dispatch, two rendered frames and 120ms sampler observation',
      'flutterResidentBefore': presentationFlutterBefore,
      'combinedResidentBefore': presentationCombinedBefore,
      'originalSelectedRow': originalSelection.$1,
      'originalSelectedColumn': originalSelection.$2,
      'clientCacheBytesBefore': active.cacheBytes,
    };
    for (var repeat = 0; repeat < 3; repeat++) {
      for (final mode in ResultPresentation.values) {
        frameOwner = ReleaseFrameOwner(
          'retained presentation switching',
          mode: mode.name,
          repeat: repeat,
          action: 'switch',
        );
        final elapsedMode = Stopwatch()..start();
        await active.commands!.invoke(
          'result.presentation.${mode.name}',
          active.commandContext,
        );
        await renderedFrame();
        await renderedFrame();
        require(
          presentationView.presentation.mode == mode,
          'Production result mode did not switch',
        );
        require(
          (presentationView.selectedRow, presentationView.selectedColumn) ==
              originalSelection,
          'Presentation switching changed retained selection',
        );
        require(
          active.cacheBytes <= 2 * 1024 * 1024,
          'Presentation switching materialized unbounded retained data',
        );
        timingsByMode[mode.name] = math.max(
          timingsByMode[mode.name] ?? 0,
          elapsedMode.elapsedMilliseconds,
        );
      }
    }
    frameOwner = const ReleaseFrameOwner(
      'retained presentation switching',
      mode: 'text',
      action: 'record-open',
    );
    await active.commands!.invoke('result.record', active.commandContext);
    await renderedFrame();
    require(
      presentationView.presentation.recordVisible,
      'Production Record View did not open',
    );
    frameOwner = const ReleaseFrameOwner(
      'retained presentation switching',
      mode: 'table',
      action: 'record-close-and-table',
    );
    await active.commands!.invoke('result.record', active.commandContext);
    await active.commands!.invoke(
      'result.presentation.table',
      active.commandContext,
    );
    await renderedFrame();
    final presentationP95 = await finishPhaseFrames(
      presentationFrames,
      firstPresentationFrame,
    );
    final afterPresentationStats = await connection.client.runtimeStats(
      connection.context(),
    );
    final presentationPeaks =
        residentPeaksByPhase['retained presentation switching']!;
    report['resultPresentationAttempt'] = {
      'retainedRows': 1000000,
      'repetitions': 3,
      'modes': timingsByMode,
      'modeTimingScope':
          'dispatch, two rendered frames and 120ms sampler observation',
      'recordViewVerified':
          presentationView.presentation.recordVisible == false,
      'sameSourceSelection':
          (presentationView.selectedRow, presentationView.selectedColumn) ==
          originalSelection,
      'databaseJobsUnchanged': setEquals(
        jobsBeforePresentation,
        active.jobs.keys.toSet(),
      ),
      'retainedBytesUnchanged':
          afterPresentationStats.retainedBytes ==
          beforePresentationStats.retainedBytes,
      'frameBuildAndRasterP95Ms': presentationP95,
      'flutterResidentBefore': presentationFlutterBefore,
      'combinedResidentBefore': presentationCombinedBefore,
      'residentPeaks': Map<String, int>.of(presentationPeaks),
      'flutterResidentGrowthBytes':
          presentationPeaks['flutter']! - presentationFlutterBefore,
      'combinedResidentGrowthBytes':
          presentationPeaks['combined']! - presentationCombinedBefore,
      'clientCacheBytes': active.cacheBytes,
    };
    require(
      setEquals(jobsBeforePresentation, active.jobs.keys.toSet()),
      'Presentation switching submitted a database job',
    );
    require(
      afterPresentationStats.retainedBytes ==
          beforePresentationStats.retainedBytes,
      'Presentation switching copied the retained result',
    );
    require(
      presentationPeaks['flutter']! - presentationFlutterBefore <=
              64 * 1024 * 1024 &&
          presentationPeaks['combined']! - presentationCombinedBefore <=
              96 * 1024 * 1024,
      'Retained presentation growth exceeded its release budget',
    );
    require(
      presentationP95 < 100,
      'Retained presentation release frame budget exceeded',
    );
    report['resultPresentations'] = {
      'retainedRows': 1000000,
      'repetitions': 3,
      'modes': timingsByMode,
      'modeTimingScope':
          'dispatch, two rendered frames and 120ms sampler observation',
      'recordViewVerified': true,
      'sameSourceSelection': true,
      'databaseJobsSubmitted': 0,
      'retainedBytesUnchanged': true,
      'frameBuildAndRasterP95Ms': presentationP95,
      'flutterResidentGrowthBytes':
          presentationPeaks['flutter']! - presentationFlutterBefore,
      'combinedResidentGrowthBytes':
          presentationPeaks['combined']! - presentationCombinedBefore,
      'clientCacheBytes': active.cacheBytes,
    };
    await dispose(completed);
    active.visibleCellObserver = null;

    phase('queued/running cancellation');
    final a = await submit('SELECT pg_sleep(30)', streaming: false, rows: 1);
    final startDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (active.jobs[a.jobId]?.state == rpc.JobState.QUEUED &&
        DateTime.now().isBefore(startDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await active.poll();
    }
    require(
      active.jobs[a.jobId]?.state == rpc.JobState.EXECUTING,
      'Long query A did not start',
    );
    final b = await submit('SELECT 77', streaming: false, rows: 1);
    require(b.state == rpc.JobState.QUEUED, 'Query B must be queued behind A');
    final queued = Stopwatch()..start();
    await connection.client.cancel(
      rpc.JobRequest(context: connection.context(), jobId: b.jobId),
    );
    final cancelledB = await wait(b.jobId, const Duration(seconds: 5));
    report['queuedCancellationMs'] = queued.elapsedMilliseconds;
    require(
      cancelledB.state == rpc.JobState.CANCELLED &&
          queued.elapsedMilliseconds < 1000 &&
          !terminal(active.jobs[a.jobId]!.state),
      'Queued cancellation did not leave A running',
    );
    final running = Stopwatch()..start();
    await connection.client.cancel(
      rpc.JobRequest(context: connection.context(), jobId: a.jobId),
    );
    final cancelledA = await wait(a.jobId, const Duration(seconds: 5));
    report['runningCancellationMs'] = running.elapsedMilliseconds;
    require(
      cancelledA.state == rpc.JobState.CANCELLED &&
          running.elapsedMilliseconds < 5000,
      'Running cancellation exceeded its budget',
    );
    await dispose(cancelledA);

    phase('repeated result lifecycle');
    var retainedFirst = '';
    final lifecycle = Stopwatch()..start();
    for (var index = 0; index < 130; index++) {
      final job = await wait(
        (await submit('SELECT $index AS n', rows: 1)).jobId,
      );
      require(job.state == rpc.JobState.COMPLETED, 'Repeated execution failed');
      if (index == 0) {
        retainedFirst = job.results.single.resultId;
      } else {
        await dispose(job);
      }
    }
    await active.poll();
    require(
      active.retainedResults.containsKey(retainedFirst),
      'Job eviction orphaned a retained result',
    );
    phase('retained result after eviction');
    final firstRow = await connection.client.resultPage(
      rpc.PageRequest(
        context: connection.context(),
        resultId: retainedFirst,
        limit: 1,
        maxBytes: 262144,
      ),
    );
    require(
      firstRow.rows.single.values.single.signedInteger == '0',
      'Retained real cell changed after 130 executions',
    );
    await active.disposeRetainedResult(retainedFirst);
    report['resultLifecycle'] = {
      'executions': 130,
      'durationMs': lifecycle.elapsedMilliseconds,
      'retainedCellVerified': true,
    };

    phase('wide rows');
    final wide = await wait(
      (await submit(
        'SELECT ${List.generate(64, (index) => "repeat('w',4000) AS c$index").join(',')} FROM generate_series(1,200)',
        rows: 200,
      )).jobId,
    );
    require(wide.state == rpc.JobState.COMPLETED, 'Wide-row execution failed');
    final page = await connection.client.resultPage(
      rpc.PageRequest(
        context: connection.context(),
        resultId: wide.results.single.resultId,
        offset: Int64(12),
        limit: 200,
        maxBytes: 262144,
      ),
    );
    require(
      page.rows.isNotEmpty &&
          page.nextOffset.toInt() > 12 &&
          page.rows.first.values.length == 64 &&
          page.rows.first.values.last.text == 'w' * 4000,
      'Byte-limited wide page did not deliver actual cells',
    );
    report['wideRows'] = {
      'rows': 200,
      'columns': 64,
      'unitsPerCell': 4000,
      'returnedRows': page.rows.length,
      'nextOffset': page.nextOffset.toInt(),
    };
    await dispose(wide);
    phase('retained presentation draft ownership');
    report['draftStep'] = 'fixture preparation';
    for (final sql in [
      'CREATE TABLE p0_release_drafts(id integer PRIMARY KEY,n text)',
      "INSERT INTO p0_release_drafts VALUES(1,'original'),(2,'second')",
    ]) {
      final preparation = await wait(
        (await submit(sql, streaming: false, rows: 1)).jobId,
      );
      report['draftPreparationState'] = preparation.state.name;
      report['draftPreparationErrorCode'] = preparation.errorCode;
      require(
        preparation.state == rpc.JobState.COMPLETED,
        'Draft fixture preparation did not complete',
      );
      await dispose(preparation);
    }
    report['draftStep'] = 'table metadata acknowledgement';
    final draftMetadata = await connection.client.explore(
      rpc.ExploreRequest(
        context: connection.context(),
        sessionId: active.document.sessionId,
        kind: rpc.ObjectKind.TABLE,
        catalog: 'postgres',
        schema: 'public',
        table: 'p0_release_drafts',
        refresh: true,
        introspectionLevel: 2,
        refreshMode: 'FRAGMENT',
        limit: 100,
      ),
    );
    report['draftMetadata'] = {
      'state': draftMetadata.metadataState,
      'level': draftMetadata.introspectionLevel,
      'complete': draftMetadata.complete,
      'objects': draftMetadata.objects.length,
      'snapshotRevision': draftMetadata.metadataSnapshotRevision.toString(),
      'configurationRevision': draftMetadata.metadataConfigurationRevision
          .toString(),
    };
    report['draftStep'] = 'query submission and completion';
    final draftResult = await wait(
      (await submit(
        'SELECT id,n FROM public.p0_release_drafts ORDER BY id',
        rows: 2,
      )).jobId,
    );
    report['draftQueryState'] = draftResult.state.name;
    report['draftQueryErrorCode'] = draftResult.errorCode;
    report['draftQueryResultCount'] = draftResult.results.length;
    require(
      draftResult.state == rpc.JobState.COMPLETED,
      'Draft fixture SELECT did not complete',
    );
    final draftOwner = active.activeOwner;
    final draftStatement = exactlyOne(
      draftResult.results,
      'retained draft query result',
    );
    require(
      draftStatement.resultId.isNotEmpty,
      'Draft fixture SELECT has no retained result',
    );
    final draftResultId = draftStatement.resultId;
    report['draftStep'] = 'loaded and rendered source cell';
    await visibleUntil(
      () => active.resultActionSources[draftOwner.id] == draftResultId,
    );
    // Registering the grid's command owner precedes asynchronous retained-page
    // delivery. Require exact loaded data and its rendered source cell; a
    // loading placeholder cannot acknowledge the Value Editor's input.
    await visibleUntil(() {
      final row = active.row(draftResultId, 0);
      return row != null &&
          row.values.length == 2 &&
          row.values[0].signedInteger == '1' &&
          row.values[1].text == 'original' &&
          elements().any(
            (element) =>
                element.widget is Semantics &&
                element.widget.key == ValueKey('$draftResultId:0:1'),
          );
    });
    report['draftStep'] = 'select exact rendered source cell';
    final draftCell = exactlyOne(
      elements()
          .map((element) => element.widget)
          .whereType<Semantics>()
          .where((widget) => widget.key == ValueKey('$draftResultId:0:1')),
      'rendered retained draft cell',
    );
    require(
      draftCell.properties.onTap != null,
      'Rendered retained cell has no selection action',
    );
    draftCell.properties.onTap!();
    final draftGrid = exactlyOne(
      elements().whereType<StatefulElement>().where((element) {
        final widget = element.widget;
        return widget is ResultGrid &&
            identical(widget.model, active) &&
            widget.result.resultId == draftResultId;
      }),
      'retained draft grid assessment owner',
    );
    // This acceptance executable observes the actual grid state. It neither
    // creates a second assessment nor records database values or error prose.
    final dynamic draftGridState = draftGrid.state;
    CapturedWorkbenchTarget? draftAssessmentTarget;
    try {
      draftAssessmentTarget = active.captureTarget(owner: draftOwner);
    } catch (_) {
      // The real assessment below still determines availability and outcome.
    }
    Map<String, Object?> targetEvidence(CapturedWorkbenchTarget? target) {
      final current = active.sessions[draftOwner.sessionId];
      final capturedSession = target?.session;
      final capturedProfile = target?.profile;
      bool? requiredTargetCurrent;
      String? requirementReasonCode;
      if (target != null) {
        try {
          active.requireTarget(target);
          requiredTargetCurrent = true;
        } catch (error) {
          requiredTargetCurrent = false;
          requirementReasonCode =
              WorkbenchFailureReason.fromError(error)?.wire ?? 'unclassified';
        }
      }
      return {
        'present': target != null,
        'requireTargetCurrent': requiredTargetCurrent,
        'requireTargetReasonCode': requirementReasonCode,
        'backendMatches': target == null
            ? null
            : identical(target.backend, active.backend),
        'documentMatches': target?.references(draftOwner),
        'profileIdMatchesOwner': target == null
            ? null
            : target.profileId == draftOwner.profileId,
        'sessionIdMatchesOwner': target == null
            ? null
            : target.sessionId == draftOwner.sessionId,
        'sourceIdentityMatchesCurrent':
            capturedSession == null || current == null
            ? null
            : capturedSession.metadataSourceIdentity ==
                  current.metadataSourceIdentity,
        'profileMatchesCurrent': capturedProfile == null || current == null
            ? null
            : capturedProfile == current.profile,
        'documentRevision': target?.revision,
        'currentDocumentRevision': draftOwner.version,
        'sessionRevision': target?.sessionRevision?.toString(),
        'contextRevision': target?.contextRevision.toString(),
        'currentSessionRevision': current?.sessionRevision.toString(),
        'currentContextRevision': current?.contextRevision.toString(),
        'currentTransaction': current?.transaction.name,
      };
    }

    Map<String, Object?> draftAssessmentEvidence({bool? editorStagePresent}) {
      final assessment = draftGridState.assessment as rpc.Editability?;
      final assessed =
          draftGridState.assessedTarget as CapturedWorkbenchTarget?;
      final gridMounted = draftGridState.mounted as bool;
      final result = gridMounted
          ? (draftGrid.widget as ResultGrid).result
          : draftStatement;
      final column = result.columns.length > 1 ? result.columns[1] : null;
      final source = active.sourceResultId(draftResultId);
      final batch = active.editBatches['${draftOwner.id}\u0000$source'];
      final stamp = draftOwner.sessionId == null
          ? null
          : active.metadataStampForSession(draftOwner.sessionId!);
      return {
        'assessmentRevision': draftGridState.assessmentRevision as int,
        'assessed': assessment != null,
        'editable': assessment?.editable,
        'reasonCode': assessment == null || assessment.reasonCode.isEmpty
            ? null
            : WorkbenchFailureReason.fromWire(assessment.reasonCode)?.wire ??
                  'unrecognized',
        'editableOrdinals': assessment?.editableColumns
            .take(64)
            .toList(growable: false),
        'editableOrdinalCount': assessment?.editableColumns.length,
        'editableOrdinalsLimited':
            (assessment?.editableColumns.length ?? 0) > 64,
        'canEdit': draftGridState.canEdit as bool,
        'gridMounted': gridMounted,
        'gridOwnerMatches': identical(draftGridState.owner, draftOwner),
        'activeOwnerMatches': identical(active.activeOwner, draftOwner),
        'gridResultMatches': gridMounted && result.resultId == draftResultId,
        'sourceResultMatches': source == draftResultId,
        'selectedRow': draftGridState.selectedRow as int,
        'selectedSourceRow': active.sourceRow(
          draftResultId,
          draftGridState.selectedRow as int,
        ),
        'selectedColumn': draftGridState.selectedColumn as int,
        'assessmentTarget': targetEvidence(assessed),
        'beforeAssessmentTarget': targetEvidence(draftAssessmentTarget),
        'metadataConfiguration': stamp?.configuration,
        'metadataSnapshot': stamp?.snapshot,
        'batchPresent': batch != null,
        'batchAppliedSnapshot': batch?.appliedSnapshot,
        'batchApplying': batch?.applying,
        'batchDiscarding': batch?.discarding,
        'batchOutcomeUnknown': batch?.outcomeUnknown,
        'columnOrdinal': column?.ordinal,
        'columnReadOnly': column?.readOnly,
        'columnProvenanceKnown': column?.provenanceKnown,
        'columnJdbcType': column?.jdbcType,
        'columnMetadataIdentityPresent': column?.metadataIdentity.isNotEmpty,
        'columnMetadataSnapshot': column?.metadataSnapshotRevision.toString(),
        'editorStagePresent': editorStagePresent,
      };
    }

    final draftAssessmentSnapshots = <String, Object?>{};
    report['draftAssessmentSnapshots'] = draftAssessmentSnapshots;
    draftAssessmentSnapshots['beforeAssessment'] = draftAssessmentEvidence();
    report['draftStep'] = 'editability assessment';
    await active.commands!.invoke('result.assess', active.commandContext);
    draftAssessmentSnapshots['afterAssessment'] = draftAssessmentEvidence();
    await renderedFrame();
    report['draftStep'] = 'open retained Value Editor';
    final draftInspection = active.commands!.invoke(
      'result.inspect',
      active.commandContext,
    );
    await visibleUntil(
      () => elements().any((element) => element.widget is ResultValueEditor),
    );
    report['draftStep'] = 'locate retained Value Editor';
    final draftEditor = exactlyOne(
      elements().where((element) => element.widget is ResultValueEditor),
      'retained draft Value Editor',
    );
    final draftEditorStagePresent =
        (draftEditor.widget as ResultValueEditor).stage != null;
    report['draftEditorStagePresent'] = draftEditorStagePresent;
    if (!draftEditorStagePresent) {
      draftAssessmentSnapshots['stageUnavailable'] = draftAssessmentEvidence(
        editorStagePresent: draftEditorStagePresent,
      );
    }
    require(
      draftEditorStagePresent,
      'Verified release fixture did not expose typed Value Editor staging',
    );
    report['draftStep'] = 'locate Edit cell checkbox';
    final editing = exactlyOne(
      elements(below: draftEditor)
          .map((element) => element.widget)
          .whereType<BusyDataCheckbox>()
          .where((widget) => widget.label == strings(draftEditor).editCell),
      'retained Value Editor Edit cell checkbox',
    );
    require(
      editing.onChanged != null,
      'Rendered Value Editor editing control is disabled',
    );
    report['draftStep'] = 'enable editing';
    editing.onChanged!(true);
    await renderedFrame();
    report['draftStep'] = 'locate editable native text';
    final input = exactlyOne(
      elements(below: draftEditor)
          .map((element) => element.widget)
          .whereType<EditableText>()
          .where((widget) => !widget.readOnly),
      'retained Value Editor editable text',
    );
    input.controller.text = 'release value draft 漢😀';
    report['draftStep'] = 'close initial Value Editor';
    await renderedButton(strings(draftEditor).close);
    await draftInspection;
    await visibleUntil(
      () => !elements().any((element) => element.widget is ResultValueEditor),
    );
    final draftView = active.resultView(draftResultId, owner: draftOwner);
    final jobsBeforeDraftSwitch = active.jobs.keys.toSet();
    final draftSourceRow = active.sourceRow(draftResultId, 0);
    final draftOriginal = active.row(draftResultId, 0)!.writeToBuffer();
    report['draftStep'] = 'switch retained presentations';
    for (final mode in ResultPresentation.values) {
      await active.commands!.invoke(
        'result.presentation.${mode.name}',
        active.commandContext,
      );
      await renderedFrame();
      require(
        draftView.presentation.draft(draftSourceRow, 2) ==
                'release value draft 漢😀' &&
            (draftView.selectedRow, draftView.selectedColumn) == (0, 1) &&
            active.sourceRow(draftResultId, 0) == draftSourceRow &&
            listEquals(
              active.row(draftResultId, 0)!.writeToBuffer(),
              draftOriginal,
            ),
        'Presentation switch changed retained source mapping, selection or unstaged draft',
      );
    }
    await active.commands!.invoke(
      'result.presentation.table',
      active.commandContext,
    );
    await renderedFrame();
    report['draftStep'] = 'reopen retained Value Editor';
    final reopenedDraft = active.commands!.invoke(
      'result.inspect',
      active.commandContext,
    );
    await visibleUntil(
      () => elements().any((element) => element.widget is ResultValueEditor),
    );
    report['draftStep'] = 'verify exact reopened draft';
    final reopenedEditor = exactlyOne(
      elements().where((element) => element.widget is ResultValueEditor),
      'reopened retained draft Value Editor',
    );
    final restoredInputs = elements(below: reopenedEditor)
        .map((element) => element.widget)
        .whereType<EditableText>()
        .where(
          (widget) =>
              !widget.readOnly &&
              widget.controller.text == 'release value draft 漢😀',
        )
        .toList(growable: false);
    report['draftRestoredInputCount'] = restoredInputs.length;
    require(
      restoredInputs.length == 1,
      'Production Value Editor failed to restore the presentation-owned draft',
    );
    report['draftStep'] = 'close reopened Value Editor';
    await renderedButton(strings(reopenedEditor).close);
    await reopenedDraft;
    await visibleUntil(
      () => !elements().any((element) => element.widget is ResultValueEditor),
    );
    report['draftStep'] = 'verify no presentation SQL';
    require(
      setEquals(jobsBeforeDraftSwitch, active.jobs.keys.toSet()),
      'Presentation draft switching executed database SQL',
    );
    report['resultPresentationDrafts'] = {
      'sourceRowMappingPreserved': true,
      'selectionPreserved': true,
      'unstagedDraftRestored': true,
      'retainedOriginalUnchanged': true,
      'databaseJobsSubmitted': 0,
      'modes': 4,
    };
    report['draftStep'] = 'dispose retained draft fixture';
    await dispose(draftResult);
    final dropDraftTable = await wait(
      (await submit(
        'DROP TABLE public.p0_release_drafts',
        streaming: false,
        rows: 1,
      )).jobId,
    );
    report['draftDropState'] = dropDraftTable.state.name;
    report['draftDropErrorCode'] = dropDraftTable.errorCode;
    require(
      dropDraftTable.state == rpc.JobState.COMPLETED,
      'Draft fixture cleanup did not complete',
    );
    await dispose(dropDraftTable);
    phase('large individual cell');
    final large = await wait(
      (await submit("SELECT repeat('漢',2000000) AS large_text", rows: 1)).jobId,
    );
    require(
      large.state == rpc.JobState.COMPLETED,
      'Large individual cell failed',
    );
    final preview = await connection.client.resultPage(
      rpc.PageRequest(
        context: connection.context(),
        resultId: large.results.single.resultId,
        limit: 1,
        maxBytes: 262144,
      ),
    );
    final value = preview.rows.single.values.single;
    require(
      value.truncated && value.valueId.isNotEmpty,
      'Large cell must retain a separate full value',
    );
    final chunk = await connection.client.resultValue(
      rpc.ValueRequest(
        context: connection.context(),
        resultId: large.results.single.resultId,
        valueId: value.valueId,
        maxBytes: 65535,
      ),
    );
    require(
      chunk.totalBytes.toInt() == 6000000 &&
          utf8.decode(chunk.data) == '漢' * 21845,
      'Large-cell retrieval corrupted exact Unicode',
    );
    report['largeCell'] = {
      'utf8Bytes': 6000000,
      'previewOnly': true,
      'firstChunkVerified': true,
    };
    phase('bounded production Value Editor inspection');
    final largeOwner = active.activeOwner;
    await visibleUntil(
      () =>
          active.resultActionSources[largeOwner.id] ==
          large.results.single.resultId,
    );
    final largeView = active.resultView(
      large.results.single.resultId,
      owner: largeOwner,
    );
    largeView.selectedRow = largeView.anchorRow = 0;
    largeView.selectedColumn = largeView.anchorColumn = 0;
    final jobsBeforeInspection = active.jobs.keys.toSet();
    final beforeInspectionStats = await connection.client.runtimeStats(
      connection.context(),
    );
    final inspectionFlutterBefore = await residentBytes(pid);
    final inspectionCombinedBefore =
        inspectionFlutterBefore + await residentBytes(connection.process.pid);
    final firstInspectionFrame = frames.length;
    final inspectionFrames = physicalFrames.begin(
      'bounded production Value Editor inspection',
    );
    final inspectionActions = <Map<String, Object?>>[];
    final inspectionViewports = <Map<String, Object?>>[];
    final inspectionTelemetry = <String, Object?>{
      'version': 1,
      'scope': 'Diagnostic ownership only; the entire unchanged phase is gated',
      'maximumActions': 32,
      'maximumViewports': 32,
      'actionsLimited': false,
      'viewportsLimited': false,
      'actions': inspectionActions,
      'viewports': inspectionViewports,
    };
    report['valueEditorActionTelemetry'] = inspectionTelemetry;
    void inspectionAction(String action, ValuePresentation mode) {
      final next = ReleaseFrameOwner(
        'bounded production Value Editor inspection',
        mode: mode.name,
        action: action,
      );
      if (frameOwner == next) return;
      frameOwner = next;
      if (inspectionActions.length < 32) {
        inspectionActions.add({
          ...next.toJson(),
          'requestedAfterFrame':
              ui.PlatformDispatcher.instance.frameData.frameNumber,
          'atMs': spanWatch.elapsedMilliseconds,
        });
      } else {
        inspectionTelemetry['actionsLimited'] = true;
      }
    }

    void inspectionViewport(String label, Element element) {
      if (inspectionViewports.length >= 32) {
        inspectionTelemetry['viewportsLimited'] = true;
        return;
      }
      final render = element.findRenderObject();
      final widget = element.widget;
      inspectionViewports.add({
        'label': label,
        'action': frameOwner.action,
        'mode': frameOwner.mode,
        'observedAfterFrame':
            ui.PlatformDispatcher.instance.frameData.frameNumber,
        'atMs': spanWatch.elapsedMilliseconds,
        'scope': widget is SelectableText
            ? 'native-text-widget'
            : 'editor-body',
        'nativeTextUnits': widget is SelectableText
            ? widget.data?.length
            : null,
        'viewportAvailable': render is RenderBox && render.hasSize,
        'width': render is RenderBox && render.hasSize
            ? render.size.width
            : null,
        'height': render is RenderBox && render.hasSize
            ? render.size.height
            : null,
      });
    }

    inspectionAction('open', ValuePresentation.raw);
    report['valueEditorFrameAttempt'] = {
      'flutterResidentBefore': inspectionFlutterBefore,
      'combinedResidentBefore': inspectionCombinedBefore,
    };
    final inspection = active.commands!.invoke(
      'result.inspect',
      active.commandContext,
    );
    await visibleUntil(
      () => elements().any((element) => element.widget is ResultValueEditor),
    );
    final editor = elements().singleWhere(
      (element) => element.widget is ResultValueEditor,
    );
    final valueLabels = strings(editor);
    inspectionViewport('opened-editor', editor);
    inspectionAction('load-chunk', ValuePresentation.raw);
    await renderedValueMenuAction(editor, valueLabels.loadValueChunk);
    await visibleUntil(
      () => elements().any(
        (element) =>
            element.widget is Text &&
            (element.widget as Text).data ==
                valueLabels.valueChunkRange('0', '65536', '6000000'),
      ),
    );
    final modeElements = elements(below: editor);
    final mode = modeElements
        .map((element) => element.widget)
        .whereType<BusyDataPopupSelector<ValuePresentation>>()
        .single;
    final loadedNative = modeElements
        .where((element) => element.widget is SelectableText)
        .take(2)
        .toList();
    if (loadedNative.length == 1) {
      inspectionViewport('loaded-raw', loadedNative.single);
    }
    inspectionAction('switch-hex', ValuePresentation.hexadecimal);
    mode.onSelected(ValuePresentation.hexadecimal);
    await renderedFrame();
    final expectedHex = ('e6bca2' * 21846).substring(0, 131072);
    final renderedHex = StringBuffer();
    var maximumNativeUnits = 0;
    const pageUnits = 8192, nativePageCount = 16;
    for (var page = 0; page < nativePageCount; page++) {
      inspectionAction('page-$page', ValuePresentation.hexadecimal);
      final expectedPage = expectedHex.substring(
        page * pageUnits,
        (page + 1) * pageUnits,
      );
      await visibleUntil(
        () =>
            elements(below: editor).any(
              (element) =>
                  element.widget is Text &&
                  (element.widget as Text).data ==
                      valueLabels.textValuePage(
                        '${page + 1}',
                        '$nativePageCount',
                      ),
            ) &&
            elements(below: editor).any(
              (element) =>
                  element.widget is SelectableText &&
                  (element.widget as SelectableText).data == expectedPage,
            ),
      );
      final nativeElement = elements(
        below: editor,
      ).where((element) => element.widget is SelectableText).single;
      final nativePage = (nativeElement.widget as SelectableText).data!;
      inspectionViewport('page-$page', nativeElement);
      require(
        nativePage.length <= pageUnits,
        'Native value preview page exceeded its bound',
      );
      renderedHex.write(nativePage);
      maximumNativeUnits = math.max(maximumNativeUnits, nativePage.length);
      if (page + 1 < nativePageCount) {
        inspectionAction('page-${page + 1}', ValuePresentation.hexadecimal);
        await renderedButton(valueLabels.textValueNextPage, below: editor);
      }
    }
    require(
      renderedHex.toString() == expectedHex,
      'Paged value inspection changed the represented bytes',
    );
    await renderedFrame();
    inspectionAction('close', ValuePresentation.hexadecimal);
    await renderedButton(valueLabels.close);
    await inspection;
    await visibleUntil(
      () => !elements().any((element) => element.widget is ResultValueEditor),
    );
    await renderedFrame();
    final inspectionP95 = await finishPhaseFrames(
      inspectionFrames,
      firstInspectionFrame,
    );
    final afterInspectionStats = await connection.client.runtimeStats(
      connection.context(),
    );
    final inspectionPeaks =
        residentPeaksByPhase['bounded production Value Editor inspection']!;
    report['valueEditorFrameAttempt'] = {
      'frameBuildAndRasterP95Ms': inspectionP95,
      'flutterResidentBefore': inspectionFlutterBefore,
      'combinedResidentBefore': inspectionCombinedBefore,
      'residentPeaks': Map<String, int>.of(inspectionPeaks),
      'flutterResidentGrowthBytes':
          inspectionPeaks['flutter']! - inspectionFlutterBefore,
      'combinedResidentGrowthBytes':
          inspectionPeaks['combined']! - inspectionCombinedBefore,
    };
    require(
      setEquals(jobsBeforeInspection, active.jobs.keys.toSet()) &&
          afterInspectionStats.retainedBytes ==
              beforeInspectionStats.retainedBytes,
      'Value inspection changed database jobs or retained storage',
    );
    require(
      inspectionPeaks['flutter']! - inspectionFlutterBefore <=
              64 * 1024 * 1024 &&
          inspectionPeaks['combined']! - inspectionCombinedBefore <=
              96 * 1024 * 1024,
      'Bounded Value Editor exceeded its release memory budget',
    );
    require(inspectionP95 < 100, 'Value Editor release frame budget exceeded');
    report['valueEditor'] = {
      'retainedUtf8Bytes': 6000000,
      'explicitLoadedBytes': 65536,
      'renderedExactHexCharacters': renderedHex.length,
      'renderedHexSha256': sha256
          .convert(utf8.encode(renderedHex.toString()))
          .toString(),
      'renderedNativePages': nativePageCount,
      'maximumNativeTextUnits': maximumNativeUnits,
      'databaseJobsSubmitted': 0,
      'retainedBytesUnchanged': true,
      'frameBuildAndRasterP95Ms': inspectionP95,
      'flutterResidentGrowthBytes':
          inspectionPeaks['flutter']! - inspectionFlutterBefore,
      'combinedResidentGrowthBytes':
          inspectionPeaks['combined']! - inspectionCombinedBefore,
    };
    await dispose(large);
    phase('four concurrent sessions');
    final concurrent = <rpc.JobInfo>[];
    for (var index = 0; index < 4; index++) {
      active.newDocument();
      await active.connect(profile, 'busydata-ui-fixture');
      concurrent.add(
        await submit(
          "SELECT n, repeat('x',64) AS text FROM generate_series(1,250000) n",
        ),
      );
    }
    for (final job in concurrent) {
      final outcome = await wait(job.jobId);
      require(
        outcome.state == rpc.JobState.COMPLETED &&
            outcome.results.single.fetchedRows.toInt() == 250000,
        'Concurrent real execution failed',
      );
      await dispose(outcome);
    }
    report['concurrentJobs'] = {
      'sessions': 4,
      'rowsPerJob': 250000,
      'allCompleted': true,
    };
    Future<rpc.JobInfo> transfer(rpc.ToolRequest request) async {
      request.context = connection.context();
      request.sessionId = active.document.sessionId!;
      request.executionId = const Uuid().v4();
      request.approvalToken = (await connection.client.reviewToolAdmission(
        request,
      )).token;
      final job = await connection.client.toolAdmission(request);
      active.track(job);
      return wait(job.jobId, const Duration(minutes: 8));
    }

    phase('successful multi-GiB direct export');
    final output = File('${active.support.path}/release-large.csv');
    final transferWatch = Stopwatch()..start();
    final exported = await transfer(
      rpc.ToolRequest(
        kind: rpc.ToolKind.EXPORT_QUERY,
        sql:
            "SELECT n AS id, repeat('x',65536) AS text FROM generate_series(1,32768) n",
        path: output.path,
        format: 'csv',
      ),
    );
    require(
      exported.state == rpc.JobState.COMPLETED &&
          exported.progressRows.toInt() == 32768,
      'Successful multi-gigabyte direct export is required',
    );
    final exportMs = transferWatch.elapsedMilliseconds;
    final bytes = await output.length();
    require(
      bytes > 2 * 1024 * 1024 * 1024,
      'The exported workload must exceed 2GiB',
    );
    final checksum = await verifyReleaseTransferBytes(
      output.openRead(),
      expectedRows: 32768,
      textBytes: 65536,
    );
    final create = await wait(
      (await submit(
        'CREATE TABLE release_import(id INTEGER PRIMARY KEY, text TEXT)',
        streaming: false,
      )).jobId,
    );
    require(
      create.state == rpc.JobState.COMPLETED,
      'Disposable import fixture creation failed',
    );
    transferWatch.reset();
    phase('successful multi-GiB import');
    final imported = await transfer(
      rpc.ToolRequest(
        kind: rpc.ToolKind.IMPORT_CSV,
        path: output.path,
        sourceSha256: checksum,
        schema: 'public',
        table: 'release_import',
        columns: ['id', 'text'],
        encoding: 'UTF-8',
      ),
    );
    require(
      imported.state == rpc.JobState.COMPLETED &&
          imported.committedRows.toInt() == 32768,
      'Successful multi-gigabyte immutable import is required',
    );
    final importMs = transferWatch.elapsedMilliseconds;
    final verify = await wait(
      (await submit(
        "SELECT count(*) AS n, sum(id)::text AS ids, count(*) FILTER (WHERE octet_length(text)=65536 AND md5(text)=md5(repeat('x',65536))) AS exact FROM release_import",
        rows: 1,
      )).jobId,
    );
    require(
      verify.state == rpc.JobState.COMPLETED,
      'Imported database verification failed',
    );
    final importedRow = await connection.client.resultPage(
      rpc.PageRequest(
        context: connection.context(),
        resultId: verify.results.single.resultId,
        limit: 1,
        maxBytes: 262144,
      ),
    );
    require(
      importedRow.rows.single.values[0].signedInteger == '32768' &&
          importedRow.rows.single.values[1].text == '536887296' &&
          importedRow.rows.single.values[2].signedInteger == '32768',
      'Durable imported row IDs, counts, and every cell checksum must match',
    );
    await dispose(verify);
    await output.delete();
    report['largeTransfers'] = {
      'bytes': bytes,
      'rows': 32768,
      'sourceSha256': checksum,
      'exportMs': exportMs,
      'importMs': importMs,
      'allExportedValuesVerified': true,
      'durableImportedValuesVerified': true,
      'interactiveResultSpooling': false,
    };
    final stats = await connection.client.runtimeStats(connection.context());
    require(
      stats.retainedBytes.toInt() == 0 &&
          stats.transferSnapshotBytes.toInt() == 0 &&
          stats.activeJobs == 0,
      'Disposal failed to recover quota',
    );
    final legacyGlobal = legacyP95(0);
    final physicalGlobal = await physicalFrames.finishObservation();
    report['physicalFrameMeasurements'] = physicalFrames.toJson();
    report['globalFrameAttempt'] = {
      ...physicalGlobal,
      'legacyDeliveryIndex': legacyGlobal,
    };
    require(
      physicalGlobal['available'] == true,
      'Release physical frame ownership/delivery is incomplete',
    );
    final p95 = (physicalGlobal['p95Us']! as int) / 1000;
    report.addAll({
      'frameSamples': physicalGlobal['count'],
      'frameBuildAndRasterP95Ms': p95,
      'frameBuildP95Ms': (physicalGlobal['buildP95Us']! as int) / 1000,
      'frameRasterP95Ms': (physicalGlobal['rasterP95Us']! as int) / 1000,
      'slowFrames': slowFrames,
      'slowFrameSamples': slowFrameSamples,
      'slowFrameSummaryLimited': slowFrameSamples > slowFrames.length,
      'phases': phases,
      'residentPeaksByPhase': residentPeaksByPhase,
      'quotaBytesAfterDisposal': stats.retainedBytes.toInt(),
    });
    require(p95 < 100, 'Release frame responsiveness exceeded 100ms');
    require(elapsed < 120000, 'Million-row completion exceeded 120s');
    exitStatus = 0;
  } catch (error, stack) {
    report['failureType'] = error.runtimeType.toString();
    final stackLines = stack.toString().split('\n');
    final failureFrames = stackLines.take(32).join('\n');
    report['failureStackLimited'] =
        stackLines.length > 32 || failureFrames.length > 8192;
    report['failureStack'] = failureFrames.length <= 8192
        ? failureFrames
        : failureFrames.substring(0, 8192);
    report['failure'] = error is StateError
        ? error.message
        : error.runtimeType.toString();
    if (error is GrpcError) {
      report['grpcCode'] = error.code;
      report['grpcMessage'] = error.message;
    }
  } finally {
    sampling = false;
    try {
      await sampler;
    } catch (error) {
      report['samplingFailure'] = error.runtimeType.toString();
      exitStatus = 1;
    }
    observingPhysicalFrames = false;
    if (model != null) {
      SchedulerBinding.instance.removeTimingsCallback(timings);
    }
    report.addAll({
      'physicalFrameMeasurements':
          physicalFrames?.toJson() ??
          {'available': false, 'reason': 'observer-not-started'},
      'legacyDeliveryFrameSamples': frames.length,
      'legacyDeliveryFrameMetrics': legacyP95(0),
      'slowFrames': slowFrames,
      'slowFrameSamples': slowFrameSamples,
      'slowFrameSummaryLimited': slowFrameSamples > slowFrames.length,
      'phases': phases,
      'residentPeaksByPhase': residentPeaksByPhase,
      'completedPresentation': model == null
          ? {'available': false}
          : presentationEnvironment(),
      'combinedPeakAtMs': peakAtMs,
      'combinedPeakResidency': combinedPeak,
      'peakCombinedResidentBytes': peakCombined,
      'peakFlutterResidentBytes': peakFlutter,
      'peakJavaResidentBytes': peakJava,
      'peakJavaHeapUsedBytes': peakHeap,
      'peakJavaDirectBufferBytes': peakDirect,
      'peakSpoolBytes': peakSpool,
      'residentSamples': samples,
      'hostLoadAverageAtEnd': (await File(
        '/proc/loadavg',
      ).readAsString()).trim(),
    });
    if (peakCombined >= 768 * 1024 * 1024) {
      report['memoryBudgetFailed'] = true;
      exitStatus = 1;
    }
    try {
      await backend?.close();
    } catch (error) {
      report['cleanupFailure'] = error.runtimeType.toString();
      exitStatus = 1;
    }
    model?.dispose();
    report['exitCode'] = exitStatus;
    await File(
      Platform.environment['BUSYDATA_PERFORMANCE_OUTPUT'] ??
          'build/performance-linux-release.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    exit(exitStatus);
  }
}
