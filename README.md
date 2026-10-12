# Grant for native iyi

A native iyi port in progress of Crystal Grant 0.23.4, starting from commit
`dfad8bfc89778a6d89e38ff481899db552e428b8`. Native code lives at the root;
the complete original source is preserved as a Git subtree in
`crystal-upstream/`. See `UPSTREAM.md` for importing and reviewing updates.

The native core compiles without `--crystal` and without Crystal shards.
SQLite uses `libsqlite3`; PostgreSQL uses `libpq`. All application-facing
code, queries, mapping contracts, error handling, and transactions are iyi.
The original ORM's full feature set has **not** been ported yet.

> **Compiler requirement:** source-free `.iyimod` consumers and the full test
> gate require an iyi compiler containing commit `a03fc3438` **and** the fix in
> [scripts/compiler-witness-union.patch](scripts/compiler-witness-union.patch).
> Apply the patch to the iyi compiler checkout and rebuild/install that compiler;
> changing Grant alone is insufficient. An older compiler can reject artifact
> imports or produce a crashing consumer. This requirement concerns artifact
> consumption, rather than ordinary compilation from Grant source. Do not assume
> the installed iyi version includes both fixes. See
> [doc/ARTIFACT-ISSUE.md](doc/ARTIFACT-ISSUE.md) for the diagnosis and verification.

## Design

- `grant/database.iyi`: the `Database` trait and mutation result.
- `grant/adapters/sqlite.iyi`: native SQLite C interface and adapter.
- `grant/adapters/postgresql.iyi`: native libpq adapter.
- `grant/value.iyi`: explicit scalar values, attributes, and database rows.
- `grant/scalars.iyi`: exact decimal, checked calendar date and UTC datetime
  values for SQLite. See `doc/SCALARS.md`.
- `grant/decimal_policy.iyi`: explicit decimal assignment scale/precision policies
  with separate exact hydration.
- `grant/errors.iyi`: error values implementing iyi's `Error` trait.
- `grant/query.iyi`: immutable chained predicates, lazy query execution,
  identifier validation, parameter binding, pagination, and CRUD.
- `grant/model.iyi`: `Mapping(T)` and `Repository(T)` for typed application
  records. Each application declares its mapping with an `impl`, rather
  than inheriting a macro-generated ActiveRecord model.
- `grant/associations.iyi`: explicit typed `BelongsTo(T)`, `HasMany(T)` and
  `HasOne(T)` readers and batch preloading with preserved scopes. See
  `doc/ASSOCIATIONS.md` for usage and limits.
- `grant/belongs_to_writes.iyi`: typed references and explicit staged assignments,
  target-only creation and atomic owner/target saves.
- `grant/association_writes.iyi`: direct collection append, ID replacement and
  nullify/delete/destroy removal with typed link transformations and atomic
  savepoints. Repository-based saves and destruction run model callbacks.
- `grant/dependent.iyi`: explicit owner destruction callbacks with scoped
  nullify/delete/destroy/restrict actions and cycle detection.
- `grant/locking.iyi`: typed optimistic version policies with atomic SQL guards,
  stale-object errors and nested rollback. See `doc/LOCKING.md`.
- `grant/timestamps.iyi`: explicit create/update stamping with a typed clock,
  UTC date/text storage and precision 0–9. See `doc/TIMESTAMPS.md`.
- `grant/transaction.iyi`: joined nested transactions, savepoints, and rollback
  on error values, cancellation, or a contained panic.
- `grant/unit_of_work.iyi` and `grant/lifecycle.iyi`: explicit shared transaction
  sessions and ordered validation/save/destroy/commit/rollback callbacks.
- `grant/validation.iyi`: structured errors and presence, absence, length,
  inclusion, exclusion, and confirmation rules.
- `grant/dynamic_validation.iyi`: typed attribute/context operands and checked
  numericality comparisons.
- `grant/validators.iyi`: numericality/comparison bounds, odd/even, format,
  acceptance and typed conditional rule wrappers. See `doc/VALIDATION.md`.
- `grant/database_validation.iyi`: scoped SQLite uniqueness with self exclusion,
  context-aware mapping validation and separate database failure values.
- `grant/normalization.iyi`: mapping-based save normalization, conditional plans
  and automatic predicate normalization. See `doc/NORMALIZATION.md`.
- `grant/dirty.iyi`: snapshot-based change tracking with fixed attribute names.
- `Repository.update_changed`: explicit baseline/dirty-state partial updates,
  clean-save callback execution, timestamp suppression and readonly fields.
  See `doc/PARTIAL-UPDATES.md`.
- `grant/bulk.iyi`: SQLite insert/skip/upsert batches, actual affected/returned
  rows, atomic chunking, explicit scope guards and timestamps. See `doc/BULK.md`.
- `grant/schema.iyi`, `grant/schema_constraints.iyi` and `grant/migrations.iyi`:
  table/index definitions, explicit composite keys, typed check/unique/foreign-key
  constraints, column introspection and checksum-verified transactional migrations.
- `grant/schema_alter.iyi` and `grant/schema_transaction.iyi`: atomic SQLite
  column/constraint edits and explicit DDL transaction ownership.
- `grant/schema_snapshot.iyi`: SQLite catalog snapshots, atomic restoration and
  native iyi source factories. See `doc/SCHEMA.md` for scope and usage.
- `grant/schema_catalog.iyi`: SQLite table/key/check/unique/foreign-key/index
  metadata, including inline constraints and expression-index terms.
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

