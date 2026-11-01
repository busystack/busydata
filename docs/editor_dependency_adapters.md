# Official dependencies and editor extension boundaries

BusyData uses official unmodified Pub packages. The minimum compatibility changes
are `re_editor` 0.8.0 to 0.9.0 and `http2` 2.3.1 to 3.1.0. Flutter 3.47.5,
Dart 3.13.4, `grpc` 5.1.0, Fluent UI 4.16.1 and Yaru Window 0.2.2 retain their
pins. Dependency changes require the complete dependency and packaging gates.

The official [re_editor changelog](https://pub.dev/packages/re_editor/changelog)
identifies 0.9.0's Flutter compilation fix. Its public platform input client
implements `onFocusReceived`, which the pinned Flutter interface requires and
0.8.0 lacks. The official [http2 changelog](https://pub.dev/packages/http2/changelog)
and [upstream cancellation change](https://dart.googlesource.com/http/+/d6dd5ec9a24e66b386cc38d52c6d4e8decb26902)
identify the late canceled-stream header fix. The official 3.1.0 unknown-header
path does not by itself reject every unsolicited response-stream pattern as a
connection error. BusyData's transport contract additionally requires strict
response-stream identity validation through public transport APIs.
`private_rpc_transport.dart` applies this guard on the launch-owned TLS channel.
Its public transport delegate records the highest locally allocated request ID;
the incoming guard retains at most nine frame-header bytes and passes bodies
unchanged. Unsolicited response headers and server-push frames terminate the
connection with `PROTOCOL_ERROR`; late headers for a closed lower client stream
remain the official transport's responsibility. Other frame parsing, header
compression and flow control remain upstream. This follows
[RFC 9113 stream identity rules](https://www.rfc-editor.org/rfc/rfc9113.html#name-stream-identifiers).
Both cancellation and unsolicited-stream tests exercise that actual guard;
applying the dependency change alone does not satisfy acceptance. The production
factory has no cleartext or default-trust-store fallback and introduces no
execution retry. One owned physical `RawSocket` close handle covers TCP and TLS
negotiation under a 30-second deadline. Attempt epochs prevent late connection
completion from replacing a newer owner. Public raw TLS I/O limits each read to
64 KiB and queued output to 32 MiB; cancellation releases pending writes and an
open source subscription before close. This byte adapter does not implement TLS,
HTTP/2 framing semantics, SQL or retry policy.

The [official 3.1.0 source archive](https://pub.dev/api/archives/http2-3.1.0.tar.gz)
contains an unobserved derivative of the writer completion future in
`lib/src/connection.dart`. An outgoing sink error can consequently become an
uncaught asynchronous error even when the original completion is observed.
BusyData's public byte adapter records real terminal errors and emits them through
the incoming transport/RPC failure path before settling its writer pipe. Explicit
local cancellation also settles the pipe without a second error. Writer completion
means only that the local source was drained or cancelled; it never acknowledges
delivery, successful SQL execution or a successful RPC. Real read/write faults
still fail active calls. The official transport implementation remains unmodified.

`SqlEditorController` implements the public `CodeLineEditingController` interface.
It owns accepted immutable values, exact source, primary/secondary ranges,
composition, monotonic revisions, undo/redo and notifications. An unbound official
controller performs provisional public editing commands; a separate navigation
helper receives only accepted state. Neither helper forwards listeners or owns
BusyData history. All growth is admitted before publication, and helper histories
are cleared. Rejected native input leaves the accepted value unchanged. BusyData resynchronizes
its current platform connection through public Flutter APIs.

`SqlSource` preserves every UTF-16 boundary, including the interior of CRLF,
through explicit source-owned positions. Collapsed deletion from inside CRLF
removes that separator as one grapheme; explicit selected ranges keep their exact
UTF-16 endpoints through character, word and line deletion and undo/redo.
Immutable 256-row chunks share unchanged line projections and separator storage.
The current exact flat source is charged
as document text; historical flat strings are released. Composition and pending
clipboard/load state contribute workspace auxiliary charges. Document admission
replaces text and auxiliary reservations atomically. Undo/redo retention has its
own independent process-wide limit: an undo that cannot fit the current live
workspace must refuse without consuming its retained frame. The document and
workspace live-text limits remain unchanged. `preValue` is a borrowed
previous value during synchronous notifications and is null afterward; asynchronous
consumers capture bounded explicit state with their own revision checks.

Editor clipboard operations retain the existing exact UTF-8/NUL and size checks.
A native `PlatformException` becomes a structured clipboard-unavailable state with
localized feedback. A failed cut leaves accepted SQL, selection and history
unchanged; stale asynchronous replies cannot edit a newer source generation.
Unexpected programming failures retain their original exception identity.

`WorkbenchSqlEditor` mounts official read-only primary layout and hit testing.
`SqlEditorInput` owns the public Flutter `DeltaTextInputClient` connection and
validates an entire native batch's exact `oldText` chain and captured owner before
applying explicit replacement spans in one controller transaction. External editor
changes retire the platform client ID before a fresh connection is attached.
Accepted native states refresh the captured source/window owner without echoing
an equal editing state back to the IME. Remote-state tracking belongs to that
physical connection; a fresh connection, rejected input or changed surrounding
window receives the required synchronization. This follows the pinned public
[`EditableText` remote-state check](https://github.com/flutter/flutter/blob/6a19cca56475dbfba1478ee68d7bd0c2ef891da1/packages/flutter/lib/src/widgets/editable_text.dart#L4016).
The pinned Linux [input handler](https://github.com/flutter/flutter/blob/6a19cca56475dbfba1478ee68d7bd0c2ef891da1/engine/src/flutter/shell/platform/linux/fl_text_input_handler.cc#L290)
replaces its native text model on `setEditingState`; an unnecessary echo can
retire the composing range needed by a later native preedit cancellation.
Rejected or stale input cannot replace current SQL or its undo/redo state. The
first-party layer also owns extra-range painting, the visible caret's reduced-motion
behavior, semantic visible-line actions, dynamic shortcuts and typed rejection
feedback. All editing shortcut actions check the current owner and actual view
permission; the backing layout widget's read-only setting does not define product
editability. Accepted preedit commits without changing its text when its owning
focus, writable view or controller retires, preserving a single undo unit.
Appearance and geometry changes preserve the same native connection/composition.
Platform close notifications clear Flutter's connection only while still owned;
desktop newline actions do not duplicate an editor key or native delta.
Public indicator paragraphs already contain viewport scroll offsets;
caret and selection geometry adds only the viewport and paragraph origins.
Geometry is unavailable when editor or scroll ownership is stale. Completion uses
captured Java responses and the same public geometry. Editor adapters do not parse
database semantics, access JDBC or authorize SQL execution.

The complete official-source gate uses a project-owned Pub cache and a short
owned temporary directory, preserving the shared user cache. It validates fresh
Pub metadata, exact locked version/archive identity, archive SHA256, every
published regular file and absence of injected files. Only explicitly named
Pub-generated package metadata is exempt when absent from an archive. Unknown
path/Git package sources fail closed. SDK packages are classified separately.
Package archive comparisons do not certify SDK bytes; the same verification
entrypoint also checks the SDK source revision and installed runtime/cache bytes
against official publisher identities. Package inventory revalidates the combined
report and source bytes before bundling licenses and dependency provenance.

Verification bounds are 512 packages, 128 MiB per compressed archive and member,
2 GiB expanded bytes and 16,384 archive members per package, and a 20-minute
verification deadline. Archives are streamed and hashed; unsafe paths, links,
duplicates, corrupt caches and incomplete artifacts fail explicitly. These are
build verification bounds and do not enlarge editor, clipboard, RPC, retained
result or process memory budgets. Reports and downloaded archives belong under
ignored `build/official-dependencies/`; source-bound aggregate evidence records
actual results. Component tests and Linux rendering do not certify native Windows
or installed strict-Snap acceptance.
