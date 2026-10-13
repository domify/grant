# Structural port spike

Compiler: `/home/priit/contribute/iyi/bin/iyi`, native mode (no `--crystal`). Always use `IYI_CACHE_DIR=$PWD/.iyi-cache`.

The supervisor draft now compiles into a native program. `delete_test.iyi` translates both examples from `crystal-upstream/spec/grant/persistence/delete_spec.cr`, retaining all nine original assertions and exact descriptions. `T6DeleteRecord` is translated from `persistence_regression_models.cr`; unrelated fixture models are deferred to their specs. SQLite is real and in memory. `spike_crud_test.iyi` additionally exercises create, save/update, find, where, destroy and callbacks.

A nested test initially failed to resolve local imports. The spike and generated targets therefore use root-level names, derived from upstream paths to avoid collisions. `iyi test --json FILE` builds, executes, and reports machine-readable results.

Column introspection must run inside instantiated method bodies, not during `macro finished` expansion. Generated methods now defer their macro bodies. Named arguments go through a generic `assign_attributes(args : T) forall T` helper, expanded through `T.keys`. Base explicitly owns the transaction registry: inherited class variables otherwise separate the rollback registry from instance snapshots. Required modules are re-exported for generated code. Missing prelude helpers were replaced with loops. No compiler blocker remains for this spike.

## Measurements

Measured `/usr/bin/time -f "%e s %M KB"` around `iyi test --json delete_test.iyi`, including compilation and execution:

| Cache | Elapsed | Peak RSS | Result |
| --- | ---: | ---: | --- |
| Cold, empty repository `.iyi-cache` | 0.81 s | 195516 KB | 1 passed, 0 failed |
| Warm, immediately repeated | 0.71 s | 143244 KB | 1 passed, 0 failed |

This is a vertical slice. The full gate intentionally fails until every in-scope source spec is translated and passing.

## Harness validation

The native fast gate passes both root tests. The full gate runs all source `*_test.iyi` programs; generated build artifacts, compiler cache, upstream Crystal sources and worker worktrees are not source-test directories. Pre-existing `build/port-*-artifact/consumer` outputs belong to the previous attempt and must not be discovered as new port source tests.

`bin/port-loop` passes Bash syntax checking and was deliberately not started. Its full-gate integration requirement is strict: partial Stage B branches cannot merge until full coverage passes. This follows TASK.md literally; stagnation exits rather than relaxing the gate.

Both requested Git commits were attempted, but this session exposes `.git` read-only. Git fails creating `.git/index.lock`. Setup files are ready in the working tree; the supervisor must commit them from a writable session before starting the loop.

## Transaction port increments

`grant_transaction_atomicity_test.iyi` preserves the six atomicity examples and all assertions. `grant_transaction_return_value_test.iyi` preserves the seven return-value examples, including all four successful result type assertions. Native union type descriptors with identical rendered names do not compare equal directly; these assertions compare their exact rendered type names after `.or_panic` removes returned errors.

`grant/transaction.iyi` now owns adapter-scoped connection state. Base supplies record rollback closures, which savepoints merge into their enclosing transaction on release. Plain nested blocks join; `requires_new` opens a savepoint; independent blocks open a separate SQLite connection. Model, instance, root Grant and connection transaction forms preserve block values and return original block errors. The connection form is implemented by the exported `ConnectionTransactions` trait because native iyi forbids reopening imported classes. This avoids a Base/adapter import cycle while preserving the call syntax.

`grant_transaction_isolation_sql_test.iyi` preserves all seven in-scope examples. SQLite levels map to the upstream `BEGIN`, `BEGIN DEFERRED`, `BEGIN IMMEDIATE` and `BEGIN EXCLUSIVE` statements. A nested isolation request returns `TransactionIsolationError < ErrorBase`; independent transactions may choose their own level. `transaction_sql_recorder.iyi` captures the actual transaction-control statements through an observer at the native control-statement execution point, replacing the upstream memory log backend without changing the assertions.

`grant_transaction_joinable_test.iyi` preserves all five joinable examples. `grant_transaction_handle_test.iyi` preserves all fifteen handle examples, including object identity, callback order, manual transactions, named savepoints and returned error checks. Handles are cached on their transaction state. Manual savepoint markers retain queue offsets so rollback restores only records and callbacks registered after the marker. The native connection transaction trait supplies the manual control API, and models expose `connection` as in the upstream specs.

`grant_transaction_after_all_commit_test.iyi` preserves all seven after-all-commit examples. After-all callbacks merge out of released savepoints and independently committed transactions, are discarded on rollback, and run after ordinary commit callbacks. Transaction stacks are keyed by `IyiScheduler.current.object_id`, the native runtime fiber identity; the single-threaded native scheduler needs no mutex around this registry. The upstream detached `spawn` example uses an iyi task group and the same rendezvous channel, preserving both event-order assertions.

`grant_transactions_save_natural_key_test.iyi` preserves all four natural-key examples and all 20 assertions. Column annotations retain `auto:` (integer keys default to auto-generation, string keys do not). Base binds primary keys as SQLite values, uses the declared primary column for deletion, and reports missing natural keys through the structural `Grant::Error` / `Grant::Errors` collection. String-key CRUD and the existing transaction regression suite pass.
