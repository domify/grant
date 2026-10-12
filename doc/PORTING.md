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
- Transaction success/error/panic rollback, joined nesting, and `requires_new`
  savepoint behavior on SQLite.
- Explicit shared units of work, ordered validation/save/create/update/destroy
  callbacks, deferred commit hooks, rollback hooks and first-record deduplication.
- Structured validation errors and presence/absence, length, inclusion/exclusion
  and confirmation rules with explicit contexts and nil/blank options.
- Explicit normalization plans, plus snapshot-based dirty state supporting
  mutable values through a supplied copying trait. Unknown runtime writes return
  `AttributeError`; batch clearing validates names before changing any baseline.
- Basic table/index definitions, SQLite/PostgreSQL column introspection and
  transactional SQL migration ordering, targets, rollback and checksum checking.
  PostgreSQL behavior beyond connection failure remains unverified.
- Native port of the original placeholder scanner, with 15 parity assertions
  covering strings, escape strings, quoted identifiers, comments, casts,
  Unicode text, dollar quotes, and escaped question-mark operators.
- The earlier core passed typed model artifact consumption. The expanded port
  currently fails that gate due to a compiler trait-field layout mismatch; see
  `ARTIFACT-ISSUE.md`. Source execution passes all 13 native test programs.
- `scripts/check.sh` repeats the type/format/tests and artifact consumer checks.

Native tests cover these areas, not the original ORM's entire parity tracker.
The original Crystal tests in `crystal-upstream/spec` are the behavior reference and have not
been translated wholesale to native iyi yet.

## Remaining work

1. Verify real PostgreSQL CRUD, transactions, and result types in an isolated
   server, then add exact decimal, date/time, and binary value types.
2. Complete schema alteration/dumping, composite keys and migration capabilities;
   add connection pools, prepared-statement caches and nonblocking scheduling.
3. Complete remaining validators, conditional normalization, around callbacks,
   dirty-state repository integration, timestamps and defaults with parity cases.
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
- At layout bootstrap, `scripts/check.sh` passed six native test programs and
  the artifact consumer. The current expanded port passes 13 source tests; its
  artifact consumer is blocked as described above.
- The upstream script recognizes an already imported revision as a no-op.
- In disposable repositories, a new source revision imports only into the
  subtree, leaves the native library tree unchanged, and matches the new
  source tree exactly. A native-root source is rejected.
