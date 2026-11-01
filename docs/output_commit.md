# Destination integrity

Java owns database exports and native backup output. Flutter owns SQL documents,
workspace/recovery files and diagram/schema exports. Each owner uses its shared
output-commit helper; feature implementations do not construct replacement moves.
The helpers follow the same no-clobber and reviewed replacement policy.

| Output owner | Publication policy |
| --- | --- |
| Java direct-query/retained-result/full-value exports and native dump | OutputCommit, exact approved identity, private same-filesystem partial, platform no-clobber moves and centralized cleanup |
| Java restore | Immutable selected-source snapshot and selected native input; no user-output replacement |
| Result/snapshot spools | Private exclusive UUID files with quota, leases and cleanup; no selected-destination replacement |
| Flutter SQL/workspace, snapshots, diagrams and notes | OutputDestination, captured identity, exclusive private partial and reviewed no-clobber publication; captured document revisions remain Flutter-owned |
| Flutter recovery/settings | Shared atomic writer in owned support storage with explicit revisions and bounded records; corruption quarantine uses an owned UUID backup |
| Encrypted portal records | Private serialized replacement at a fixed application support path; no user-selected destination |
| Build identities/inventories | Generated replacement in owned build/target directories; run/source checks remain required |
| Canonical source/evidence archives | Exclusive partials and hard-link no-clobber publication, safe extraction, exact hashes/sizes/member completeness; existing archives never replaced |
| Third-party client/source downloads | Pinned checksum-validated generated-cache publication; notices and corresponding-source provenance retained |
| Native backup test copies | Disposable fixture/evidence files in test storage; never a product output finalizer |

## Publication phases

Reviewed content, displaced directory entry, and produced partial are separate
identities. Entry identity is no-follow and accepts files, links and directories;
only content review requires an ordinary file and a bounded hash. Record every
successful move before a hook, hash, cancellation check or further mutation.

| Phase | Mismatch | Exception / cancellation | Cleanup failure | Production-path tests |
| --- | --- | --- | --- | --- |
| Prepared | Leave destination untouched | Leave destination untouched; release handles | Delete only owned partial, report its retained name on failure | Late file/link/directory; parent/partial substitution; unsupported primitive |
| Preserved but unverified | Restore the actual displaced entry, regardless of approval, if its identity is established | Same bounded restoration; never rehash during compensation | Retain/report recovery and partial independently | Late file/link/directory; throwing verification; cancellation |
| Preserved and verified | Stop publication; restore through no-replace when recovery still belongs to this operation | Same restoration into vacant destination | Report actual restoration/partial cleanup failures and every retained artifact | Publication failure; competing restore; changed/missing recovery |
| Published | Never mutate a competing destination; retain recovery and report uncertainty | Publication remains recorded; do not roll back housekeeping or replay SQL/export | Preserve published output and remaining recovery; explicitly report publication | Cleanup denied; writer after publication; parent change |
| Finished | No continuing ownership claim over selected pathname | Release all handles | Report unresolved release error without claiming nothing was written | Normal create/replacement; revision-safe save/close |

Portable read tests bind manifest and SQL reads to one held root and verified
native file handles. Boundaries include root acquisition, preliminary alias
resolution, ancestor traversal, final open, and native content read. Replacement
may be rejected/locked or an already authorized handle read; outside SQL bytes
are never allowed. Retain lexical/size/count/Unicode/aggregate limits and atomic
workspace adoption. Windows junction tests must execute on Windows or be recorded
as unavailable; Linux results do not certify Windows.

Flutter's `OutputDestination` captures the normalized selected path, every parent
directory's native identity, the existing regular file's identity/size/modified
time and a bounded content SHA-256. Snapshot, diagram SVG/PNG and notes exports
show the existing Yaru/Fluent replacement dialog before supplying that capture to
`atomicWrite`. SQL saves retain their existing selected destination, external
change review, captured revision/bytes, serialized completion and close guards.

