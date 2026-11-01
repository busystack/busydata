import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:http2/transport.dart' as h2;
import 'package:busydata/src/backend/private_rpc_transport.dart';
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart';

List<int> frame(int type, int flags, int id, List<int> data) => [
  data.length >> 16,
  (data.length >> 8) & 255,
  data.length & 255,
  type,
  flags,
  (id >> 24) & 127,
  (id >> 16) & 255,
  (id >> 8) & 255,
  id & 255,
  ...data,
];
List<int> literal(String name, String value) => [
  0,
  name.length,
  ...ascii.encode(name),
  value.length,
  ...ascii.encode(value),
];
void main() {
  for (final unsolicited in [false, true]) {
    test(
      unsolicited
          ? 'unsolicited server stream is still rejected'
          : 'late metadata headers after cancellation preserve another owned RPC',
      () async {
        final listener = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final channel = ClientTransportConnectorChannel(
          _FixtureConnector(listener.port),
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        );
        final client = WorkbenchClient(channel);
        final firstArrived = Completer<void>(), cancelled = Completer<void>();
        final sockets = <Socket>[];
        final subscription = listener.listen((socket) {
          sockets.add(socket);
          var bytes = <int>[], preface = false;
          socket.add(frame(4, 0, 0, []));
          socket.listen((chunk) {
            bytes.addAll(chunk);
            if (bytes.length > 262144) throw StateError('Fixture byte budget');
            if (!preface) {
              if (bytes.length < 24) return;
              expect(
                ascii.decode(bytes.take(24).toList()),
                'PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n',
              );
              bytes.removeRange(0, 24);
              preface = true;
            }
            while (bytes.length >= 9) {
              final length = bytes[0] << 16 | bytes[1] << 8 | bytes[2];
              if (bytes.length < length + 9) return;
              final type = bytes[3], flags = bytes[4];
              final id =
                  (bytes[5] & 127) << 24 |
                  bytes[6] << 16 |
                  bytes[7] << 8 |
                  bytes[8];
              bytes.removeRange(0, length + 9);
              if (type == 4 && flags == 0) socket.add(frame(4, 1, 0, []));
              if (type == 0 &&
                  flags & 1 != 0 &&
                  id == 1 &&
                  !firstArrived.isCompleted) {
                firstArrived.complete();
              }
              if (type == 3 && id == 1 && !cancelled.isCompleted) {
                cancelled.complete();
              }
              if (type == 0 && flags & 1 != 0 && id == 3) {
                // The server may have sent these headers before seeing CANCEL.
                socket.add(frame(1, 4, unsolicited ? 99 : 1, [0x88]));
                socket.add(
                  frame(1, 4, 3, [
                    0x88,
                    ...literal('content-type', 'application/grpc'),
                  ]),
                );
                final payload = SchemaObjects(
                  complete: true,
                  instanceId: 'wire',
                ).writeToBuffer();
                socket.add(
                  frame(0, 0, 3, [
                    0,
                    payload.length >> 24,
                    (payload.length >> 16) & 255,
                    (payload.length >> 8) & 255,
                    payload.length & 255,
                    ...payload,
                  ]),
                );
                socket.add(frame(1, 5, 3, literal('grpc-status', '0')));
              }
            }
          }, onError: (Object _) {});
        });
        addTearDown(() async {
          await channel.terminate();
          for (final socket in sockets) {
            socket.destroy();
          }
          await subscription.cancel();
          await listener.close();
        });
        final first = client.explore(ExploreRequest());
        final firstOutcome = expectLater(
          first,
          throwsA(
            isA<GrpcError>().having(
              (e) => e.code,
              'cancelled',
              StatusCode.cancelled,
            ),
          ),
        );
        await firstArrived.future.timeout(const Duration(seconds: 5));
        await first.cancel();
        await firstOutcome;
        await cancelled.future.timeout(const Duration(seconds: 5));
        final second = client
            .explore(ExploreRequest())
            .timeout(const Duration(seconds: 5));
        if (unsolicited) {
          await expectLater(
            second,
            throwsA(
              isA<GrpcError>().having(
                (e) => e.message,
                'protocol rejection',
                contains('errorCode: 1'),
              ),
            ),
          );
        } else {
          final reply = await second;
          expect(reply.complete, isTrue);
          expect(reply.instanceId, 'wire');
        }
      },
    );
  }
}

// Clear-text belongs only to this disposable wire fixture. Production uses
// privateRpcChannel's mandatory launch-certificate TLS connector.
class _FixtureConnector implements ClientTransportConnector {
  _FixtureConnector(this.port);
  final int port;
  Socket? socket;
  @override
  String get authority => '127.0.0.1:$port';
  @override
  Future<h2.ClientTransportConnection> connect() async {
    final connected = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket = connected;
    return GuardedClientTransportConnection.viaStreams(connected, connected);
  }

  @override
  Future get done => socket?.done ?? Future<void>.value();
  @override
  void shutdown() => socket?.destroy();
}
