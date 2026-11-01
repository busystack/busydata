import 'dart:convert';
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'confined_workspace.dart';

enum OutputPhase {
  prepared,
  preservedUnverified,
  preservedVerified,
  published,
  finished,
}

/// A selected path and the exact file reviewed there. Native publication always
/// uses a no-replace primitive. Replacement first preserves the reviewed file.
class OutputDestination {
  OutputDestination._(
    this.file,
    this._parents,
    this._original,
    this.contentHash,
  );
  final File file;
  final Map<String, _Identity> _parents;
  final _Identity? _original;
  final String? contentHash;
  bool get exists => _original != null;
  String? get entryToken => _original?.token;
  static String? currentEntryToken(File file) =>
      _native.identity(file.path)?.token;

  static Future<OutputDestination> newDestination(File selected) async {
    final reviewed = await capture(selected);
    if (reviewed.exists) {
      throw OutputCommitFailure(
        'Destination already exists; select a new file or review replacement',
      );
    }
    return reviewed;
  }

  PartialOutput capturePartial(File partial) {
    _checkParents();
    final identity = _native.identity(partial.path);
    if (identity == null ||
        !identity.regular ||
        p.normalize(p.absolute(partial.parent.path)) != file.parent.path) {
      throw OutputCommitFailure(
        'Partial output does not belong to this destination',
      );
    }
    return PartialOutput._(partial.path, identity);
  }

  Future<void> writePartial(
    File partial,
    List<int> bytes,
    PartialOutput expected,
  ) async {
    _checkParents();
    final path = partial.path;
    await Isolate.run(() => _writePartialWorker(path, bytes, expected));
  }

  Future<void> cleanupPartial(
    File partial, {
    required PartialOutput expected,
  }) async {
    if (p.normalize(p.absolute(partial.parent.path)) != file.parent.path) {
      throw OutputCommitFailure(
        'Partial cleanup belongs to another destination',
      );
    }
    _checkParents();
    final locks = _native.lockParents(_parents.keys.toList().reversed);
    try {
      _checkParents();
      final anchored = _native.entryPath(partial.path, locks.last);
      final identity = _native.identity(anchored);
      if (identity == null) return;
      if (!identity.regular) {
        throw OutputCommitFailure(
          'Partial cleanup encountered a non-file; choose recovery explicitly',
          partialPath: partial.path,
        );
      }
      if (expected.path != partial.path ||
          !identity.sameObject(expected._identity)) {
        throw OutputCommitFailure(
          'Partial file changed; automatic cleanup was refused',
          partialPath: partial.path,
        );
      }
      await File(anchored).delete();
    } catch (failure) {
      throw OutputCommitFailure(
        'Staging cleanup unresolved',
        partialPath: partial.path,
        primary: failure,
      );
    } finally {
      for (final handle in locks.reversed) {
        _native.close(handle);
      }
    }
  }

  static Future<OutputDestination> capture(File selected) async {
    final file = File(p.normalize(p.absolute(selected.path)));
    final parents = <String, _Identity>{};
    var directory = file.parent.path;
    while (true) {
      final identity = _native.identity(directory);
      if (identity == null || !identity.directory) {
        throw OutputCommitFailure(
          'Destination parent is missing, linked or not a directory',
        );
      }
      parents[directory] = identity;
      final parent = p.dirname(directory);
      if (parent == directory) break;
      directory = parent;
    }
    final original = _native.identity(file.path);
    if (original != null && !original.regular) {
      throw OutputCommitFailure(
        'Choose a regular destination file; links and reparse points are rejected',
      );
    }
    final hash = original == null ? null : await _hash(file);
    if (_native.identity(file.path) != original) {
      throw OutputCommitFailure('Destination changed while reviewing it');
    }
    final result = OutputDestination._(file, parents, original, hash);
    result._checkParents();
    return result;
  }

