import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'editor/sql_editor.dart';
import 'package:uuid/uuid.dart';
import '../../platform/common/output_commit.dart';

void _validateEditorText(String text) {
  if (text.length > 8000000) {
    throw const DocumentResourceLimit('SQL exceeds 8M UTF-16 units');
  }
  int lines = 1;
  for (int i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit != 10 && unit != 13) continue;
    if (++lines > 100000) {
      throw const DocumentResourceLimit(
        'SQL exceeds 100,000 editor lines; use a smaller file or a direct export workflow',
      );
    }
    if (unit == 13 && i + 1 < text.length && text.codeUnitAt(i + 1) == 10) i++;
  }
}

SqlEditorController _boundedEditor(String text, CodeLineOptions options) {
  _validateEditorText(text);
  return SqlEditorController.fromText(text, options);
}

/// Canonical SQL must not be silently changed by UTF-8/protobuf replacement.
const maxSqlFileBytes = 24000000;
const maxSqlRpcBytes = 15000000;

int validateSqlUnicode(String text, {int? maxUtf8Bytes}) {
  var bytes = 0;
  for (int offset = 0; offset < text.length; offset++) {
    final unit = text.codeUnitAt(offset);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++offset >= text.length ||
          text.codeUnitAt(offset) < 0xdc00 ||
          text.codeUnitAt(offset) > 0xdfff) {
        throw const FormatException(
          'SQL contains an incomplete Unicode character; finish composition or correct the text',
        );
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException(
        'SQL contains an incomplete Unicode character; finish composition or correct the text',
      );
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (maxUtf8Bytes != null && bytes > maxUtf8Bytes) {
      throw DocumentResourceLimit(
        'SQL exceeds the $maxUtf8Bytes-byte command limit; select a smaller statement',
      );
    }
  }
  return bytes;
}

/// Live text and canonical copies share one workbench budget. Reservations keep
/// a completed save admissible even when other documents change during I/O.
class DocumentBudget {
  DocumentBudget({this.maxDocuments = 100, this.maxUnits = 32000000});
  final int maxDocuments, maxUnits;
  final _entries = <SqlDocument, _DocumentCharge>{};
  final _auxiliary = <Object, int>{};
  int get units =>
      _entries.values.fold(0, (sum, entry) => sum + entry.units) +
      _auxiliary.values.fold(0, (sum, cost) => sum + cost);
  void auxiliary(Object owner, int cost) {
    if (cost < 0 || units - (_auxiliary[owner] ?? 0) + cost > maxUnits) {
      throw const DocumentResourceLimit('Workspace text budget reached');
    }
    if (cost == 0) {
      _auxiliary.remove(owner);
    } else {
      _auxiliary[owner] = cost;
    }
  }

  int get count => _entries.length;

  void requireAdditional(int count, int units) {
    if (this.count + count > maxDocuments || this.units + units > maxUnits) {
      throw const DocumentResourceLimit(
        'Workspace text budget reached; save and close documents before opening more',
      );
    }
  }

  void attachAll(List<SqlDocument> documents) {
    final pending = <SqlDocument, _DocumentCharge>{};
    for (final document in documents) {
      if (document._disposed ||
          document._budget != null ||
          pending.containsKey(document) ||
          _entries.containsKey(document)) {
        throw StateError(
          'Document is closed or already belongs to a workspace',
        );
      }
      pending[document] = _DocumentCharge(
        document.editor.text.length,
        document.savedText.length,
      );
    }
    if (count + pending.length > maxDocuments ||
        units +
                pending.entries.fold(
                  0,
                  (sum, entry) =>
                      sum + entry.value.units + entry.key.editor.chargedUnits,
                ) >
            maxUnits) {
      throw const DocumentResourceLimit(
        'Workspace text budget reached; save and close documents before opening more',
      );
    }
    _entries.addAll(pending);
    for (final document in pending.keys) {
      document._budget = this;
      final extra = document.editor.chargedUnits;
      if (extra != 0) _auxiliary[document._editorAuxiliaryOwner] = extra;
    }
  }

