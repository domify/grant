# Native iyi conversion status

Source: Crystal Grant 0.23.4 at commit
`dfad8bfc89778a6d89e38ff481899db552e428b8`.
Target: `/home/priit/contribute/grant`. Native code is at the root; original
Crystal source is preserved unchanged as the `crystal-upstream/` Git subtree.

## Active scope

Current user instruction: focus only on SQLite. Retain the existing PostgreSQL
adapter and reference test, but defer PostgreSQL implementation and verification.

## Conversion model

Automatic `iyi migrate` produced 46 modules from 256 Crystal files after
normalizing reserved identifiers in a temporary input tree. One module merged
198 files; it then failed type checking, including a namespace-flattening
collision (`overrides = overrides`). The input normalizations and generated
code were exploratory, not a validated API-preserving conversion. This output
is retained outside this repo at
`/home/priit/apps/grant-port-reference/migration-candidate/` for diagnosis.

The working native implementation instead uses explicit database/query/mapping
contracts. Trait implementations replace inherited macro DSLs; recoverable
errors are union values; records and model mappings are owned by applications.
No code delegates native model behavior to the archived Crystal ORM.

## Implemented and checked

- Native SQLite adapter via libsqlite3, parameter binding, row decoding, single
  statement enforcement, explicit close, and database error values.
- SQLite BLOB parameters and decoding through immutable `Binary` values;
  byte-array input/output is copied, empty BLOB differs from NULL, embedded NUL
  and arbitrary byte values round-trip, and binary schema defaults use hex SQL
  literals. SQLite tests cover binary filters, IN membership and update/storage
  type. Binary PostgreSQL support remains deferred. Suite now has 16 SQLite programs.
- Native PostgreSQL adapter via libpq, copied result data, parameter binding,
  PostgreSQL placeholder rewriting, and explicit errors for unsupported binary
  values. It compiles and its connection failure path is tested; live SQL is
  not yet verified.
- Lazy, immutable equality/null predicates with AND semantics, ordering,
  pagination, count, insert returning a row, scoped update and delete.
- Typed `BelongsTo`, `HasMany` and `HasOne` readers and explicit batch
  preloading for Int64 keys, preserving target scopes and rejecting global
  pagination during preloading. Through/polymorphic relations remain pending.
- Direct collection append and ID replacement using an application `Link(T)`;
  scoped nullify/delete removals and repository destroy with model callbacks.
  Collection operations use savepoints inside a shared unit of work, preserving
  atomicity when an outer caller catches errors. SQLite parity cases cover
  validation, scope violations, foreign-key errors, callback abort and nested
  rollback. Source suite now has 14 SQLite test programs.
- Direct has-one replacement (including unsaved targets), scoped removal of all
  members and explicit BeforeDestroy dependent rules supporting nullify, delete,
  destroy and restrict. SQLite cases exercise unique foreign keys, failed
  replacement restoration, owner callback failure, nested rollback, wrong
  session rejection and cyclic destruction. Suite now has 15 SQLite programs.
- Repository writes are atomic within outer managed transactions using
  savepoints. Scoped updates hydrate by fixed primary key after applying the
  original predicates, even when a filter column changes.
- Immutable `where_in` predicates with bound values, empty-set false semantics
  and explicit NULL membership. Repository scoped `all`/`first` decode records
  and reject scopes for another table or database.
- Identifier checks and parameter binding; extra tenant predicates cannot
  replace an earlier tenant predicate.
- Typed `Mapping(T)` and `Repository(T)` with validation, decoding, lookup,
  insertion, and scoped update. A scope for another database is rejected.
- Transaction success/error/panic rollback, joined nesting, and `requires_new`
  savepoint behavior on SQLite.
- Explicit shared units of work, ordered validation/save/create/update/destroy
  callbacks, deferred commit hooks, rollback hooks and first-record deduplication.
- Structured validation errors and presence/absence, length, inclusion/exclusion
  and confirmation rules with explicit contexts and nil/blank options.
- Numericality with typed static comparison bounds, finite-number checks,
  integer/numeric-only options, odd/even and per-constraint metadata; native
  regex format, acceptance and typed conditional validator wrappers. Integer
  comparisons preserve Int64 precision. Typed dynamic operands now use checked
  rules and propagate evaluation failures separately from validation issues;
  attribute/context policies and SQLite writes are covered by
  `dynamic_validation_test.iyi`.
