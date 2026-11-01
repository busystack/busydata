import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:ffi';
import 'dart:typed_data';

final class _MallInfo extends Struct {
  @UintPtr()
  external int arena;
  @UintPtr()
  external int ordblks;
  @UintPtr()
  external int smblks;
  @UintPtr()
  external int hblks;
  @UintPtr()
  external int hblkhd;
  @UintPtr()
  external int usmblks;
  @UintPtr()
  external int fsmblks;
  @UintPtr()
  external int uordblks;
  @UintPtr()
  external int fordblks;
  @UintPtr()
  external int keepcost;
}

Map<String, int> nativeAllocatorDiagnostics() {
  if (!Platform.isLinux) {
    throw UnsupportedError('Native allocator diagnostics require Linux/glibc');
  }
  final read = DynamicLibrary.process()
      .lookupFunction<_MallInfo Function(), _MallInfo Function()>('mallinfo2');
  final data = read();
  return {
    'arenaBytes': data.arena,
    'allocatedBytes': data.uordblks,
    'freeBytes': data.fordblks,
    'mappedBytes': data.hblkhd,
  };
}

/// Numeric, bounded residency attribution. Mapping names/addresses and service
/// URLs are deliberately omitted. This does not change the gate's RSS metric.
Future<Map<String, int>> mappedMemoryDiagnostics(int process) async {
  var bytes = 0;
  final text = await File('/proc/$process/smaps')
      .openRead()
      .map((chunk) {
        bytes += chunk.length;
        if (bytes > 8 * 1024 * 1024) {
          throw StateError('Mapping diagnostic response budget exceeded');
        }
        return chunk;
      })
      .transform(utf8.decoder)
      .join();
  return mappedResidentTotals(text);
}

Map<String, int> mappedResidentTotals(String text) {
  final totals = <String, int>{};
  var category = 'anonymous';
  final mappingPattern = RegExp(
    r'^[0-9a-f]+-[0-9a-f]+\s+([rwxps-]+)\s+\S+\s+\S+\s+\d+\s*(.*)$',
  );
  final whitespace = RegExp(r'\s+');
  for (final line in const LineSplitter().convert(text)) {
    final mapping = mappingPattern.firstMatch(line);
    if (mapping != null) {
      final name = mapping.group(2)!;
      category = name.isEmpty || name.startsWith('[anon:')
          ? (mapping.group(1)!.contains('x')
                ? 'anonymousExecutable'
                : 'anonymous')
          : name.startsWith('[')
          ? 'special'
          : 'file';
    } else if (line.startsWith('Rss:')) {
      final bytes = int.parse(line.split(whitespace)[1]) * 1024;
      totals[category] = (totals[category] ?? 0) + bytes;
    }
  }
  return totals;
}

/// Numeric process lineage only; no command arguments, environment or URLs.
Future<Map<String, int>> processIdentity(int process) async {
  final stat = await File('/proc/$process/stat').readAsString();
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return {
    'pid': process,
    'parentPid': int.parse(fields[1]),
    'startTicks': int.parse(fields[19]),
  };
}

/// Test-only inspection of the already running debug VM. Never enables a
/// listener, triggers GC, reads object values, or records the private service URI.
Future<Map<String, Object?>> debugMemoryDiagnostics() async {
  final service = await developer.Service.getInfo();
  final isolate = developer.Service.getIsolateId(Isolate.current);
  final address = service.serverUri;
  if (address == null || isolate == null) {
    return {'available': false, 'reason': 'Debug VM service unavailable'};
  }
  if (!['127.0.0.1', '::1', 'localhost'].contains(address.host)) {
    throw StateError('Owned debug VM service must use loopback');
  }
  final WebSocket socket;
  try {
    socket = await WebSocket.connect(
      address.resolve('ws').replace(scheme: 'ws').toString(),
    ).timeout(const Duration(seconds: 5));
  } catch (error) {
    // A socket exception can contain the service URI's private authentication
    // path. Keep only the failure type in the test/evidence channel.
    throw StateError('Debug aggregate connection failed: ${error.runtimeType}');
  }
  final reply = Completer<Map<String, dynamic>>();
  final subscription = socket.listen(
    (event) {
      if (event is! String || event.length > 8 * 1024 * 1024) {
        if (!reply.isCompleted) {
          reply.completeError(
            StateError('VM diagnostic response budget exceeded'),
          );
        }
        return;
      }
      try {
        final parsed = jsonDecode(event) as Map<String, dynamic>;
        if (parsed['id'] != 'memory') return;
        if (parsed['error'] != null) {
          final failure = parsed['error'] as Map<String, dynamic>;
          // Error data may contain private object/service identifiers. Retain
          // only the numeric RPC code and the aggregate method being inspected.
          throw StateError(
            'Debug VM rejected getMemoryUsage '
            '(RPC code ${failure['code']})',
          );
        }
        if (!reply.isCompleted) {
          reply.complete(parsed['result'] as Map<String, dynamic>);
        }
      } catch (error, stack) {
        if (!reply.isCompleted) reply.completeError(error, stack);
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!reply.isCompleted) {
        reply.completeError(
          StateError('Debug aggregate channel failed: ${error.runtimeType}'),
          stack,
        );
      }
    },
    onDone: () {
      if (!reply.isCompleted) {
        reply.completeError(
          StateError('Debug VM closed its diagnostic channel'),
        );
      }
    },
  );
  try {
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 'memory',
        'method': 'getMemoryUsage',
        // Aggregate counters avoid the VM's unbounded per-class inventory.
        // This diagnostic never requests a collection.
        'params': {'isolateId': isolate},
      }),
    );
    final data = await reply.future.timeout(const Duration(seconds: 5));
    return {
      'available': true,
      'manualGc': false,
      for (final key in ['heapUsage', 'heapCapacity', 'externalUsage'])
        key: data[key],
    };
  } finally {
    await subscription.cancel();
    await socket.close();
  }
}