  void _admitEditor(SqlDocument document, int text, int auxiliary) {
    final entry = _entries[document];
    if (entry == null) return;
    final next = _DocumentCharge(text, entry.saved)
      ..reservations.addAll(entry.reservations);
    final owner = document._editorAuxiliaryOwner;
    if (auxiliary < 0 ||
        units -
                entry.units -
                (_auxiliary[owner] ?? 0) +
                next.units +
                auxiliary >
            maxUnits) {
      throw const DocumentResourceLimit(
        'Workspace text budget reached; close another document before editing',
      );
    }
    _entries[document] = next;
    if (auxiliary == 0) {
      _auxiliary.remove(owner);
    } else {
      _auxiliary[owner] = auxiliary;
    }
  }

  void _update(SqlDocument document, {int? text, int? saved}) {
    final entry = _entries[document];
    if (entry == null) return;
    final next = _DocumentCharge(text ?? entry.text, saved ?? entry.saved)
      ..reservations.addAll(entry.reservations);
    if (units - entry.units + next.units > maxUnits) {
      throw const DocumentResourceLimit(
        'Workspace text budget reached; close another document before editing',
      );
    }
    _entries[document] = next;
  }

  void Function() _reserve(SqlDocument document, int length) {
    final entry = _entries[document];
    if (entry == null) return () {};
    final token = Object();
    final next = _DocumentCharge(entry.text, entry.saved)
      ..reservations.addAll(entry.reservations)
      ..reservations[token] = length;
    if (units - entry.units + next.units > maxUnits) {
      throw const DocumentResourceLimit(
        'Saved text exceeds the workspace budget',
      );
    }
    _entries[document] = next;
    return () => _entries[document]?.reservations.remove(token);
  }

  void _detach(SqlDocument document) {
    _entries.remove(document);
    _auxiliary.remove(document._editorAuxiliaryOwner);
  }
}

class _DocumentCharge {
  _DocumentCharge(this.text, this.saved);
  final int text, saved;
  final reservations = <Object, int>{};
  int get units {
    var canonical = saved;
    for (final length in reservations.values) {
      if (length > canonical) canonical = length;
    }
    return text + canonical;
  }
}

/// Captured save buffers are admitted before encoding, across all documents.
class SaveCaptureBudget {
  SaveCaptureBudget({this.maxBytes = 67108864, this.maxOperations = 16});
  final int maxBytes, maxOperations;
  static final shared = SaveCaptureBudget();
  int bytes = 0, operations = 0;
  void Function() reserve(int cost) {
    if (operations >= maxOperations || cost > maxBytes - bytes) {
      throw const DocumentResourceLimit(
        'Too many saves are pending; wait for them before saving again',
      );
    }
    operations++;
    bytes += cost;
    var released = false;
    return () {
      if (released) return;
      released = true;
      operations--;
      bytes -= cost;
    };
  }
}

class SqlDocument {
  SqlDocument({
    String? id,
    String text = '',
    this.path,
    this.profileId,
    this.untitledNumber,
    this.io = const DocumentIo(),
    SaveCaptureBudget? saveBudget,
  }) : id = id ?? const Uuid().v4(),
       editor = _boundedEditor(
         text,
         CodeLineOptions(
           lineBreak: text.contains('\r\n')
               ? TextLineBreak.crlf
               : TextLineBreak.lf,
         ),
       ),
       _savedText = path == null ? '' : text,
       saveBudget = saveBudget ?? SaveCaptureBudget.shared {
    editor.admitChange = (next, auxiliaryUnits) {
      _validateEditorText(next.source.text);
      _budget?._admitEditor(this, next.source.length, auxiliaryUnits);
    };
    _observedText = editor.text;
    editor.addListener(_changed);
  }
  final String id;

  /// Creation-assigned presentation metadata; never an editor/recovery identity.
  int? untitledNumber;
  final DocumentIo io;
  final SqlEditorController editor;
  final Object _editorAuxiliaryOwner = Object();
  DocumentBudget? _budget;
  final SaveCaptureBudget saveBudget;
  String _savedText;
  String get savedText => _savedText;
  set savedText(String text) {
    _validateEditorText(text);
    _budget?._update(this, saved: text.length);
    _savedText = text;
  }

