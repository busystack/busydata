# Metadata response ownership

Java owns the normalized metadata model and publishes immutable snapshots.
Flutter retains only presentation state and a bounded scalar admission fence for
at most eight physical-session handles. This fence contains no catalog objects,
identifier semantics or independent database cache.

A response is owned by a backend instance, saved-profile identity, opaque Java
metadata source identity, physical-session identity, session revision, context
revision, metadata configuration revision and snapshot revision. Document and
retained-result consumers additionally check their captured document version or
result/view/row/selection owner. A profile label is never an executable identity.
Unsaved profiles may have an empty profile ID; exact captured equality still
applies and does not weaken source/session ownership.

The source identity comes from the central Java data-source identity. Changing a
live catalog, schema or search path changes the physical semantic context rather
than inventing a different saved source. Different visibility principals cannot
share configuration authority. Flutter receives the source identity in every
SessionInfo response, including before its first metadata response. It never
reconstructs that identity from UI text or connection settings.

## Revision domains

Snapshot numbers are ordered within an exact physical semantic epoch and source
configuration. They are not a global monotonic clock across all session states.
A session revision/context change can discard a transaction-owned overlay and
expose a numerically lower durable snapshot. A higher actual source configuration
can likewise retire an overlay. Those transitions establish a new domain; a lower
snapshot in that new domain is valid, while an older configuration or an older
snapshot within the same domain remains stale.

When any consumer observes a newer actual source configuration, the shared
registry propagates that scalar floor to every currently registered physical
session with the same Java-issued source identity. This includes sessions that
have not yet received metadata. Their snapshot becomes explicitly unknown (zero)
until that session receives its own response in the new domain. Disconnecting the
session that first observed the configuration cannot lose another live session's
floor. Different sources retain separate configuration authority.

Pending Open/Adopt handles cannot issue frontend metadata requests until they are
accepted into the live-session map. Delayed status, cleanup and transaction
responses must prove that their captured owner still exists before adoption; they
cannot recreate a removed handle. An unknown or disconnected session carries no
usable metadata authority, even if its revision counters did not advance.
Changing to that terminal state cancels in-flight language and metadata actions.
No observer reconnects or retries a database operation implicitly.

## Atomic presentation adoption

The registry prepares admission without changing observable state, then publishes
only if its generation is still current. Every consumer must honor a rejection
before advancing session revisions or replacing UI rows. Explorer stages a whole
branch across page and exact-namespace awaits and validates one final owner and
snapshot before changing its nodes, cursor, defaults, counts or evidence. A
rejected same-owner refresh can retain the previous complete branch, but cannot
lend it the newer response's authority. Structure follows the same rule.

Related Rows checks its captured result/view, source row and selection, then the
shared metadata stamp before opening choices. Selecting a choice checks those
owners again. A valid newer reply advances the same fence used by Explorer and
SQL services; another consumer cannot subsequently publish an older response.
Java independently verifies the current relationship, exact typed key values and
reviewed browse owner before generated execution. UI admission is never execution
authorization.

These rules require strict protocol 15. They introduce no persistent user-data
migration and no second runtime format. User-data schema 4 and rebuildable
metadata-cache schema 5 retain their existing independent ownership and migration
contracts.