- SQLite uniqueness with scope columns, NULL scopes, explicit query conditions,
  self exclusion, case-insensitive text and typed conditions. `DatabaseRules`
  combines scalar rules with SQL rules and propagates database failures separately.
  Context-aware mapping validation receives create/update and the actual persisted
  update key. Query adds inequality, case-insensitive equality and existence checks.
  See `VALIDATION.md`; suite now has 18 SQLite programs.
- Explicit normalization plans, plus snapshot-based dirty state supporting
  mutable values through a supplied copying trait. Unknown runtime writes return
  `AttributeError`; batch clearing validates names before changing any baseline.
- Mapping-declared normalization is now applied before repository validation via
  typed record reconstruction, and repository query arguments inherit the plan.
  Conditional normalizers see create/update context but never run on query
  arguments. SQLite cases exercise stored data, legacy hydration and invalid
  transformed types. See `NORMALIZATION.md`; suite now has 19 SQLite programs.
- Basic table/index definitions, SQLite/PostgreSQL column introspection and
  transactional SQL migration ordering, targets, rollback and checksum checking.
  PostgreSQL behavior beyond connection failure remains unverified.
- SQLite column additions/removals/type/null/default edits combine into atomic
  table rebuilds, preserving generated columns, constraints, indexes, views,
  triggers and AUTOINCREMENT sequences. Explicit DDL transaction ownership
  handles foreign-key settings, nested savepoints, final integrity checks and
  migration version/checksum atomicity. Error, cancellation and panic rollback,
  default/backfill cases and removed/re-added column names are covered by
  `schema_alter_test.iyi`; see `SCHEMA.md`.
- Native SQLite main-schema snapshots preserve catalog SQL and migration
  checksums, omit application data and original tool metadata, and restore
  atomically with an explicit replacement option. `schema_snapshot_test.iyi`
  covers constraints, cycles, generated columns, views, triggers, external
  references and rollback. The gate also compiles and executes a generated
  native iyi snapshot factory using Grant artifacts only.
- Explicit and flagged composite table primary keys, WITHOUT ROWID and typed
  named CHECK/UNIQUE/composite foreign-key definitions. Named table constraints
  can be added/removed by rebuild. CASCADE, RESTRICT, SET NULL, SET DEFAULT and
  update cascades, failed constraint addition and copied configuration are
  verified in `schema_constraints_test.iyi`. Column metadata reports SQLite
  primary-key positions. Composite-key repositories remain pending; existing
  inline/unnamed constraint removal is implemented as described below.
- Live SQLite catalog APIs for tables, existence, ordered primary keys,
  named/unnamed inline/table checks and unique constraints, composite foreign keys
  and indexes. Index terms preserve direction, collation, expression markers and
  original SQL, with constraint indexes distinct from bare indexes. Implicit
  reference targets remain nullable metadata rather than fabricated key names.
  `schema_catalog_test.iyi` checks source/artifact consumption and post-rebuild reads.
- SQLite column metadata adds declared TypeFamily, character limit, decimal
  precision/scale, ordinary storage affinity, ordinal positions and generated
  rowid-key flags. Nullability follows actual SQLite behavior for composite,
  BIGINT, inline DESC, STRICT and WITHOUT ROWID primary keys. Catalog column
  existence optionally checks a type family. Main-schema PRAGMAs cannot be
  shadowed by temporary tables. `schema_metadata_test.iyi` verifies source and
  artifact consumption, storage behavior, unsupported parameters and live reads
  after rebuilds. This metadata does not infer mappings or enforce lengths.
- SQLite named inline/table CHECK, UNIQUE and REFERENCES removal, plus selection
  by check expression or ordered unique/foreign-key columns. Token matching
  preserves literal case and adjacent clauses, including defaults, collations,
  generated columns, conflict actions and foreign-key deferral. All matching
  constraints are removed; primary keys and unrelated named column clauses are
  protected. `schema_constraint_removal_test.iyi` verifies enforcement changes,
  copied selectors, data/dependent-object/sequence preservation and atomic
  rollback, and runs as a source-free artifact consumer. See `SCHEMA.md`.
- Native port of the original placeholder scanner, with 15 parity assertions
  covering strings, escape strings, quoted identifiers, comments, casts,
  Unicode text, dollar quotes, and escaped question-mark operators.
- Optimistic locking uses explicit version policies, atomic SQL predicates and
  StaleObjectError values. SQLite cases cover stale/missing targets, scopes,
  overflow and nested/callback rollback. Bulk locking integration and
  pessimistic APIs remain pending; see `LOCKING.md`.