  String? path, profileId, diskHash, sessionId;
  String connectionCatalog = '', connectionSchema = '';
  String? diskEntryToken;
  int version = 1;
  int savedVersion = 0,
      _pendingSaves = 0,
      _saveSequence = 0,
      _errorSequence = 0;
  bool _disposed = false;
  Object? lastSaveError;
  String _observedText = '';
  Future<void> _saveTail = Future<void>.value();
  bool get saving => _pendingSaves != 0;
  Future<void> get writesFinished => _saveTail;
  Future<void> get savesFinished => _saveTail.then((_) {
    if (lastSaveError != null) throw lastSaveError!;
  });
  void _changed() {
    if (_observedText != editor.text) {
      _observedText = editor.text;
      version++;
    }
  }

  bool get dirty => editor.text != savedText;
  String get title => path == null
      ? untitledNumber == null
            ? 'Untitled query'
            : 'Query $untitledNumber'
      : p.basename(path!);
  int get caret => editor.offsetForPosition(editor.selection.extent);

  (int, int) get selectionUtf16 {
    final selection = editor.selection;
    final base = editor.offsetForPosition(selection.base),
        extent = editor.offsetForPosition(selection.extent);
    return base < extent ? (base, extent) : (extent, base);
  }

  void selectOffsets(int start, int end) => editor.selectOffsets(start, end);

  /// One exact-source replacement and one owned undo entry. Original UTF-16
  /// coordinates, including literal line endings, remain authoritative.
  bool replaceWithMappedPositions(String replacement, int Function(int) map) =>
      editor.replaceSource(replacement, map);

  void toggleLineComments() {
    if (editor.isComposing) {
      throw StateError('Finish IME composition before commenting SQL');
    }
    final original = editor.value;
    final ranges = [original.selection, ...original.secondarySelections];
    final selected = <int>{};
    for (final range in ranges) {
      final end = range.endIndex > range.startIndex && range.endOffset == 0
          ? range.endIndex - 1
          : range.endIndex;
      for (int line = range.startIndex; line <= end; line++) {
        selected.add(line);
      }
    }
    final pending = [
      for (final index in selected) (original.codeLines[index], 0),
    ];
    bool remove = true;
    int additions = 0;
    while (pending.isNotEmpty) {
      final (line, depth) = pending.removeLast();
      if (depth > 64) {
        throw StateError(
          'Expand nested folded regions before commenting this selection',
        );
      }
      if (line.text.trim().isNotEmpty) {
        additions += 3;
        if (!line.text.trimLeft().startsWith('--')) remove = false;
      }
      for (final child in line.chunks) {
        pending.add((child, depth + 1));
      }
    }
    if (!remove && editor.text.length + additions > 8000000) {
      throw StateError('Commenting exceeds the 8M document budget');
    }
    final deltas = <int, (int, int)>{};
    int added = 0;
    CodeLine change(CodeLine line, {int? index}) {
      final indent = line.text.length - line.text.trimLeft().length;
      String text = line.text;
      int delta = 0;
      if (line.text.trim().isNotEmpty) {
        if (remove) {
          final count = line.text.substring(indent).startsWith('-- ') ? 3 : 2;
          text =
              line.text.substring(0, indent) +
              line.text.substring(indent + count);
          delta = -count;
        } else {
          text =
              '${line.text.substring(0, indent)}-- ${line.text.substring(indent)}';
          delta = 3;
        }
      }
      added += delta;
      if (index != null) deltas[index] = (indent, delta);
      return line.copyWith(
        text: text,
        chunks: [for (final child in line.chunks) change(child)],
      );
    }

    final updated = CodeLines.from(original.codeLines);
    for (final index in selected) {
      updated[index] = change(updated[index], index: index);
    }
    if (editor.text.length + added > 8000000) {
      throw StateError('Commenting exceeds the 8M document budget');
    }
    int offset(int line, int value) {
      final (indent, delta) = deltas[line] ?? (0, 0);
      return value <= indent
          ? value
          : (value + delta).clamp(indent, updated[line].text.length);
    }

    final mapped = ranges
        .map(
          (range) => range.copyWith(
            baseOffset: offset(range.baseIndex, range.baseOffset),
            extentOffset: offset(range.extentIndex, range.extentOffset),
          ),
        )
        .toList();
    editor.runRevocableOp(
      () => editor.value = original.copyWith(
        codeLines: updated,
        selection: mapped.first,
        secondarySelections: mapped.skip(1).toList(),
      ),
    );
  }

