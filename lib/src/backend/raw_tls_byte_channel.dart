import 'dart:async';
import 'dart:io';

/// A bounded public dart:io adapter retaining the physical socket's close handle
/// through TLS negotiation. HTTP/2 remains entirely owned by the official
/// transport; this class supplies only byte reads and a normal public IOSink.
class RawTlsByteChannel {
  RawTlsByteChannel({
    required RawSocket transport,
    required RawSecureSocket tls,
  }) : _transport = transport,
       _tls = tls {
    _input = StreamController<List<int>>(
      onListen: () {
        _listened = true;
        if (!_stopped) _tls.readEventsEnabled = true;
      },
      onPause: () {
        if (!_stopped) _tls.readEventsEnabled = false;
      },
      onResume: () {
        if (!_stopped) _tls.readEventsEnabled = true;
      },
      onCancel: () {
        if (!_stopped) _tls.readEventsEnabled = false;
      },
    );
    _tls.readEventsEnabled = false;
    _tls.writeEventsEnabled = false;
    _events = _tls.listen(_event, onError: _fail, onDone: _peerClosed);
    _consumer = _TlsConsumer(this);
    _sink = IOSink(_consumer);
    outgoing = _BoundedTlsSink(this, _sink);
    unawaited(
      _sink.done.then<void>(
        (_) {
          if (!_done.isCompleted) _done.complete();
        },
        onError: (Object error, StackTrace stack) {
          _fail(error, stack);
          if (!_done.isCompleted) _done.complete();
        },
      ),
    );
  }
  static const maxBufferedOutputBytes = 32 * 1024 * 1024;
  final RawSocket _transport;
  final RawSecureSocket _tls;
  late final StreamController<List<int>> _input;
  late final StreamSubscription<RawSocketEvent> _events;
  late final IOSink _sink;
  late final _TlsConsumer _consumer;
  Future<void>? _boundWrite;
  late final StreamSink<List<int>> outgoing;
  final _done = Completer<void>();
  Completer<void>? _writable;
  var _queued = 0;
  Object? _terminalError;
  bool _stopped = false, _listened = false, _closingOutput = false;
  Stream<List<int>> get incoming => _input.stream;
  Future<void> get done => _done.future;
  int get bufferedOutputBytes => _queued;

  /// Real I/O/admission failure remains visible on incoming and in this state.
  /// A normal owned shutdown has no terminal error. Writer completion alone is
  /// never an acknowledgement of an RPC or delivery of buffered bytes.
  Object? get terminalError => _terminalError;

  void _event(RawSocketEvent event) {
    if (_stopped) return;
    try {
      if (event == RawSocketEvent.read) {
        final bytes = _tls.read(65536);
        if (bytes != null && !_input.isClosed) _input.add(bytes);
      } else if (event == RawSocketEvent.write) {
        _tls.writeEventsEnabled = false;
        final ready = _writable;
        _writable = null;
        if (ready != null && !ready.isCompleted) ready.complete();
      } else if (event == RawSocketEvent.readClosed) {
        _peerClosed();
      }
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _peerClosed() {
    if (_stopped) return;
    if (_closingOutput) {
      _endInput();
      return;
    }
    if (_writable != null || _queued != 0) {
      _fail(
        const SocketException('Private RPC peer closed while writing'),
        StackTrace.current,
      );
    } else {
      _endInput();
      shutdown();
    }
  }

  Future<void> _closeOutput() async {
    if (_stopped) return;
    _closingOutput = true;
    try {
      await _tls.close().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          unawaited(_transport.close());
          throw const SocketException('Private RPC transport close deadline');
        },
      );
    } catch (error, stack) {
      _fail(error, stack);
    } finally {
      shutdown();
    }
  }

  void _endInput() {
    if (!_input.isClosed) unawaited(_input.close());
  }

