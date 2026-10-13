# Port hints

The native structural spike passes. Read doc/PORTING.md for deferred macro bodies, generic named argument assignment, public module re-exports, and Base-owned transaction state.

Start with transactions. Stage A owns shared base, columns, SQLite adapter, query builder, transactions, callbacks and validations. Stage B owns query, associations, and dirty_state+other in separate worktrees.

Use `ruby port/manifest.rb generate` to refresh generated metadata while retaining progress. Use `ruby port/manifest.rb stats` for totals. Do not modify generated source/area/example counts or exclusions.

The full gate strictly rejects unfinished entries. Consequently Stage B integration rejects partial coverage even if its individual tests pass: this is the literal full-gate requirement in TASK.md, not a relaxed integration gate. A restart hint records the failure. The stagnation cutoff prevents indefinite retrying.

This setup session mounts .git read-only, so its requested commits could not be created. The supervisor must run in a writable Git checkout to commit setup and operate worktrees.
