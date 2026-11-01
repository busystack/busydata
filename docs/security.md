# Security and failure behavior

Metadata source ownership uses explicit profile fields, including security
configuration and optional presence, rather than protobuf serialization order.
Java resolves an indexed durable source binding when acquiring a physical
session; independent catalog connections inherit it. Schema-4 migration preserves
existing saved-source IDs and preferences atomically. Only fingerprints and
opaque IDs enter the binding table, with a 4,096-record limit; it stores no
passwords, private-key contents or SQL. A metadata source ID does not authorize
execution, bypass profile equality or replace session/revision checks.

Each primary application launch creates a fresh private-pipe secret and a
SAN-valid loopback certificate. The listener binds only 127.0.0.1; all RPCs require
the launch secret. Flutter trusts the privately supplied certificate and performs
normal hostname verification. There is no discovery file, public reflection,
permissive certificate callback or secret command-line argument. Launcher-owned
JVM/classpath options are fixed; environment JVM injection variables are removed.
Backend stderr is discarded rather than forwarding possible credentials or SQL.

The private channel rejects unsolicited response-stream identities and server
push before forwarding their frame headers to the official HTTP/2 decoder.
Only frame-envelope state is retained; application values and compressed headers
are not copied into a parallel transport model. Official upstream package bytes
are checked against their locked official archives before verification and
packaging; the first-party extension boundaries are documented in
[editor dependency adapters](editor_dependency_adapters.md).
TLS negotiation retains a physical socket close handle and a bounded cancellation
race, so channel termination cannot leave an unanswered handshake connected.
Graceful shutdown still waits for active RPC transport completion. Socket cleanup
does not retry an RPC, resolve a database transaction or replay an unknown write.

Fresh database profiles use **Driver default** (`DRIVER_DEFAULT`), which does not
universally verify certificates or hostnames. The pinned JDBC mappings are:

| Policy | PostgreSQL | MySQL | MariaDB |
| --- | --- | --- | --- |
| Driver default | `prefer` | `PREFERRED` | `disable` |
| Require (`INSECURE`) | `require` | `REQUIRED` | `trust` |
| Verify CA | `verify-ca` | `VERIFY_CA` | `verify-ca` |
| Full Verification | `verify-full` | `VERIFY_IDENTITY` | `verify-full` |
| Disabled | `disable` | `DISABLED` | `disable` |

Require requires encryption without certificate/hostname verification. Verify CA
checks the certificate chain; Full Verification also checks the database hostname.
Driver default permits unencrypted connections; Disabled explicitly disables TLS.
Enabling Use SSL initially chooses Require; clearing it chooses Disabled. Existing
saved policies retain their meanings. An observed cipher proves encryption only.
No application-level downgrade retry or global public-key retrieval is added.
Database negotiation is separate from the pinned authenticated loopback gRPC link.

Explicit verification combines the selected CA and selected Java/System public
roots. Java reads the bundled runtime's `cacerts`; Linux System reads
`/etc/ssl/certs/ca-certificates.crt`; Windows System uses public ROOT stores, never
MY/private identities. Unselected providers are not substituted. Saved MariaDB
Full Verification profiles predating explicit trust-source selection retain the
pinned driver's deferred verifier; they are not equivalent to explicit root policy.
All three JDBC adapters support selected client certificates and unencrypted or
encrypted PKCS#8/OpenSSL PEM keys with a separate key password. Private key work
is bounded. MySQL/MariaDB use isolated temporary PKCS12 stores; PostgreSQL implicit
home client identities are disabled. Arbitrary driver classes/key providers are
unsupported. Tunnels preserve the original database hostname for TLS.

