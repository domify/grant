# Grant native iyi port

Port the behavior of `crystal-upstream/` to native iyi following the
language's philosophy. Read `README.md`, `doc/PORTING.md`, and the current files
before editing. Read `UPSTREAM.md` for the reviewed source commit and update workflow.
Native code belongs at the repository root. Crystal source is imported only
under `crystal-upstream/`; read its `CLAUDE.md`, relevant source, and focused
specs as reference. Do not hand-edit the imported tree. Use the explicit-source
`scripts/update-crystal-upstream.sh` to import updates; port behavior separately.

Native library code must compile without `--crystal` or a Crystal ORM bridge.
Use explicit imports, fully typed public APIs, sealed record types, and local
trait implementations. Preserve behavior with meaningful parity cases; adapt
APIs where class reopening, global macros, or exception unwinding conflict with
native iyi. Use error union values and implement the compiler's `Error` trait.

The source Grant is a large ORM, not just SQLite CRUD. Do not claim full parity
from the core tests, copied source files, or the automated migration candidate.
The rejected migration experiment is not library code. The canonical native
checkout is `/home/priit/contribute/grant`; the earlier `~/apps/grant-iyi`
copy is superseded. Update the source inventory and porting status
when a feature is implemented and verified.

The native API currently consists of a `Database` trait, C-backed SQLite and
PostgreSQL adapters, immutable lazy queries, `Mapping(T)`, `Repository(T)`,
error unions, nested transactions/savepoints, explicit `UnitOfWork` sessions,
lifecycle hooks, validation rules, normalization plans, dirty snapshots, schema
definitions and SQL migrations. These feature ports are partial; consult
`doc/PORTING.md` and `doc/ARTIFACT-ISSUE.md` before assuming complete parity. The app supplies its typed record and
mapping. Neither a global model registry nor an inherited macro DSL is used.
Consumer web handlers and RPC handlers should call the same model services.

Additional scalar validators are in `grant/validators.iyi`: numericality, format,
acceptance and `When` with a typed `Condition`. Conditions inspect explicit
attributes/context. See `doc/VALIDATION.md` for semantics and unported validators;
dynamic comparison operands are still pending. SQLite uniqueness lives in
`grant/database_validation.iyi`: propagate SQL failures as `DatabaseError` and
back validation with an appropriate unique index. Context-aware mappings override
`validate(record, context)`; repository update contexts supply the actual persisted
ID so nil input IDs cannot incorrectly fail self-exclusion.

Current user scope is SQLite only: implement and verify SQLite behavior first.
Keep the existing PostgreSQL adapter, but defer PostgreSQL development and live
verification until the user expands scope. The default check runner excludes
the PostgreSQL test. SQLite is the local behavioral test target. PostgreSQL connection failure is
covered; live PostgreSQL CRUD remains unverified. Tests use disposable data.
Never run the original entire Crystal spec suite in one compilation: it can
require around 20 GB RAM. For original parity reference runs, use focused specs
or the source project's grouped runner in a separate writable checkout.

Run the native test programs listed in README after appropriate changes and
check formatting with `iyi fmt --check grant grant.iyi *_test.iyi`. An artifact
build must also work for APIs crossing modules. Use a writable `IYI_CACHE_DIR`
when needed; do not repurpose HOME. There are no runtime dependency shards;
link the system SQLite/libpq libraries for the relevant adapter.

A mutable connection is owned by one request/task at a time. Pooling,
concurrent scheduling, belongs-to assignment helpers/through/polymorphism, around callbacks and the
other remaining features listed in `doc/PORTING.md` are still pending; do not assume
support. Do not silently coerce exact numeric values to floats or substitute
fake successes for unsupported operations.

SQLite `Binary` values bind as BLOB and are copied on decoding. Empty BLOB is
distinct from NULL. Do not coerce arbitrary bytes through text encoding. The
PostgreSQL adapter rejects Binary binding until its port is resumed.

Direct collection writes use `CollectionWriter(T)` and an application-owned
`Link(T)` implementation. New records and attachments run repository callbacks;
nullify/delete removals are set-based and skip callbacks, while destroy runs
callbacks. Collection operations use savepoints inside an outer unit of work.
`replace_one` implements direct has-one replacement and `remove_all` clears a
scoped collection. Register `Dependency(O, C)` on the owner's BeforeDestroy
pipeline for nullify/delete/destroy/restrict behavior; owner and child repos
must share the same UnitOfWork instance. Repository writes use nested savepoints.
Unsaved-owner staging and association-specific hooks remain pending. See
`doc/ASSOCIATIONS.md`.

The subtree bootstrap uses local commits on `feature/phase-0-native-iyi`, keeping
original Crystal history. Do not push or change public default branches without
user instructions. Keep source imports and native changes in separate commits.

The source-free artifact gate is currently failing: the installed compiler
rejects a synthetic trait witness, and the local compiler builds a consumer
with a mismatched trait-field layout that crashes. Keep this failure visible.
Do not add synthetic witness declarations to application code as a workaround.
