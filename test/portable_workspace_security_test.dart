import 'dart:convert';
import 'dart:io';
import 'dart:ffi';

import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/common/output_commit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<void> directoryAlias(String link, String target) async {
  if (Platform.isWindows) {
    final result = await Process.run('cmd', [
      '/d',
      '/c',
      'mklink',
      '/J',
      p.normalize(link),
      p.normalize(target),
    ]);
    expect(
      result.exitCode,
      0,
      reason:
          'Windows workspace junction fixture unavailable: ${result.stderr}',
    );
  } else {
    await Link(link).create(target);
  }
}

int handleCount() {
  if (Platform.isLinux) return Directory('/proc/self/fd').listSync().length;
  final library = DynamicLibrary.open('kernel32.dll');
  final memory = library
      .lookupFunction<
        Pointer<Void> Function(Uint32, IntPtr),
        Pointer<Void> Function(int, int)
      >('LocalAlloc')(0, 4);
  try {
    final status = library
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)
        >('GetProcessHandleCount')(-1, memory.cast<Uint32>());
    expect(status, isNot(0));
    return memory.cast<Uint32>().value;
  } finally {
    library.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)
    >('LocalFree')(memory);
  }
}

class WorkspaceFixture {
  WorkspaceFixture(
    this.outer,
    this.portable,
    this.nested,
    this.outside,
    this.sql,
    this.secret,
    this.manifest,
  );
  final Directory outer, portable, nested, outside;
  final File sql, secret, manifest;
  final reference = 'nested/deeper/資料😀.sql';
  static const authorized = "SELECT 'authorized 漢😀';",
      outsideBytes = 'SELECT outside_secret;';
  static Future<WorkspaceFixture> create() async {
    final outer = await Directory.systemTemp.createTemp(
      'busydata-confined-native-',
    );
    final portable = await Directory('${outer.path}/portable').create();
    final nested = await Directory('${portable.path}/nested').create();
    await Directory('${nested.path}/deeper').create();
    final outside = await Directory('${outer.path}/outside').create();
    await Directory('${outside.path}/deeper').create();
    final sql = File('${nested.path}/deeper/資料😀.sql'),
        secret = File('${outside.path}/deeper/資料😀.sql');
    await sql.writeAsString(authorized);
    await secret.writeAsString(outsideBytes);
    final result = WorkspaceFixture(
      outer,
      portable,
      nested,
      outside,
      sql,
      secret,
      File('${portable.path}/workspace.busydata'),
    );
    await result.writeManifest([result.reference]);
    return result;
  }

  Future<void> writeManifest(List<String> references) => manifest.writeAsString(
    jsonEncode({
      'version': 1,
      'documents': [
        for (final reference in references)
          {'path': reference, 'profileId': null},
      ],
    }),
  );
}

