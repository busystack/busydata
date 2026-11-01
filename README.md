# BusyData

Independent Flutter desktop database workbench with one bundled Java 25 JDBC
backend. Linux uses Yaru/GTK/Handy; Windows uses Fluent and a native Win32 caption.
PostgreSQL, MySQL and MariaDB are the only user-facing connectors.
Linux releases use the Snap Store only; Windows source, native tests and MSIX
tooling remain supported. The bundled runtime requires no separate Java install.

This is an implementation in progress, **not a production-complete release**.
Read the [user guide](docs/user_guide.md) for implemented workflows and
[development](docs/development.md) for required verification and unaccepted
installed Snap/Windows/MSIX gates.

See [development](docs/development.md), [user guide](docs/user_guide.md),
[architecture](docs/architecture.md), and [security](docs/security.md).
Copied UI source retains the BusyMax Apache-2.0 notices; bundled dependencies
retain their own licenses. No product publication, registration or signing is
performed by this repository's local verification commands.

The `official-dependencies` verification stage checks every resolved locked
package against its official publisher archive and verifies the approved
Flutter/Dart source revision, complete Dart SDK and present desktop/compiler cache
files against official publisher identities. It never repairs or modifies
installed software. Reviewed dependency/toolchain upgrades must update these
publisher identities; matching version strings alone do not establish unchanged
source. See [development](docs/development.md) for the commands and owned cache.
