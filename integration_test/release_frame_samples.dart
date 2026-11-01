// Internal release-benchmark evidence only; never product presentation state.
import 'dart:async';

class ReleaseFrameOwner {
  const ReleaseFrameOwner(this.phase, {this.mode, this.repeat, this.action});
  final String phase;
  final String? mode, action;
  final int? repeat;
  Map<String, Object?> toJson() => {
    'phase': phase,
    'mode': mode,
    'repeat': repeat,
    'action': action,
  };
  @override
  bool operator ==(Object other) =>
      other is ReleaseFrameOwner &&
      phase == other.phase &&
      mode == other.mode &&
      repeat == other.repeat &&
      action == other.action;
  @override
  int get hashCode => Object.hash(phase, mode, repeat, action);
}

class ReleaseFrameTiming {
  const ReleaseFrameTiming({
    required this.frameNumber,
    required this.vsyncStartUs,
    required this.buildStartUs,
    required this.buildFinishUs,
    required this.rasterStartUs,
    required this.rasterFinishUs,
    required this.rasterFinishWallUs,
    required this.deliveredAtUs,
  });
  final int frameNumber,
      vsyncStartUs,
      buildStartUs,
      buildFinishUs,
      rasterStartUs,
      rasterFinishUs,
      rasterFinishWallUs,
      deliveredAtUs;
  int get buildUs => buildFinishUs - buildStartUs;
  int get rasterUs => rasterFinishUs - rasterStartUs;
  int get sumUs => buildUs + rasterUs;
  List<int> toRow() => [
    frameNumber,
    vsyncStartUs,
    buildStartUs,
    buildFinishUs,
    rasterStartUs,
    rasterFinishUs,
    rasterFinishWallUs,
    deliveredAtUs,
  ];
}

class ReleaseFrameMeasurement {
  ReleaseFrameMeasurement._(this.id, this.name);
  final int id;
  final String name;
  final List<int> _ids = [];
  bool _sealed = false, _timedOut = false;
}

class ReleaseFrameSamples {
  ReleaseFrameSamples({
    required this.observationStartFrame,
    this.maxRecords = 20000,
    this.maxContexts = 512,
  }) {
    if (observationStartFrame < 0 || maxRecords < 1 || maxContexts < 1) {
      _issue('invalid_observation_frontier');
    }
  }
  final int observationStartFrame, maxRecords, maxContexts;
  final _owners = <int, List<int>>{};
  final _timings = <int, ReleaseFrameTiming>{};
  final _contexts = <ReleaseFrameOwner, int>{};
  final _measurements = <ReleaseFrameMeasurement>[];
  final _globalIds = <int>[];
  final _errors = <String, int>{};
  final _waiters = <Completer<void>>{};
  ReleaseFrameMeasurement? _active;
  var _globalSealed = false, _globalTimedOut = false, _waitDepth = 0;
  var _lastOwner = -1,
      _preObservation = 0,
      _postObservation = 0,
      _outsideOwnerCalls = 0;

  void _issue(String code) =>
      _errors.update(code, (n) => n + 1, ifAbsent: () => 1);

  ReleaseFrameOwner? ownerForFrame(int frameNumber) {
    final context = _owners[frameNumber]?[1];
    return context == null ? null : _contexts.keys.elementAt(context);
  }

  ReleaseFrameMeasurement begin(String name) {
    if (_active != null ||
        _globalSealed ||
        _measurements.length >= 64 ||
        name.length > 128) {
      _issue('invalid_measurement_admission');
      throw StateError('Release frame measurement admission unavailable');
    }
    final value = ReleaseFrameMeasurement._(_measurements.length, name);
    _measurements.add(value);
    _active = value;
    return value;
  }

  void ownFrame(int frameNumber, ReleaseFrameOwner owner) {
    if (frameNumber <= observationStartFrame && _active == null) {
      _outsideOwnerCalls++;
      return;
    }
    if (frameNumber < 0 || frameNumber <= observationStartFrame) {
      _issue('invalid_owner_frame');
      return;
    }
    if (_owners.containsKey(frameNumber) || frameNumber <= _lastOwner) {
      _issue('duplicate_or_reordered_owner');
      return;
    }
    if (_owners.length >= maxRecords) {
      _issue('owner_overflow');
      return;
    }
    if (owner.phase.length > 128 ||
        (owner.mode?.length ?? 0) > 64 ||
        (owner.action?.length ?? 0) > 128) {
      _issue('owner_label_overflow');
      return;
    }
    var context = _contexts[owner];
    if (context == null) {
      if (_contexts.length >= maxContexts) {
        _issue('context_overflow');
        return;
      }
      context = _contexts.length;
      _contexts[owner] = context;
    }
    _lastOwner = frameNumber;
    final global = !_globalSealed && _waitDepth == 0;
    _owners[frameNumber] = [
      frameNumber,
      context,
      _active?.id ?? -1,
      global ? 1 : 0,
    ];
    if (global) _globalIds.add(frameNumber);
    _active?._ids.add(frameNumber);
  }

  void addTiming(ReleaseFrameTiming value) {
    if (_timings.containsKey(value.frameNumber)) {
      _issue('duplicate_timing');
      return;
    }
    if (_timings.length >= maxRecords) {
      _issue('timing_overflow');
      return;
    }
    _timings[value.frameNumber] = value;
    if (value.frameNumber < 0 || value.buildUs < 0 || value.rasterUs < 0) {
      _issue('invalid_timing');
    }
    if (!_owners.containsKey(value.frameNumber)) {
      if (value.frameNumber >= 0 &&
          value.frameNumber <= observationStartFrame) {
        _preObservation++;
      } else if (_globalSealed && value.frameNumber > _lastOwner) {
        _postObservation++;
      } else {
        _issue('unknown_owner');
      }
    }
    for (final waiter in _waiters.toList()) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
  }

