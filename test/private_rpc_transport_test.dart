import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart';
import 'package:busydata/src/backend/private_rpc_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

List<int> frame(int type, int id, List<int> payload, {int flags = 0}) => [
  payload.length >> 16,
  (payload.length >> 8) & 255,
  payload.length & 255,
  type,
  flags,
  (id >> 24) & 127,
  (id >> 16) & 255,
  (id >> 8) & 255,
  id & 255,
  ...payload,
];

Future<List<int>> publicGrpcCertificate() async {
  final configuration = File('.dart_tool/package_config.json').absolute;
  final packages =
      (jsonDecode(await configuration.readAsString()) as Map)['packages']
          as List;
  final grpc = packages.cast<Map>().singleWhere(
    (package) => package['name'] == 'grpc',
  );
  final root = Directory.fromUri(
    configuration.uri.resolve(grpc['rootUri'] as String),
  ).uri;
  return File.fromUri(root.resolve('test/data/localhost.crt')).readAsBytes();
}

void main() {
  test(
    'every header fragmentation boundary preserves the exact valid bytes',
    () async {
      final source = [
        ...frame(4, 0, const []),
        ...frame(1, 1, const [0x88], flags: 4),
        ...frame(0, 1, frame(1, 99, const [0x88]), flags: 1),
        ...frame(1, 3, const [0x88], flags: 4),
        ...frame(6, 0, List<int>.filled(8, 7)),
      ];
      for (var split = 1; split <= 12; split++) {
        var violations = 0;
        final guard = PrivateRpcFrameGuard(onViolation: () => violations++)
          ..registerStream(1)
          ..registerStream(3);
        final chunks = <List<int>>[];
        for (var start = 0; start < source.length; start += split) {
          chunks.add(
            source.sublist(
              start,
              (start + split).clamp(0, source.length).toInt(),
            ),
          );
        }
        final actual = await guard
            .bind(Stream.fromIterable(chunks))
            .expand((part) => part)
            .toList();
        expect(actual, source, reason: 'fragment width $split');
        expect(violations, 0);
        expect(guard.bufferedHeaderBytes, 0);
        expect(guard.payloadBytesRemaining, 0);
      }
    },
  );

  test(
    'native typed byte streams and large payloads keep only a bounded header',
    () async {
      var violations = 0, received = 0;
      final guard = PrivateRpcFrameGuard(onViolation: () => violations++)
        ..registerStream(1);
      final payload = Uint8List(2 * 1024 * 1024);
      payload.fillRange(0, payload.length, 0xff);
      final header = frame(0, 1, const [])..replaceRange(0, 3, [32, 0, 0]);
      Stream<Uint8List> chunks() async* {
        for (final byte in header) {
          yield Uint8List.fromList([byte]);
        }
        for (var offset = 0; offset < payload.length; offset += 16384) {
          yield Uint8List.sublistView(payload, offset, offset + 16384);
        }
      }

      await for (final part in guard.bind(chunks())) {
        received += part.length;
        expect(guard.bufferedHeaderBytes, lessThanOrEqualTo(9));
      }
      expect(received, 9 + payload.length);
      expect(guard.payloadBytesRemaining, 0);
      expect(violations, 0);
    },
  );

  for (final (type, id) in [(1, 0), (1, 2), (1, 99), (5, 1)]) {
    test(
      'unsolicited frame $type/$id is rejected before any of its bytes are forwarded',
      () async {
        var violations = 0;
        final guard = PrivateRpcFrameGuard(onViolation: () => violations++)
          ..registerStream(1)
          ..registerStream(3);
        final valid = frame(4, 0, const []);
        final source = [
          ...valid,
          ...frame(type, id, const [0x88]),
          ...frame(1, 3, const [0x88]),
        ];
        final actual = await guard
            .bind(
              Stream.fromIterable([
                for (final byte in source) Uint8List.fromList([byte]),
              ]),
            )
            .expand((part) => part)
            .toList();
        expect(actual, valid);
        expect(violations, 1);
        expect(guard.failed, isTrue);
      },
    );
  }

  test(
    'closed lower client streams remain admissible without a tombstone cache',
    () async {
      var violations = 0;
      final guard = PrivateRpcFrameGuard(onViolation: () => violations++)
        ..registerStream(1)
        ..registerStream(3);
      final late = frame(1, 1, const [0x88], flags: 4);
      final actual = await guard
          .bind(Stream.value(late))
          .expand((part) => part)
          .toList();
      expect(actual, late);
      expect(violations, 0);
      expect(guard.highestOpenedStream, 3);
    },
  );

  test(
    'opening a higher client identifier implicitly closes unused lower identifiers',
    () async {
      var violations = 0;
      final guard = PrivateRpcFrameGuard(onViolation: () => violations++)
        ..registerStream(3);
      final late = frame(1, 1, const [0x88], flags: 4);
      final actual = await guard
          .bind(Stream.value(late))
          .expand((part) => part)
          .toList();
      expect(actual, late);
      expect(violations, 0);
      expect(guard.highestOpenedStream, 3);
    },
  );

  test(
    'connection controls and extension frames retain upstream validation ownership',
    () async {
      final guard = PrivateRpcFrameGuard(
        onViolation: () => fail('valid envelope rejected'),
      );
      final source = [
        ...frame(4, 0, const []),
        ...frame(2, 99, List.filled(5, 0)),
        ...frame(255, 88, const [1, 2, 3]),
      ];
      final actual = await guard
          .bind(Stream.value(source))
          .expand((part) => part)
          .toList();
      expect(actual, source);
    },
  );

  test(
    'stream ownership is positive monotonic odd 31-bit and one input has one guard',
    () async {
      final guard = PrivateRpcFrameGuard(onViolation: () {});
      for (final invalid in [0, -1, 2, 0x80000001]) {
        expect(() => guard.registerStream(invalid), throwsArgumentError);
        expect(guard.highestOpenedStream, 0);
      }
      guard.registerStream(3);
      expect(() => guard.registerStream(3), throwsArgumentError);
      expect(() => guard.registerStream(1), throwsArgumentError);
      await guard.bind(const Stream.empty()).drain<void>();
      expect(() => guard.bind(const Stream.empty()), throwsStateError);
    },
  );

  test(
    'downstream cancellation releases the owned incoming subscription',
    () async {
      var cancelled = false;
      final incoming = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final guard = PrivateRpcFrameGuard(onViolation: () {});
      final subscription = guard.bind(incoming.stream).listen((_) {});
      expect(incoming.hasListener, isTrue);
      await subscription.cancel();
      expect(cancelled, isTrue);
      expect(incoming.hasListener, isFalse);
      await incoming.close();
    },
  );

  test('pause and resume propagate to the owned incoming stream', () async {
    var pauses = 0, resumes = 0;
    final incoming = StreamController<List<int>>(
      onPause: () => pauses++,
      onResume: () => resumes++,
    );
    final guard = PrivateRpcFrameGuard(onViolation: () {});
    final subscription = guard.bind(incoming.stream).listen((_) {});
    subscription.pause();
    expect(pauses, 1);
    subscription.resume();
    expect(resumes, 1);
    await subscription.cancel();
    await incoming.close();
  });

  test(
    'production factory has no insecure endpoint or unlimited certificate option',
    () {
      for (final (port, certificate) in [
        (0, [1]),
        (65536, [1]),
        (1, <int>[]),
        (1, List<int>.filled(65537, 1)),
      ]) {
        expect(
          () => privateRpcChannel(port: port, certificateBytes: certificate),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'private production channel never falls back to cleartext after TLS failure',
    () async {
      // A public certificate from the exact pinned official gRPC package is only
      // a trust input here. No fixture private key or external service is needed.
      final certificate = await publicGrpcCertificate();
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      final observed = <int>[];
      final incoming = listener.listen((socket) {
        sockets.add(socket);
        var replied = false;
        socket.listen((bytes) {
          observed.addAll(
            bytes.take((65536 - observed.length).clamp(0, 65536).toInt()),
          );
          if (!replied) {
            replied = true;
            socket.add(frame(4, 0, const []));
          }
        }, onError: (Object _) {});
      });
      final channel = privateRpcChannel(
        port: listener.port,
        certificateBytes: certificate,
      );
      addTearDown(() async {
        await channel.terminate();
        for (final socket in sockets) {
          socket.destroy();
        }
        await incoming.cancel();
        await listener.close();
      });
      await expectLater(
        WorkbenchClient(channel).ping(
          Context(),
          options: CallOptions(timeout: const Duration(seconds: 3)),
        ),
        throwsA(isA<GrpcError>()),
      );
      expect(sockets, hasLength(1));
      expect(observed, isNotEmpty);
      expect(
        observed.first,
        22,
        reason:
            'The endpoint must begin with a TLS handshake, never an HTTP/2 preface.',
      );
      expect(
        ascii.decode(observed.take(24).toList(), allowInvalid: true),
        isNot(startsWith('PRI * HTTP/2.0')),
      );
    },
  );
  test(
    'terminating during an unanswered TLS handshake closes the owned socket',
    () async {
      final certificate = await publicGrpcCertificate();
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      final hello = Completer<void>(), closed = Completer<void>();
      final incoming = listener.listen((socket) {
        sockets.add(socket);
        socket.listen(
          (bytes) {
            if (bytes.isNotEmpty && !hello.isCompleted) hello.complete();
            // The fixture deliberately never replies to ClientHello.
          },
          onError: (Object _) {
            if (!closed.isCompleted) closed.complete();
          },
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
        );
      });
      final channel = privateRpcChannel(
        port: listener.port,
        certificateBytes: certificate,
      );
      addTearDown(() async {
        await channel.terminate();
        for (final socket in sockets) {
          socket.destroy();
        }
        await incoming.cancel();
        await listener.close();
      });
      final call = WorkbenchClient(channel).ping(
        Context(),
        options: CallOptions(timeout: const Duration(seconds: 10)),
      );
      final outcome = expectLater(call, throwsA(isA<GrpcError>()));
      await hello.future.timeout(const Duration(seconds: 3));
      await channel.terminate().timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            throw TimeoutException('channel termination was not acknowledged'),
      );
      await closed.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException(
          'owned TLS socket remained open after channel termination',
        ),
      );
      expect(sockets, hasLength(1));
      await outcome;
    },
  );
}
