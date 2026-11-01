# Native transport and accessibility requirements

Native clients remain official and unmodified. PostgreSQL uses its documented
`PGHOSTADDR` transport address with the reviewed original hostname. MySQL and
MariaDB transfers through an owned SSH tunnel use a BusyData stream relay:
private Unix socket on Linux, or a private Windows named pipe owned by the
selected client's launcher. No resolver imports, client memory, loader hooks,
SDK files, or upstream binaries are patched.

The relay negotiates the reviewed TLS policy on the same upstream connection
through the owned SSH forwarding port. Its private JSSE context retains the
original destination for hostname verification, selected roots and client
identity. It translates only the documented initial SSL request and associated
authentication packet sequence numbers. Command-phase data is streamed unchanged
with bounded buffers; SQL and passwords never enter diagnostics. The native
client uses its supported local IPC transport with local TLS disabled; verified
TLS is enforced by the relay before forwarding its authentication response.
There is no unverified/plaintext fallback for a required policy. MySQL's explicit
PREFERRED behavior and MariaDB's existing disabled default remain distinct.
Existing native TLS capability checks remain authoritative; the relay does not
silently admit an unsupported selected policy or client-key format.

The Windows launcher uses only documented pipe, process and job APIs. It accepts
a fresh operation-bound pipe name, loopback bridge and authentication nonce from
the parent, removes those variables before starting the official client, limits
handle inheritance to standard streams, applies a current-user-only pipe ACL,
rejects remote connections and competing first instances, verifies the actual
pipe client PID, and owns a kill-on-close job. Reviewed Unicode arguments remain
literal. Cancellation closes both relay ends and the owned child; it never
changes host name-service registrations or other applications. Pre-existing
endpoint options cannot replace the generated private transport, while an
option-shaped database identifier after `--` remains literal data.

Relay authentication and completion must be acknowledged before a dump is
published or native success is acknowledged. Nonzero client exits retain their
typed, redacted native diagnostics. Restore can partially commit; a failed or
interrupted restore remains subject to unknown-outcome quarantine and is never
replayed automatically. Review, exact session/source ownership and single-use
approval checks precede execution.

Native Windows CTest requires 25 cases: the 20 private-pipe cases plus five
process/stdio/handle cases. They cover literal Unicode/quoted arguments, exact
binary stdio, sequential/concurrent isolation, invalid or missing handoffs, failure
propagation, launcher operation without a sibling DLL, and owned-child cleanup. Linux source
policy checks, Java routing/TLS peers and cross-compilation cannot certify actual
Windows clients or installed behavior. Actual Windows SSH/verified TLS,
authentication, ordinary-user permissions, Defender/process mitigations and
installed MSIX/Store acceptance remain open until their genuine gates pass.
The former injection-readiness tests are replaced by IPC authentication/isolation
tests and a policy check rejecting prohibited foreign-memory/loader APIs.

Primary API references: [libpq host/hostaddr](https://www.postgresql.org/docs/17/libpq-connect.html#LIBPQ-PARAMKEYWORDS),
[Win32 handle-list inheritance](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute),
[job process ownership](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects),
and [pinned MySQL identity/SNI separation](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql-common/client.cc#L4162).

Linux accessibility acceptance runs the ordinary Handy/Flutter release window
under owned Xvfb/D-Bus, real AT-SPI, Orca and IBus. It verifies the entire recorded
bundle before launch, isolates application/display/bus/clipboard/reader storage,
and requires cleanup and bounded secret-free diagnostics. Real checks include:

- Password-field role before entering a disposable secret; native session/target,
  BEGIN/manual-commit and rollback/idle observations.
- Repeated Tab/Shift+Tab traversal, Escape containment, actual enabled/visible
  modal controls, verified focused-descendant ancestry and origin focus restoration.
- IBus preedit/cancel/commit, multi-caret undo, Unicode caret/selection/insert/delete
  through public AT-SPI interfaces and actual editor/close workflows.
- Real copied database cells, grid keyboard/inspection, plan navigation, schema and
  designer/nested-dialog focus, and actual Orca speech before navigating away.

Private platform-setting entrypoints call unchanged `startLinux()` and observe
actual MediaQuery, composed Yaru theme, locale/direction, rendered text size and
GTK font/animation services; they install no provider/theme overrides. The matrix
includes light, dark, text 125%, display DPR 2, high contrast/text 200%, and dark
Arabic RTL/text 200% with reduced motion. Every case must match its individual
setting receipts before running workflows; an environment flag or pass Boolean
alone cannot certify settings. Private builds restore and verify the exact
ordinary bundle inventory afterward.

Controller unit tests reject hidden/disabled/ambiguous/stale controls, independent
focused leaves and workspace escape. They verify bounded fresh acknowledgments;
passing them is not a native desktop acceptance run. Original logs/screenshots and
source/bundle/settings identities belong under ignored run-specific `build/` or
CI artifacts. Genuine Windows DPI/appearance/high contrast/reduced motion,
screen-reader, IME, filesystem/junction/locking and installed-package acceptance
remain separate unaccepted gates. See [development.md](development.md).
