part of 'output_commit.dart';

/// Shared lexical policy for portable save and load. Never canonicalize a final
/// link into a file. Native resolution below is authoritative, not this check.
List<String> portableSegments(String reference) {
  if (reference.isEmpty ||
      reference.length > 4096 ||
      reference.contains('\u0000') ||
      reference.contains('\\') ||
      reference.contains(':') ||
      p.posix.isAbsolute(reference)) {
    throw const FormatException(
      'Workspace document paths must be normalized portable relative paths',
    );
  }
  final parts = reference.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
      p.posix.normalize(reference) != reference) {
    throw const FormatException(
      'Workspace document paths must stay beneath the workspace directory',
    );
  }
  return parts;
}

class WorkspaceReadCancelled implements Exception {
  const WorkspaceReadCancelled();
  @override
  String toString() => 'Workspace loading cancelled';
}

class WorkspaceReadControl {
  bool cancelled = false;
  void cancel() {
    cancelled = true;
  }
}

class NativeReadLimit implements Exception {
  const NativeReadLimit(this.limit);
  final int limit;
}

typedef WorkspaceReadHook =
    Future<void> Function(String phase, String reference);

/// Runs the entire root/manifest/document lifetime on a worker. Boundary events
/// carry only names/identities, never SQL. Cancellation is acknowledged between
/// bounded reads; killing an isolate with owned native handles is not used.
Future<T> confinedWorkspaceWorker<T>(
  Future<T> Function(SendPort events) work, {
  WorkspaceReadHook? hook,
  WorkspaceReadControl? control,
}) async {
  final events = ReceivePort();
  final subscription = events.listen((dynamic message) async {
    final event = message as List;
    final reply = event[2] as SendPort;
    try {
      if (control?.cancelled ?? false) throw const WorkspaceReadCancelled();
      await hook?.call(event[0] as String, event[1] as String);
      if (control?.cancelled ?? false) throw const WorkspaceReadCancelled();
      reply.send(null);
    } catch (error) {
      reply.send(error);
    }
  });
  final port = events.sendPort;
  try {
    return await Isolate.run(() => work(port));
  } finally {
    await subscription.cancel();
    events.close();
  }
}

class ConfinedRead {
  const ConfinedRead(this.bytes, this.entryToken);
  final Uint8List bytes;
  final String entryToken;
}

/// Owned only by the worker. No validated pathname is returned for content I/O.
class NativeWorkspaceRoot {
  NativeWorkspaceRoot._(this.path, this._handles, this._identity, this.events);
  final String path;
  final List<int> _handles;
  final _Identity _identity;
  final SendPort events;
  int get _root => _handles.last;

  static Future<NativeWorkspaceRoot> open(
    String selected,
    SendPort events,
  ) async {
    final path = p.normalize(p.absolute(selected));
    // The explicitly selected root may itself have an ancestor alias. Acquire
    // its resolved directory, then use only that object as authority.
    final physical = Directory(path).resolveSymbolicLinksSync();
    final handles = <int>[];
    try {
      if (Platform.isWindows) {
        if (sizeOf<IntPtr>() != 8) {
          throw const FileSystemException(
            'Workspace reading requires Windows x64',
          );
        }
        var current = p.rootPrefix(physical);
        handles.add(_workspaceWindowsRoot(current));
        for (final component in p.split(p.relative(physical, from: current))) {
          if (component == '.') continue;
          handles.add(
            _workspaceWindowsOpen(handles.last, component, directory: true),
          );
        }
      } else if (Platform.isLinux) {
        final name = _native.string(physical);
        try {
          final handle = _native.library.lookupFunction<_OpenN, _OpenD>('open')(
            name,
            0x2b0000,
            0,
          );
          if (handle < 0) {
            throw FileSystemException(
              'Cannot acquire workspace root',
              path,
              OSError('', _native.error()),
            );
          }
          handles.add(handle);
        } finally {
          _native.free(name);
        }
      } else {
        throw const FileSystemException(
          'Confined workspace reading supports Linux and Windows',
        );
      }
      final identity = _native.identityHandle(handles.last);
      if (!identity.directory) {
        throw const FormatException(
          'Workspace root must be an ordinary directory',
        );
      }
      final result = NativeWorkspaceRoot._(path, handles, identity, events);
      await result.boundary('root-acquired', '');
      return result;
    } catch (_) {
      for (final handle in handles.reversed) {
        _native.close(handle);
      }
      rethrow;
    }
  }