  Future<void> save(String target, {bool overwriteExternal = false}) {
    if (_disposed) return Future<void>.error(StateError('Document is closed'));
    final text = editor.text, revision = version, documentId = id;
    final sequence = ++_saveSequence;
    late final Uint8List bytes;
    void Function()? releaseCapture, releaseCanonical;
    Object? encodingError;
    StackTrace? encodingStack;
    try {
      final size = validateSqlUnicode(text);
      if (_pendingSaves >= 4) {
        throw const DocumentResourceLimit(
          'Four saves are already pending for this document; wait before retrying',
        );
      }
      // The native-file worker receives one bounded byte copy while this exact
      // capture remains authoritative for revision-safe saved metadata.
      releaseCapture = saveBudget.reserve(size * 2 + text.length * 2);
      releaseCanonical = _budget?._reserve(this, text.length);
      final encoded = utf8.encode(text);
      bytes = encoded.asUnmodifiableView();
    } catch (error, stack) {
      releaseCapture?.call();
      releaseCanonical?.call();
      releaseCapture = releaseCanonical = null;
      if (error is DocumentResourceLimit) {
        lastSaveError = error;
        _errorSequence = sequence;
        return Future<void>.error(error, stack);
      }
      encodingError = error;
      encodingStack = stack;
    }
    final destination = p.normalize(p.absolute(target));
    final file = File(destination);
    _pendingSaves++;
    final operation = _saveTail
        .then((_) async {
          if (_disposed || id != documentId) {
            throw StateError('Document closed before saving');
          }
          if (encodingError != null) {
            Error.throwWithStackTrace(encodingError, encodingStack!);
          }
          // Earlier queued saves have completed; their successful disk state is now
          // the expected state for this operation, without changing captured text.
          final previousPath = path == null
              ? null
              : p.normalize(p.absolute(path!));
          final sameTarget = Platform.isWindows
              ? previousPath?.toLowerCase() == destination.toLowerCase()
              : previousPath == destination;
          final expected = sameTarget ? diskHash : null;
          if (!overwriteExternal &&
              sameTarget &&
              diskEntryToken != null &&
              OutputDestination.currentEntryToken(file) != diskEntryToken) {
            throw StateError(
              'File identity changed outside BusyData. Review before overwriting.',
            );
          }
          final observed = await io.hash(file);
          if (!overwriteExternal &&
              sameTarget &&
              expected != null &&
              observed != expected) {
            throw StateError(
              'File changed outside BusyData. Review before overwriting.',
            );
          }
          await file.parent.create(recursive: true);
          final reviewedDestination = await OutputDestination.capture(file);
          if (reviewedDestination.contentHash != observed) {
            throw StateError(
              'File changed while reviewing its destination. Review and retry.',
            );
          }
          // Bind this replacement to the exact on-disk state observed before I/O.
          // Explicit overwrite review permits the observed version, not later edits
          // made by another process while the temporary file is being written.
          await io.write(
            file,
            bytes,
            destination: reviewedDestination,
            beforeReplace: () async {
              if (await io.hash(file) != observed) {
                throw StateError(
                  'File changed while saving. Original file preserved; review and retry.',
                );
              }
            },
          );
          savedText = utf8.decode(bytes);
          savedVersion = revision;
          path = destination;
          diskHash = sha256.convert(bytes).toString();
          diskEntryToken = OutputDestination.currentEntryToken(file);
          if (sequence >= _errorSequence) lastSaveError = null;
        })
        .whenComplete(() {
          _pendingSaves--;
          releaseCapture?.call();
          releaseCanonical?.call();
        });
    // Preserve failure for this caller, while letting subsequent saves retry.
    _saveTail = operation.then(
      (_) {},
      onError: (Object error, StackTrace _) {
        if (sequence >= _errorSequence) {
          lastSaveError = error;
          _errorSequence = sequence;
        }
      },
    );
    return operation;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _budget?._detach(this);
    _budget = null;
    editor.admitChange = null;
    editor.beforeChange = null;
    editor.onChangeRejected = null;
    editor.removeListener(_changed);
    editor.dispose();
  }
}

