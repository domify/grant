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
error unions, and basic transactions. The app supplies its typed record and
mapping. Neither a global model registry nor an inherited macro DSL is used.
Consumer web handlers and RPC handlers should call the same model services.

SQLite is the local behavioral test target. PostgreSQL connection failure is
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
concurrent scheduling, nested transactions, associations, callbacks and the
other features listed in `doc/PORTING.md` are still pending; do not assume
support. Do not silently coerce exact numeric values to floats or substitute
fake successes for unsupported operations.

The subtree bootstrap uses local commits on `feature/phase-0-native-iyi`, keeping
original Crystal history. Do not push or change public default branches without
user instructions. Keep source imports and native changes in separate commits.
