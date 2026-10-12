# Native iyi conversion status

Source: Crystal Grant 0.23.4 at commit
`dfad8bfc89778a6d89e38ff481899db552e428b8`.
Target: `/home/priit/contribute/grant`. Native code is at the root; original
Crystal source is preserved unchanged as the `crystal-upstream/` Git subtree.

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
- Native PostgreSQL adapter via libpq, copied result data, parameter binding,
  PostgreSQL placeholder rewriting, and explicit errors for unsupported binary
  values. It compiles and its connection failure path is tested; live SQL is
  not yet verified.
- Lazy, immutable equality/null predicates with AND semantics, ordering,
  pagination, count, insert returning a row, scoped update and delete.
- Identifier checks and parameter binding; extra tenant predicates cannot
  replace an earlier tenant predicate.
- Typed `Mapping(T)` and `Repository(T)` with validation, decoding, lookup,
  insertion, and scoped update. A scope for another database is rejected.
- Basic transaction success/error/panic rollback behavior on SQLite.
- Native port of the original placeholder scanner, with 15 parity assertions
  covering strings, escape strings, quoted identifiers, comments, casts,
  Unicode text, dollar quotes, and escaped question-mark operators.
- Typed model artifact build using `--emit-iyimod`, plus a successful
  source-free consumer build/run using `--use-iyimod`.
- `scripts/check.sh` repeats the type/format/tests and artifact consumer checks.

Native tests cover these areas, not the original ORM's entire parity tracker.
The original Crystal tests in `crystal-upstream/spec` are the behavior reference and have not
been translated wholesale to native iyi yet.

## Remaining work

1. Verify real PostgreSQL CRUD, transactions, and result types in an isolated
   server, then add exact decimal, date/time, and binary value types.
2. Port schema definitions/introspection and migrations; add adapters' feature
   capability contracts, connection pools, prepared-statement caches, and
   scheduling without blocking request tasks.
3. Port validations, normalization, lifecycle/commit callbacks, dirty tracking,
   timestamps, defaults, and scoped operations with parity cases.
4. Port association loading/writing, nested attributes, STI, eager loading,
   dependent behavior, and scoped relation APIs.
5. Port bulk operations, locking, encryption, serialization, multiple databases,
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
- `scripts/check.sh` passes: six native test programs, type/format checks,
  and a source-free `.iyimod` consumer build/run.
- The upstream script recognizes an already imported revision as a no-op.
- In disposable repositories, a new source revision imports only into the
  subtree, leaves the native library tree unchanged, and matches the new
  source tree exactly. A native-root source is rejected.