/// Filesystem operations are injected only to synchronize/fault-test actual save
/// ownership. Production always uses native filesystem I/O and atomic rename.
class DocumentIo {
  const DocumentIo();
  Future<String?> hash(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError(
        'SQL destination is a symbolic link; choose its actual file explicitly.',
      );
    }
    if (!await file.exists()) return null;
    if (await file.length() > maxSqlFileBytes) {
      throw const DocumentResourceLimit(
        'SQL destination exceeds the 24MB review budget; choose a new file',
      );
    }
    var bytes = 0;
    return sha256
        .bind(
          file.openRead().map((chunk) {
            bytes += chunk.length;
            if (bytes > maxSqlFileBytes) {
              throw const DocumentResourceLimit(
                'SQL destination grew beyond its review budget',
              );
            }
            return chunk;
          }),
        )
        .first
        .then((digest) => digest.toString());
  }

  Future<void> write(
    File file,
    List<int> bytes, {
    required Future<void> Function() beforeReplace,
    OutputDestination? destination,
  }) => atomicWrite(
    file,
    bytes,
    beforeReplace: beforeReplace,
    replaceFile: replace,
    destination: destination,
  );
  Future<void> replace(File temporary, File destination) async {
    // Existing deterministic fault/delay hook. The shared output commit always
    // performs publication after this hook succeeds; hooks cannot authorize it.
  }
}

Future<void> atomicWrite(
  File file,
  List<int> bytes, {
  void Function(String)? restrictFile,
  Future<void> Function()? beforeReplace,
  Future<void> Function(File temporary, File destination)? replaceFile,
  Future<void> Function(File temporary)? removeTemporary,
  OutputDestination? destination,
  Future<void> Function(String)? commitHook,
}) async {
  await file.parent.create(recursive: true);
  final reviewedDestination =
      destination ?? await OutputDestination.capture(file);
  if (reviewedDestination.file.path != p.normalize(p.absolute(file.path))) {
    throw StateError('Output approval belongs to another destination');
  }
  final temporary = File('${file.parent.path}/.${const Uuid().v4()}.tmp');
  Object? primary;
  PartialOutput? partialIdentity;
  var stagingCreated = false;
  try {
    await temporary.create(exclusive: true);
    stagingCreated = true;
    partialIdentity = reviewedDestination.capturePartial(temporary);
    restrictFile?.call(temporary.path);
    await reviewedDestination.writePartial(temporary, bytes, partialIdentity);
    await beforeReplace?.call();
    await replaceFile?.call(temporary, file);
    await reviewedDestination.commit(
      temporary,
      expected: partialIdentity,
      hook: commitHook,
    );
  } catch (error) {
    if (stagingCreated && partialIdentity == null) {
      primary = OutputCommitFailure(
        'Staging ownership could not be established',
        partialPath: temporary.path,
        primary: error,
      );
      throw primary;
    }
    primary = error;
    rethrow;
  } finally {
    try {
      if (removeTemporary != null) {
        await removeTemporary(temporary);
      } else if (partialIdentity != null) {
        await reviewedDestination.cleanupPartial(
          temporary,
          expected: partialIdentity,
        );
      }
    } catch (cleanup) {
      if (primary == null) rethrow;
      throw FileWriteFailure(primary, cleanup);
    }
  }
}

class FileWriteFailure implements Exception {
  const FileWriteFailure(this.primary, this.cleanup);
  final Object primary, cleanup;
  @override
  String toString() => '$primary; temporary-file cleanup also failed: $cleanup';
}