const _allocationProfileResponseLimit = 8 * 1024 * 1024;
const _allocationProfileClassLimit = 32768;
const _allocationProfileTopLimit = 20;
var _allocationProfileSamples = 0;

class _AllocationProfileUnavailable implements Exception {
  const _AllocationProfileUnavailable(this.reason, [this.rpcCode]);
  final String reason;
  final int? rpcCode;
}

Map<String, Object?> _allocationProfileSummary(
  Object? value,
  void Function() checkDeadline,
) {
  if (value is! Map || value['type'] != 'AllocationProfile') {
    throw const _AllocationProfileUnavailable('invalid-profile');
  }
  final members = value['members'];
  if (members is! List || members.length > _allocationProfileClassLimit) {
    throw const _AllocationProfileUnavailable('class-budget');
  }
  final top = <Map<String, Object>>[];
  var totalBytes = 0, totalInstances = 0, index = 0;
  const maximumCounter = 9007199254740991;
  final unsafeName = RegExp(r'[\x00-\x1f\x7f/\\]');
  for (final member in members) {
    if (index++ % 256 == 0) checkDeadline();
    if (member is! Map || member['class'] is! Map) {
      throw const _AllocationProfileUnavailable('invalid-class');
    }
    final name = (member['class'] as Map)['name'];
    final bytes = member['bytesCurrent'],
        instances = member['instancesCurrent'];
    if (name is! String ||
        name.isEmpty ||
        name.length > 256 ||
        unsafeName.hasMatch(name) ||
        bytes is! int ||
        instances is! int ||
        bytes < 0 ||
        instances < 0 ||
        bytes > maximumCounter - totalBytes ||
        instances > maximumCounter - totalInstances) {
      throw const _AllocationProfileUnavailable('invalid-class-counters');
    }
    totalBytes += bytes;
    totalInstances += instances;
    top.add({
      'className': name,
      'bytesCurrent': bytes,
      'instancesCurrent': instances,
    });
    top.sort((a, b) {
      final bytes = (b['bytesCurrent'] as int).compareTo(
        a['bytesCurrent'] as int,
      );
      if (bytes != 0) return bytes;
      final name = (a['className'] as String).compareTo(
        b['className'] as String,
      );
      return name != 0
          ? name
          : (b['instancesCurrent'] as int).compareTo(
              a['instancesCurrent'] as int,
            );
    });
    if (top.length > _allocationProfileTopLimit) top.removeLast();
  }
  checkDeadline();
  return {
    'available': true,
    'classCount': members.length,
    'reportedCurrentBytesTotal': totalBytes,
    'reportedCurrentInstancesTotal': totalInstances,
    'topClasses': top,
    'classNamesMayBeAmbiguousAcrossLibraries': true,
  };
}

