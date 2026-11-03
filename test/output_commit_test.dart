import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/common/output_commit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// A real sharing conflict at the Windows content-open boundary. Metadata
// inspection and no-replace restoration remain permitted by share-delete.
void Function() holdWindowsWriter(String path) {
  final library = DynamicLibrary.open('kernel32.dll');
  final extended = path.startsWith(r'\\')
      ? '\\\\?\\UNC\\${path.substring(2)}'
      : '\\\\?\\$path';
  final units = extended.codeUnits;
  final memory = library
      .lookupFunction<
        Pointer<Void> Function(Uint32, IntPtr),
        Pointer<Void> Function(int, int)
      >('LocalAlloc')(0, (units.length + 1) * 2)
      .cast<Uint16>();
  expect(memory, isNot(nullptr));
  try {
    memory.asTypedList(units.length + 1).setAll(0, [...units, 0]);
    final handle = library
        .lookupFunction<
          IntPtr Function(
            Pointer<Uint16>,
            Uint32,
            Uint32,
            Pointer<Void>,
            Uint32,
            Uint32,
            IntPtr,
          ),
          int Function(Pointer<Uint16>, int, int, Pointer<Void>, int, int, int)
        >('CreateFileW')(memory, 0x40000000, 7, nullptr, 3, 0x200000, 0);
    expect(
      handle,
      isNot(-1),
      reason: 'Windows sharing-denial fixture unavailable',
    );
    return () {
      expect(
        library.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'CloseHandle',
        )(handle),
        isNot(0),
      );
    };
  } finally {
    library.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)
    >('LocalFree')(memory.cast<Void>());
  }
}

class CleanupFailureIo extends DocumentIo {
  CleanupFailureIo(this.edit);
  final void Function() edit;
  @override
  Future<void> write(
    File file,
    List<int> bytes, {
    required Future<void> Function() beforeReplace,
    OutputDestination? destination,
  }) => atomicWrite(
    file,
    bytes,
    destination: destination,
    beforeReplace: beforeReplace,
    commitHook: (phase) async {
      if (phase == 'before-backup-cleanup') {
        edit();
        throw const FileSystemException('injected cleanup denial');
      }
    },
  );
}