class DraftStore {
  DraftStore(this.directory, {this.restrictPath, this.write});
  final Directory directory;
  final void Function(String, bool)? restrictPath;
  final Future<void> Function(File, List<int>)? write;
  int restoredSelection = 0;
  String? restoredStartupScratchId;
  final unadoptedRecords = <dynamic>[];
  final restoredRecords = <String, dynamic>{};
  Future<void> save(
    List<SqlDocument> documents,
    int selected, {
    String? startupScratchId,
    List<dynamic> unadopted = const [],
  }) async {
    if (documents.length + unadopted.length > 100) {
      throw const DocumentResourceLimit(
        'Recovery supports at most 100 documents',
      );
    }
    final records = [
      for (final d in documents)
        {
          'id': d.id,
          'untitledNumber': d.untitledNumber,
          'text': d.editor.text,
          'savedText': d.savedText,
          'path': d.path,
          'profileId': d.profileId,
          'connectionCatalog': d.connectionCatalog,
          'connectionSchema': d.connectionSchema,
          'diskHash': d.diskHash,
        },
    ];
    var size = 64;
    for (final record in records) {
      for (final key in ['text', 'savedText']) {
        if ((record[key] as String).length > 8000000) {
          throw const DocumentResourceLimit(
            'Recovery document exceeds 8M UTF-16 units',
          );
        }
      }
      for (final value in record.values) {
        if (value is String) size += jsonStringBytes(value);
      }
      size += 128;
      if (size > 33554432) {
        throw const DocumentResourceLimit(
          'Recovery exceeds 32MiB; save ordinary SQL files before closing',
        );
      }
    }
    final bytes = utf8.encode(
      jsonEncode({
        'version': 1,
        'selected': selected,
        'documents': [...records, ...unadopted],
        'startupScratchId': ?startupScratchId,
      }),
    );
    if (bytes.length > 33554432) {
      throw const DocumentResourceLimit('Recovery exceeds 32MiB');
    }
    final file = File(p.join(directory.path, 'drafts.json'));
    if (write != null) {
      await write!(file, bytes);
    } else {
      await directory.create(recursive: true);
      restrictPath?.call(directory.path, true);
      await atomicWrite(
        file,
        bytes,
        restrictFile: (path) => restrictPath?.call(path, false),
      );
    }
  }

  Future<List<SqlDocument>> load() async {
    final file = File(p.join(directory.path, 'drafts.json'));
    if (!await file.exists()) return [];
    try {
      final text = utf8.decode(await readBoundedFile(file, 33554432));
      checkJsonNesting(text);
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const FormatException('Unsupported draft version');
      }
      restoredSelection = data['selected'] as int? ?? 0;
      restoredStartupScratchId = data['startupScratchId'] as String?;
      final records = data['documents'] as List;
      if (records.length > 100) {
        throw const DocumentResourceLimit(
          'Recovery document count exceeds 100',
        );
      }
      final output = <SqlDocument>[];
      final ids = <String>{};
      for (final raw in records) {
        SqlDocument? document;
        try {
          final d = raw as Map<String, dynamic>;
          _validateEditorText(d['text'] as String);
          if ((d['text'] as String).length > 8000000 ||
              (d['savedText'] as String).length > 8000000 ||
              (d['id'] as String).isEmpty ||
              (d['id'] as String).length > 128 ||
              ids.contains(d['id'])) {
            throw const DocumentResourceLimit(
              'Recovery document resource limit reached',
            );
          }
          document =
              SqlDocument(
                  id: d['id'] as String,
                  text: d['text'] as String,
                  path: d['path'] as String?,
                  profileId: d['profileId'] as String?,
                  untitledNumber: switch (d['untitledNumber']) {
                    final int number when number > 0 && number <= 1000000000 =>
                      number,
                    null => null,
                    _ => throw const FormatException('Invalid query name'),
                  },
                )
                ..savedText = d['path'] == null ? '' : d['savedText'] as String
                ..diskHash = d['diskHash'] as String?
                ..connectionCatalog = d['connectionCatalog'] as String? ?? ''
                ..connectionSchema = d['connectionSchema'] as String? ?? '';
          ids.add(document.id);
          output.add(document);
          restoredRecords[document.id] = raw;
        } catch (_) {
          document?.dispose();
          unadoptedRecords.add(raw);
        }
      }
      return output;
    } on DocumentResourceLimit {
      rethrow;
    } catch (_) {
      final quarantine = await OutputDestination.newDestination(
        File('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}'),
      );
      await quarantine.commit(file);
      rethrow;
    }
  }
}

