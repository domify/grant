# Database migration gaps

Status, 2026-10-17: the library gaps below are fixed, and Grant now delegates to the local db,
SQLite and PostgreSQL checkouts. The original inspection is retained as history; see local
integration and validation below.

Inspected on 2026-10-16, using these resolved modules:

- `github.com/iyilang/db v0.1.1`
- `github.com/iyilang/sqlite v0.0.0-20261015191849-b0d89d58a814`
- `github.com/iyilang/pg v0.0.0-20261015182941-6e9e50d7fef4`

The dependencies are pinned in `iyi.mod` and `iyi.sum`. Driver replacement is blocked on the
behavior below. Grant's existing drivers and all translated assertions remain intact. No library
cache files or upstream Crystal files were changed.

## Actual transaction state

Grant's `Driver::Connection#in_transaction?` reports SQLite autocommit state or PostgreSQL's
transaction status, including transactions started through raw SQL. Adapter liveness and replay
logic uses it in `grant/adapter/base.iyi` to avoid probing or replaying within a transaction.

`db/core.iyi` has a private `@transaction` flag, managed by `begin_transaction` and
`release_from_transaction`; it has no public actual-state reader. Grant issues transaction control
SQL itself to preserve lazy BEGIN, isolation modes, savepoints and manual transactions. The flag
therefore cannot replace the existing method.

`sqlite/core.iyi` exposes a raw handle but no autocommit reader. Calling SQLite directly through
that handle would retain the driver-specific C binding this migration is intended to remove.

`pg/pq/frame.iyi` decodes `ReadyForQuery#transaction_status`, but `pg/core.iyi` consumes that frame
without retaining its status on the connection. `PGConnection` and `PQConnection` have no public
transaction-state reader. Inferring state from SQL text would be incorrect for failed COMMIT,
server-side aborts, comments, multiple statements and statements executed by other library APIs.

Needed: a connection API reporting actual idle, active-transaction and failed-transaction state,
updated on every server response, including errors. SQLite can derive it from autocommit.

## SQLite statement validation

Run the checked-in probe from the checkout root:

```sh
IYI_CACHE_DIR=$PWD/.iyi-cache /home/priit/contribute/iyi/bin/iyi \
  run port/feedback/migrate_db_probe.iyi
```

Observed output:

```text
multiple statements rejected: false
missing parameter became NULL: true
missing parameter reused previous value: true
```

`SQLite3Statement.prepare` passes a nil tail pointer to `sqlite3_prepare_v2`; it silently ignores
trailing SQL. Grant currently rejects trailing SQL before executing any prefix. The probe's
`CREATE TABLE ...; SELECT 2` succeeds through the library.

`SQLite3Statement.bind_args` checks only supplied arguments; it does not check the statement's
parameter count. `SELECT ?` with an empty argument array returns NULL. Grant currently reports a
parameter-count error. Cached statements also need bindings cleared before rebinding, so a missing
argument cannot retain a previous execution's value.

Needed: reject unconsumed SQL before execution, reject empty prepared statements, and validate the
complete argument count on each execution. These checks belong to the SQLite driver rather than a
second SQL parser or C statement layer in Grant.

## Other integration findings

The public entry points are `db/db/core`, `db/db/value`, `db/db/errors`, `sqlite/sqlite/core` and
`pg/pg/core` through dependency-qualified imports. The common types are `Connection`, `ResultSet`,
`DBValue` and `ExecResult`; result iteration uses `move_next` and `read`. `ExecResult` supplies
`rows_affected` and `last_insert_id`.

`DBValue` also includes Time, Bytes, narrower integers and custom driver values. Grant's existing
row readers normalize PostgreSQL numeric values and timestamps and expose binary strings. The
migration needs explicit compatibility conversion at the Grant boundary, preserving public APIs.
This is integration work, not a request to narrow the library's value union.