void main() {
  late Directory root;
  late File target, partial;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('busydata-native-output-');
    target = File('${root.path}/output.sql');
    partial = File('${root.path}/owned-partial.tmp');
    await partial.writeAsString('new output');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'fresh file workers recognize absent destinations before publication',
    () async {
      final path = '${root.path}/new-output.sql';
      for (var attempt = 0; attempt < 3; attempt++) {
        expect(
          await Isolate.run(() async {
            final destination = await OutputDestination.newDestination(
              File(path),
            );
            return destination.exists;
          }),
          isFalse,
        );
      }
      final destination = await OutputDestination.newDestination(File(path));
      await destination.commit(partial);
      expect(await File(path).readAsString(), 'new output');
      expect(await partial.exists(), isFalse);
    },
  );

  test(
    'native content verification denial restores without opening content again',
    () async {
      await target.writeAsString('reviewed');
      final token = OutputDestination.currentEntryToken(target);
      final destination = await OutputDestination.capture(target);
      void Function()? releaseWriter;
      try {
        await expectLater(
          destination.commit(
            partial,
            hook: (phase) async {
              if (phase == 'after-preserve') {
                final backup = await root.list().singleWhere(
                  (f) => f.path.endsWith('.busydata-backup'),
                );
                if (Platform.isWindows) {
                  releaseWriter = holdWindowsWriter(backup.path);
                } else {
                  final result = await Process.run('chmod', [
                    '000',
                    backup.path,
                  ]);
                  expect(result.exitCode, 0);
                }
              }
            },
          ),
          throwsA(isA<OutputCommitFailure>()),
        );
        expect(OutputDestination.currentEntryToken(target), token);
        expect(
          await root
              .list()
              .where((f) => f.path.endsWith('.busydata-backup'))
              .length,
          0,
        );
      } finally {
        releaseWriter?.call();
        if (!Platform.isWindows) {
          final result = await Process.run('chmod', ['600', target.path]);
          expect(result.exitCode, 0);
        }
      }
      expect(await target.readAsString(), 'reviewed');
      expect(await partial.readAsString(), 'new output');
    },
  );

  for (final boundary in [
    'before-finalization',
    'after-preserve',
    'after-publish',
  ]) {
    test('held parent survives pathname substitution at $boundary', () async {
      final parent = await Directory('${root.path}/selected').create();
      final moved = Directory('${root.path}/moved');
      final selected = await File(
        '${parent.path}/out.sql',
      ).writeAsString('reviewed');
      final staged = await File(
        '${parent.path}/partial',
      ).writeAsString('produced');
      final destination = await OutputDestination.capture(selected);
      var prevented = false;
      OutputCommitFailure? failure;
      try {
        await destination.commit(
          staged,
          hook: (phase) async {
            if (phase != boundary) return;
            try {
              await parent.rename(moved.path);
            } on FileSystemException catch (error) {
              expect(Platform.isWindows, isTrue);
              expect(error.osError?.errorCode, anyOf(5, 32, 33));
              prevented = true;
              return;
            }
            await parent.create();
            await selected.writeAsString('competing directory');
          },
        );
      } on OutputCommitFailure catch (error) {
        failure = error;
      }
      if (prevented) {
        expect(failure, isNull);
        expect(await selected.readAsString(), 'produced');
      } else {
        expect(failure, isNotNull);
        expect(await selected.readAsString(), 'competing directory');
        expect(
          await File('${moved.path}/out.sql').readAsString(),
          boundary == 'after-publish' ? 'produced' : 'reviewed',
        );
        expect(failure!.published, boundary == 'after-publish');
        if (boundary == 'after-publish') {
          expect(failure.recoveryPath, startsWith(moved.path));
          expect(await File(failure.recoveryPath!).readAsString(), 'reviewed');
        } else {
          expect(failure.partialPath, '${moved.path}/partial');
          expect(await File(failure.partialPath!).readAsString(), 'produced');
        }
      }
    });
  }

  test(
    'published save with failed cleanup protects newer edits and tab close',
    () async {
      await target.writeAsString('original');
      late SqlDocument document;
      final io = CleanupFailureIo(() {
        document.editor.selectAll();
        document.editor.replaceSelection('newer revision');
      });
      document = SqlDocument(text: 'original', path: target.path, io: io);
      final model = WorkbenchModel(root)..draftRecovery = false;
      model.adoptDocuments([document], notify: false);
      final saved = document.savedVersion;
      try {
        document.editor.selectAll();
        document.editor.replaceSelection('published revision');
        await expectLater(
          document.save(target.path),
          throwsA(
            isA<OutputCommitFailure>().having(
              (e) => e.published,
              'published',
              isTrue,
            ),
          ),
        );
        expect(await target.readAsString(), 'published revision');
        expect(document.editor.text, 'newer revision');
        expect(document.savedVersion, saved);
        expect(document.savedText, 'original');
        expect(document.dirty, isTrue);
        await expectLater(
          model.closeDocument(document, reviewedRevision: document.version),
          throwsA(anything),
        );
        expect(model.documents, contains(document));
        final backups = await root
            .list()
            .where((f) => f.path.endsWith('.busydata-backup'))
            .toList();
        expect(backups, hasLength(1));
        expect(await File(backups.single.path).readAsString(), 'original');
        expect(
          await root
              .list()
              .where(
                (f) =>
                    f.path.endsWith('.tmp') &&
                    p.normalize(f.path) != p.normalize(partial.path),
              )
              .length,
          0,
        );
      } finally {
        model.dispose();
      }
    },
  );

  for (final phase in ['after-preserve', 'before-verify', 'before-publish']) {
    test(
      'failure or cancellation at $phase restores with entry identity only',
      () async {
        await target.writeAsString('reviewed');
        final before = OutputDestination.currentEntryToken(target);
        final destination = await OutputDestination.capture(target);
        var verifications = 0;
        await expectLater(
          destination.commit(
            partial,
            hook: (boundary) async {
              if (boundary == 'before-verify') verifications++;
              if (boundary == phase) throw const WorkspaceReadCancelled();
            },
          ),
          throwsA(
            isA<OutputCommitFailure>().having(
              (e) => e.published,
              'published',
              isFalse,
            ),
          ),
        );
        expect(OutputDestination.currentEntryToken(target), before);
        expect(await target.readAsString(), 'reviewed');
        expect(await partial.readAsString(), 'new output');
        expect(
          await root
              .list()
              .where((f) => f.path.endsWith('.busydata-backup'))
              .length,
          0,
        );
        expect(verifications, lessThanOrEqualTo(1));
      },
    );
  }
  test(
    'competing entry immediately before restore remains and all artifacts are reported',
    () async {
      await target.writeAsString('reviewed');
      final before = OutputDestination.currentEntryToken(target);
      final destination = await OutputDestination.capture(target);
      OutputCommitFailure? failure;
      try {
        await destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-verify') {
              throw const FileSystemException('verification failed');
            }
            if (phase == 'before-restore') {
              await target.writeAsString('late writer');
            }
          },
        );
        fail('Must report retained recovery');
      } on OutputCommitFailure catch (error) {
        failure = error;
      }
      expect(failure.published, isFalse);
      expect(failure.cleanup, isNotNull);
      expect(failure.partialPath, p.normalize(partial.path));
      expect(
        OutputDestination.currentEntryToken(File(failure.recoveryPath!)),
        before,
      );
      expect(await File(failure.recoveryPath!).readAsString(), 'reviewed');
      expect(await target.readAsString(), 'late writer');
      await destination.cleanupPartial(
        partial,
        expected: destination.capturePartial(partial),
      );
      expect(await partial.exists(), isFalse);
      expect(await File(failure.recoveryPath!).exists(), isTrue);
    },
  );
  for (final kind in ['file', 'link', 'directory', 'missing']) {
    test(
      'changed recovery $kind stops restoration and remains untouched',
      () async {
        await target.writeAsString('reviewed');
        final destination = await OutputDestination.capture(target);
        final victim = await File(
          '${root.path}/victim',
        ).writeAsString('untouched');
        OutputCommitFailure? failure;
        String? substituted;
        try {
          await destination.commit(
            partial,
            hook: (phase) async {
              if (phase != 'after-preserve') return;
              final backup = await root.list().singleWhere(
                (f) => f.path.endsWith('.busydata-backup'),
              );
              substituted = backup.path;
              await backup.rename('${root.path}/kept');
              switch (kind) {
                case 'file':
                  await File(backup.path).writeAsString('other');
                case 'directory':
                  await Directory(backup.path).create();
                case 'link':
                  if (Platform.isWindows) {
                    final dir = await Directory(
                      '${root.path}/victim-directory',
                    ).create();
                    final result = await Process.run('cmd', [
                      '/d',
                      '/c',
                      'mklink',
                      '/J',
                      p.normalize(backup.path),
                      p.normalize(dir.path),
                    ]);
                    expect(
                      result.exitCode,
                      0,
                      reason: 'Windows junction fixture unavailable',
                    );
                  } else {
                    await Link(backup.path).create(victim.path);
                  }
              }
            },
          );
          fail('Unknown recovery must stop');
        } on OutputCommitFailure catch (error) {
          failure = error;
        }
        expect(failure.published, isFalse);
        expect(failure.recoveryPath, substituted);
        expect(failure.cleanup, isNotNull);
        expect(await File('${root.path}/kept').readAsString(), 'reviewed');
        expect(await victim.readAsString(), 'untouched');
        expect(await target.exists(), isFalse);
        if (kind == 'file') {
          expect(await File(substituted!).readAsString(), 'other');
        }
        if (kind == 'directory') {
          expect(await Directory(substituted!).exists(), isTrue);
        }
        if (kind == 'link') {
          expect(
            await FileSystemEntity.type(substituted!, followLinks: false),
            FileSystemEntityType.link,
          );
        }
        if (kind == 'missing') {
          expect(
            await FileSystemEntity.type(substituted!, followLinks: false),
            FileSystemEntityType.notFound,
          );
        }
        final owned = destination.capturePartial(partial);
        await destination.cleanupPartial(partial, expected: owned);
        expect(await partial.exists(), isFalse);
      },
    );
  }
  test(
    'partial substituted before native publication is not moved or deleted',
    () async {
      final destination = await OutputDestination.capture(target);
      final owned = destination.capturePartial(partial);
      await expectLater(
        destination.commit(
          partial,
          expected: owned,
          hook: (phase) async {
            if (phase == 'before-publish') {
              await partial.rename('${root.path}/kept');
              await partial.writeAsString('foreign');
            }
          },
        ),
        throwsA(isA<OutputCommitFailure>()),
      );
      await expectLater(
        destination.cleanupPartial(partial, expected: owned),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await partial.readAsString(), 'foreign');
      expect(await target.exists(), isFalse);
      expect(await File('${root.path}/kept').readAsString(), 'new output');
    },
  );
  test(
    'postpublication writer keeps its pathname and backup remains',
    () async {
      await target.writeAsString('reviewed');
      final destination = await OutputDestination.capture(target);
      await expectLater(
        destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'after-publish') {
              await target.rename('${root.path}/published');
              await target.writeAsString('later writer');
            }
          },
        ),
        throwsA(
          isA<OutputCommitFailure>().having(
            (e) => e.published,
            'published',
            isTrue,
          ),
        ),
      );
      expect(await target.readAsString(), 'later writer');
      expect(await File('${root.path}/published').readAsString(), 'new output');
      final backup = await root.list().singleWhere(
        (f) => f.path.endsWith('.busydata-backup'),
      );
      expect(await File(backup.path).readAsString(), 'reviewed');
      expect(await partial.exists(), isFalse);
    },
  );
  test(
    'late directory blocks new publication without recursive deletion',
    () async {
      final destination = await OutputDestination.capture(target);
      await expectLater(
        destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-publish') {
              await Directory(target.path).create();
              await File('${target.path}/child').writeAsString('child');
            }
          },
        ),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await File('${target.path}/child').readAsString(), 'child');
      expect(await partial.readAsString(), 'new output');
    },
  );

  for (final kind in ['file', 'link', 'directory']) {
    test('restore actual displaced $kind without content review', () async {
      String? displacedToken;
      await target.writeAsString('reviewed');
      final victim = File('${root.path}/victim');
      await victim.writeAsString('untouched');
      final destination = await OutputDestination.capture(target);
      await expectLater(
        destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-finalization') {
              await target.rename('${root.path}/reviewed');
              switch (kind) {
                case 'file':
                  await target.writeAsString('other');
                case 'link':
                  await Link(target.path).create(victim.path);
                case 'directory':
                  await Directory(target.path).create();
                  await File('${target.path}/child').writeAsString('child');
              }
              displacedToken = OutputDestination.currentEntryToken(target);
            }
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(OutputDestination.currentEntryToken(target), displacedToken);
      if (kind == 'link') {
        expect(await Link(target.path).target(), p.normalize(victim.path));
      } else if (kind == 'directory') {
        expect(await File('${target.path}/child').readAsString(), 'child');
      } else {
        expect(await target.readAsString(), 'other');
      }
      expect(await victim.readAsString(), 'untouched');
      expect(
        await root
            .list()
            .where((f) => f.path.endsWith('.busydata-backup'))
            .length,
        0,
      );
      expect(await partial.readAsString(), 'new output');
    });
  }

  test('native new-destination commit publishes complete bytes', () async {
    final destination = await OutputDestination.newDestination(target);
    await destination.commit(partial);
    expect(await target.readAsString(), 'new output');
    expect(await partial.exists(), isFalse);
  });
  test(
    'new-destination operation rejects existing file without changing bytes',
    () async {
      await target.writeAsString('original');
      await expectLater(
        OutputDestination.newDestination(target),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await target.readAsString(), 'original');
    },
  );
  test(
    'no-clobber native move rejects a destination appearing after final check',
    () async {
      final destination = await OutputDestination.newDestination(target);
      await expectLater(
        destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-publish') {
              await target.writeAsString('intervening file');
            }
          },
        ),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await target.readAsString(), 'intervening file');
      expect(await partial.readAsString(), 'new output');
    },
  );
  test(
    'reviewed replacement preserves the exact existing file then publishes',
    () async {
      await target.writeAsString('original');
      final destination = await OutputDestination.capture(target);
      var preserved = false;
      await destination.commit(
        partial,
        hook: (phase) async {
          if (phase == 'after-preserve') {
            preserved = true;
            expect(await target.exists(), isFalse);
            final backups = await root
                .list()
                .where((file) => file.path.endsWith('.busydata-backup'))
                .toList();
            expect(backups, hasLength(1));
            expect(await File(backups.single.path).readAsString(), 'original');
          }
        },
      );
      expect(preserved, isTrue);
      expect(await target.readAsString(), 'new output');
      expect(
        await root
            .list()
            .where((file) => file.path.endsWith('.busydata-backup'))
            .isEmpty,
        isTrue,
      );
    },
  );
  test('same-byte file replacement after review is a conflict', () async {
    await target.writeAsString('original');
    final destination = await OutputDestination.capture(target);
    await target.rename('${root.path}/original-elsewhere.sql');
    await target.writeAsString('original');
    await expectLater(
      destination.commit(partial),
      throwsA(isA<OutputCommitFailure>()),
    );
    expect(await target.readAsString(), 'original');
    expect(await partial.readAsString(), 'new output');
  });
  test('failed publication restores original into its empty name', () async {
    await target.writeAsString('original');
    final destination = await OutputDestination.capture(target);
    await expectLater(
      destination.commit(
        partial,
        hook: (phase) async {
          if (phase == 'before-publish') {
            throw const FileSystemException('injected unsupported atomic move');
          }
        },
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsString(), 'original');
    expect(await partial.readAsString(), 'new output');
  });
  test(
    'backup cleanup failure preserves publication and reports retained original',
    () async {
      await target.writeAsString('original');
      final destination = await OutputDestination.capture(target);
      await expectLater(
        destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-backup-cleanup') {
              throw const FileSystemException('injected cleanup failure');
            }
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.readAsString(), 'new output');
      expect(await partial.exists(), isFalse);
      final backup = await root.list().singleWhere(
        (f) => f.path.endsWith('.busydata-backup'),
      );
      expect(await File(backup.path).readAsString(), 'original');
    },
  );
  test(
    'intervening destination after preserve keeps prior file for recovery',
    () async {
      await target.writeAsString('original');
      final destination = await OutputDestination.capture(target);
      OutputCommitFailure? failure;
      try {
        await destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-publish') {
              await target.writeAsString('other actor');
            }
          },
        );
        fail('Intervening file was replaced');
      } on OutputCommitFailure catch (error) {
        failure = error;
      }
      expect(await target.readAsString(), 'other actor');
      expect(failure.recoveryPath, isNotNull);
      expect(await File(failure.recoveryPath!).readAsString(), 'original');
    },
  );
  test(
    'cross-directory partial cannot be moved by the commit abstraction',
    () async {
      final elsewhere = await root.createTemp('other-filesystem-policy-');
      final foreign = File('${elsewhere.path}/partial.tmp');
      await foreign.writeAsString('foreign partial');
      final destination = await OutputDestination.newDestination(target);
      await expectLater(
        destination.commit(foreign),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await target.exists(), isFalse);
      expect(await foreign.readAsString(), 'foreign partial');
    },
  );
  test(
    'symlink appearing at publication never redirects or replaces output',
    () async {
      final unrelated = File('${root.path}/unrelated.sql');
      await unrelated.writeAsString('unrelated');
      final destination = await OutputDestination.newDestination(target);
      await expectLater(
        destination.commit(
          partial,
          hook: (phase) async {
            if (phase == 'before-publish') {
              if (Platform.isWindows) {
                final directory = Directory('${root.path}/unrelated-directory');
                await directory.create();
                final result = await Process.run('cmd', [
                  '/d',
                  '/c',
                  'mklink',
                  '/J',
                  p.normalize(target.path),
                  p.normalize(directory.path),
                ]);
                expect(
                  result.exitCode,
                  0,
                  reason:
                      'Ordinary-user junction fixture must be available on native Windows',
                );
              } else {
                await Link(target.path).create(unrelated.path);
              }
            }
          },
        ),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await unrelated.readAsString(), 'unrelated');
      expect(await Link(target.path).exists(), isTrue);
    },
  );
  test(
    'parent replacement fails and never writes into replacement directory',
    () async {
      final parent = Directory('${root.path}/selected');
      await parent.create();
      final selected = File('${parent.path}/output.sql'),
          staged = File('${parent.path}/partial.tmp');
      await staged.writeAsString('new output');
      final destination = await OutputDestination.newDestination(selected);
      await parent.rename('${root.path}/original-parent');
      await parent.create();
      await expectLater(
        destination.commit(staged),
        throwsA(isA<OutputCommitFailure>()),
      );
      expect(await selected.exists(), isFalse);
      expect(
        await File('${root.path}/original-parent/partial.tmp').readAsString(),
        'new output',
      );
    },
  );
  test(
    'Unicode and long paths use the same native no-clobber primitive',
    () async {
      final directory = Directory('${root.path}/${'long-' * 35}漢😀');
      await directory.create();
      final destination = File('${directory.path}/SQL 漢😀.sql');
      await atomicWrite(destination, utf8.encode('exact 漢😀'));
      expect(await destination.readAsString(), 'exact 漢😀');
    },
  );
  test(
    'atomic failure/cancellation cleans its partial and leaves selected file intact',
    () async {
      await target.writeAsString('original');
      await expectLater(
        atomicWrite(
          target,
          utf8.encode('new output'),
          replaceFile: (_, _) async =>
              throw StateError('controlled cancellation'),
        ),
        throwsStateError,
      );
      expect(await target.readAsString(), 'original');
      expect(
        await root
            .list()
            .where(
              (file) =>
                  file.path.endsWith('.tmp') &&
                  p.normalize(file.path) != p.normalize(partial.path),
            )
            .isEmpty,
        isTrue,
      );
    },
  );
}