class PortableWorkspace {
  static Future<void> save(File file, List<SqlDocument> documents) async {
    if (documents.length > 100) {
      throw const DocumentResourceLimit(
        'Workspace supports at most 100 documents',
      );
    }
    if (documents.any((d) => d.path == null || d.dirty)) {
      throw StateError(
        'Save each document as an ordinary .sql file before saving the portable workspace. Drafts remain local.',
      );
    }
    final root = p.normalize(p.absolute(file.parent.path));
    final references = <String>[];
    for (final document in documents) {
      final absolute = p.normalize(p.absolute(document.path!));
      if (!p.isWithin(root, absolute)) {
        throw const FormatException(
          'Portable workspace documents must be inside the workspace directory',
        );
      }
      final reference = p.split(p.relative(absolute, from: root)).join('/');
      portableSegments(reference);
      if (!reference.toLowerCase().endsWith('.sql')) {
        throw const FormatException('Workspaces reference ordinary .sql files');
      }
      references.add(reference);
    }
    await confinedWorkspaceWorker(
      (events) => _validatePortableSave(root, references, events),
    );
    await atomicWrite(
      file,
      utf8.encode(
        jsonEncode({
          'version': 1,
          'documents': [
            for (var index = 0; index < documents.length; index++)
              {
                'path': references[index],
                'profileId': documents[index].profileId,
                'connectionCatalog': documents[index].connectionCatalog,
                'connectionSchema': documents[index].connectionSchema,
              },
          ],
        }),
      ),
    );
  }

  static Future<List<SqlDocument>> load(
    File file, {
    WorkspaceReadHook? hook,
    WorkspaceReadControl? control,
  }) async {
    final path = p.normalize(p.absolute(file.path));
    final List<_PortableDocument> records;
    try {
      records = await confinedWorkspaceWorker(
        (events) => _loadPortableDocuments(path, events),
        hook: hook,
        control: control,
      );
    } on NativeReadLimit catch (limit) {
      throw DocumentResourceLimit(
        'Workspace file exceeds the ${limit.limit}-byte limit',
      );
    }
    final output = <SqlDocument>[];
    try {
      for (final record in records) {
        output.add(
          SqlDocument(
              text: record.text,
              path: record.path,
              profileId: record.profileId,
            )
            ..diskHash = record.hash
            ..diskEntryToken = record.entryToken
            ..connectionCatalog = record.catalog
            ..connectionSchema = record.schema,
        );
      }
      return output;
    } catch (_) {
      for (final document in output) {
        document.dispose();
      }
      rethrow;
    }
  }
}

class _PortableDocument {
  const _PortableDocument(
    this.text,
    this.path,
    this.profileId,
    this.hash,
    this.entryToken,
    this.catalog,
    this.schema,
  );
  final String text, path, hash, entryToken, catalog, schema;
  final String? profileId;
}

