/// Opt-in, bounded counters for separate diagnostic runs. No labels or values
/// from documents, database records or credentials are collected.
class PresentationDiagnostics {
  static const enabled = bool.fromEnvironment(
    'BUSYDATA_PRESENTATION_DIAGNOSTICS',
  );
  static final _calls = <String, int>{};
  static final _microseconds = <String, int>{};
  static Stopwatch? start(String operation) {
    if (!enabled) return null;
    count(operation);
    return Stopwatch()..start();
  }

  static void count(String operation) {
    if (enabled) {
      _calls.update(operation, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  static void finish(String operation, Stopwatch? watch) {
    if (watch == null) return;
    _microseconds.update(
      operation,
      (value) => value + watch.elapsedMicroseconds,
      ifAbsent: () => watch.elapsedMicroseconds,
    );
  }

  static Map<String, Object> snapshot() => {
    'enabled': enabled,
    'calls': Map<String, int>.of(_calls),
    'microseconds': Map<String, int>.of(_microseconds),
  };
}