Native transfers use the same PostgreSQL/MySQL policy mappings; MariaDB Driver
default/Disabled use `--skip-ssl` and Full Verification uses `--ssl` with
`--ssl-verify-server-cert`. MariaDB Require, Verify CA and legacy deferred-root
verification cannot safely be represented by the pinned native client. Encrypted
TLS keys lack a safe CLI password channel. These combinations fail before connecting
instead of downgrading. JDBC support does not imply native-tool format parity.
See the [driver parameter](https://jdbc.postgresql.org/documentation/use/),
[Connector/J security](https://dev.mysql.com/doc/connector-j/en/connector-j-connp-props-security.html)
and [MariaDB TLS](https://mariadb.com/docs/connectors/mariadb-connector-j/using-tls-ssl-with-mariadb-java-connector)
references for the policy vocabulary.

MINA SSHD uses explicitly selected reviewed known_hosts and rejects unknown or
changed keys. Password, one selected private key/passphrase, or a Linux agent
socket with one explicitly selected SHA256 fingerprint is supported. The agent
adapter filters identities, refuses other-key signatures and disables agent
mutation/forwarding. It does not discover SSH_AUTH_SOCK or offer unrelated keys.
Profile-specific new/changed-key approval is implemented with opaque Java-owned
SQLite public-key bindings; endpoint/profile/algorithm/fingerprint changes invalidate
approval. Changed keys are rejected until explicitly reviewed. Known-host files
are not rewritten. Windows selected-agent named-pipe transport is implemented but
unverified on this Linux host. Real Linux agent and host-review tests cover
selected/unrelated identities, changed-key rejection and approval binding.

Linux confinement uses BusyMax's ported portal-derived encrypted record mechanism:
HKDF/AES-GCM, BusyData namespace, version 1 generic credential records. Unconfined
Linux and Windows use OS secure storage. Unavailable storage requires explicit
session-only credentials, never plaintext fallback. Testing does not save profile
or secret changes; edits do not mutate existing sessions. Credentials necessarily
enter Flutter/Java memory. Java retains credentials for independently requested
metadata and native tools; immutable copies cannot be promised erased.

SQL, session mutation, staged apply and tools share Java review policy. Tokens are
one-use, short-lived fingerprints of the actual request, target and session
revision; staged plans also revalidate metadata and row identity. Original values
must match the actual retained row in a finished result owned by the same physical
session. Only a direct SELECT from one base table is editable; ambiguous query
provenance and generated-column writes are rejected. Parsing is not an
authorization boundary. Conservative read-only classification supplements supported
server/session restrictions and actual database permissions. Unknown syntax is
reviewed. DDL, imports and execution-backed plans have their engine's real commit
behavior. Cancellation or network loss cannot prove a write did not occur.
Unknown connections are quarantined and cannot execute more user work. Physical
resources are released while the uncertain console remains reachable through its
owned handle; at most eight console handles are retained until explicit disconnect.
Final context/cleanup failure does not turn an unacknowledged write into a definite
cancellation. An acknowledged write retains its completed outcome. Driver
cancellation uses the exact published statement outside the job status monitor,
and the session cannot be reused before cancellation control has settled.
The privilege designer reads grant catalogs instead of MariaDB SHOW GRANTS, which
can contain authentication hashes. It never queries password/authentication fields.
Drafted SQL names existing principals, uses engine-specific quoting and explicit
privileges, and executes only through the normal review layer. Database-level
MySQL/MariaDB grants escape wildcard names under the actual server policy;
MySQL partial_revokes mode uses literal names. Drafts remain SQL, so review server
policy again before executing them after a server configuration change.

Imports accept only a selected regular file, hash-bind review to an immutable
quota-controlled copy and use parameterized batches. LOAD DATA LOCAL is disabled.
Native backup commands use selected major-version-compatible executables, argument
arrays, isolated private password files and bounded redacted diagnostics. Restore
suppresses client startup configuration/login paths and local infile, prevents native client shell/file
commands, and can partially commit. PostgreSQL restore uses a fresh private
restricted-mode key and official psql 17.11 (or 18.6+ on that major), strips only
canonical pg_dump wrapper markers, and keeps all SQL/COPY content unchanged.
MySQL/MariaDB use binary batch mode with local infile disabled. A nonzero client
exit is classified as a native-tool failure rather than a filesystem failure.
An exact client error header containing code 1213 and SQLSTATE 40001 identifies a
database deadlock; diagnostics omit the server message, SQL and source values.
A failed restore remains an unknown outcome because earlier statements may have
committed. BusyData never retries or replays it automatically. The disposable
native-backup gate can collect bounded numeric lock ownership and fixed lock
states after a failed MariaDB restore. It records unavailable or disabled
instrumentation explicitly; current locks and older deadlock history alone do
not establish the cause of that restore failure.

Native tools retain the database hostname through an application-owned SSH
forward: PostgreSQL uses host/hostaddr; MySQL/MariaDB use private local IPC and a
BusyData stream relay whose per-operation TLS context verifies the original
hostname when Full Verification is selected. The relay uses the documented MySQL
TLS handshake and streams command bytes unchanged. Official clients, resolver
imports and upstream binaries remain unmodified. Relay completion is checked
before success acknowledgement; review/source ownership and unknown-outcome
rules remain unchanged. See [native transport requirements](native_transport_acceptance.md).
Native restore fences the shared persistent metadata source and retained
editability evidence before client launch. Overlapping operations cannot publish
fresh structure or bypass that editability barrier. An unknown external write
requires explicit metadata reconciliation and retains its unknown job outcome;
refresh does not replay SQL or resolve the console transaction.
Real three-engine native dump/restore through SSH and verified TLS requires its
live gate; Windows helper acceptance requires a genuine Windows host. The Snap
recipe source-builds and bundles the exact client matrix
with corresponding sources and notices. Installed-package access requires native
confined acceptance of the installed artifact.

History defaults to no SQL text. Enabling retention can retain SQL secrets;
disabling removes stored text. Enabling during an active job does not retroactively
retain its SQL, and completion does not resurrect deleted active history. Draft recovery defaults on and saves SQL in private
local files; its separate setting can disable and remove recovery. Workspaces
exclude credentials. Spools are quota-controlled with restrictive permissions and
ordinary crash cleanup, without a secure-erasure claim. Credential scratch files are isolated under BusyData support storage and cleaned
only after acquiring its metadata lease on restart, without following symlinks.
Installed Windows ACLs, comprehensive
secret-leak/diagnostic audits and disk-full fault injection remain release blockers.

The strict Snap requests network/network-bind, home/removable-media and manually
connected ssh-keys access. Home excludes hidden SSH configuration. No undocumented
agent interface is assumed; confined socket access and portal storage still need
installed tests. Do not infer secure-storage/file/SSH acceptance from bootstrap
smoke tests. See [development.md](development.md) for required installed gates.
Only completed generated distribution copies receive public payload permissions;
SDKs, caches, private fixtures and recovery data are excluded. Safe acceptance
archive extraction retains the traversal/link filter, then republishes only the
extracted bundle. A separate read-only primed-payload check rejects inaccessible
required directories even when a privileged builder can read their files.

Native MySQL configuration isolates login-path handling according to the official
[option-file rules](https://dev.mysql.com/doc/refman/8.4/en/option-file-options.html).
For direct transfers, selected MySQL/MariaDB TLS identity paths are explicit client arguments, following
[MySQL dump options](https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html) and
[MariaDB dump options](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump).
For SSH transfers, the private relay consumes bounded identity snapshots and the
reviewed root snapshot; its JSSE context never changes JVM-wide trust. Local IPC
uses an operation-specific protected endpoint. Windows additionally verifies the
selected child PID and authenticates its private loopback handoff with a fresh
nonce that is removed before the client starts.
The selected 17.11/8.4.10/11.8.9 client round trips, SSH/TLS, interruptions and
installed Snap/Windows access require their independent verification gates.

Account management sends entered credentials through private typed RPC. Reviews,
job summaries, history and bridge errors exclude password SQL/server messages.
The server itself may audit account statements; users must review its logging
policy. Password reset does not silently change unsupported authentication plugins.
PostgreSQL follows its [SCRAM password policy](https://www.postgresql.org/docs/17/auth-password.html),
MySQL uses [caching_sha2_password](https://dev.mysql.com/doc/refman/8.4/en/caching-sha2-pluggable-authentication.html),
and MariaDB [SET PASSWORD](https://mariadb.com/docs/server/reference/sql-statements/account-management-sql-statements/set-password)
retains engine authentication semantics. Account UI acceptance on Windows remains
unverified despite Fluent widget coverage on the Linux test host.

Verified staged-edit recovery includes original database values and is private
local metadata, separate from SQL history privacy. Disabling local recovery removes
its saved records; an applying record cannot be discarded while its job is active.
Recovery records marked committed or unknown prohibit rebinding/application.
Explicitly discarding an uncertain record does not undo or prove absence of writes.

CSV/JSON import approval binds the exact source path, mapping, encoding, NULL and
delimiter settings, policy and session revision to a server-owned SHA256 digest.
The digest shares the existing bounded approval store and 120-second lifetime.
Start consumes the permit before its bounded long source check, without trusting
a client-provided digest or extending the approval lifetime. Cancellation or a
changed source submits no import job and requires fresh review. A submitted job
rechecks its captured revision and verifies an immutable, quota-accounted source
snapshot before writing. The five-minute import admission transport budget does
not grant execution approval, retry a mutation, or resolve a transaction.

Encrypted Linux credential records are bounded to 8MiB on disk before decoding,
four JSON nesting levels, 512 bindings, 256 UTF-16 units per reference, 4096 per
credential, and 4MiB encoded clear contents. Portal secret material is limited to
4096 bytes. Rejections retain the existing record and do not write plaintext.
SQL files admit 8M UTF-16 units/100,000 lines, with a corresponding 24M UTF-8-byte
read ceiling; commands reject malformed UTF-16 and preflight a 15M-byte RPC payload.
Literal file and SQL-token line separators survive editor operations and formatting.

Live editor admission now includes current and canonical SQL text (32M UTF-16
units, 100 tabs), not only recovery files. Captured saves reserve 64MiB and 16
operations globally, with four pending saves per document; byte admission precedes
encoding. Rejected edits preserve text, selection and undo and report a controlled
status. Snapshot capture charges retained strings while building objects with a
32MiB working limit, alongside the existing 6MiB encoded limit. Credential save
and temporary cleanup failures are retained separately; their text presentation
never includes underlying secret-bearing diagnostic messages.

Grid copying is limited to 10,000 fetched cells and 1MiB of encoded UTF-8,
including CSV quotes, JSON escaping, separators and multibyte characters. Binary
and arrays are admitted before flattening, with array depth/element limits.
Oversized copies and clipboard denial preserve the cells and report a controlled
failure. SQL-copy replies are checked against their retained result/backend and
the same byte ceiling before writing the clipboard. Retained-value exports bind
the document, result/value, backend and session context before opening the native
picker; closure, disposal or restart requires fresh review. The Java export path
still owns full-value file writing and does not rerun SQL.

Installed acceptance uses a separate test entrypoint, isolated package support,
private disposable host portal/keyring services, selected agent and real TLS
fixtures. The executable checks its actual AppArmor profile; environment variables
alone cannot prove confinement. The user-managed agent socket is explicitly
selected inside package-owned storage; access is subject to installed AppArmor
verification, not an assumed capability of `ssh-keys`. The portal service selection
follows the [XDG portal configuration](https://flatpak.github.io/xdg-desktop-portal/docs/configuration-file.html).

Selected TLS certificates/keys and SSH keys/known_hosts are read through opened
handles with a 1MiB byte limit and copied into private Java-owned scratch storage
before providers parse them. Later source replacement cannot change a connection's
selected copy. TLS chains are limited to 64 entries. Teardown attempts every owned
file/session/tunnel even after one failure, is idempotent, and retains the primary
and cleanup failures. Disconnect warnings contain fixed safe descriptions;
shutdown cleanup failures produce a nonzero child exit instead of a clean-exit
claim. Private copies are removed normally; secure erasure is not promised.

Linux OS close requests are consumed by the owned window controller and sent to
the existing Flutter close coordinator through the public cancellable framework
request. The controller admits one outstanding request, retains weak physical
window/application owners and a request generation, and bounds replies to 1KiB
before decoding. Only the exact current success reply can authorize exit.
Cancellation, owner destruction, transport errors and malformed replies preserve
the window; requests are never automatically retried. Human review may remain
pending, while the single admission stays occupied until completion or disposal.
The controller does not replace Flutter's platform-message handler or resolve
database transactions itself.

## Reviewed destination finalization

`OutputCommit` owns all Java export/value/dump staging and cleanup. Staging is
private, on the selected destination filesystem, and flushed before publication.
Linux opens each ancestor without following symlinks and commits relative to its
retained directory descriptor. `renameat2(RENAME_NOREPLACE)` atomically refuses a
newly appeared destination. Windows locks every ordinary ancestor against
deletion/renaming, rejects reparse points, and uses `MoveFileExW` without replacement
or copy flags. On both platforms reviewed replacement first moves the existing file
to a unique sibling with the no-clobber primitive, verifies the preserved identity,
and publishes the partial with another no-clobber move. Native Windows behavior still
requires genuine installed acceptance.

Approval includes normalized path, ancestor identities and existing-file identity
and content hash. The exact approved identity is handed from safety consumption
to the queued transfer; it is not recaptured as a new implicit approval. Overwrite
at a reviewed absent path still uses no-clobber publication. Unsupported filesystem
primitives and cross-device operations fail without an unsafe copy/rename fallback.

No filesystem API provides an inode-conditional replacement against arbitrary
concurrent writers on every supported filesystem. A file moved during preservation
that does not match the review is returned only with no-clobber semantics. A writer
appearing after preservation retains the selected pathname; the reviewed original
is retained beside it for explicit recovery. Automatic unconditional rollback is
prohibited. Permissions or cleanup failure retain the primary failure; completed
output acknowledgement is not relabelled as database uncertainty. This is whole-file
publication, not a promise of power-loss durability, secure erasure, or protection
from a malicious process running as the same OS user.

Portable workspace SQL references are normalized forward-slash relative paths and
must remain lexically and physically beneath the workspace directory. Saving rejects
outside documents. Loading rejects traversal, POSIX/drive/UNC absolute forms, mixed
separators, final links, and linked/reparse ancestors that resolve outside the root
before it reads SQL. There is no legacy fallback for an unsafe reference.

## Source and evidence integrity

The canonical manifest binds source contents, normalized paths/types and reviewed
intentional executable bits. Source ZIP extraction safely rejects traversal,
symlinks, duplicate/case-colliding members and excess/missing/mutated content.
Archive reproduction, every stage source identity, retained sizes/hashes/member
completeness and declared artifact existence are checked before evidence sealing.
Source and evidence publication use atomic no-clobber hard links, with no unsafe
replacement fallback. Archives contain only declared source or hash-bound evidence;
private fixtures, credentials, SQL drafts, result spools and transient caches are
excluded. Historical artifacts without canonical source receipts are not accepted.

The Windows native-tool forwarding correction and remaining genuine-platform
security checks are documented in [native_transport_acceptance.md](native_transport_acceptance.md).

The output-owner classification is in [output_commit.md](output_commit.md);
Flutter document/export ownership and recovery are in [output_commit.md](output_commit.md).

Verification command logs are drained continuously and capped at 32MiB per
stage. Overflow or an incomplete drain fails the stage rather than certifying
truncated evidence. Native process logs retain their smaller existing budgets.

Linux protected-field acceptance requires the protected role, fresh editable,
enabled, visible and showing state, keyboard focus and complete containment in
the native scrolling viewports/window before one credential-entry action and
real authentication. The owned GTK/ATK projection exposes those states for
protected fields too; it does not retain the old engine-specific visibility
exception. Diagnostic output contains roles, states, geometry and character
counts, never credential text. Public semantic presentation is masked before
publication; native password copy/cut is unavailable. The bridge cannot bypass
existing UI ownership, typed staging, review or backend authorization.
An enabled offscreen control can request its bounded native reveal operation.
That operation grants no hidden focus or editing permission: clients must
observe a fresh visible control before input. Reveal retains current view,
epoch, revision and node admission and never generates a database operation.
Runtime modification of upstream accessible classes/interfaces and private
engine hooks is prohibited; see
[native accessibility ownership](native_accessibility_bridge.md).

Modal keyboard acceptance requires a fresh, enabled, visible control within the
expected dialog. A native ancestor may report focus ownership alongside its
descendant; only verified ancestry permits ignoring that ancestor. Independent
focused leaves, stale/cyclic ancestry, workspace focus or a container without an
actual focused control cannot pass. Each keyboard action has a bounded fresh
acknowledgment, and plan approval is recorded separately from result delivery.

Unavailable signed-repository access or installed-test facilities fails the
release gate. Changing host networking or confinement cannot substitute for
genuine product-package acceptance.


Central metadata is discovery evidence, never authorization. Generated table
browsing requires the exact current Java object identity and positive metadata
revision, canonical namespace/name, configured structural coverage and the
original physical/context owner before any operation is approved. Flutter logical
document keys and restored names supply no authority. Live selection proof is
ephemeral, is never serialized with workspace/preferences, and cannot rebind an
already owned document to another physical connection. Native TABLE/VIEW kind and
temporary-shadow checks use the selected central identity; SHOW display aliases
never become executable identifiers or incarnation evidence. Source ownership
includes the exact connection configuration and user, namespaces and overloads;
session-local objects never enter durable shared catalogs. A damaged rebuildable
catalog cannot erase profiles, history, recovery or introspection preferences.
Cached evidence is stale after backend restart until reconciliation.
MySQL/MariaDB qualified table names can still resolve to session temporary tables.
Eligible retained edit provenance and generated table operations therefore verify
the native target on the locked physical session. Another connection's permanent
dictionary identity is insufficient. Opaque procedure/dynamic execution records
uncertainty before submission, including when its eventual outcome is a failure.
Only owned native evidence can reconcile it; previously unproved retained results
cannot acquire edit authority after a temporary table disappears.

Language endpoints execute no SQL and perform no live catalog work. Formatter
and quick-fix text still enters ordinary execution review. Related-row browsing
checks metadata revision, relationship identity, retained source ownership and
exact typed key predicates before ordinary Review/Browse. Values remain bound;
only verified identifiers are adapter-quoted. Clone produces intentions only.
DEFAULT is a dedicated assignment intent, never accepted as interpolated SQL or
as an overloaded NULL. Optimistic predicates continue to use retained originals.
Large-value interpretation is explicitly bounded and cannot replace exact stored
bytes; image decoding requires recognized bytes and bounded decoded dimensions.

PostgreSQL array changes require exact retained native evidence and a revalidated
central column type OID. The native literal or binary payload is bound as a JDBC
Array parameter, preserving lower bounds and engine values; the presentation
tree is not serialized into mutation SQL. Raw binary headers and sizes are
checked before element expansion. The pinned driver's binary-array `toString`
normalizes through Java arrays and is therefore excluded from exact retention.
Driver identity resolution must return the same verified OID; unsupported cases
fail instead of binding a similarly named type. SQL-copy literal escaping is a
separate explicit export operation and never authorizes a write.

The implementation uses the pinned driver's public
[`PgArray` constructors](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/jdbc/PgArray.java),
[`setArray` binding](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/jdbc/PgPreparedStatement.java),
and [type identity resolution](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/jdbc/TypeInfoCache.java).
No reflective access to private driver members, synthetic type-cache identity or
unreviewed SQL retry is used.

SQL selection preserves native Unicode identifier characters and recognizes
PostgreSQL Unicode dollar tags only at a legal identifier boundary. Non-ASCII
identifier whitespace is never trimmed into a different executable statement.
The independent splitter retains original fragments; formatting never supplies
SQL execution text. Retained edit reviews compare native physical identity and
exact original values, then hold a native table metadata read lock inside the
owned change transaction while rechecking structure before mutation.

Raw PostgreSQL editor statements enter the pinned driver's native transport once
through `PostgresRawStatements`. The original independently split fragment is a
zero-parameter `NativeQuery`; no JDBC escape processing, driver statement splitter
or SQLSTATE-triggered replay runs on this path. The driver still owns protocol
encoding, TLS, bounded result buffers, cursor fetching and native value decoding.
The adapter owns the statement deadline, cancellation lifetime and result chain;
closing it waits for any already-started cancellation before its physical session
can serve another command. Generated parameterized operations retain JDBC binding.
An exhausted result chain revokes queued timeout workers. Explicit cancellation
has no effect before execution or after the final result, while open cursor
fetching keeps its active owner.
This is required because the pinned driver's
[JDBC parser](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/core/Parser.java)
uses Java identifier characters for dollar tags, while the supported PostgreSQL
scanner accepts a larger native identifier repertoire. Literal contents and tags
are never rewritten to accommodate that difference. The adapter uses the pinned
driver's public `NativeQuery`, `QueryExecutor`, `ResultHandler` and `BaseStatement`
interfaces; it does not patch or replace a dependency.

## Identifier and artifact evidence

Generated schema operations use the captured central metadata rules and physical
server affinity. Foreign-key uniqueness and DROP lookup are separate native
domains. Ambiguous DROP keys and unsupported trigger lookup cannot authorize
generated SQL; exact quoting alone cannot resolve a native comparison ambiguity.
Native comparison acquisition is independent, cancellable and bounded; neither
completion nor diagnostics reads the live catalog.

Imported schema JSON is untrusted evidence. Strict parsing rejects duplicate
decoded keys, malformed Unicode, trailing input and oversized node/string/depth
budgets before allocating the comparison model. Typed constraint records must
agree with their exact definition header. Legacy conversion preserves original
files and rejects contradictory evidence. Comparison and source inspection do
not authorize execution; generated SQL retains the existing explicit review,
owner, transaction and recovery contracts.

Metadata source identities are opaque Java-issued ownership evidence, not
permission to query or mutate a database. Related-row requests must carry present
expected physical-session/context revisions; Java rejects mismatches before
retained-row, prepared-witness or catalog access. Response adoption checks the
actual source/configuration and retained result/selection owner before showing
choices and again before opening a reviewed browse operation. A delayed read
cannot restore a disconnected session or clear transaction uncertainty. Generated
browse Review/Submit retains its independent current-metadata validation.