Future<List<_PortableDocument>> _loadPortableDocuments(
  String path,
  SendPort events,
) async {
  final root = await NativeWorkspaceRoot.open(p.dirname(path), events);
  try {
    final manifest = await root.read(p.basename(path), 1048576);
    final text = _portableUtf8(manifest.bytes);
    checkJsonNesting(text);
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data.keys.any((k) => !['version', 'documents'].contains(k))) {
      throw const FormatException('Unknown workspace version or fields');
    }
    final records = data['documents'] as List;
    if (records.length > 100) {
      throw const DocumentResourceLimit(
        'Workspace supports at most 100 documents',
      );
    }
    // Validate the complete manifest before any SQL content open.
    for (final raw in records) {
      final row = raw as Map<String, dynamic>;
      if (row.keys.any(
        (k) => ![
          'path',
          'profileId',
          'connectionCatalog',
          'connectionSchema',
        ].contains(k),
      )) {
        throw const FormatException('Unsupported workspace content');
      }
      final reference = row['path'] as String;
      portableSegments(reference);
      if (!reference.toLowerCase().endsWith('.sql')) {
        throw const FormatException('Workspaces reference ordinary .sql files');
      }
      if (row['profileId'] != null && row['profileId'] is! String) {
        throw const FormatException('Invalid workspace profile reference');
      }
      for (final key in ['connectionCatalog', 'connectionSchema']) {
        final value = row[key];
        if (value != null &&
            (value is! String ||
                value.length > 512 ||
                value.contains('\u0000'))) {
          throw const FormatException('Invalid workspace connection context');
        }
      }
    }
    final output = <_PortableDocument>[];
    var total = 0;
    for (final raw in records) {
      final row = raw as Map<String, dynamic>,
          reference = row['path'] as String;
      final read = await root.read(
        reference,
        (33554432 - total).clamp(0, maxSqlFileBytes),
      );
      total += read.bytes.length;
      final decoded = _portableUtf8(read.bytes);
      _validateEditorText(decoded);
      output.add(
        _PortableDocument(
          decoded,
          p.joinAll([p.dirname(path), ...portableSegments(reference)]),
          row['profileId'] as String?,
          sha256.convert(read.bytes).toString(),
          read.entryToken,
          row['connectionCatalog'] as String? ?? '',
          row['connectionSchema'] as String? ?? '',
        ),
      );
    }
    await root.boundary('before-adoption', '');
    root.verifyAssociation(p.basename(path), manifest.entryToken);
    for (var index = 0; index < records.length; index++) {
      root.verifyAssociation(
        (records[index] as Map<String, dynamic>)['path'] as String,
        output[index].entryToken,
      );
    }
    return output;
  } finally {
    root.close();
  }
}

String _portableUtf8(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('Workspace file is not valid UTF-8');
  }
}

Future<void> _validatePortableSave(
  String path,
  List<String> references,
  SendPort events,
) async {
  final root = await NativeWorkspaceRoot.open(path, events);
  try {
    for (final reference in references) {
      final read = await root.read(reference, 0, content: false);
      root.verifyAssociation(reference, read.entryToken);
    }
  } finally {
    root.close();
  }
}

class DocumentResourceLimit implements Exception {
  const DocumentResourceLimit(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Quotas are checked before a whole-file allocation, including files that grow
/// after opening. These reads never establish a session or execute SQL.
Future<Uint8List> readBoundedFile(File file, int limit) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const FileSystemException(
      'Choose a regular file, not a symbolic link',
    );
  }
  final handle = await file.open();
  try {
    if (await handle.length() > limit) {
      throw DocumentResourceLimit('File exceeds the $limit-byte limit');
    }
    final bytes = BytesBuilder(copy: false);
    while (true) {
      final block = await handle.read(
        (limit - bytes.length + 1).clamp(1, 65536),
      );
      if (block.isEmpty) break;
      if (bytes.length + block.length > limit) {
        throw DocumentResourceLimit('File grew beyond the $limit-byte limit');
      }
      bytes.add(block);
    }
    return bytes.takeBytes();
  } finally {
    await handle.close();
  }
}

void checkJsonNesting(String text) {
  var depth = 0;
  var quoted = false, escaped = false;
  for (final unit in text.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (unit == 92) {
        escaped = true;
      } else if (unit == 34) {
        quoted = false;
      }
    } else if (unit == 34) {
      quoted = true;
    } else if (unit == 91 || unit == 123) {
      if (++depth > 32) {
        throw const DocumentResourceLimit('JSON nesting exceeds 32');
      }
    } else if (unit == 93 || unit == 125) {
      depth--;
    }
  }
}

/// Exact UTF-8 size of a JSON string without first creating its encoded copy.
int jsonStringBytes(String text) {
  var bytes = 2;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 34 || unit == 92 || const [8, 9, 10, 12, 13].contains(unit)) {
      bytes += 2;
    } else if (unit < 32) {
      bytes += 6;
    } else if (unit < 128) {
      bytes++;
    } else if (unit < 2048) {
      bytes += 2;
    } else if (unit >= 0xd800 &&
        unit <= 0xdbff &&
        i + 1 < text.length &&
        text.codeUnitAt(i + 1) >= 0xdc00 &&
        text.codeUnitAt(i + 1) <= 0xdfff) {
      bytes += 4;
      i++;
    } else if (unit >= 0xd800 && unit <= 0xdfff) {
      bytes += 6;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}
