import 'package:flutter_test/flutter_test.dart';
import '../integration_test/release_frame_samples.dart';

ReleaseFrameTiming frame(
  int id, {
  int buildUs = 1000,
  int rasterUs = 2000,
  int deliveredAtUs = 0,
}) {
  final start = id * 1000000;
  return ReleaseFrameTiming(
    frameNumber: id,
    vsyncStartUs: start,
    buildStartUs: start + 10,
    buildFinishUs: start + 10 + buildUs,
    rasterStartUs: start + 10 + buildUs,
    rasterFinishUs: start + 10 + buildUs + rasterUs,
    rasterFinishWallUs: start + 1000000000,
    deliveredAtUs: deliveredAtUs,
  );
}

ReleaseFrameMeasurement own(ReleaseFrameSamples samples, List<int> ids) {
  final measurement = samples.begin('retained presentation switching');
  for (final id in ids) {
    samples.ownFrame(
      id,
      const ReleaseFrameOwner(
        'retained presentation switching',
        mode: 'tree',
        repeat: 0,
        action: 'switch',
      ),
    );
  }
  return measurement;
}

void main() {
  test('delayed previous-phase slow frame keeps its physical owner', () async {
    final samples = ReleaseFrameSamples(observationStartFrame: 0);
    samples.ownFrame(1, const ReleaseFrameOwner('million-row query'));
    final measurement = own(samples, [2, 3, 4, 5]);
    final pending = samples.finish(measurement);
    samples.addTiming(frame(1, buildUs: 250000));
    for (final id in [2, 3, 4, 5]) {
      samples.addTiming(frame(id));
    }
    final result = await pending;
    expect(result['available'], isTrue);
    expect(result['count'], 4);
    expect(result['p95Us'], 3000);
    expect(result['firstFrame'], 2);
    expect(samples.ownerForFrame(1)?.phase, 'million-row query');
    expect(samples.ownerForFrame(2)?.phase, 'retained presentation switching');
    expect(samples.ownerForFrame(99), isNull);
    expect((samples.toJson()['timings'] as List).length, 5);
  });

  test('late current closing frame remains required and slow', () async {
    final samples = ReleaseFrameSamples(observationStartFrame: 0);
    final measurement = own(samples, [1, 2, 3, 4]);
    var completed = false;
    final pending = samples.finish(measurement).then((value) {
      completed = true;
      return value;
    });
    for (final id in [1, 2, 3]) {
      samples.addTiming(frame(id));
    }
    await Future<void>.value();
    expect(completed, isFalse);
    samples.addTiming(frame(4, rasterUs: 150000));
    final result = await pending;
    expect(result['available'], isTrue);
    expect(result['lastFrame'], 4);
    expect(result['p95Us'], 151000);
    expect(result['maxRasterUs'], 150000);
    expect(result['quantileIndex'], 3);
  });

  test(
    'delivery wait idle frames dilute neither phase nor global workload',
    () async {
      final samples = ReleaseFrameSamples(observationStartFrame: 0);
      final measurement = own(samples, [1, 2, 3, 4]);
      final pending = samples.finish(measurement);
      for (var id = 5; id <= 40; id++) {
        samples.ownFrame(
          id,
          const ReleaseFrameOwner(
            'retained presentation switching',
            action: 'delivery-only',
          ),
        );
        samples.addTiming(frame(id, buildUs: 1, rasterUs: 1));
      }
      for (final id in [1, 2, 3]) {
        samples.addTiming(frame(id));
      }
      samples.addTiming(frame(4, buildUs: 200000));
      expect((await pending)['p95Us'], 202000);
      final global = await samples.finishObservation();
      expect(global['count'], 4);
      expect(global['p95Us'], 202000);
      expect((samples.toJson()['timings'] as List).length, 40);
      expect((samples.toJson()['owners'] as List).length, 40);
    },
  );

  test('missing closing delivery cannot pass from its fast prefix', () async {
    final samples = ReleaseFrameSamples(observationStartFrame: 0);
    final measurement = own(samples, [1, 2, 3, 4]);
    for (final id in [1, 2, 3]) {
      samples.addTiming(frame(id));
    }
    final result = await samples.finish(measurement, timeout: Duration.zero);
    expect(result['available'], isFalse);
    expect(result['timedOut'], isTrue);
    expect(result['missingFrameIds'], [4]);
    samples.addTiming(frame(4));
    expect(samples.summary(measurement)['available'], isFalse);
  });

  test('engine frame ID gaps do not fabricate missing raster frames', () async {
    final samples = ReleaseFrameSamples(observationStartFrame: 0);
    final measurement = own(samples, [1, 3, 8, 15]);
    for (final id in [1, 3, 8, 15]) {
      samples.addTiming(frame(id));
    }
    final result = await samples.finish(measurement);
    expect(result['available'], isTrue);
    expect(result['missingFrameIds'], isEmpty);
    expect(result['coverage'], {'owned': 4, 'delivered': 4, 'missing': 0});
  });

  test(
    'unknown admitted-window timing is raw evidence and unavailable',
    () async {
      final samples = ReleaseFrameSamples(observationStartFrame: 0);
      final measurement = own(samples, [1, 2, 3, 4]);
      for (final id in [1, 2, 3, 4, 5]) {
        samples.addTiming(frame(id));
      }
      final result = await samples.finish(measurement);
      expect(result['available'], isFalse);
      expect(result['errors'], containsPair('unknown_owner', 1));
      expect((samples.toJson()['timings'] as List).length, 5);
    },
  );

  test(
    'pre-observation timings are explicitly outside admitted work',
    () async {
      final samples = ReleaseFrameSamples(observationStartFrame: 10);
      final measurement = own(samples, [11, 12, 13, 14]);
      samples.addTiming(frame(9, buildUs: 300000));
      for (final id in [11, 12, 13, 14]) {
        samples.addTiming(frame(id));
      }
      expect((await samples.finish(measurement))['available'], isTrue);
      expect(samples.toJson()['preObservationTimings'], 1);
      expect((samples.toJson()['timings'] as List).length, 5);
    },
  );

  for (final duplicateOwner in [false, true]) {
    test(
      'duplicate ${duplicateOwner ? 'physical owner' : 'timing'} cannot overwrite and pass',
      () async {
        final samples = ReleaseFrameSamples(observationStartFrame: 0);
        final measurement = own(samples, [1, 2, 3, 4]);
        for (final id in [1, 2, 3, 4]) {
          samples.addTiming(frame(id));
        }
        if (duplicateOwner) {
          samples.ownFrame(4, const ReleaseFrameOwner('other phase'));
        } else {
          samples.addTiming(frame(4, buildUs: 1));
        }
        final result = await samples.finish(measurement);
        expect(result['available'], isFalse);
        expect(result['count'], 4);
        expect((samples.toJson()['errors'] as Map).isNotEmpty, isTrue);
      },
    );
  }

  test('record cap makes the retained prefix explicitly unavailable', () async {
    final samples = ReleaseFrameSamples(
      observationStartFrame: 0,
      maxRecords: 4,
    );
    final measurement = own(samples, [1, 2, 3, 4, 5]);
    for (final id in [1, 2, 3, 4, 5]) {
      samples.addTiming(frame(id));
    }
    final result = await samples.finish(measurement);
    expect(result['available'], isFalse);
    expect(result['errors'], containsPair('owner_overflow', 1));
    expect(result['errors'], containsPair('timing_overflow', 1));
    expect((samples.toJson()['owners'] as List).length, 4);
    expect((samples.toJson()['timings'] as List).length, 4);
  });

  test('invalid public frame identity is not a clock-based fallback', () async {
    final samples = ReleaseFrameSamples(observationStartFrame: -1);
    final measurement = own(samples, [1, 2, 3, 4]);
    for (final id in [1, 2, 3, 4]) {
      samples.addTiming(frame(id));
    }
    expect((await samples.finish(measurement))['available'], isFalse);
  });

  test('owner context cap cannot relabel a different mode and pass', () async {
    final samples = ReleaseFrameSamples(
      observationStartFrame: 0,
      maxContexts: 1,
    );
    final measurement = own(samples, [1, 2, 3, 4]);
    samples.ownFrame(
      5,
      const ReleaseFrameOwner(
        'retained presentation switching',
        mode: 'text',
        repeat: 1,
        action: 'switch',
      ),
    );
    for (final id in [1, 2, 3, 4]) {
      samples.addTiming(frame(id));
    }
    final result = await samples.finish(measurement);
    expect(result['available'], isFalse);
    expect(result['errors'], containsPair('context_overflow', 1));
    expect((samples.toJson()['contexts'] as List).length, 1);
  });

  test(
    'batch boundaries and delivery times do not change physical quantiles',
    () async {
      Future<Map<String, Object?>> collect(List<List<int>> batches) async {
        final samples = ReleaseFrameSamples(observationStartFrame: 0);
        final measurement = own(samples, [1, 2, 3, 4, 5]);
        final pending = samples.finish(measurement);
        for (var batch = 0; batch < batches.length; batch++) {
          for (final id in batches[batch]) {
            samples.addTiming(
              frame(id, buildUs: id * 1000, deliveredAtUs: batch * 1000000),
            );
          }
          await Future<void>.value();
        }
        return pending;
      }

      final together = await collect([
        [1, 2, 3, 4, 5],
      ]);
      final delayed = await collect([
        [1],
        [2, 3],
        [4],
        [5],
      ]);
      expect(delayed, together);
      expect(delayed['p95Us'], 7000);
    },
  );

  test(
    'a failed budget still has numeric count rank ownership and raw data',
    () async {
      final samples = ReleaseFrameSamples(observationStartFrame: 0);
      final measurement = own(samples, [1, 2, 3, 4]);
      for (final id in [1, 2, 3, 4]) {
        samples.addTiming(frame(id, buildUs: 150000));
      }
      final result = await samples.finish(measurement);
      expect(result['p95Us'], greaterThanOrEqualTo(100000));
      final evidence = samples.toJson();
      expect(
        (evidence['measurements'] as List).single,
        containsPair('count', 4),
      );
      expect(
        (evidence['measurements'] as List).single,
        containsPair('quantileIndex', 3),
      );
      expect((evidence['owners'] as List).length, 4);
      expect((evidence['timings'] as List).length, 4);
      expect(evidence['contexts'], [
        ReleaseFrameOwner(
          'retained presentation switching',
          mode: 'tree',
          repeat: 0,
          action: 'switch',
        ).toJson(),
      ]);
    },
  );
}