Driver errors inherit `DBError`. SQLite exposes `SQLite3Error#code`; PostgreSQL exposes
`pg/pq/errors::PQError#field_message(:code)` and socket failures through `ConnectionLost`. These can
feed Grant's existing error translator while retaining `DatabaseError` at the public boundary.
Grant can keep its observer and transaction-materialization hooks around calls into the library.
Neither error translation nor the hooks require rebuilding a native SQL driver.

## Local integration, 2026-10-17

The local libraries now implement actual `Connection#transaction_state`:

- db `f0654df`, `abf1674`: required state contract and raw SQL/savepoint contract tests.
- SQLite `de37bd1`, `c8f9424`: autocommit state, statement-tail and argument validation,
  binding clearing, and resetting cached exec statements after errors to release locks.
- pg `0c87010`: retain every ReadyForQuery status, including error recovery.

Grant's `iyi.mod` replaces all three modules with `../iyis/<module>`. These are supported top-level
replacements; the module cache stays untouched. The db bridge uses DBValue without narrowing the
library union and retains Grant's hooks, error boundary, normalized rows and mutation API.
Recursive array values are converted with the library's `to_db_value` helper. Public query and
adapter modules re-export the driver types they expose.

The full pre-migration gate reports `PORT 104/476 EXAMPLES 751/4736 AREA transactions FAIL`.
It ran 276 adapter programs: 275 passed, one SQLite idle-reconnect run collided with a parallel
draft's temporary fixture directory. That unchanged target passes under both adapters when rerun
with its own TMPDIR. All other gate errors are unfinished source entries. Active drafts, caches, build
temporaries and logs now live under the checkout, with separate temporary directories per run.

SQLite integration delegates to `SQLite3Connection` and the common db facade. No SQLite C binding
remains in Grant. The library validates SQL tails and bind counts before execution, clears cached
bindings, and releases cached exec statements after failures. Grant retains its bulk-insert SQL,
foreign-key and busy-timeout setup, SQLiteError cause, normalized binary strings and public errors.

PostgreSQL integration delegates to `PGConnection` and the common db facade. No libpq binding
remains in Grant. ReadyForQuery status drives liveness and replay decisions for raw SQL
transactions,
including failed transactions. Placeholder rewriting and RETURNING remain Grant SQL conventions.
Native numeric values, UTC timestamps and byte buffers retain Grant's integer/float, RFC 3339 and
binary-string boundary. Server SQLSTATE and connection loss retain Grant's existing public errors.
Unread results are drained before reuse; a drain error is translated with the statement and binds.

The ordinary port follow-up completes the ignore-case example in `w6b_lazy_decrypt_spec.cr`,
retaining both original assertions. Its companion encrypted column preserves case and its
structured predicates seal values at assembly. The original twelve example IDs still partition
exactly once across the existing child entries, which are now all done.

Generic assembler observation: the runtime `Model.responds_to?(:encrypted_attributes)` guard still
instantiated the unavailable class method for the SQL-only stub model. The initial full-gate log
records that compile failure in both assembler suites. The assembler now selects the optional API
with compile-time `Model.class.has_method?`; both original suites pass without changing their stubs
or assertions. This follows the toolchain's TypeNode metaclass reflection API.

## Final validation, 2026-10-17

Grant migration commits are `4c70962` (db facade), `840416c` (SQLite) and `760ca33` (PostgreSQL),
on `native-iyi-fast-port`. Library heads are db `abf1674`, SQLite `c8f9424` and pg `0c87010`.
The library suites pass all 15, 5 and 16 native test programs respectively.

Full gate counts:

```text
before: PORT 104/476 EXAMPLES 751/4736 AREA transactions FAIL
after:  PORT 105/476 EXAMPLES 763/4736 AREA transactions FAIL
```

The final full run passes all 142 native programs under both adapters: 284 passed, zero failed,
zero skipped. Its only errors are 371 unfinished source entries, so the harness still exits 1.
The baseline's isolated temporary-directory collision and successful rerun are recorded above.
The final run uses its own TMPDIR under `build/db-migration/gate-tmp`; its complete log is
`build/db-migration/after.log`. No existing translated assertion file, upstream source, exclusion
or gate rule changed. No push, tag or module-cache edit was performed.