Partials have an exclusive UUID name in the selected parent. A native held file
handle checks its identity and rejects links before writing; Linux uses owner-only
permissions. Writes use a bounded native buffer in a Dart worker isolate and are
flushed before publication. SQL save admission accounts for the worker byte copy
within the unchanged 64MiB capture budget. Filesystem errors remain typed
`FileSystemException` errors for the established save/close policy.

Linux publication uses `renameat2(RENAME_NOREPLACE)` against a verified held parent
descriptor. Windows uses `MoveFileExW(MOVEFILE_WRITE_THROUGH)` without replacement
or cross-device copy flags. Windows parent handles exclude delete sharing and
reject reparse points. Unsupported primitives, cross-directory partials and changed
parents fail explicitly; no unconditional rename or copy fallback is attempted.

A reviewed existing file is first moved to a unique sibling backup with the same
atomic no-clobber primitive and then checked against its captured identity and hash.
If the moved file is not the reviewed file, BusyData restores it only into the now
absent selected name; it never exchanges that file for BusyData output. The new file
is published using the same no-clobber primitive. A writer appearing after
preservation keeps the selected pathname, publication fails, and the reviewed
original remains at the reported recovery path. Cleanup and recovery never overwrite
a concurrent actor's file. A reported failure is not permission to close a dirty SQL
document. Cleanup refuses changed parents, links or replacement partial identities.

Native filesystem primitives cannot provide a universal conditional replacement
transaction against arbitrary privileged concurrent writers. The application
detects meaningful races, preserves retained originals and reports ambiguity. It
does not promise secure erasure. Windows native output/reparse/long-path execution
still requires the genuine Windows acceptance run; Linux tests are not that evidence.

`test/output_commit_test.dart` and Java `OutputCommitTest` cover absent/existing destinations, late creation,
same-byte replacement, reviewed replacement, publication/cleanup failure and safe
recovery, symlink/junction races, changed parents, cross-directory rejection,
Unicode/long paths and abandoned partial cleanup. `output_review_dialog_test.dart`
uses the existing Linux and Windows controls to test cancellation and destination
changes during review. Existing F2 delayed-I/O/save/recovery/close regressions remain.

Both owners distinguish the reviewed content from the no-follow displaced
entry and the produced file. A failed verification, including cancellation,
restores the displaced file/link/directory by identity and no-replace move without
rehashing it. Changed or missing recovery entries stop automatic mutation.
Partials are cleaned independently of retained recovery and ownership failures
report staging locations. After publication, cleanup failures and late writers
leave the published destination alone. Java exposes `RecoveryRequired.published`
and `OUTPUT_PUBLISHED_RECOVERY_REQUIRED`; Flutter exposes
`OutputCommitFailure.published`. Native job messages include the filesystem reason
and recovery location. They never automatically resubmit SQL or an export. SQL
save completion still requires success: unresolved cleanup leaves saved revision
metadata unchanged, newer edits dirty, and close protected.

Portable workspaces retain canonical forward-slash relative references. The
complete manifest is lexically validated before any SQL content open. Save uses
the same reference policy and confined native opening before writing a manifest.
`NativeWorkspaceRoot` in the existing Flutter FFI library owns the root, ancestor
and file handles on a worker isolate; database sessions are not involved.

On Linux, authoritative opens use `openat2` with `RESOLVE_BENEATH`,
`RESOLVE_NO_MAGICLINKS`, `RESOLVE_NO_SYMLINKS`, final `O_NOFOLLOW` and nonblocking
inspection. The flags are available in the Linux 5.6 contract; newer regular-file
flags are not required. An `EAGAIN`, unavailable syscall or filesystem denial is
a reported failure, without an unrestricted fallback. In-root ancestor aliases
are resolved only to candidate relative parent paths; each authoritative open
starts again beneath the held root. The original final filename is retained.