- Explicit timestamp callbacks fill create fields and update fields using a
  typed UTC clock, precision 0–9 and immutable mapped record reconstruction.
  SQLite cases verify every precision through storage/reload, preserved explicit
  values, disabled create/update stamping, copied column configuration, UTC date
  rollover and deterministic clock reads. Combined optimistic writes verify
  timestamp/version restoration after stale writes, callback aborts and outer
  rollback. Suppression/timezone/no-op-save behavior remains pending;
  see `TIMESTAMPS.md`.
- Explicit partial-column touch, AfterTouch and transaction observers; timestamp
  policies accept supplied times and declared additional timestamp fields.
  Guarded touches write timestamps and an incremented version in one SQL UPDATE,
  skipping validation and save callbacks while preserving unrelated pending
  fields. SQLite triggers verify one write; stale/missing/scoped targets, SQL and
  callback failures and nested rollback are covered in `touch_test.iyi`.
- Explicit partial repository updates compare against loaded attribute/dirty-state
  baselines. No-op saves validate and run save/update/around/commit callbacks but
  perform no UPDATE or timestamp clock read; scopes/existence are still checked.
  Readonly mapping attributes and creation timestamps are protected on updates.
  Forced fields, explicit timestamp suppression, normalization, stale siblings and
  nested/outer rollback are covered by `partial_update_test.iyi`. Caller-owned
  state is not silently marked clean before commit. Automatic state checkpointing
  and no-op optimistic writes remain pending; see `PARTIAL-UPDATES.md`.
- Native SQLite bulk insert/skip/upsert with bound stored values, real affected/
  returned rows, primary/named-index conflict targets, selected/protected updates
  and bind-cap-aware atomic chunking. Explicit equality scopes protect tenant
  conflict updates; explicit timestamp metadata stamps every chunk from one UTC
  clock read. Failure/outer rollback, exact scalars/BLOBs and unsupported option
  errors are verified by `bulk_test.iyi`; see `BULK.md`. Model converter inference,
  custom fragments, partial/expression targets and bulk optimistic guards remain
  pending. PostgreSQL bulk development is deferred.
- Typed belongs-to Reference policies produce explicit staged Assignment records.
  Saving inserts a new target before the owner in one shared unit of work;
  existing targets are written only with explicit autosave. create_target saves
  only the target and returns the rebuilt unsaved owner. Scope, validation, SQL,
  callback, reference and nested rollback cases are in `belongs_to_write_test.iyi`;
  global caches/inverses and general nested autosave remain pending.
- Around callbacks wrap validation/save/create/update/destroy in registration
  order, with prepend support and typed single-use continuations. Skipping,
  repeated/escaped continuation calls, swallowed errors, returned nil after a
  successful write and contained panics cannot produce fake write successes.
  SQLite rollback and ordinary before/after callback order are exercised by
  `around_test.iyi`; see `LIFECYCLE.md`.
- Exact Decimal, Date and UTC DateTime values bind as text on SQLite, with checked
  parsers and explicit hydration helpers. Decimal arithmetic/rounding stays exact;
  schema defaults, equality/IN, repository storage/reload and invalid input cases
  are covered by `scalars_test.iyi`. SQLite Decimal schema columns use TEXT to
  avoid NUMERIC affinity loss. SQL numeric ordering/ranges/aggregation and mapping
  automatic metadata remain pending; see `SCALARS.md`.
- Explicit `DecimalPolicy` supports nullable assignment, exact string/integer
  conversion, declared scale rounding and optional post-rounding precision checks.
  Hydration preserves already stored exact values without assignment rounding or
  precision alteration. `decimal_policy_test.iyi` covers signed ties, carries,
  huge values, configuration errors and typed mapping storage/update/hydration.
- The trait-field artifact regression is fixed in iyi compiler commit
  `a03fc3438`. Schema migration artifacts exposed compound references containing
  definition witnesses, fixed by the additional local compiler patch preserved
  in `scripts/compiler-witness-union.patch`. All 126 compiler artifact tests pass.
  The rebuilt local compiler passes twenty-two artifact test consumers, the generated
  schema factory consumer and the minimal layout reproduction. Older installed
  compilers require both fixes; see `ARTIFACT-ISSUE.md`. Current source execution
  passes all 35 SQLite test programs.
- `scripts/check.sh` repeats the type/format/tests and artifact consumer checks.

Native tests cover these areas, not the original ORM's entire parity tracker.
The original Crystal tests in `crystal-upstream/spec` are the behavior reference and have not
been translated wholesale to native iyi yet.

## Remaining work

1. Complete exact decimal SQL comparison/ordering/aggregation and automatic column
   metadata. PostgreSQL live CRUD/result verification remain deferred.