  Future<bool> _awaitIds(List<int> ids, Duration timeout) async {
    final deadline = Stopwatch()..start();
    _waitDepth++;
    try {
      while (ids.any((id) => !_timings.containsKey(id))) {
        final remaining = timeout - deadline.elapsed;
        if (remaining <= Duration.zero) return false;
        final changed = Completer<void>();
        _waiters.add(changed);
        try {
          await changed.future.timeout(remaining);
        } on TimeoutException {
          return false;
        } finally {
          _waiters.remove(changed);
        }
      }
      return true;
    } finally {
      _waitDepth--;
    }
  }

  Future<Map<String, Object?>> finish(
    ReleaseFrameMeasurement value, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_active != value || value._sealed) {
      _issue('invalid_measurement_close');
      throw StateError('Release frame measurement owner changed');
    }
    // Freeze the original workload before yielding. Later idle frames are raw
    // evidence only, and cannot enter this phase or the global denominator.
    value._sealed = true;
    _active = null;
    if (!await _awaitIds(List<int>.of(value._ids), timeout)) {
      value._timedOut = true;
    }
    return summary(value);
  }

  Future<Map<String, Object?>> finishObservation({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_active != null || _globalSealed) {
      _issue('invalid_observation_close');
      throw StateError(
        'Release frame observation cannot close an active measurement',
      );
    }
    _globalSealed = true;
    if (!await _awaitIds(List<int>.of(_globalIds), timeout)) {
      _globalTimedOut = true;
    }
    return globalSummary();
  }

  static Map<String, Object?> _quantile(List<ReleaseFrameTiming> values) {
    final sums = values.map((v) => v.sumUs).toList()..sort();
    final builds = values.map((v) => v.buildUs).toList()..sort();
    final rasters = values.map((v) => v.rasterUs).toList()..sort();
    final rank = sums.isEmpty
        ? null
        : (sums.length * .95).floor().clamp(0, sums.length - 1);
    return {
      'count': sums.length,
      'quantile': .95,
      'quantileIndex': rank,
      'p95Us': rank == null ? null : sums[rank],
      'maxUs': sums.isEmpty ? null : sums.last,
      'buildP95Us': rank == null ? null : builds[rank],
      'rasterP95Us': rank == null ? null : rasters[rank],
      'maxBuildUs': builds.isEmpty ? null : builds.last,
      'maxRasterUs': rasters.isEmpty ? null : rasters.last,
    };
  }

  Map<String, Object?> _summary(
    List<int> ids, {
    required bool sealed,
    required bool timedOut,
    required int minimum,
  }) {
    final missing = ids.where((id) => !_timings.containsKey(id)).toList();
    final values = ids
        .where(_timings.containsKey)
        .map((id) => _timings[id]!)
        .toList();
    final byContext = <int, List<ReleaseFrameTiming>>{};
    for (final value in values) {
      byContext
          .putIfAbsent(_owners[value.frameNumber]![1], () => [])
          .add(value);
    }
    return {
      ..._quantile(values),
      'available':
          sealed &&
          !timedOut &&
          missing.isEmpty &&
          values.length >= minimum &&
          _errors.isEmpty,
      'sealed': sealed,
      'timedOut': timedOut,
      'minimumSamples': minimum,
      'admittedCount': ids.length,
      'firstFrame': ids.isEmpty ? null : ids.first,
      'lastFrame': ids.isEmpty ? null : ids.last,
      'missingFrameIds': missing,
      'coverage': {
        'owned': ids.length,
        'delivered': values.length,
        'missing': missing.length,
      },
      'errors': Map<String, int>.of(_errors),
      'byContext': [
        for (final entry in byContext.entries)
          {'context': entry.key, ..._quantile(entry.value)},
      ],
    };
  }

  Map<String, Object?> summary(ReleaseFrameMeasurement value) => {
    'name': value.name,
    ..._summary(
      value._ids,
      sealed: value._sealed,
      timedOut: value._timedOut,
      minimum: 4,
    ),
  };
  Map<String, Object?> globalSummary() => _summary(
    _globalIds,
    sealed: _globalSealed,
    timedOut: _globalTimedOut,
    minimum: 1,
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'maxRecords': maxRecords,
    'maxContexts': maxContexts,
    'observationStartFrame': observationStartFrame,
    'errors': Map<String, int>.of(_errors),
    'preObservationTimings': _preObservation,
    'postObservationTimings': _postObservation,
    'outsideOwnerCalls': _outsideOwnerCalls,
    'contexts': [for (final context in _contexts.keys) context.toJson()],
    'ownerColumns': ['frameNumber', 'context', 'measurement', 'globalWorkload'],
    'owners': _owners.values.toList(),
    'timingColumns': [
      'frameNumber',
      'vsyncStartUs',
      'buildStartUs',
      'buildFinishUs',
      'rasterStartUs',
      'rasterFinishUs',
      'rasterFinishWallUs',
      'deliveredAtUs',
    ],
    'timings': _timings.values.map((v) => v.toRow()).toList(),
    'measurements': _measurements.map(summary).toList(),
    'global': globalSummary(),
  };
}