  Future<void> boundary(String phase, String reference) async {
    final reply = ReceivePort();
    try {
      events.send([phase, reference, reply.sendPort]);
      final failure = await reply.first;
      if (failure != null) throw failure;
    } finally {
      reply.close();
    }
  }

  String _candidate(String reference) {
    final parts = portableSegments(reference);
    final physicalRoot = _workspaceFinalPath(_root);
    final parentReference = parts
        .take(parts.length - 1)
        .join(Platform.pathSeparator);
    // This resolution only produces a candidate relative parent (including
    // existing absolute in-root aliases). No bytes are read through this path.
    final parent = parentReference.isEmpty
        ? physicalRoot
        : Directory(
            Platform.isLinux
                ? '/proc/self/fd/$_root/$parentReference'
                : p.join(physicalRoot, parentReference),
          ).resolveSymbolicLinksSync();
    if (!p.equals(parent, physicalRoot) && !p.isWithin(physicalRoot, parent)) {
      throw const FormatException(
        'Workspace document resolves outside the workspace directory',
      );
    }
    return p.normalize(
      p.join(p.relative(parent, from: physicalRoot), parts.last),
    );
  }

  Future<int> _open(String reference) async {
    final candidate = _candidate(reference);
    await boundary('before-open', reference);
    final parts = p.split(candidate);
    final held = <int>[];
    try {
      for (var i = 0; i < parts.length - 1; i++) {
        await boundary('before-ancestor', reference);
        // Linux always re-traverses from root. A previously opened directory
        // renamed out of the root cannot authorize a subsequent SQL open.
        final handle = Platform.isLinux
            ? _workspaceLinuxOpen(
                _root,
                parts.take(i + 1).join('/'),
                directory: true,
              )
            : _workspaceWindowsOpen(
                held.isEmpty ? _root : held.last,
                parts[i],
                directory: true,
              );
        held.add(handle);
        if (!_native.identityHandle(handle).directory) {
          throw const FormatException(
            'Workspace ancestor is not an ordinary directory',
          );
        }
        await boundary('ancestor-acquired', reference);
      }
      await boundary('before-final-open', reference);
      final handle = Platform.isLinux
          ? _workspaceLinuxOpen(_root, candidate, directory: false)
          : _workspaceWindowsOpen(
              held.isEmpty ? _root : held.last,
              parts.last,
              directory: false,
            );
      try {
        if (!_native.identityHandle(handle).regular) {
          throw const FormatException(
            'Workspaces reference ordinary files, not links or special objects',
          );
        }
        return handle;
      } catch (_) {
        _native.close(handle);
        rethrow;
      }
    } finally {
      for (final handle in held.reversed) {
        _native.close(handle);
      }
    }
  }

  Future<ConfinedRead> read(
    String reference,
    int limit, {
    bool content = true,
  }) async {
    final handle = await _open(reference);
    Pointer<Uint8> buffer = nullptr;
    try {
      final identity = _native.identityHandle(handle);
      await boundary('file-acquired', reference);
      if (!content) return ConfinedRead(Uint8List(0), identity.token);
      if (identity.size > limit) throw NativeReadLimit(limit);
      buffer = _native.allocate(65536);
      final bytes = BytesBuilder(copy: false);
      while (true) {
        await boundary('before-read', reference);
        // The identity recorded at this exact native read boundary comes from
        // the same descriptor passed to read/ReadFile, never from a pathname.
        if (!_native.identityHandle(handle).sameObject(identity)) {
          throw const FileSystemException(
            'Opened workspace file identity changed',
          );
        }
        await boundary('read-handle:${identity.token}', reference);
        final count = _workspaceRead(
          handle,
          buffer,
          (limit - bytes.length + 1).clamp(1, 65536),
        );
        if (count == 0) break;
        if (bytes.length + count > limit) throw NativeReadLimit(limit);
        bytes.add(Uint8List.fromList(buffer.asTypedList(count)));
      }
      if (_native.identityHandle(handle) != identity) {
        throw const FileSystemException('Workspace file changed while reading');
      }
      return ConfinedRead(bytes.takeBytes(), identity.token);
    } finally {
      if (buffer != nullptr) _native.free(buffer);
      _native.close(handle);
    }
  }

