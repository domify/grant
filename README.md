# Grant for native iyi

A native iyi port in progress of Crystal Grant 0.23.4, starting from commit
`dfad8bfc89778a6d89e38ff481899db552e428b8`. Native code lives at the root;
the complete original source is preserved as a Git subtree in
`crystal-upstream/`. See `UPSTREAM.md` for importing and reviewing updates.

The native core compiles without `--crystal` and without Crystal shards.
SQLite uses `libsqlite3`; PostgreSQL uses `libpq`. All application-facing
code, queries, mapping contracts, error handling, and transactions are iyi.
The original ORM's full feature set has **not** been ported yet.

## Design

- `grant/database.iyi`: the `Database` trait and mutation result.
- `grant/adapters/sqlite.iyi`: native SQLite C interface and adapter.
- `grant/adapters/postgresql.iyi`: native libpq adapter.
- `grant/value.iyi`: explicit scalar values, attributes, and database rows.
- `grant/errors.iyi`: error values implementing iyi's `Error` trait.
- `grant/query.iyi`: immutable chained predicates, lazy query execution,
  identifier validation, parameter binding, pagination, and CRUD.
- `grant/model.iyi`: `Mapping(T)` and `Repository(T)` for typed application
  records. Each application declares its mapping with an `impl`, rather
  than inheriting a macro-generated ActiveRecord model.
- `grant/transaction.iyi`: commit on success, rollback on an error union,
  cancellation, or a contained panic.
- `grant/sql/placeholder_scanner.iyi`: port of Grant's quote/comment-aware
  placeholder rewriter, including PostgreSQL dollar quotes and JSON operators.
- `UPSTREAM.md`: source repository, reviewed commit, and update workflow.
- `crystal-upstream/`: unchanged imported Crystal source, tests, and docs.

A module owns its types. Imports form a DAG, public signatures are fully typed,
and trait implementations live with their types. There are no model-discovery
macros, global connection registries, monkey patches, or exception-based error
handling in the native core. The API intentionally changes where these Crystal
mechanisms conflict with iyi's compilation model. See `model_test.iyi` for a
complete typed record mapping and CRUD example.

## Running

`./scripts/check.sh` runs the native checks and the source-free artifact
consumer check.

Run from this directory with iyi 0.16.2. Install the system development packages
providing `libsqlite3` and `libpq` before linking their respective adapters.

```sh
iyi check grant.iyi
iyi run sqlite_test.iyi
iyi run query_test.iyi
iyi run model_test.iyi
iyi run transaction_test.iyi
iyi run placeholder_test.iyi
iyi run postgresql_test.iyi
```

When the default cache is not writable, prefix commands with
`IYI_CACHE_DIR=/tmp/iyi-grant-native-cache`.

`transaction_test.iyi` deliberately triggers one panic; its diagnostic appears
on stderr and the program succeeds only if rollback preserved the database.
`postgresql_test.iyi` checks only a failed connection to a nonexistent local
socket. PostgreSQL live CRUD has not been verified in this session.

The package manifest identifies `github.com/domify/grant`, matching the source
repository's remote. This is a local working tree, not a published native
release. A consumer can use a local `replace` pointing here; choose and declare
its requirement version explicitly. Root `grant.iyi` re-exports the core modules;
import specific adapter/mapping/query names at the call site.

## Limits and remaining conversion

SQLite CRUD, typed mapping, validation errors, scoped writes, SQL parameter
binding, and transactions are exercised against actual in-memory databases.
An artifact build of the typed model test and a separate consumer build/run
with only `.iyimod` files (no library source in the consumer) have succeeded.

The current scalar contract is null, boolean, Int64, Float64, and String.
SQLite returns booleans as integers; a mapping must decode them explicitly.
PostgreSQL retains decimals, dates, UUIDs, and JSON as exact text for explicit
mapping, rather than converting money to floats. BLOB/bytea decoding is rejected.
SQLite INSERT RETURNING requires SQLite 3.35 or newer.

Connections are explicitly owned and closed by the caller. There is no pool,
statement cache, automatic reconnection, or nonblocking database scheduling yet.
A connection/transaction must be used by one owner at a time; it must not be
shared across concurrent request tasks. The synchronous C calls can block the
native scheduler. Basic transaction blocks have no savepoint/nesting support.
Schema creation in the examples is explicit SQL; a migration API is not ported.

Associations, lifecycle callbacks, dirty tracking, encrypted/serialized columns,
locking, sharding, bulk operations, schema introspection/migrations, and the
remaining original features still need native implementations and parity cases.
The original parity percentages do not apply to this port. `doc/PORTING.md`
and `doc/source-inventory.json` record the conversion status.

## License

MIT; see `LICENSE`. The Crystal subtree and original Git history retain the original source,
tests, and attribution.

## Repository layout

`~/contribute/grant` is the canonical working tree. Native iyi is at the root;
`crystal-upstream/` is the imported Crystal reference. The earlier temporary
`~/apps/grant-iyi` copy is superseded by this checkout.

Run native commands from the root and any Crystal reference commands from
`crystal-upstream/`. Update the reference with
`scripts/update-crystal-upstream.sh SOURCE_REPOSITORY SOURCE_REF`, then port
behavior in separate commits. See `UPSTREAM.md` for review tracking and
publishing constraints. The source fork's existing Crystal branches and tags
retain their history; no public release or default-branch change is made here.
