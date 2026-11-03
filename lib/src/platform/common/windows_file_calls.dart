part of 'output_commit.dart';

typedef _CreateResultN =
    IntPtr Function(
      Pointer<Uint16>,
      Uint32,
      Uint32,
      Pointer<Void>,
      Uint32,
      Uint32,
      IntPtr,
      Pointer<Uint32>,
    );
typedef _CreateResultD =
    int Function(
      Pointer<Uint16>,
      int,
      int,
      Pointer<Void>,
      int,
      int,
      int,
      Pointer<Uint32>,
    );
typedef _InfoResultN = Int32 Function(IntPtr, Pointer<Uint8>, Pointer<Uint32>);
typedef _InfoResultD = int Function(int, Pointer<Uint8>, Pointer<Uint32>);
typedef _IoResultN =
    Int32 Function(
      IntPtr,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Pointer<Void>,
      Pointer<Uint32>,
    );
typedef _IoResultD =
    int Function(
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint32>,
      Pointer<Void>,
      Pointer<Uint32>,
    );
typedef _FlushResultN = Int32 Function(IntPtr, Pointer<Uint32>);
typedef _FlushResultD = int Function(int, Pointer<Uint32>);
typedef _MoveResultN =
    Int32 Function(Pointer<Uint16>, Pointer<Uint16>, Uint32, Pointer<Uint32>);
typedef _MoveResultD =
    int Function(Pointer<Uint16>, Pointer<Uint16>, int, Pointer<Uint32>);
typedef _PathResultN =
    Uint32 Function(IntPtr, Pointer<Uint16>, Uint32, Uint32, Pointer<Uint32>);
typedef _PathResultD =
    int Function(int, Pointer<Uint16>, int, int, Pointer<Uint32>);

/// First-party wrappers retain the OS error in caller-owned memory before
/// returning through FFI. Dart runtime/symbol resolution cannot overwrite it.
class _WindowsFileCalls {
  _WindowsFileCalls(this.owner) : library = DynamicLibrary.open(_libraryPath());
  final _NativeOutput owner;
  final DynamicLibrary library;
  int lastError = 0;

  static String _libraryPath() {
    // Explicit compile-time test input only. Ordinary applications always load
    // their own packaged file by absolute path, without a PATH search.
    const testLibrary = String.fromEnvironment('BUSYDATA_WINDOWS_FILE_LIBRARY');
    if (testLibrary.isNotEmpty) {
      if (!p.isAbsolute(testLibrary)) {
        throw StateError('The native Windows test library must be absolute');
      }
      return testLibrary;
    }
    return p.join(
      p.dirname(Platform.resolvedExecutable),
      'backend',
      'native',
      'busydata_windows_files.dll',
    );
  }

  T _capture<T>(T Function(Pointer<Uint32>) operation) {
    final error = owner.allocate(4).cast<Uint32>();
    try {
      final result = operation(error);
      lastError = error.value;
      return result;
    } finally {
      owner.free(error.cast<Uint8>());
    }
  }

  late final _create = library.lookupFunction<_CreateResultN, _CreateResultD>(
    'busydata_create_file_w',
  );
  late final _info = library.lookupFunction<_InfoResultN, _InfoResultD>(
    'busydata_file_information',
  );
  late final _read = library.lookupFunction<_IoResultN, _IoResultD>(
    'busydata_read_file',
  );
  late final _write = library.lookupFunction<_IoResultN, _IoResultD>(
    'busydata_write_file',
  );
  late final _flush = library.lookupFunction<_FlushResultN, _FlushResultD>(
    'busydata_flush_file',
  );
  late final _move = library.lookupFunction<_MoveResultN, _MoveResultD>(
    'busydata_move_file_w',
  );
  late final _path = library.lookupFunction<_PathResultN, _PathResultD>(
    'busydata_final_path_w',
  );

  int create(
    Pointer<Uint16> name,
    int access,
    int share,
    Pointer<Void> security,
    int disposition,
    int flags,
    int template,
  ) => _capture(
    (error) => _create(
      name,
      access,
      share,
      security,
      disposition,
      flags,
      template,
      error,
    ),
  );
  int information(int file, Pointer<Uint8> info) =>
      _capture((error) => _info(file, info, error));
  int read(
    int file,
    Pointer<Uint8> data,
    int count,
    Pointer<Uint32> read,
    Pointer<Void> overlapped,
  ) => _capture((error) => _read(file, data, count, read, overlapped, error));
  int write(
    int file,
    Pointer<Uint8> data,
    int count,
    Pointer<Uint32> written,
    Pointer<Void> overlapped,
  ) => _capture(
    (error) => _write(file, data, count, written, overlapped, error),
  );
  int flush(int file) => _capture((error) => _flush(file, error));
  int move(Pointer<Uint16> source, Pointer<Uint16> destination, int flags) =>
      _capture((error) => _move(source, destination, flags, error));
  int finalPath(int file, Pointer<Uint16> buffer, int count, int flags) =>
      _capture((error) => _path(file, buffer, count, flags, error));
}