  void verifyAssociation(String reference, String token) {
    // Metadata only. Reject a detached root or substituted save target rather
    // than associating authorized bytes with an unrelated displayed pathname.
    if (_native
                .identity(Directory(path).resolveSymbolicLinksSync())
                ?.sameObject(_identity) !=
            true ||
        _native
                .identity(p.joinAll([path, ...portableSegments(reference)]))
                ?.token !=
            token) {
      throw const FileSystemException(
        'Workspace path changed while loading; reopen its current location',
      );
    }
  }

  void close() {
    for (final handle in _handles.reversed) {
      _native.close(handle);
    }
    _handles.clear();
  }
}

typedef _OpenAt2N =
    IntPtr Function(IntPtr, Int32, Pointer<Uint8>, Pointer<Uint64>, IntPtr);
typedef _OpenAt2D =
    int Function(int, int, Pointer<Uint8>, Pointer<Uint64>, int);

int _workspaceLinuxOpen(int root, String relative, {required bool directory}) {
  final name = _native.string(relative);
  Pointer<Uint8> memory = nullptr;
  try {
    memory = _native.allocate(24);
    final how = memory.cast<Uint64>();
    // Stable Linux 5.6 ABI: NOFOLLOW|CLOEXEC, nonblocking regular-file inspection;
    // BENEATH|NO_MAGICLINKS|NO_SYMLINKS. No newer OPENAT2_REGULAR flag.
    how[0] = directory
        ? 0x2b0000
        : 0xa0900; // Also O_NOCTTY for unsupported devices.
    how[1] = 0;
    how[2] = 0xe;
    final handle = _native.library.lookupFunction<_OpenAt2N, _OpenAt2D>(
      'syscall',
    )(437, root, name, how, 24);
    if (handle < 0) {
      throw FileSystemException(
        'Confined workspace open failed; no unrestricted fallback',
        relative,
        OSError('', _native.error()),
      );
    }
    return handle;
  } finally {
    if (memory != nullptr) _native.free(memory);
    _native.free(name);
  }
}

// Windows x64 ABI. FFI lays out pointer alignment (UNICODE_STRING=16,
// OBJECT_ATTRIBUTES=48, IO_STATUS_BLOCK=16); no packed or guessed byte offsets.
final class _UnicodeString extends Struct {
  @Uint16()
  external int length;
  @Uint16()
  external int maximumLength;
  external Pointer<Uint16> buffer;
}

final class _ObjectAttributes extends Struct {
  @Uint32()
  external int length;
  @IntPtr()
  external int root;
  external Pointer<_UnicodeString> name;
  @Uint32()
  external int attributes;
  external Pointer<Void> security;
  external Pointer<Void> quality;
}

typedef _NtOpenN =
    Int32 Function(
      Pointer<IntPtr>,
      Uint32,
      Pointer<_ObjectAttributes>,
      Pointer<Uint8>,
      Pointer<Void>,
      Uint32,
      Uint32,
      Uint32,
      Uint32,
      Pointer<Void>,
      Uint32,
    );
typedef _NtOpenD =
    int Function(
      Pointer<IntPtr>,
      int,
      Pointer<_ObjectAttributes>,
      Pointer<Uint8>,
      Pointer<Void>,
      int,
      int,
      int,
      int,
      Pointer<Void>,
      int,
    );

int _workspaceWindowsRoot(String path) {
  final name = _native.wide(path);
  try {
    final handle = _native.library.lookupFunction<_CreateN, _CreateD>(
      'CreateFileW',
    )(name, 0x1000a0, 1, nullptr, 3, 0x02200000, 0);
    if (handle == -1) {
      throw FileSystemException(
        'Cannot hold workspace volume',
        path,
        OSError('', _native.error()),
      );
    }
    try {
      if (!_native.identityHandle(handle).directory) {
        throw const FormatException(
          'Workspace volume must be an ordinary directory',
        );
      }
      return handle;
    } catch (_) {
      _native.close(handle);
      rethrow;
    }
  } finally {
    _native.free(name.cast<Uint8>());
  }
}

