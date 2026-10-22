# Port TODO

State at 26c362f (2026-10-21): 273/476 specs and 2447/4735 upstream examples are done.
`bin/port-check --integrate` passes everywhere except one known PostgreSQL failure below.
One Codex worker loop (`port/run-port-resume.sh`) ports and runs `--integrate` between rounds.
Reviewer guidance for the worker is in `port/feedback/all.md` (gitignored).

## Open decisions

1. PostgreSQL connection startup is slow (about 270 ms). The `priit/pg` driver computes the
   SCRAM-SHA-256 PBKDF2 (4096 HMAC rounds) in pure iyi in `pg/pq/scram.iyi`, rebuilding pad
   strings on every round. `test/grant_connection_pool_reaper_test.iyi` therefore fails on pg
   (`reaper.sweep == 3` with a 250 ms max age) and keeps CI red. Proposed fix in `priit/pg`:
   precompute the HMAC pad state once and cache SaltedPassword per (password, salt,
   iterations), then bump `iyi.mod`. Details: `port/bugs/gate-pool-reaper-max-age.md`.
2. Done 2026-10-22: `bin/port-check` runs tests in `PORT_JOBS` parallel slots (own SQLite file,
   PostgreSQL database and TMPDIR each) and CI runs sqlite and pg as separate parallel jobs.
3. Decided 2026-10-22: `persistence/destroyed_guard_spec.cr` goes next; `save`, `update` and
   `destroy` return `Bool | RecordDestroyedError`. Draft: `port/bugs/destroyed-guard-signature.md`.

## iyi compiler bugs

- Hash equality returns false for equal hashes with union or tuple values:
  `port/bugs/iyi-dirty-hash-equality.md`, `port/bugs/iyi-hash-union-equality.md`. Tests use
  strict helper comparisons until it is fixed in iyi.

## Deferred children (categories left for last)

- `test/grant_connection_w6_database_tasks_disabled_test.iyi`
- `test/grant_convenience_methods_bulk_test.iyi` (bulk)
- `test/grant_persistence_helpers_readonly_test.iyi`
- `test/grant_query_aggregations_typed_chunked_test.iyi` (scale: chunked IN lists)
- `test/grant_query_grouped_aggregates_chunked_test.iyi` (scale: chunked IN lists)
- `test/grant_query_excluding_invert_composite_test.iyi` (composite keys)
- `test/grant_query_scoping_block_async_test.iyi` (async)
- `test/grant_persistence_equality_sti_test.iyi` (STI)
- `test/grant_query_query_parity_explain_test.iyi` (not in a deferred category; finish next)

Also deferred: sharding, composite keys, encryption, STI, bulk, scale, async, middleware,
instrumentation, query logs, `secure_password`, `signed_id`, `prevent_writes`.
