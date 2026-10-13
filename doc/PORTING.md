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