  void _admit(List<int> data) {
    if (_stopped) {
      throw const SocketException('Private RPC transport is closed');
    }
    if (data.length > maxBufferedOutputBytes - _queued) {
      const error = SocketException('Private RPC transport output limit');
      _fail(error, StackTrace.current);
      throw error;
    }
    _queued += data.length;
  }

  Future<void> _write(List<int> data) async {
    try {
      var offset = 0;
      while (offset < data.length) {
        if (_stopped) {
          throw const SocketException('Private RPC transport is closed');
        }
        offset += _tls.write(data, offset, data.length - offset);
        if (offset == data.length) break;
        final ready = Completer<void>();
        _writable = ready;
        _tls.writeEventsEnabled = true;
        await ready.future;
      }
    } finally {
      _queued -= data.length;
      if (_queued < 0) _queued = 0;
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_stopped) return;
    _terminalError = error;
    if (!_input.isClosed) _input.addError(error, stack);
    shutdown();
  }

  Future<void> _closeSink() async {
    final binding = _boundWrite;
    if (binding != null) await binding;
    try {
      await _sink.close();
    } catch (_) {
      /* The owned read error already reports the transport failure. */
    }
  }

  void shutdown() {
    if (_stopped) return;
    _stopped = true;
    _queued = 0;
    // Closing the retained original RawSocket also aborts a TLS filter whose
    // handshake Future has not completed. No detached Socket handle is used.
    unawaited(_transport.close());
    final ready = _writable;
    _writable = null;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(
        const SocketException('Private RPC transport is closed'),
      );
    }
    _consumer.abort();
    unawaited(_events.cancel());
    unawaited(
      _tls.close().then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    unawaited(_closeSink());
    // A never-listened controller must not retain queued bytes after shutdown.
    if (!_listened) {
      _input.stream.listen((_) {}, onError: (Object _) {});
    }
    _endInput();
    if (!_done.isCompleted) _done.complete();
  }
}

class _TlsConsumer implements StreamConsumer<List<int>> {
  _TlsConsumer(this.owner);
  final RawTlsByteChannel owner;
  final _cancel = Completer<void>();
  StreamIterator<List<int>>? _iterator;
  @override
  Future<void> addStream(Stream<List<int>> source) {
    if (owner._stopped) return Future<void>.value();
    final iterator = StreamIterator<List<int>>(source);
    _iterator = iterator;
    Future<void> consume() async {
      try {
        while (await iterator.moveNext()) {
          await owner._write(iterator.current);
        }
      } catch (error, stack) {
        // Real failures terminate the incoming transport before the write pipe
        // is released. Official http2 observes that terminal error; propagating
        // it through its write-pipe completion also creates an uncaught
        // derivative Future (http2 3.1.0 connection.dart:189).
        if (!owner._stopped) owner._fail(error, stack);
      }
    }

    return Future.any<void>([consume(), _cancel.future]).whenComplete(() {
      if (identical(_iterator, iterator)) _iterator = null;
      unawaited(
        iterator.cancel().then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    });
  }

  void abort() {
    if (!_cancel.isCompleted) _cancel.complete();
    final iterator = _iterator;
    _iterator = null;
    if (iterator != null) {
      unawaited(
        iterator.cancel().then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
  }

  @override
  Future<void> close() => owner._closeOutput();
}

class _BoundedTlsSink implements StreamSink<List<int>> {
  _BoundedTlsSink(this.owner, this.sink);
  final RawTlsByteChannel owner;
  final IOSink sink;
  @override
  void add(List<int> data) {
    owner._admit(data);
    try {
      sink.add(data);
    } catch (_) {
      owner._queued -= data.length;
      rethrow;
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      owner._fail(error, stackTrace ?? StackTrace.current);
  @override
  Future<void> addStream(Stream<List<int>> stream) {
    final result = sink.addStream(
      stream.map((data) {
        owner._admit(data);
        return data;
      }),
    );
    owner._boundWrite = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        owner._fail(error, stack);
      },
    );
    return result;
  }

  @override
  Future close() => sink.close();
  @override
  Future get done => sink.done;
}
