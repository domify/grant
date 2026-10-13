# Port hints

The native structural spike passes. Read doc/PORTING.md for deferred macro bodies, generic named argument assignment, public module re-exports, and Base-owned transaction state.

Start with transactions. Stage A owns shared base, columns, SQLite adapter, query builder, transactions, callbacks and validations. Stage B owns query, associations, and dirty_state+other in separate worktrees.

Use `ruby port/manifest.rb generate` to refresh generated metadata while retaining progress. Use `ruby port/manifest.rb stats` for totals. Do not modify generated source/area/example counts or exclusions.

Use `bin/port-check --integrate` for Stage B merges and the Stage A stop condition. It runs the full regression checks while allowing todo entries; its OK means no regression. Only full `bin/port-check` establishes completion and lets the loop exit 0.