  void _checkParents() {
    for (final entry in _parents.entries) {
      final actual = _native.identity(entry.key);
      if (actual == null ||
          !actual.sameObject(entry.value) ||
          !actual.directory) {
        throw OutputCommitFailure(
          'Destination parent changed; choose and review it again',
        );
      }
    }
  }

  Future<void> _verifyOriginal(String path) async {
    final actual = _native.identity(path);
    if (actual != _original ||
        (actual != null && await _hash(File(path)) != contentHash)) {
      throw OutputCommitFailure(
        'Destination changed after review; no replacement was authorized',
      );
    }
  }

  /// Hook phases synchronize races/failures in tests; no production hooks come
  /// from workspaces. A failed rollback never overwrites an intervening file.
  Future<void> commit(
    File partial, {
    Future<void> Function(String)? hook,
    PartialOutput? expected,
  }) async {
    if (p.normalize(p.absolute(partial.parent.path)) != file.parent.path) {
      throw OutputCommitFailure(
        'Partial output must be on the selected destination filesystem',
      );
    }
    _checkParents();
    final locks = _native.lockParents(_parents.keys.toList().reversed);
    final backup = File(
      '${file.parent.path}/.${const Uuid().v4()}.busydata-backup',
    );
    var phase = OutputPhase.prepared;
    var preserved = false;
    _Identity? displaced;
    String anchored(String path) => _native.entryPath(path, locks.last);
    String visible(String path) {
      try {
        return p.join(_workspaceFinalPath(locks.last), p.basename(path));
      } on FileSystemException {
        return path; // Parent uncertainty remains in the primary error.
      }
    }

    late _Identity partialIdentity;
    try {
      final observedPartial = _native.identity(anchored(partial.path));
      if (observedPartial == null ||
          !observedPartial.regular ||
          (expected != null &&
              (expected.path != partial.path ||
                  !observedPartial.sameObject(expected._identity)))) {
        throw OutputCommitFailure('Partial output is missing or is a link');
      }
      partialIdentity = observedPartial;
      _checkParents();
      final paths = _parents.keys.toList().reversed.toList();
      for (var index = 0; index < paths.length; index++) {
        if (!_native
            .identityHandle(locks[index])
            .sameObject(_parents[paths[index]]!)) {
          throw OutputCommitFailure(
            'Destination parent changed while acquiring its native handle',
          );
        }
      }
      await _verifyOriginal(anchored(file.path));
      await hook?.call('before-finalization');
      _checkParents();
      if (_original != null) {
        _native.moveNew(file.path, backup.path, locks.last);
        phase = OutputPhase.preservedUnverified;
        preserved = true;
        // Entry ownership is distinct from approval and survives failed hashing.
        displaced = _native.identity(anchored(backup.path));
        if (displaced == null) {
          throw OutputCommitFailure('Displaced entry disappeared');
        }
        await hook?.call('after-preserve');
        await hook?.call('before-verify');
        await _verifyOriginal(anchored(backup.path));
        phase = OutputPhase.preservedVerified;
        _checkParents();
      }
      if (_native.identity(anchored(partial.path)) != partialIdentity) {
        throw OutputCommitFailure('Partial output changed before publication');
      }
      await hook?.call('before-publish');
      _checkParents();
      if (_native.identity(anchored(partial.path)) != partialIdentity) {
        throw OutputCommitFailure('Partial output changed before publication');
      }
      if (preserved && _native.identity(anchored(backup.path)) != displaced) {
        throw OutputCommitFailure('Recovery entry changed before publication');
      }
      _native.moveNew(partial.path, file.path, locks.last);
      phase = OutputPhase.published;
      await hook?.call('after-publish');
      _checkParents();
      if (_native.identity(anchored(file.path)) != partialIdentity) {
        throw OutputCommitFailure('Published output changed before completion');
      }
      if (preserved) {
        await hook?.call('before-backup-cleanup');
        _checkParents();
        if (_native.identity(anchored(file.path)) != partialIdentity ||
            _native.identity(anchored(backup.path)) != displaced) {
          throw OutputCommitFailure(
            'Output or recovery changed before cleanup',
          );
        }
        await File(anchored(backup.path)).delete();
        preserved = false;
      }
      phase = OutputPhase.finished;
    } catch (primary) {
      if (phase == OutputPhase.published || phase == OutputPhase.finished) {
        throw OutputCommitFailure(
          'Output was published; completion or recovery cleanup remains unresolved. Review before any retry',
          recoveryPath: preserved ? visible(backup.path) : null,
          published: true,
          primary: primary,
        );
      }
      if (preserved) {
        // Restore only into an absent name. If another actor owns that name,
        // retain the original instead of deleting or replacing either file.
        try {
          await hook?.call('before-restore');
          final actual = _native.identity(anchored(backup.path));
          if (displaced == null ||
              actual == null ||
              !actual.sameObject(displaced)) {
            throw OutputCommitFailure(
              'Recovery entry ownership is unknown; automatic restoration refused',
            );
          }
          _native.moveNew(backup.path, file.path, locks.last);
          preserved = false;
        } catch (restore) {
          throw OutputCommitFailure(
            'Output was not published; displaced entry requires recovery',
            recoveryPath: visible(backup.path),
            partialPath: visible(partial.path),
            primary: primary,
            cleanup: restore,
          );
        }
      }
      throw OutputCommitFailure(
        'Output was not published',
        partialPath: visible(partial.path),
        primary: primary,
      );
    } finally {
      for (final handle in locks.reversed) {
        _native.close(handle);
      }
    }
  }