Windows opens one component at a time using `NtCreateFile.RootDirectory` and
`FILE_OPEN_REPARSE_POINT`. Held directory and file handles exclude write/delete
sharing, and each opened component is inspected before use. Native structures
assert the approved x64 ABI; NTSTATUS is converted through
`RtlNtStatusToDosError`, file handles require `FILE_TYPE_DISK`, and successful
handles are closed on rejection as well as success. A denied primitive reports
a runtime limitation. Genuine native Windows execution remains required; Linux compilation does not
certify it.

Manifest and SQL content are read through their verified handles in at most
64KiB blocks, with unchanged 1MiB manifest, 24MB document, 32MiB aggregate,
100-document, Unicode, UTF-16 and editor-line limits. Cancellation is checked
between bounded operations and all native resources unwind before returning.
Text and stored hashes derive from those bytes. Before adoption, metadata checks
reject detached roots and substituted targets; stored entry tokens also reject
same-byte/different-file replacements at a later save. Explicit ordinary SQL-file
opening remains a separate workflow. No handle is closed and reopened by name
to read or hash portable content.

`portable_workspace_security_test.dart` instruments the actual native read
boundary with the identity of the descriptor passed to `read`/`ReadFile`. It
checks root, ancestor and final-entry substitution; final links/directories/FIFOs;
opened-file replacement; nested Unicode and in-root aliases; growth; cancellation;
repeated failure/decoding cleanup; and all-or-nothing adoption. Windows junction
fixtures execute on Windows, including assertions when sharing locks prevent a
race. Content-denial testing uses POSIX permissions on Linux and an open Windows
writer with compatible metadata/delete sharing on Windows; it is not skipped.
The FIFO fixture is Linux-only because a Windows disk directory has no POSIX FIFO.

## Failure boundaries

| Boundary | Owned state and tested exit |
| --- | --- |
| Parent acquisition, staging allocation/flush and initial review | Prepared; close every acquired handle; delete only identified application staging. Parent/partial conflicts, unsupported primitives and abandoned writes are covered. |
| Preservation move, displaced identity capture, hook, content hash and permission restriction | Move is recorded first as preserved-unverified. Missing/changed entry identity retains uncertainty; all other failures attempt entry-only restoration. File/link/directory, denied hashing and interrupted hashing are covered. |
| Publication hook, parent/partial/recovery check and no-replace move | Preserved-verified or prepared. Restore through held parent on failure; a late destination wins its pathname. Vacant-publication failure and competing restoration are covered. |
| Published hook, output check and recovery deletion | Published is recorded before any fallible work. No rollback; preserve recovery on uncertainty or cleanup failure. Late writer, cleanup denial, parent movement and dirty-close tests are covered. |
| Staging cleanup and handle release | Cleanup is independent of recovery. Identity/type mismatch prevents deletion; primary and cleanup failures retain their paths. No recursive directory deletion or link-target operation is used. |
| Reader root acquisition, alias candidate resolution and native component opens | Each handle enters its owner before inspection/hooks. Failed root acquisition unwinds its chain; failed traversal/final validation unwinds acquired ancestors and file. Substitution tests exercise the production opens. |
| Native buffer allocation/read, cancellation, quota/UTF-8/editor validation and adoption | File buffer/handle closes in `finally`; root closes in the worker's outer `finally`; isolate event ports close on every result. No documents enter the workbench until the cohort succeeds. Repeated cancellation/missing/decode failures and current-tab preservation are tested. |

Java query, retained-result/value exports and native backups use
`OutputCommit.open`. Flutter SQL, portable workspace, draft recovery and
snapshot/diagram/schema/notes exports use `atomicWrite`/`OutputDestination`.

Native API references: [Linux no-replace rename](https://man7.org/linux/man-pages/man2/rename.2.html),
[Java move options](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/Files.html),
[Dart file link behavior](https://api.dart.dev/dart-io/File-class.html),
[Linux confined opens](https://man7.org/linux/man-pages/man2/openat2.2.html),
[Windows relative opens](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile).