`./scripts/check.sh` runs the SQLite native checks and the source-free artifact
consumer checks. Set `IYI` to the desired compiler executable. Source-free
consumers currently require iyi compiler fix `a03fc3438` plus the local compound
witness-reference fix in `scripts/compiler-witness-union.patch`; the local fixed
checkout can be selected with `IYI=/home/priit/contribute/iyi/bin/iyi`.
Current development scope is SQLite only; PostgreSQL work is
deferred and its existing adapter/test are retained.

The native source targets iyi 0.16.2 syntax; use the patched compiler above for
the full verification gate. Run from this directory. Install the system development packages
providing `libsqlite3` and `libpq` before linking their respective adapters.

```sh
iyi check grant.iyi
iyi run sqlite_test.iyi
iyi run query_test.iyi
iyi run model_test.iyi
iyi run transaction_test.iyi
iyi run nested_transaction_test.iyi
iyi run lifecycle_test.iyi
iyi run validation_test.iyi
iyi run normalization_test.iyi
iyi run dirty_test.iyi
iyi run schema_test.iyi
iyi run migrations_test.iyi
iyi run schema_alter_test.iyi
iyi run schema_snapshot_test.iyi
iyi run schema_constraints_test.iyi
iyi run schema_catalog_test.iyi
iyi run schema_constraint_removal_test.iyi
iyi run schema_metadata_test.iyi
iyi run partial_update_test.iyi
iyi run bulk_test.iyi
iyi run decimal_policy_test.iyi
iyi run binary_test.iyi
iyi run placeholder_test.iyi
iyi run association_test.iyi
iyi run association_write_test.iyi
iyi run dependent_test.iyi
iyi run validators_test.iyi
iyi run uniqueness_test.iyi
iyi run normalization_model_test.iyi
iyi run locking_test.iyi
iyi run timestamps_test.iyi
iyi run touch_test.iyi
iyi run scalars_test.iyi
iyi run dynamic_validation_test.iyi
iyi run around_test.iyi
iyi run belongs_to_write_test.iyi
```

When the default cache is not writable, prefix commands with
`IYI_CACHE_DIR=/tmp/iyi-grant-native-cache`.

`transaction_test.iyi`, `around_test.iyi`, `schema_alter_test.iyi` and `bulk_test.iyi` deliberately trigger contained panics; their diagnostics appear
on stderr and the programs succeed only if rollback preserved the database.
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
The earlier core passed the source-free artifact consumer check. After adding
transaction sessions, an artifact layout bug was found and fixed in iyi
compiler commit `a03fc3438`. The fixed local compiler passes the model consumer. Source builds previously passed 13 native test programs (including PostgreSQL
connection failure). The current SQLite-only suite has 35 programs, including
association reads, transactional writes, dependent destruction, binary data and
additional validators, SQLite uniqueness, model normalization, locking, timestamps,
touch, exact scalar values, table/constraint rebuilds, schema snapshots/catalogs
partial updates, bulk operations and decimal policies. See
`doc/ARTIFACT-ISSUE.md` for the reproduction and observed compiler versions.
`./scripts/check.sh` retains and expands the artifact gate. Older installed
compilers may still fail it until they include both fixes. The gate checks twenty-two
artifact test consumers and separately compiles a generated schema factory.

The current value contract is null, boolean, Int64, Float64, String, `Binary`,
`Decimal`, `Date` and `DateTime`. Exact scalars bind as text on SQLite and
are decoded explicitly by mappings; see `doc/SCALARS.md`.
SQLite BLOB binding/decoding preserves arbitrary bytes, including NUL and empty
payloads. `Binary.from_bytes` snapshots its input; `bytes` returns a fresh copy.
Decoded BLOBs own their data independently of the statement/connection.
SQLite returns booleans as integers; a mapping must decode them explicitly.
PostgreSQL retains decimals, dates, UUIDs, and JSON as exact text for explicit
mapping, rather than converting money to floats. PostgreSQL bytea remains
unsupported; binary parameters/defaults are rejected explicitly there.
SQLite INSERT RETURNING requires SQLite 3.35 or newer.

Connections are explicitly owned and closed by the caller. There is no pool,
statement cache, automatic reconnection, or nonblocking database scheduling yet.
A connection/transaction must be used by one owner at a time; it must not be
shared across concurrent request tasks. The synchronous C calls can block the
native scheduler. Nested transactions join the outer transaction by default; `requires_new` uses
a savepoint. Share one `UnitOfWork` between repositories to defer commit hooks
until the outer transaction commits. SQL migrations, SQLite column/constraint
alteration and main-schema snapshots are implemented. Table definitions can
declare composite keys; repositories still use single Int64 model IDs.
Named and unnamed CHECK/UNIQUE/foreign-key constraints can be removed by name,
expression or ordered source columns, including inline clauses. Additional
column collation/comment metadata and DDL size options, attached/temporary
schema handling and other schema capabilities remain pending; see `doc/SCHEMA.md`.

Validation, normalization, dirty tracking, callbacks, and migrations implement
a subset of the original behavior. Mapping-declared normalization runs before
validation and coerces query predicates. Partial updates consume explicit dirty
snapshots; automatic record/state checkpointing and rollback reconciliation remain
pending.
Around callbacks wrap validation/save/create/update/destroy with typed single-use
continuations; see `doc/LIFECYCLE.md`. Several validators remain pending. Association caches/inverses, through/polymorphic associations,
encrypted/serialized columns, pessimistic locking,
sharding, advanced bulk operations, and the remaining original features still need native
implementations and parity cases.
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