void main() {
  for (final phase in [
    'root-acquired',
    'before-open',
    'ancestor-acquired',
    'file-acquired',
  ]) {
    test(
      'native $phase substitution reads only the authorized handle',
      () async {
        final f = await WorkspaceFixture.create();
        final loaded = <SqlDocument>[], readTokens = <String>[];
        final token = OutputDestination.currentEntryToken(f.sql)!;
        var attempted = false, prevented = false;
        try {
          try {
            loaded.addAll(
              await PortableWorkspace.load(
                f.manifest,
                hook: (boundary, reference) async {
                  if (reference == f.reference &&
                      boundary.startsWith('read-handle:')) {
                    readTokens.add(boundary.substring(12));
                  }
                  if (boundary != phase ||
                      attempted ||
                      (phase != 'root-acquired' && reference != f.reference)) {
                    return;
                  }
                  attempted = true;
                  try {
                    if (phase == 'root-acquired') {
                      await f.portable.rename('${f.outer.path}/held-root');
                      await directoryAlias(f.portable.path, f.outside.path);
                    } else if (phase == 'file-acquired') {
                      await f.sql.rename('${f.sql.path}.held');
                      if (Platform.isWindows) {
                        await directoryAlias(f.sql.path, f.outside.path);
                      } else {
                        await Link(f.sql.path).create(f.secret.path);
                      }
                    } else {
                      await f.nested.rename('${f.portable.path}/held-nested');
                      await directoryAlias(f.nested.path, f.outside.path);
                    }
                  } on FileSystemException catch (error) {
                    expect(Platform.isWindows, isTrue, reason: '$error');
                    expect(error.osError?.errorCode, anyOf(5, 32, 33));
                    prevented = true;
                  }
                },
              ),
            );
          } on FileSystemException {
            /* Confinement or association rejected. */
          } on FormatException {
            /* Confinement rejected. */
          }
          expect(attempted, isTrue);
          expect(readTokens.every((value) => value == token), isTrue);
          if (phase == 'file-acquired' || phase == 'root-acquired') {
            expect(readTokens, isNotEmpty);
          }
          if (prevented) {
            expect(
              loaded,
              hasLength(1),
              reason:
                  'The Windows lock must preserve a usable authorized workspace',
            );
          }
          for (final document in loaded) {
            expect(document.editor.text, WorkspaceFixture.authorized);
          }
          expect(await f.secret.readAsString(), WorkspaceFixture.outsideBytes);
        } finally {
          for (final document in loaded) {
            document.dispose();
          }
          await f.outer.delete(recursive: true);
        }
      },
    );
  }

  for (final kind in ['link', 'directory', if (Platform.isLinux) 'fifo']) {
    test(
      'native final open prevents $kind substitution or rejects it before reading',
      () async {
        final f = await WorkspaceFixture.create();
        final loaded = <SqlDocument>[];
        var attempted = false, prevented = false, reads = 0;
        Object? failure;
        try {
          // Establish that the ordinary fixture can rename this exact file
          // before the native reader holds its directory/session handles.
          final control = await f.sql.rename('${f.sql.path}.control');
          await control.rename(f.sql.path);
          try {
            loaded.addAll(
              await PortableWorkspace.load(
                f.manifest,
                hook: (phase, reference) async {
                  if (reference != f.reference) return;
                  if (phase.startsWith('read-handle:')) reads++;
                  if (phase != 'before-final-open') return;
                  attempted = true;
                  try {
                    await f.sql.rename('${f.sql.path}.held');
                  } on FileSystemException catch (error) {
                    expect(Platform.isWindows, isTrue);
                    expect(error.osError?.errorCode, anyOf(5, 32, 33));
                    prevented = true;
                    return;
                  }
                  if (kind == 'directory') {
                    await Directory(f.sql.path).create();
                    await File('${f.sql.path}/child').writeAsString('retained');
                  } else if (kind == 'fifo') {
                    final result = await Process.run('mkfifo', [f.sql.path]);
                    expect(
                      result.exitCode,
                      0,
                      reason: 'FIFO fixture unavailable',
                    );
                  } else if (Platform.isWindows) {
                    await directoryAlias(f.sql.path, f.outside.path);
                  } else {
                    await Link(f.sql.path).create(f.secret.path);
                  }
                },
              ),
            );
          } on FileSystemException catch (error) {
            failure = error;
          } on FormatException catch (error) {
            failure = error;
          }
          expect(attempted, isTrue);
          expect(await f.secret.readAsString(), WorkspaceFixture.outsideBytes);
          if (prevented) {
            expect(failure, isNull);
            expect(loaded, hasLength(1));
            expect(loaded.single.editor.text, WorkspaceFixture.authorized);
            expect(reads, greaterThan(0));
            expect(await f.sql.readAsString(), WorkspaceFixture.authorized);
            return;
          }
          expect(failure, isNotNull);
          expect(loaded, isEmpty);
          expect(reads, 0);
          expect(
            await File('${f.sql.path}.held').readAsString(),
            WorkspaceFixture.authorized,
          );
          if (kind == 'directory') {
            expect(
              await File('${f.sql.path}/child').readAsString(),
              'retained',
            );
          }
        } finally {
          for (final document in loaded) {
            document.dispose();
          }
          await f.outer.delete(recursive: true);
        }
      },
    );
  }

  test(
    'nested Unicode and in-root ancestor aliases use the same native reader',
    () async {
      final f = await WorkspaceFixture.create();
      final loaded = <SqlDocument>[];
      try {
        await directoryAlias('${f.portable.path}/別名😀', f.nested.path);
        await f.writeManifest(['別名😀/deeper/資料😀.sql']);
        loaded.addAll(await PortableWorkspace.load(f.manifest));
        expect(loaded.single.editor.text, WorkspaceFixture.authorized);
        expect(
          loaded.single.diskEntryToken,
          OutputDestination.currentEntryToken(f.sql),
        );
        await PortableWorkspace.save(f.manifest, loaded);
        expect(
          (jsonDecode(await f.manifest.readAsString())['documents'] as List)
              .single['path'],
          '別名😀/deeper/資料😀.sql',
        );
      } finally {
        for (final document in loaded) {
          document.dispose();
        }
        await f.outer.delete(recursive: true);
      }
    },
  );

  test(
    'growing opened file obeys original byte limit or Windows write protection',
    () async {
      final f = await WorkspaceFixture.create();
      var grew = false, prevented = false;
      final loaded = <SqlDocument>[];
      try {
        try {
          loaded.addAll(
            await PortableWorkspace.load(
              f.manifest,
              hook: (phase, reference) async {
                if (phase != 'file-acquired' || reference != f.reference) {
                  return;
                }
                try {
                  final writer = await f.sql.open(mode: FileMode.append);
                  try {
                    await writer.truncate(maxSqlFileBytes + 1);
                    grew = true;
                  } finally {
                    await writer.close();
                  }
                } on FileSystemException catch (error) {
                  expect(Platform.isWindows, isTrue);
                  expect(error.osError?.errorCode, anyOf(5, 32, 33));
                  prevented = true;
                }
              },
            ),
          );
          expect(prevented, isTrue);
        } on DocumentResourceLimit {
          expect(grew, isTrue);
        }
        if (prevented) {
          expect(loaded.single.editor.text, WorkspaceFixture.authorized);
        }
      } finally {
        for (final document in loaded) {
          document.dispose();
        }
        await f.outer.delete(recursive: true);
      }
    },
  );

  test(
    'cancelled and rejected reads repeatedly release native handles',
    () async {
      final f = await WorkspaceFixture.create();
      try {
        final warm = await PortableWorkspace.load(f.manifest);
        for (final d in warm) {
          d.dispose();
        }
        final count = handleCount();
        for (var i = 0; i < 24; i++) {
          final control = WorkspaceReadControl();
          await expectLater(
            PortableWorkspace.load(
              f.manifest,
              control: control,
              hook: (phase, reference) async {
                if (reference == f.reference && phase == 'before-read') {
                  control.cancel();
                }
              },
            ),
            throwsA(isA<WorkspaceReadCancelled>()),
          );
          await f.writeManifest([f.reference, 'missing.sql']);
          await expectLater(
            PortableWorkspace.load(f.manifest),
            throwsA(isA<FileSystemException>()),
          );
          await f.writeManifest([f.reference]);
          if (i < 3) {
            await f.sql.writeAsBytes([0xff, 0xfe]);
            await expectLater(
              PortableWorkspace.load(f.manifest),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.source,
                  'source contents omitted',
                  isNull,
                ),
              ),
            );
            await f.sql.writeAsString(WorkspaceFixture.authorized);
          }
        }
        expect(handleCount(), lessThanOrEqualTo(count + 2));
        final last = await PortableWorkspace.load(f.manifest);
        expect(last.single.editor.text, WorkspaceFixture.authorized);
        last.single.dispose();
      } finally {
        await f.outer.delete(recursive: true);
      }
    },
  );

  test(
    'complete lexical validation precedes SQL reading and failed load leaves tabs intact',
    () async {
      final f = await WorkspaceFixture.create();
      final model = WorkbenchModel(f.outer)
        ..draftRecovery = false
        ..newDocument(text: 'existing draft');
      final original = model.document;
      var reads = 0;
      try {
        await f.writeManifest([f.reference, '../outside.sql']);
        await expectLater(
          PortableWorkspace.load(
            f.manifest,
            hook: (phase, reference) async {
              if (reference.endsWith('.sql') &&
                  phase.startsWith('read-handle:')) {
                reads++;
              }
            },
          ).then(model.adoptDocuments),
          throwsA(isA<FormatException>()),
        );
        expect(reads, 0);
        await f.writeManifest([f.reference, 'missing.sql']);
        await expectLater(
          PortableWorkspace.load(f.manifest).then(model.adoptDocuments),
          throwsA(isA<FileSystemException>()),
        );
        expect(model.documents, [original]);
        expect(original.editor.text, 'existing draft');
        expect(model.sessions, isEmpty);
      } finally {
        model.dispose();
        await f.outer.delete(recursive: true);
      }
    },
  );

  test(
    'loaded content cannot authorize a different same-byte save target',
    () async {
      final f = await WorkspaceFixture.create();
      final loaded = await PortableWorkspace.load(f.manifest);
      try {
        await f.sql.rename('${f.sql.path}.original');
        await f.sql.writeAsString(WorkspaceFixture.authorized);
        loaded.single.editor.selectAll();
        loaded.single.editor.replaceSelection('edited');
        await expectLater(loaded.single.save(f.sql.path), throwsStateError);
        expect(await f.sql.readAsString(), WorkspaceFixture.authorized);
        expect(loaded.single.dirty, isTrue);
      } finally {
        for (final document in loaded) {
          document.dispose();
        }
        await f.outer.delete(recursive: true);
      }
    },
  );
  test(
    'ancestor replaced after validation never supplies outside bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-workspace-race-',
      );
      final workspaceRoot = await Directory('${root.path}/portable').create();
      final nested = await Directory('${workspaceRoot.path}/nested').create();
      final outside = await Directory('${root.path}/outside').create();
      await File(
        '${nested.path}/query.sql',
      ).writeAsString('SELECT authorized;');
      await File(
        '${outside.path}/query.sql',
      ).writeAsString('SELECT outside_secret;');
      final workspace = File('${workspaceRoot.path}/workspace.busydata');
      await workspace.writeAsString(
        jsonEncode({
          'version': 1,
          'documents': [
            {'path': 'nested/query.sql', 'profileId': null},
          ],
        }),
      );
      final loaded = <SqlDocument>[];
      try {
        try {
          loaded.addAll(
            await PortableWorkspace.load(
              workspace,
              hook: (phase, reference) async {
                if (phase == 'before-open' && reference == 'nested/query.sql') {
                  await nested.rename('${workspaceRoot.path}/moved');
                  if (Platform.isWindows) {
                    final result = await Process.run('cmd', [
                      '/d',
                      '/c',
                      'mklink',
                      '/J',
                      p.normalize(nested.path),
                      p.normalize(outside.path),
                    ]);
                    expect(
                      result.exitCode,
                      0,
                      reason: 'Native junction fixture unavailable',
                    );
                  } else {
                    await Link(nested.path).create(outside.path);
                  }
                }
              },
            ),
          );
        } on FileSystemException {
          /* Safe rejection. */
        } on FormatException {
          /* Safe rejection. */
        }
        for (final document in loaded) {
          expect(document.editor.text, 'SELECT authorized;');
        }
      } finally {
        for (final document in loaded) {
          document.dispose();
        }
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'portable workspace save rejects documents outside its directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-workspace-save-',
      );
      final workspaceRoot = await Directory('${root.path}/portable').create();
      final outside = File('${root.path}/private.sql');
      final workspace = File('${workspaceRoot.path}/workspace.busydata');
      final document = SqlDocument(text: 'SELECT 1;', path: outside.path);
      try {
        await outside.writeAsString('SELECT 1;');
        await expectLater(
          PortableWorkspace.save(workspace, [document]),
          throwsA(isA<FormatException>()),
        );
        expect(await workspace.exists(), isFalse);
        expect(await outside.readAsString(), 'SELECT 1;');
      } finally {
        document.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'portable loader rejects traversal, absolute and foreign path forms',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-workspace-path-',
      );
      final workspaceRoot = await Directory('${root.path}/portable').create();
      final workspace = File('${workspaceRoot.path}/workspace.busydata');
      final outside = File('${root.path}/private.sql');
      await outside.writeAsString('SELECT private_data;');
      const unsafe = <String>[
        '../private.sql',
        'nested/../../private.sql',
        '/private/query.sql',
        r'C:/private/query.sql',
        r'C:\private\query.sql',
        r'\\server\share\query.sql',
        r'nested\../query.sql',
        'nested//query.sql',
        './query.sql',
      ];
      try {
        for (final reference in unsafe) {
          await workspace.writeAsString(
            jsonEncode({
              'version': 1,
              'documents': [
                {'path': reference, 'profileId': null},
              ],
            }),
          );
          await expectLater(
            PortableWorkspace.load(workspace),
            throwsA(isA<FormatException>()),
            reason: reference,
          );
        }
        expect(await outside.readAsString(), 'SELECT private_data;');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'portable loader rejects final links and linked directory ancestors',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-workspace-link-',
      );
      final workspaceRoot = await Directory('${root.path}/portable').create();
      final outsideRoot = await Directory('${root.path}/outside').create();
      final outside = File('${outsideRoot.path}/private.sql');
      final workspace = File('${workspaceRoot.path}/workspace.busydata');
      await outside.writeAsString('SELECT private_data;');
      try {
        await directoryAlias('${workspaceRoot.path}/linked', outsideRoot.path);
        if (Platform.isWindows) {
          await directoryAlias(
            '${workspaceRoot.path}/final.sql',
            outsideRoot.path,
          );
        } else {
          await Link('${workspaceRoot.path}/final.sql').create(outside.path);
        }
        final linkedDocument = SqlDocument(
          text: 'SELECT private_data;',
          path: '${workspaceRoot.path}/linked/private.sql',
        );
        await expectLater(
          PortableWorkspace.save(workspace, [linkedDocument]),
          throwsA(isA<FormatException>()),
        );
        linkedDocument.dispose();
        for (final reference in ['linked/private.sql', 'final.sql']) {
          await workspace.writeAsString(
            jsonEncode({
              'version': 1,
              'documents': [
                {'path': reference, 'profileId': null},
              ],
            }),
          );
          await expectLater(
            PortableWorkspace.load(workspace),
            throwsA(anyOf(isA<FormatException>(), isA<FileSystemException>())),
            reason: reference,
          );
        }
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'valid nested SQL files round trip with canonical portable paths',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-workspace-valid-',
      );
      final nested = await Directory(
        '${root.path}/nested/deeper',
      ).create(recursive: true);
      final sql = File('${nested.path}/query.sql');
      final workspace = File('${root.path}/workspace.busydata');
      final document = SqlDocument(text: 'SELECT \'漢😀\';', path: sql.path);
      final loaded = <SqlDocument>[];
      try {
        await sql.writeAsString(document.editor.text);
        await PortableWorkspace.save(workspace, [document]);
        final encoded =
            jsonDecode(await workspace.readAsString()) as Map<String, dynamic>;
        expect(
          ((encoded['documents'] as List).single
              as Map<String, dynamic>)['path'],
          'nested/deeper/query.sql',
        );
        loaded.addAll(await PortableWorkspace.load(workspace));
        expect(loaded.single.path, p.normalize(sql.path));
        expect(loaded.single.editor.text, document.editor.text);
        expect(loaded.single.dirty, isFalse);
      } finally {
        document.dispose();
        for (final restored in loaded) {
          restored.dispose();
        }
        await root.delete(recursive: true);
      }
    },
  );
}