  static Future<String> _hash(File file) {
    final path = file.path;
    return Isolate.run(() => _hashOutputWorker(path));
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

String _hashOutputWorker(String path) {
  final name = Platform.isWindows
      ? _native.wide(path).cast<Uint8>()
      : _native.string(path);
  var handle = -1;
  Pointer<Uint8> buffer = nullptr;
  try {
    handle = Platform.isWindows
        ? _native.library.lookupFunction<_CreateN, _CreateD>('CreateFileW')(
            name.cast<Uint16>(),
            0x80000000,
            1,
            nullptr,
            3,
            0x02200000,
            0,
          )
        : _native.library.lookupFunction<_OpenN, _OpenD>('open')(
            name,
            0xa0800,
            0,
          );
    if (handle == -1) {
      throw OutputCommitFailure(
        'Cannot open reviewed output without following links (OS error ${_native.error()})',
      );
    }
    final identity = _native.identityHandle(handle);
    if (!identity.regular || identity.size > 134217728) {
      throw OutputCommitFailure(
        'Review requires an ordinary file at most 128MiB',
      );
    }
    buffer = _native.allocate(65536);
    var total = 0;
    final result = _DigestSink(),
        digest = sha256.startChunkedConversion(result);
    while (true) {
      final count = _workspaceRead(handle, buffer, 65536);
      if (count == 0) break;
      total += count;
      if (total > 134217728) {
        throw OutputCommitFailure('Destination grew beyond its review budget');
      }
      digest.add(buffer.asTypedList(count));
    }
    digest.close();
    if (_native.identityHandle(handle) != identity ||
        _native.identity(path) != identity) {
      throw OutputCommitFailure('Destination changed during review');
    }
    return result.value.toString();
  } finally {
    if (buffer != nullptr) _native.free(buffer);
    if (handle != -1) _native.close(handle);
    _native.free(name);
  }
}

class OutputCommitFailure extends FileSystemException {
  OutputCommitFailure(
    String message, {
    this.recoveryPath,
    this.partialPath,
    this.primary,
    this.cleanup,
    this.published = false,
  }) : super(message, recoveryPath ?? partialPath ?? '');
  final String? recoveryPath, partialPath;
  final Object? primary, cleanup;
  final bool published;
  @override
  String toString() =>
      '$message${recoveryPath == null ? '' : '; recovery: $recoveryPath'}'
      '${partialPath == null ? '' : '; staging: $partialPath'}'
      '${primary == null ? '' : '; $primary'}${cleanup == null ? '' : '; restoration/cleanup: $cleanup'}';
}

class PartialOutput {
  const PartialOutput._(this.path, this._identity);
  final String path;
  final _Identity _identity;
}

void _writePartialWorker(String path, List<int> bytes, PartialOutput expected) {
  final buffer = _native.allocate(65536);
  var handle = -1;
  try {
    handle = _native.openPartial(path);
    final opened = _native.identityHandle(handle);
    if (!opened.regular ||
        !opened.sameObject(expected._identity) ||
        expected.path != path) {
      throw OutputCommitFailure('Partial output changed before writing');
    }
    _native.restrictHandle(handle);
    for (var offset = 0; offset < bytes.length;) {
      final count = (bytes.length - offset).clamp(0, 65536);
      buffer.asTypedList(count).setRange(0, count, bytes, offset);
      _native.write(handle, buffer, count);
      offset += count;
    }
    _native.flush(handle);
  } finally {
    _native.free(buffer);
    if (handle != -1) _native.close(handle);
  }
}

class _Identity {
  const _Identity(this.object, this.kind, this.size, this.modified);
  final String object, modified;
  final int kind, size;
  bool get directory => kind == 2;
  bool get regular => kind == 1;
  String get token => '$object:$kind';
  bool sameObject(_Identity other) =>
      object == other.object && kind == other.kind;
  @override
  bool operator ==(Object other) =>
      other is _Identity &&
      sameObject(other) &&
      size == other.size &&
      modified == other.modified;
  @override
  int get hashCode => Object.hash(object, kind, size, modified);
}

final _native = _NativeOutput();

typedef _AllocateN = Pointer<Void> Function(IntPtr);
typedef _AllocateD = Pointer<Void> Function(int);
typedef _FreeN = Void Function(Pointer<Void>);
typedef _FreeD = void Function(Pointer<Void>);
typedef _StatN =
    Int32 Function(Int32, Pointer<Uint8>, Int32, Uint32, Pointer<Uint8>);
typedef _StatD = int Function(int, Pointer<Uint8>, int, int, Pointer<Uint8>);
typedef _OpenN = Int32 Function(Pointer<Uint8>, Int32, Uint32);
typedef _OpenD = int Function(Pointer<Uint8>, int, int);
typedef _CloseN = Int32 Function(Int32);
typedef _CloseD = int Function(int);
typedef _MoveN =
    Int32 Function(Int32, Pointer<Uint8>, Int32, Pointer<Uint8>, Uint32);
typedef _MoveD = int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int);
typedef _ErrnoN = Pointer<Int32> Function();
typedef _ErrnoD = Pointer<Int32> Function();
typedef _LocalAllocateN = Pointer<Void> Function(Uint32, IntPtr);
typedef _LocalAllocateD = Pointer<Void> Function(int, int);
typedef _LocalFreeN = Pointer<Void> Function(Pointer<Void>);
typedef _LocalFreeD = Pointer<Void> Function(Pointer<Void>);
typedef _CreateN =
    IntPtr Function(
      Pointer<Uint16>,
      Uint32,
      Uint32,
      Pointer<Void>,
      Uint32,
      Uint32,
      IntPtr,
    );
typedef _CreateD =
    int Function(Pointer<Uint16>, int, int, Pointer<Void>, int, int, int);
typedef _InfoN = Int32 Function(IntPtr, Pointer<Uint8>);
typedef _InfoD = int Function(int, Pointer<Uint8>);
typedef _WinCloseN = Int32 Function(IntPtr);
typedef _WinCloseD = int Function(int);
typedef _WinMoveN = Int32 Function(Pointer<Uint16>, Pointer<Uint16>, Uint32);
typedef _WinMoveD = int Function(Pointer<Uint16>, Pointer<Uint16>, int);
typedef _ErrorN = Uint32 Function();
typedef _ErrorD = int Function();
typedef _WriteN = IntPtr Function(Int32, Pointer<Uint8>, IntPtr);
typedef _WriteD = int Function(int, Pointer<Uint8>, int);
typedef _WinWriteN =
    Int32 Function(
      IntPtr,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Pointer<Void>,
    );
typedef _WinWriteD =
    int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>);

