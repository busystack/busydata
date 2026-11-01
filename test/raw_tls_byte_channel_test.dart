import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:busydata/src/backend/raw_tls_byte_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:http2/transport.dart' as h2;
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart';
import 'package:busydata/src/backend/private_rpc_transport.dart';

Future<Directory> grpcFixtures() async {
  final file = File('.dart_tool/package_config.json').absolute;
  final data = jsonDecode(await file.readAsString()) as Map;
  final package = (data['packages'] as List).cast<Map>().singleWhere(
    (p) => p['name'] == 'grpc',
  );
  return Directory.fromUri(file.uri.resolve(package['rootUri'] as String));
}

class TlsPair {
  TlsPair(this.channel, this.peer, this.listener, this.accepted);
  final RawTlsByteChannel channel;
  final SecureSocket peer;
  final SecureServerSocket listener;
  final StreamSubscription<SecureSocket> accepted;
  static Future<TlsPair> open() async {
    // These are public, non-production fixtures in the unmodified pinned gRPC
    // package. Neither the fixture key nor any user key is copied or logged.
    final source = await grpcFixtures();
    final certificate = await File(
      '${source.path}/test/data/localhost.crt',
    ).readAsBytes();
    final key = await File(
      '${source.path}/test/data/localhost.key',
    ).readAsBytes();
    final serverContext = SecurityContext()
      ..useCertificateChainBytes(certificate)
      ..usePrivateKeyBytes(key)
      ..setAlpnProtocols(const ['h2'], true);
    final listener = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
      supportedProtocols: ['h2'],
    );
    final connected = Completer<SecureSocket>();
    final accepted = listener.listen((peer) {
      if (!connected.isCompleted) {
        connected.complete(peer);
      } else {
        peer.destroy();
      }
    }, onError: connected.completeError);
    RawSocket? raw;
    try {
      raw = await RawSocket.connect(
        InternetAddress.loopbackIPv4,
        listener.port,
      );
      final context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(certificate)
        ..setAlpnProtocols(const ['h2'], false);
      final secure = await RawSecureSocket.secure(
        raw,
        host: 'localhost',
        context: context,
        supportedProtocols: ['h2'],
      ).timeout(const Duration(seconds: 5));
      final peer = await connected.future.timeout(const Duration(seconds: 5));
      expect(secure.selectedProtocol, 'h2');
      return TlsPair(
        RawTlsByteChannel(transport: raw, tls: secure),
        peer,
        listener,
        accepted,
      );
    } catch (_) {
      await raw?.close();
      await accepted.cancel();
      await listener.close();
      rethrow;
    }
  }

  Future<void> close() async {
    channel.shutdown();
    peer.destroy();
    await accepted.cancel();
    await listener.close();
    await channel.done.timeout(const Duration(seconds: 2));
  }
}

class OversizedBytes extends ListBase<int> {
  @override
  int get length => RawTlsByteChannel.maxBufferedOutputBytes + 1;
  @override
  set length(int value) => throw UnsupportedError('Immutable fixture');
  @override
  int operator [](int index) =>
      throw StateError('Admission must precede byte access');
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('Immutable fixture');
}

class FixtureConnector implements ClientTransportConnector {
  FixtureConnector(this.pair);
  final TlsPair pair;
  @override
  String get authority => 'localhost';
  @override
  Future<h2.ClientTransportConnection> connect() async =>
      GuardedClientTransportConnection.viaStreams(
        pair.channel.incoming,
        pair.channel.outgoing,
      );
  @override
  Future get done => pair.channel.done;
  @override
  void shutdown() => pair.channel.shutdown();
}