2. Complete column collation/comment metadata and DDL size/precision options, attached/temporary schema
   dumping, composite model keys and the remaining migration capabilities;
   add connection pools, prepared-statement caches and nonblocking scheduling.
3. Complete remaining validators, conditional callback metadata and normalization parity,
   automatic dirty-state checkpoint/rollback integration, no-op optimistic saves,
   remaining timestamp behavior and defaults.
4. Complete association inverses/caches, through/polymorphic and composite-key loading,
   nested attributes, STI, dependent behavior and the remaining relation APIs.
5. Complete bulk fragments/targets/model integration and remaining locking APIs;
   port encryption, serialization, multiple databases,
   sharding and other features in the original module inventory.
6. Translate and run the original behavior cases in small native test groups;
   validate source-free `.iyimod` consumption and consumer integration.

The ct application has not been switched to this incomplete port yet. A complete
conversion requires this remaining work; changing file extensions does not
satisfy it.

## Repository organization

Native iyi code and tools now live at the root of `~/contribute/grant`.
The complete tracked Crystal baseline is imported unchanged under
`crystal-upstream/` with Git subtree metadata. The original history and the
original `main` baseline remain available; the layout is prepared on
`feature/phase-0-native-iyi`. The earlier `~/apps/grant-iyi` tree is superseded.

`UPSTREAM.md` separates imported source revisions from native behavior review.
`scripts/update-crystal-upstream.sh` takes an explicit Crystal repo/ref, checks
its layout, and makes a squashed source import. Native behavior changes are
separate work and separate commits. No remote or public branch has been changed.

## Layout verification

- The imported `crystal-upstream/` Git tree matches the source baseline's root
  tree exactly (`b298faa7a10c7bff3d4e433032938f94348eb8fd`).
- All archived source-inventory hashes match the corresponding subtree files.
- At layout bootstrap, `scripts/check.sh` passed six native test programs and
  the artifact consumer. The current expanded port passes 35 SQLite source tests,
  twenty-two artifact test consumers and a generated schema factory consumer with
  the fixed local compiler.
- The upstream script recognizes an already imported revision as a no-op.
- In disposable repositories, a new source revision imports only into the
  subtree, leaves the native library tree unchanged, and matches the new
  source tree exactly. A native-root source is rejected.

## Model facade and sealed class mappings (2026-10-13)

- Added package-root `import grant/model::*` with common typed ORM names,
  preserving the previous model path. Core contracts moved unchanged to
  `grant/record_repository.iyi`; timestamp/association modules depend on that
  lower-level module to keep the import graph acyclic.
- Added local `derive mapped_record`, `mapped` and `validates_presence` macros.
  Application-owned classes and structs can generate typed attribute extraction,
  checked hydration and rebuilding with explicit validation. This covers the
  typed-field portion of the original columns API; it does not port its inherited
  DSL, converter inference, association caches or all model behavior.
- `model_api_test.iyi` uses a separate producer class/mapping, real SQLite CRUD,
  validation errors, class reference semantics and malformed-row rejection. The
  source-free gate includes the producer's expanded derive and mapping. See
  `doc/MODEL-API.md` for the API and remaining limitations.

## Field declarations (2026-10-13)

- Added `field` plus opt-in `derive field_constructor` to declare read-only fields,
  types and defaults once. Existing explicit constructors/mapped_record remain
  supported. Defaults run per construction, including mutable expressions;
  nullable fields can omit the nil default. Non-nullable fields require defaults.
- Native model API checks cover positional/keyword construction, defaults, real
  SQLite validation/insertion/hydration and isolated mutable defaults. The fixture
  is also included in the source-free producer/consumer gate.
- This does not add the inherited Crystal column DSL, writable fields, custom
  database column names or automatic association metadata.

## Single-declaration models (2026-10-13)

- Added local `table`, the model form of `validates_presence`, and `derive model`.
  Field constructors and checked attribute hydration delegate to the existing
  derives. Model-owned metadata configures a stateless generic `ModelMapping(T)`
  exposed through `Model.mapping`; database connections remain repository-owned.
- Supports presence rules, omitted validation and custom single primary keys.
  Missing table declarations and unknown presence fields fail at compile time.
  Native/API artifact checks cover actual SQLite writes/hydration, validation,
  default construction, no-validation records and custom-key lookup.
- Explicit mapping structs and their current presence macro remain supported for
  custom validation, normalization, tenant policies and other business rules.
  No inherited ActiveRecord DSL, automatic schema creation or global registry.