int _workspaceWindowsOpen(
  int root,
  String component, {
  required bool directory,
}) {
  if (sizeOf<IntPtr>() != 8 ||
      sizeOf<_UnicodeString>() != 16 ||
      sizeOf<_ObjectAttributes>() != 48) {
    throw const FileSystemException('Unsupported Windows filesystem ABI');
  }
  if (component.isEmpty ||
      component.contains(RegExp(r'[\\/:\x00]')) ||
      component == '.' ||
      component == '..') {
    throw const FormatException('Invalid workspace component');
  }
  final allocations = <Pointer<Uint8>>[];
  Pointer<Uint8> alloc(int size) {
    final result = _native.allocate(size);
    allocations.add(result);
    result.asTypedList(size).fillRange(0, size, 0);
    return result;
  }

  try {
    final units = component.codeUnits;
    final text = alloc((units.length + 1) * 2).cast<Uint16>();
    text.asTypedList(units.length).setAll(0, units);
    final name = alloc(sizeOf<_UnicodeString>()).cast<_UnicodeString>();
    name.ref
      ..length = units.length * 2
      ..maximumLength = (units.length + 1) * 2
      ..buffer = text;
    final attributes = alloc(
      sizeOf<_ObjectAttributes>(),
    ).cast<_ObjectAttributes>();
    attributes.ref
      ..length = sizeOf<_ObjectAttributes>()
      ..root = root
      ..name = name
      ..attributes = 0x40;
    final result = alloc(8).cast<IntPtr>(), statusBlock = alloc(16);
    final ntdll = DynamicLibrary.open('ntdll.dll');
    final status = ntdll.lookupFunction<_NtOpenN, _NtOpenD>('NtCreateFile')(
      result,
      directory
          ? 0x1000a0
          : 0x100081, // SYNCHRONIZE|READ_ATTRIBUTES|TRAVERSE / READ_DATA
      attributes,
      statusBlock,
      nullptr,
      0,
      1,
      1,
      0x200020 | (directory ? 1 : 0x40),
      nullptr,
      0,
    );
    if (status < 0) {
      final code = ntdll
          .lookupFunction<Uint32 Function(Int32), int Function(int)>(
            'RtlNtStatusToDosError',
          )(status);
      throw FileSystemException(
        'Confined workspace open failed; no path fallback',
        component,
        OSError('', code),
      );
    }
    final handle = result.value;
    try {
      final identity = _native.identityHandle(handle);
      if (directory ? !identity.directory : !identity.regular) {
        throw const FormatException(
          'Workspace links, junctions and special files are rejected at the authoritative open',
        );
      }
      if (!directory &&
          _native.library
                  .lookupFunction<Uint32 Function(IntPtr), int Function(int)>(
                    'GetFileType',
                  )(handle) !=
              1) {
        throw const FormatException('Workspace file is not a disk file');
      }
      return handle;
    } catch (_) {
      _native.close(handle);
      rethrow;
    }
  } finally {
    for (final memory in allocations.reversed) {
      _native.free(memory);
    }
  }
}

String _workspaceFinalPath(int handle) {
  if (Platform.isLinux) {
    return Directory('/proc/self/fd/$handle').resolveSymbolicLinksSync();
  }
  final memory = _native.allocate(65536).cast<Uint16>();
  try {
    final count = _native.library
        .lookupFunction<
          Uint32 Function(IntPtr, Pointer<Uint16>, Uint32, Uint32),
          int Function(int, Pointer<Uint16>, int, int)
        >('GetFinalPathNameByHandleW')(handle, memory, 32768, 0);
    if (count == 0 || count >= 32768) {
      throw FileSystemException(
        'Cannot identify held workspace directory',
        '',
        OSError('', _native.error()),
      );
    }
    final value = String.fromCharCodes(memory.asTypedList(count));
    if (value.startsWith('\\\\?\\UNC\\')) return '\\\\${value.substring(8)}';
    return value.startsWith('\\\\?\\') ? value.substring(4) : value;
  } finally {
    _native.free(memory.cast<Uint8>());
  }
}

int _workspaceRead(int handle, Pointer<Uint8> buffer, int count) {
  if (Platform.isLinux) {
    final read = _native.library.lookupFunction<_WriteN, _WriteD>('read');
    final size = read(handle, buffer, count);
    if (size < 0) {
      throw FileSystemException(
        'Cannot read confined workspace file',
        '',
        OSError('', _native.error()),
      );
    }
    return size;
  }
  final receipt = _native.allocate(4).cast<Uint32>();
  try {
    if (_native.library.lookupFunction<_WinWriteN, _WinWriteD>('ReadFile')(
          handle,
          buffer,
          count,
          receipt,
          nullptr,
        ) ==
        0) {
      throw FileSystemException(
        'Cannot read confined workspace file',
        '',
        OSError('', _native.error()),
      );
    }
    return receipt.value;
  } finally {
    _native.free(receipt.cast<Uint8>());
  }
}