class WaitingService extends WorkbenchServiceBase {
  final arrived = Completer<void>();
  final response = Completer<BackendInfo>();
  int calls = 0;
  @override
  Future<BackendInfo> ping(ServiceCall call, Context request) {
    calls++;
    if (!arrived.isCompleted) arrived.complete();
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Fixture only');
}

void main() {
  test(
    'real TLS preserves multi-page byte I/O with pause and resume',
    () async {
      final pair = await TlsPair.open();
      addTearDown(pair.close);
      final payload = Uint8List(2 * 1024 * 1024);
      for (var i = 0; i < payload.length; i++) {
        payload[i] = (i * 31 + 7) & 255;
      }
      final echoed = Completer<void>();
      final peerSubscription = pair.peer.listen(
        pair.peer.add,
        onError: echoed.completeError,
      );
      addTearDown(peerSubscription.cancel);
      var offset = 0;
      final input = pair.channel.incoming.listen((part) {
        expect(
          part,
          orderedEquals(
            Uint8List.sublistView(payload, offset, offset + part.length),
          ),
        );
        offset += part.length;
        if (offset == payload.length && !echoed.isCompleted) echoed.complete();
      }, onError: echoed.completeError);
      addTearDown(input.cancel);
      input.pause();
      final writing = pair.channel.outgoing.addStream(
        Stream.fromIterable([
          for (var i = 0; i < payload.length; i += 16384)
            Uint8List.sublistView(payload, i, i + 16384),
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(offset, 0);
      input.resume();
      await writing.timeout(const Duration(seconds: 10));
      await echoed.future.timeout(const Duration(seconds: 10));
      expect(offset, payload.length);
      expect(pair.channel.bufferedOutputBytes, 0);
    },
  );

  test('peer EOF retains every partial final read', () async {
    final pair = await TlsPair.open();
    addTearDown(pair.close);
    final peerSubscription = pair.peer.listen((_) {});
    addTearDown(peerSubscription.cancel);
    final reading = pair.channel.incoming.expand((bytes) => bytes).toList();
    pair.peer.add([0, 255, 42]);
    await pair.peer.flush();
    pair.peer.add([8, 0, 9, 10]);
    await pair.peer.close();
    expect(await reading.timeout(const Duration(seconds: 5)), [
      0,
      255,
      42,
      8,
      0,
      9,
      10,
    ]);
  });

  test(
    'shutdown cancels a still-open outgoing source and releases its subscription',
    () async {
      final pair = await TlsPair.open();
      addTearDown(pair.close);
      final seen = Completer<void>(), cancelled = Completer<void>();
      final peerSubscription = pair.peer.listen((part) {
        if (part.isNotEmpty && !seen.isCompleted) seen.complete();
      });
      addTearDown(peerSubscription.cancel);
      final input = pair.channel.incoming.listen(
        (_) {},
        onError: (Object _) {},
      );
      addTearDown(input.cancel);
      final source = StreamController<List<int>>(
        onCancel: () {
          if (!cancelled.isCompleted) cancelled.complete();
        },
      );
      addTearDown(source.close);
      final writing = pair.channel.outgoing
          .addStream(source.stream)
          .then<Object?>((_) => null, onError: (Object error) => error);
      source.add(Uint8List(16384));
      await seen.future.timeout(const Duration(seconds: 5));
      pair.channel.shutdown();
      final result = await writing.timeout(const Duration(seconds: 2));
      expect(result, anyOf(isNull, isA<SocketException>()));
      await cancelled.future.timeout(const Duration(seconds: 2));
      expect(source.hasListener, isFalse);
      expect(pair.channel.bufferedOutputBytes, 0);
      expect(pair.channel.terminalError, isNull);
    },
  );

  test(
    'never-listened input and oversized output terminate without retaining data',
    () async {
      final pair = await TlsPair.open();
      addTearDown(pair.close);
      final peerSubscription = pair.peer.listen((_) {});
      addTearDown(peerSubscription.cancel);
      expect(
        () => pair.channel.outgoing.add(OversizedBytes()),
        throwsA(isA<SocketException>()),
      );
      await pair.channel.done.timeout(const Duration(seconds: 2));
      expect(pair.channel.bufferedOutputBytes, 0);
      expect(pair.channel.terminalError, isA<SocketException>());
      expect(
        () => pair.channel.outgoing.add([1]),
        throwsA(isA<SocketException>()),
      );
    },
  );
  test(
    'real outgoing faults remain observable on incoming and terminal state',
    () async {
      final pair = await TlsPair.open();
      addTearDown(pair.close);
      final peerSubscription = pair.peer.listen((_) {});
      addTearDown(peerSubscription.cancel);
      final reported = Completer<Object>();
      final input = pair.channel.incoming.listen(
        (_) {},
        onError: (Object error) {
          if (!reported.isCompleted) reported.complete(error);
        },
      );
      addTearDown(input.cancel);
      final source = StreamController<List<int>>();
      addTearDown(source.close);
      final writing = pair.channel.outgoing.addStream(source.stream);
      const error = SocketException('Deliberate owned fixture source fault');
      source.addError(error, StackTrace.current);
      expect(
        await reported.future.timeout(const Duration(seconds: 2)),
        same(error),
      );
      await writing.timeout(const Duration(seconds: 2));
      expect(pair.channel.terminalError, same(error));
      expect(source.hasListener, isFalse);
    },
  );

  test(
    'TLS peer EOF fails a started RPC without replay or a successful response',
    () async {
      final pair = await TlsPair.open();
      final service = WaitingService();
      final server = ConnectionServer([service]);
      final serving = h2.ServerTransportConnection.viaSocket(pair.peer);
      await server.serveConnection(connection: serving);
      final fixtures = await grpcFixtures();
      final certificate = await File(
        '${fixtures.path}/test/data/localhost.crt',
      ).readAsBytes();
      final client = ClientTransportConnectorChannel(
        FixtureConnector(pair),
        options: ChannelOptions(
          credentials: ChannelCredentials.secure(certificates: certificate),
        ),
      );
      addTearDown(() async {
        await client.terminate();
        if (!service.response.isCompleted) {
          service.response.complete(BackendInfo());
        }
        await serving.terminate();
        await pair.close();
      });
      final call = WorkbenchClient(client).ping(
        Context(),
        options: CallOptions(timeout: const Duration(seconds: 5)),
      );
      final outcome = expectLater(
        call,
        throwsA(
          isA<GrpcError>().having(
            (error) => error.code,
            'pinned gRPC response-stream fault mapping',
            StatusCode.unknown,
          ),
        ),
      );
      await service.arrived.future.timeout(const Duration(seconds: 5));
      pair.peer.destroy();
      await outcome.timeout(const Duration(seconds: 2));
      await pair.channel.done.timeout(const Duration(seconds: 2));
      // Byte EOF itself is not a socket error. The incomplete response remains
      // a failed RPC even though releasing the local writer completes normally.
      expect(pair.channel.terminalError, isNull);
      expect(service.calls, 1);
    },
  );
}
