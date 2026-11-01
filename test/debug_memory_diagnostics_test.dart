import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/debug_memory_diagnostics.dart';

void main() {
  test('disabled allocation profiling creates no HTTP client', () async {
    var clientsCreated = 0;
    final result = await HttpOverrides.runZoned(
      debugAllocationProfileDiagnostics,
      createHttpClient: (_) {
        clientsCreated++;
        throw StateError('Disabled profiling attempted HTTP access');
      },
    );
    expect(result, {'available': false, 'reason': 'disabled'});
    expect(clientsCreated, 0);
  });

  test(
    'mapping diagnostics retain all RSS categories and no path or address',
    () {
      final totals = mappedResidentTotals('''
1000-2000 rw-p 00000000 00:00 0
Rss: 10 kB
2000-3000 r-xp 00000000 00:00 0 [anon:dart-code]
Rss: 20 kB
3000-4000 r--p 00000000 01:01 1 /fixture/generated/code (deleted)
Rss: 30 kB
4000-5000 rw-p 00000000 00:00 0 [heap]
Rss: 40 kB
''');
      expect(totals, {
        'anonymous': 10240,
        'anonymousExecutable': 20480,
        'file': 30720,
        'special': 40960,
      });
    },
  );
  test(
    'lineage identifies this process without recording process arguments',
    () async {
      if (!Platform.isLinux) return;
      final identity = await processIdentity(pid);
      expect(
        identity.keys,
        unorderedEquals(['pid', 'parentPid', 'startTicks']),
      );
      expect(identity['pid'], pid);
      expect(identity['parentPid'], greaterThan(0));
      expect(identity['startTicks'], greaterThan(0));
    },
  );
  test(
    'native allocation counters are distinct from RSS and do not alter allocation policy',
    () {
      if (!Platform.isLinux) {
        expect(nativeAllocatorDiagnostics, throwsUnsupportedError);
        return;
      }
      final data = nativeAllocatorDiagnostics();
      expect(data['arenaBytes'], data['allocatedBytes']! + data['freeBytes']!);
      expect(data.values, everyElement(greaterThanOrEqualTo(0)));
    },
  );
}
