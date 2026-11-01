import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:grpc/grpc.dart';
import 'package:http2/transport.dart' as h2;
import 'raw_tls_byte_channel.dart';

/// BusyData's private RPC endpoint always uses its launch-owned certificate.
/// There is no clear-text, default-trust-store or failed-TLS fallback.
ClientTransportConnectorChannel privateRpcChannel({
  required int port,
  required List<int> certificateBytes,
}) {
  if (port < 1 ||
      port > 65535 ||
      certificateBytes.isEmpty ||
      certificateBytes.length > 65536) {
    throw ArgumentError('Invalid private RPC endpoint');
  }
  final credentials = ChannelCredentials.secure(
    certificates: List<int>.unmodifiable(certificateBytes),
  );
  const deadline = Duration(seconds: 30);
  return _PrivateRpcChannel(
    _PinnedLoopbackConnector(port, credentials, deadline),
    options: ChannelOptions(
      credentials: credentials,
      idleTimeout: const Duration(minutes: 10),
      connectTimeout: deadline,
    ),
  );
}

class _PrivateRpcChannel extends ClientTransportConnectorChannel {
  _PrivateRpcChannel(this._owned, {required super.options}) : super(_owned);
  final _PinnedLoopbackConnector _owned;
  @override
  Future<void> terminate() async {
    _owned.shutdown();
    await super.terminate();
  }

  @override
  Future<void> shutdown() async {
    _owned.cancelPending();
    try {
      await super.shutdown();
    } finally {
      _owned.shutdown();
    }
  }
}

class _PinnedLoopbackConnector implements ClientTransportConnector {
  _PinnedLoopbackConnector(this.port, this.credentials, this.deadline);
  final int port;
  final ChannelCredentials credentials;
  final Duration deadline;
  int _epoch = 0;
  _TlsAttempt? _attempt;

  @override
  String get authority => '127.0.0.1:$port';

  @override
  Future<h2.ClientTransportConnection> connect() async {
    _attempt?.stop();
    final attempt = _TlsAttempt(++_epoch);
    _attempt = attempt;
    final timer = Timer(deadline, attempt.stop);
    try {
      final connecting = RawSocket.startConnect(
        InternetAddress.loopbackIPv4,
        port,
      );
      unawaited(
        connecting.then<void>((task) {
          if (attempt.stopped) task.cancel();
          unawaited(
            task.socket.then<void>((socket) {
              if (attempt.stopped) unawaited(socket.close());
            }, onError: (Object _, StackTrace _) {}),
          );
        }, onError: (Object _, StackTrace _) {}),
      );
      final task = await attempt.race(connecting);
      attempt.task = task;
      final raw = await attempt.race(task.socket);
      if (attempt.stopped ||
          !identical(attempt, _attempt) ||
          attempt.epoch != _epoch) {
        await raw.close();
        throw const SocketException('Private RPC connection superseded');
      }
      attempt.raw = raw;
      raw.setOption(SocketOption.tcpNoDelay, true);
      final negotiating = RawSecureSocket.secure(
        raw,
        host: '127.0.0.1',
        context: credentials.securityContext,
        supportedProtocols: const ['h2'],
      );
      unawaited(
        negotiating.then<void>((socket) {
          if (attempt.stopped) {
            unawaited(
              socket.close().then<void>(
                (_) {},
                onError: (Object _, StackTrace _) {},
              ),
            );
          }
        }, onError: (Object _, StackTrace _) {}),
      );
      final secure = await attempt.race(negotiating);
      if (attempt.stopped ||
          !identical(attempt, _attempt) ||
          attempt.epoch != _epoch) {
        unawaited(
          secure.close().then<void>(
            (_) {},
            onError: (Object _, StackTrace _) {},
          ),
        );
        throw const SocketException('Private RPC connection superseded');
      }
      if (secure.selectedProtocol != 'h2') {
        unawaited(
          secure.close().then<void>(
            (_) {},
            onError: (Object _, StackTrace _) {},
          ),
        );
        throw const SocketException('Private RPC TLS protocol mismatch');
      }
      final bytes = RawTlsByteChannel(transport: raw, tls: secure);
      attempt.bytes = bytes;
      return GuardedClientTransportConnection.viaStreams(
        bytes.incoming,
        bytes.outgoing,
      );
    } catch (_) {
      attempt.stop();
      rethrow;
    } finally {
      timer.cancel();
    }
  }

  @override
  Future get done => _attempt?.bytes?.done ?? Future<void>.value();

  void cancelPending() {
    if (_attempt?.bytes == null) shutdown();
  }

  @override
  void shutdown() {
    _epoch++;
    _attempt?.stop();
  }
}

class _TlsAttempt {
  _TlsAttempt(this.epoch);
  final int epoch;
  final _cancel = Completer<void>();
  RawSocket? raw;
  ConnectionTask<RawSocket>? task;
  RawTlsByteChannel? bytes;
  bool stopped = false;

  Future<T> race<T>(Future<T> value) => Future.any<T>([
    value,
    _cancel.future.then<T>(
      (_) => throw const SocketException(
        'Private RPC connection cancelled or timed out',
      ),
    ),
  ]);