/// Diagnostic-only shallow class totals from the already running owned isolate.
/// No object values, class/library IDs, paths, reset or collection are requested.
Future<Map<String, Object?>> debugAllocationProfileDiagnostics() async {
  if (Platform.environment['BUSYDATA_MEMORY_DIAGNOSTICS'] != '1') {
    return {'available': false, 'reason': 'disabled'};
  }
  if (_allocationProfileSamples >= 5) {
    return {'available': false, 'reason': 'sample-budget'};
  }
  final sample = ++_allocationProfileSamples;
  const deadline = Duration(seconds: 5);
  final clock = Stopwatch()..start();
  Duration remaining() {
    final value = deadline - clock.elapsed;
    if (value <= Duration.zero) {
      throw const _AllocationProfileUnavailable('client-deadline');
    }
    return value;
  }

  final result = <String, Object?>{
    'available': false,
    'sampleIndex': sample,
    'gcRequested': false,
    'resetRequested': false,
    'transport': 'owned-loopback-http-get',
    'clientDeadlineMs': deadline.inMilliseconds,
    'maximumRetainedResponseBytes': _allocationProfileResponseLimit,
    'maximumClassCount': _allocationProfileClassLimit,
    'topLimit': _allocationProfileTopLimit,
  };
  HttpClient? client;
  HttpClientRequest? request;
  StreamIterator<List<int>>? chunks;
  var responseComplete = false;
  try {
    final service = await developer.Service.getInfo().timeout(remaining());
    final isolate = developer.Service.getIsolateId(Isolate.current);
    final address = service.serverUri;
    if (address == null || isolate == null) {
      throw const _AllocationProfileUnavailable('service-unavailable');
    }
    if (address.scheme != 'http' ||
        !['127.0.0.1', '::1', 'localhost'].contains(address.host) ||
        !address.path.endsWith('/') ||
        address.hasQuery ||
        address.hasFragment ||
        address.userInfo.isNotEmpty) {
      throw const _AllocationProfileUnavailable('unsupported-service-address');
    }
    // Keep the owned service's authentication prefix in memory only. Never
    // follow redirects or send this private request through an ambient proxy.
    // vm_service 15.3 omits false gc/reset options; neither action is requested.
    final target = address
        .resolve('getAllocationProfile')
        .replace(queryParameters: {'isolateId': isolate});
    client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    client.autoUncompress = false;
    client.connectionTimeout = remaining();
    request = await client.getUrl(target).timeout(remaining());
    request.followRedirects = false;
    request.persistentConnection = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(remaining());
    result['httpStatusCode'] = response.statusCode;
    if (response.statusCode != HttpStatus.ok) {
      throw const _AllocationProfileUnavailable('http-status');
    }
    final encoding = response.headers.value(HttpHeaders.contentEncodingHeader);
    if ((encoding != null && encoding != 'identity') ||
        response.headers.contentType?.mimeType != 'application/json') {
      throw const _AllocationProfileUnavailable(
        'unsupported-response-encoding',
      );
    }
    if (response.contentLength > _allocationProfileResponseLimit) {
      throw const _AllocationProfileUnavailable('response-budget');
    }
    final body = BytesBuilder(copy: false);
    chunks = StreamIterator<List<int>>(response);
    while (await chunks.moveNext().timeout(remaining())) {
      final chunk = chunks.current;
      if (chunk.length > _allocationProfileResponseLimit - body.length) {
        throw const _AllocationProfileUnavailable('response-budget');
      }
      body.add(chunk);
    }
    responseComplete = true;
    result['responseBytes'] = body.length;
    remaining();
    final parsed = jsonDecode(utf8.decode(body.takeBytes()));
    remaining();
    if (parsed is! Map) {
      throw const _AllocationProfileUnavailable('invalid-rpc-response');
    }
    if (parsed['error'] case final Map error) {
      throw _AllocationProfileUnavailable(
        'rpc-error',
        error['code'] is int ? error['code'] as int : null,
      );
    }
    result.addAll(_allocationProfileSummary(parsed['result'], remaining));
  } on _AllocationProfileUnavailable catch (error) {
    result['reason'] = error.reason;
    if (error.rpcCode != null) result['rpcCode'] = error.rpcCode;
  } on TimeoutException {
    result['reason'] = 'client-deadline';
  } on Object catch (error) {
    // Exception messages can contain private service authentication URLs.
    result['reason'] = 'profile-unavailable';
    result['failureType'] = error.runtimeType.toString();
  } finally {
    // Aborting/closing this owned client bounds client-side work; it cannot
    // cancel VM/DDS allocation-profile generation or synchronous JSON decoding.
    if (!responseComplete) request?.abort();
    client?.close(force: true);
    try {
      await chunks?.cancel().timeout(const Duration(seconds: 1));
      result['cleanupComplete'] = true;
    } on Object catch (error) {
      result['cleanupComplete'] = false;
      result['cleanupFailureType'] = error.runtimeType.toString();
    }
    result['elapsedMs'] = clock.elapsedMilliseconds;
  }
  return result;
}
