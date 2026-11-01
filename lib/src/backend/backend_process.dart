import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'generated/busydata.pbgrpc.dart';
import 'private_rpc_transport.dart';

abstract interface class BackendConnection {
  Process get process;
  WorkbenchClient get client;
  String get instanceId;
  Context context();
  Future<void> close();
}

class BackendProcess implements BackendConnection {
  static const rpcTimeout = Duration(seconds: 30);
  static const javaMaxHeapMiB = 128;
  static const javaMaxDirectMemoryMiB = 64;
  static const javaGarbageCollector = 'Serial';
  BackendProcess._(this.process, this.channel, this.client, this.instanceId);
  @override
  final Process process;
  final ClientTransportConnectorChannel channel;
  @override
  final WorkbenchClient client;
  @override
  final String instanceId;
  bool _closed = false;
  @override
  Context context() => Context(
    instanceId: instanceId,
    requestId: const Uuid().v4(),
    protocolVersion: ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.value,
  );

  static Future<BackendProcess> start(Directory support) async {
    const developmentBundle = String.fromEnvironment('BUSYDATA_BACKEND_DIR');
    final base = p.absolute(
      developmentBundle.isEmpty
          ? p.join(p.dirname(Platform.resolvedExecutable), 'backend')
          : developmentBundle,
    );
    final runtime = p.join(
      base,
      'runtime',
      'bin',
      Platform.isWindows ? 'java.exe' : 'java',
    );
    if (!File(runtime).existsSync()) {
      throw StateError(
        'Bundled backend runtime is missing. Build with tool/bundle_backend.py.',
      );
    }
    final random = Random.secure();
    final secret = List.generate(
      32,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final environment = Map<String, String>.of(Platform.environment)
      ..remove('JAVA_TOOL_OPTIONS')
      ..remove('JDK_JAVA_OPTIONS')
      ..remove('_JAVA_OPTIONS')
      ..remove('CLASSPATH');
    if (Platform.isLinux) {
      // exec starts a new allocator: the native launcher's mallopt settings do
      // not cross this boundary. Apply the same bounded Linux policy before
      // the owned runtime initializes, using glibc's supported startup inputs.
      environment
        ..remove('GLIBC_TUNABLES')
        ..['MALLOC_ARENA_MAX'] = '2'
        ..['MALLOC_MMAP_THRESHOLD_'] = '131072'
        ..['MALLOC_TRIM_THRESHOLD_'] = '131072';
    }
    final child = await Process.start(
      p.absolute(runtime),
      [
        '--enable-native-access=ALL-UNNAMED',
        // Java does not inherit the launcher's OS-selected temporary directory
        // from TMPDIR on Linux. Set the trusted platform path before its JNI
        // loaders initialize; no workspace setting supplies JVM arguments.
        '-Djava.io.tmpdir=${Directory.systemTemp.absolute.path}',
        '-Xms32m',
        '-Xmx${javaMaxHeapMiB}m',
        '-XX:MaxDirectMemorySize=${javaMaxDirectMemoryMiB}m',
        // This backend retains a small live dataset and spools result values.
        // Keep collector footprint predictable at the existing 128MiB heap;
        // desktop acceptance measures pauses, cancellation and combined RSS.
        '-XX:+UseSerialGC',
        // Use Java's client compiler ergonomics for this small backend. Keep
        // heap/direct caps unchanged; desktop gates measure the whole workload.
        '-XX:+NeverActAsServerClassMachine',
        '-cp',
        p.join(base, 'lib', '*'),
        'io.busystack.busydata.Main',
      ],
      workingDirectory: p.absolute(base),
      environment: environment,
      includeParentEnvironment: false,
    );
    child.stderr.listen((_) {});
    child.stdin.writeln(
      jsonEncode({
        'secret': secret,
        'parentPid': pid,
        'supportDirectory': support.absolute.path,
      }),
    );
    await child.stdin.flush();
    ClientTransportConnectorChannel? startedChannel;
    try {
      final ready = await child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 30));
      if (ready.length > 16384) throw StateError('Invalid bootstrap response');
      final data = jsonDecode(ready) as Map<String, dynamic>;
      if (data['errorCode'] is String) {
        final message = switch (data['errorCode']) {
          'BACKEND_STARTUP_METADATA' =>
            'Cannot open private metadata. Check directory permissions, corruption, or another active writer.',
          'BACKEND_STARTUP_PRIVATE_STORAGE' =>
            'Cannot prepare private result or credential storage. Check permissions and free disk space.',
          'BACKEND_STARTUP_TLS' =>
            'Cannot initialize bundled TLS security providers.',
          'BACKEND_STARTUP_LISTENER' =>
            'Cannot bind the private loopback service. Check package network permissions.',
          _ => 'Invalid backend bootstrap.',
        };
        throw StateError(message);
      }
      if (data['protocolVersion'] !=
              ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.value ||
          data['version'] != '0.1.0') {
        throw StateError('Backend/protocol version mismatch');
      }
      final port = data['port'] as int;
      if (port < 1 || port > 65535) throw StateError('Invalid loopback port');
      final channel = privateRpcChannel(
        port: port,
        certificateBytes: utf8.encode(data['certificatePem'] as String),
      );
      startedChannel = channel;
      final client = WorkbenchClient(
        channel,
        options: CallOptions(
          metadata: {'x-busydata-launch': secret},
          timeout: rpcTimeout,
        ),
      );
      final backend = BackendProcess._(
        child,
        channel,
        client,
        data['instanceId'] as String,
      );
      await client.ping(backend.context());
      return backend;
    } catch (_) {
      try {
        await startedChannel?.terminate().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await child.stdin.close().timeout(const Duration(seconds: 2));
      } catch (_) {}
      child.kill();
      try {
        await child.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        child.kill(ProcessSignal.sigkill);
      }
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await client.shutdown(
        context(),
        options: CallOptions(timeout: const Duration(seconds: 3)),
      );
    } catch (_) {}
    try {
      await process.stdin.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 2));
      }
    }
    // The owned child has exited. No RPC can complete by waiting indefinitely for
    // HTTP/2 graceful stream shutdown, so terminate the remaining local transport.
    await channel.terminate().timeout(const Duration(seconds: 2));
  }
}