  void stop() {
    if (stopped) return;
    stopped = true;
    task?.cancel();
    final socket = raw;
    if (socket != null) unawaited(socket.close());
    bytes?.shutdown();
    if (!_cancel.isCompleted) _cancel.complete();
  }
}

/// Checks stream ownership without decoding headers, buffering bodies or
/// interpreting HTTP/2 flow control. The official transport owns those tasks.
///
/// RFC 9113 sections 5.1/5.1.1: lower idle identifiers become closed when a
/// higher client identifier is opened. A high-water mark therefore allows late
/// cancelled-stream headers without retaining tombstones or live-stream maps.
class PrivateRpcFrameGuard {
  PrivateRpcFrameGuard({required this.onViolation});
  final void Function() onViolation;
  final _header = Uint8List(9);
  int _headerBytes = 0, _remaining = 0, _highestOpened = 0;
  bool _fatal = false, _bound = false;
  int get bufferedHeaderBytes => _headerBytes;
  int get payloadBytesRemaining => _remaining;
  int get highestOpenedStream => _highestOpened;
  bool get failed => _fatal;

  void registerStream(int id) {
    if (id <= _highestOpened || id <= 0 || id > 0x7fffffff || id.isEven) {
      throw ArgumentError('Invalid private RPC stream ownership');
    }
    _highestOpened = id;
  }

  Stream<List<int>> bind(Stream<List<int>> input) {
    if (_bound) throw StateError('Private RPC guard already bound');
    _bound = true;
    return input.cast<List<int>>().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, output) {
          if (_fatal) return;
          var offset = 0;
          while (offset < chunk.length) {
            if (_remaining > 0) {
              final count = math.min(_remaining, chunk.length - offset);
              if (offset == 0 && count == chunk.length) {
                output.add(chunk);
              } else if (chunk is Uint8List) {
                output.add(
                  Uint8List.sublistView(chunk, offset, offset + count),
                );
              } else {
                output.add(chunk.sublist(offset, offset + count));
              }
              offset += count;
              _remaining -= count;
              continue;
            }
            while (_headerBytes < 9 && offset < chunk.length) {
              _header[_headerBytes++] = chunk[offset++];
            }
            if (_headerBytes < 9) return;
            final type = _header[3];
            final id =
                (_header[5] & 127) << 24 |
                _header[6] << 16 |
                _header[7] << 8 |
                _header[8];
            if (type == 5 ||
                type == 1 && (id == 0 || id.isEven || id > _highestOpened)) {
              _fatal = true;
              onViolation();
              return;
            }
            _remaining = _header[0] << 16 | _header[1] << 8 | _header[2];
            output.add(Uint8List.fromList(_header));
            _headerBytes = 0;
          }
        },
      ),
    );
  }
}

/// A supported public transport adapter. No upstream implementation is copied
/// or modified. The guard invokes public terminate(PROTOCOL_ERROR) before an
/// invalid frame can enter the official parser; a stream error would otherwise
/// be remapped to CONNECT_ERROR by the upstream incoming-stream error handler.
class GuardedClientTransportConnection implements h2.ClientTransportConnection {
  GuardedClientTransportConnection._(this._delegate, this._guard);
  factory GuardedClientTransportConnection.viaStreams(
    Stream<List<int>> incoming,
    StreamSink<List<int>> outgoing,
  ) {
    h2.ClientTransportConnection? connection;
    var earlyViolation = false;
    void reject() {
      final current = connection;
      if (current == null) {
        earlyViolation = true;
        return;
      }
      unawaited(
        current
            .terminate(
              h2.ErrorCode.PROTOCOL_ERROR,
              'Private RPC stream ownership violation',
            )
            .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }

    final guard = PrivateRpcFrameGuard(onViolation: reject);
    final delegate = h2.ClientTransportConnection.viaStreams(
      guard.bind(incoming),
      outgoing,
      settings: const h2.ClientSettings(allowServerPushes: false),
    );
    connection = delegate;
    if (earlyViolation) reject();
    return GuardedClientTransportConnection._(delegate, guard);
  }
  final h2.ClientTransportConnection _delegate;
  final PrivateRpcFrameGuard _guard;

  @override
  h2.ClientTransportStream makeRequest(
    List<h2.Header> headers, {
    bool endStream = false,
  }) {
    final stream = _delegate.makeRequest(headers, endStream: endStream);
    _guard.registerStream(stream.id);
    return stream;
  }

  @override
  bool get isOpen => _delegate.isOpen;
  @override
  int? get peerMaxConcurrentStreams => _delegate.peerMaxConcurrentStreams;
  @override
  set onActiveStateChanged(h2.ActiveStateHandler callback) =>
      _delegate.onActiveStateChanged = callback;
  @override
  Future<void> get onInitialPeerSettingsReceived =>
      _delegate.onInitialPeerSettingsReceived;
  @override
  Stream<int> get onPingReceived => _delegate.onPingReceived;
  @override
  Stream<void> get onFrameReceived => _delegate.onFrameReceived;
  @override
  Future ping() => _delegate.ping();
  @override
  Future finish() => _delegate.finish();
  @override
  Future terminate([int? errorCode, String? message]) =>
      _delegate.terminate(errorCode, message);
}