class _NativeOutput {
  _NativeOutput()
    : library = Platform.isWindows
          ? DynamicLibrary.open('kernel32.dll')
          : DynamicLibrary.process();
  final DynamicLibrary library;
  Pointer<Uint8> allocate(int size) {
    final memory = Platform.isWindows
        ? library.lookupFunction<_LocalAllocateN, _LocalAllocateD>(
            'LocalAlloc',
          )(0, size)
        : library.lookupFunction<_AllocateN, _AllocateD>('malloc')(size);
    if (memory == nullptr) {
      throw OutputCommitFailure(
        'Output filesystem inspection allocation failed',
      );
    }
    return memory.cast<Uint8>();
  }

  void free(Pointer<Uint8> memory) {
    if (Platform.isWindows) {
      library.lookupFunction<_LocalFreeN, _LocalFreeD>('LocalFree')(
        memory.cast<Void>(),
      );
    } else {
      library.lookupFunction<_FreeN, _FreeD>('free')(memory.cast<Void>());
    }
  }

  Pointer<Uint8> string(String path) {
    final bytes = utf8.encode(path), result = allocate(bytes.length + 1);
    result.asTypedList(bytes.length + 1).setAll(0, [...bytes, 0]);
    return result;
  }

  Pointer<Uint16> wide(String path) {
    var absolute = p.normalize(p.absolute(path));
    if (!absolute.startsWith(r'\\?\')) {
      absolute = absolute.startsWith(r'\\')
          ? '\\\\?\\UNC\\${absolute.substring(2)}'
          : '\\\\?\\$absolute';
    }
    final units = absolute.codeUnits,
        result = allocate((units.length + 1) * 2).cast<Uint16>();
    result.asTypedList(units.length + 1).setAll(0, [...units, 0]);
    return result;
  }

  int error() => Platform.isWindows
      ? library.lookupFunction<_ErrorN, _ErrorD>('GetLastError')()
      : library.lookupFunction<_ErrnoN, _ErrnoD>('__errno_location')().value;

  int openPartial(String path) {
    final name = Platform.isWindows ? wide(path).cast<Uint8>() : string(path);
    try {
      final handle = Platform.isWindows
          ? library.lookupFunction<_CreateN, _CreateD>('CreateFileW')(
              name.cast<Uint16>(),
              0x40000080,
              0,
              nullptr,
              3,
              0x00200000,
              0,
            )
          : library.lookupFunction<_OpenN, _OpenD>('open')(name, 0xa0001, 0);
      if (handle == -1) {
        throw OutputCommitFailure(
          'Cannot open private partial output (OS error ${error()})',
        );
      }
      return handle;
    } finally {
      free(name);
    }
  }

  void restrictHandle(int handle) {
    if (Platform.isLinux &&
        library.lookupFunction<
              Int32 Function(Int32, Uint32),
              int Function(int, int)
            >('fchmod')(handle, 0x180) !=
            0) {
      throw OutputCommitFailure(
        'Cannot restrict private partial output (Linux error ${error()})',
      );
    }
  }

  void flush(int handle) {
    final status = Platform.isWindows
        ? library.lookupFunction<_WinCloseN, _WinCloseD>('FlushFileBuffers')(
            handle,
          )
        : library.lookupFunction<_CloseN, _CloseD>('fsync')(handle);
    if (Platform.isWindows ? status == 0 : status != 0) {
      throw OutputCommitFailure(
        'Cannot flush private partial output (OS error ${error()})',
      );
    }
  }

  void write(int handle, Pointer<Uint8> bytes, int count) {
    var written = 0;
    final receipt = Platform.isWindows
        ? allocate(4).cast<Uint32>()
        : nullptr.cast<Uint32>();
    try {
      while (written < count) {
        int size;
        if (Platform.isWindows) {
          if (library.lookupFunction<_WinWriteN, _WinWriteD>('WriteFile')(
                handle,
                bytes + written,
                count - written,
                receipt,
                nullptr,
              ) ==
              0) {
            throw OutputCommitFailure(
              'Cannot write private partial output (Windows error ${error()})',
            );
          }
          size = receipt.value;
        } else {
          size = library.lookupFunction<_WriteN, _WriteD>('write')(
            handle,
            bytes + written,
            count - written,
          );
          if (size < 0) {
            if (error() == 4) continue;
            throw OutputCommitFailure(
              'Cannot write private partial output (Linux error ${error()})',
            );
          }
        }
        if (size <= 0 || size > count - written) {
          throw OutputCommitFailure('Partial output write made no progress');
        }
        written += size;
      }
    } finally {
      if (Platform.isWindows) free(receipt.cast<Uint8>());
    }
  }

  void close(int handle) {
    if (Platform.isWindows) {
      library.lookupFunction<_WinCloseN, _WinCloseD>('CloseHandle')(handle);
    } else {
      library.lookupFunction<_CloseN, _CloseD>('close')(handle);
    }
  }

  _Identity identityHandle(int handle) {
    final information = allocate(Platform.isWindows ? 52 : 256);
    Pointer<Uint8> empty = nullptr;
    try {
      if (!Platform.isWindows) empty = string('');
      if (Platform.isWindows) {
        if (library.lookupFunction<_InfoN, _InfoD>(
              'GetFileInformationByHandle',
            )(handle, information) ==
            0) {
          throw OutputCommitFailure(
            'Cannot inspect held output parent (Windows error ${error()})',
          );
        }
        return _windowsIdentity(information);
      }
      if (library.lookupFunction<_StatN, _StatD>('statx')(
            handle,
            empty,
            0x1100,
            0x7ff,
            information,
          ) !=
          0) {
        throw OutputCommitFailure(
          'Cannot inspect held output parent (Linux error ${error()})',
        );
      }
      return _linuxIdentity(information);
    } finally {
      if (!Platform.isWindows) free(empty);
      free(information);
    }
  }

  _Identity _windowsIdentity(Pointer<Uint8> information) {
    final fields = information.cast<Uint32>().asTypedList(13),
        attributes = fields[0];
    return _Identity(
      '${fields[7]}:${fields[11]}:${fields[12]}',
      attributes & 0x400 != 0 ? 3 : (attributes & 0x10 != 0 ? 2 : 1),
      (fields[8] << 32) | fields[9],
      '${fields[5]}:${fields[6]}',
    );
  }

  _Identity _linuxIdentity(Pointer<Uint8> information) {
    final bytes = ByteData.sublistView(information.asTypedList(256));
    if (bytes.getUint32(0, Endian.host) & 0x341 != 0x341) {
      throw OutputCommitFailure(
        'Filesystem cannot provide reviewed output identity',
      );
    }
    final mode = bytes.getUint16(28, Endian.host) & 0xf000;
    return _Identity(
      '${bytes.getUint32(136, Endian.host)}:${bytes.getUint32(140, Endian.host)}:${bytes.getUint64(32, Endian.host)}',
      mode == 0x4000 ? 2 : (mode == 0x8000 ? 1 : (mode == 0xa000 ? 3 : 4)),
      bytes.getUint64(40, Endian.host),
      '${bytes.getInt64(112, Endian.host)}:${bytes.getUint32(120, Endian.host)}',
    );
  }

  _Identity? identity(String path) {
    if (!Platform.isLinux && !Platform.isWindows) {
      throw UnsupportedError('Desktop output supports Linux and Windows');
    }
    if (Platform.isWindows) {
      final name = wide(path);
      Pointer<Uint8> information = nullptr;
      var handle = -1;
      try {
        information = allocate(52);
        handle = library.lookupFunction<_CreateN, _CreateD>('CreateFileW')(
          name,
          0x80,
          3,
          nullptr,
          3,
          0x02200000,
          0,
        );
        if (handle == -1) {
          final code = error();
          if (code == 2 || code == 3) return null;
          throw OutputCommitFailure(
            'Cannot inspect selected output (Windows error $code)',
          );
        }
        if (library.lookupFunction<_InfoN, _InfoD>(
              'GetFileInformationByHandle',
            )(handle, information) ==
            0) {
          throw OutputCommitFailure(
            'Cannot inspect selected output (Windows error ${error()})',
          );
        }
        return _windowsIdentity(information);
      } finally {
        if (handle != -1) close(handle);
        free(name.cast<Uint8>());
        free(information);
      }
    }
    final name = string(path);
    Pointer<Uint8> information = nullptr;
    try {
      information = allocate(256);
      if (library.lookupFunction<_StatN, _StatD>('statx')(
            -100,
            name,
            0x100,
            0x7ff,
            information,
          ) !=
          0) {
        final code = error();
        if (code == 2) return null;
        throw OutputCommitFailure(
          'Cannot inspect selected output (Linux error $code)',
        );
      }
      return _linuxIdentity(information);
    } finally {
      free(name);
      free(information);
    }
  }

  List<int> lockParents(Iterable<String> paths) {
    final handles = <int>[];
    try {
      for (final path in paths) {
        final name = Platform.isWindows
            ? wide(path).cast<Uint8>()
            : string(path);
        try {
          final handle = Platform.isWindows
              ? library.lookupFunction<_CreateN, _CreateD>('CreateFileW')(
                  name.cast<Uint16>(),
                  0x80,
                  3,
                  nullptr,
                  3,
                  0x02200000,
                  0,
                )
              : library.lookupFunction<_OpenN, _OpenD>('open')(
                  name,
                  0xb0000,
                  0,
                );
          if (handle == -1) {
            throw OutputCommitFailure(
              'Cannot hold the destination parent (OS error ${error()})',
            );
          }
          handles.add(handle);
        } finally {
          free(name);
        }
      }
      return handles;
    } catch (_) {
      for (final handle in handles.reversed) {
        close(handle);
      }
      rethrow;
    }
  }

  void moveNew(String source, String destination, int directoryHandle) {
    if (Platform.isWindows) {
      final from = wide(source);
      Pointer<Uint16> to = nullptr;
      try {
        to = wide(destination);
        if (library.lookupFunction<_WinMoveN, _WinMoveD>('MoveFileExW')(
              from,
              to,
              8,
            ) ==
            0) {
          throw OutputCommitFailure(
            'Safe output commit failed; the destination was not overwritten (Windows error ${error()})',
          );
        }
      } finally {
        free(from.cast<Uint8>());
        free(to.cast<Uint8>());
      }
    } else {
      final from = string(p.basename(source));
      Pointer<Uint8> to = nullptr;
      try {
        to = string(p.basename(destination));
        if (library.lookupFunction<_MoveN, _MoveD>('renameat2')(
              directoryHandle,
              from,
              directoryHandle,
              to,
              1,
            ) !=
            0) {
          throw OutputCommitFailure(
            'Safe output commit failed; no unsafe fallback was attempted (Linux error ${error()})',
          );
        }
      } finally {
        free(from);
        free(to);
      }
    }
  }

  String entryPath(String path, int directoryHandle) => Platform.isLinux
      ? '/proc/self/fd/$directoryHandle/${p.basename(path)}'
      : path;
}
