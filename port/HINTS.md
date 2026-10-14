# Port hints

Scope is SQLite and PostgreSQL (2026-10-14). Only MySQL-only examples are excluded. `bin/port-check` runs every `*_test.iyi` with `CURRENT_ADAPTER=sqlite` and `CURRENT_ADAPTER=pg`; `PORT_ADAPTERS=sqlite` limits a local run. PostgreSQL runs in docker: `docker start grant-pg` (postgres:17, user grant/password, 127.0.0.1:5433); each checkout gets its own database `grant_<hash>`.

Run one test by hand: `CURRENT_ADAPTER=pg PG_DATABASE_URL=postgres://grant:password@127.0.0.1:5433/<db> IYI_CACHE_DIR=$PWD/.iyi-cache /home/priit/contribute/iyi/bin/iyi test file_test.iyi` (create `<db>` with psql first; use your checkout's own name, never a shared one). Use `bin/port-check --fast FILE...` for your targets, `bin/port-check --integrate` before handing a branch back; only full `bin/port-check` establishes completion.

## Faithfulness rules that have been broken before

- Never flatten an upstream adapter branch to its SQLite side. `if CURRENT_ADAPTER == "pg"`, `adapter.postgres?`, `{% if adapter_literal == ... %}` stay runtime branches; the PostgreSQL side must run and pass under `CURRENT_ADAPTER=pg`. A test that hard-codes `Sqlite.new`, `sqlite3::memory:` or a temp `.sqlite3` file where upstream uses `CURRENT_ADAPTER`, `ADAPTER_URL`, `C02Support` or `W6C04` is wrong.
- `pending!("PostgreSQL only")` / `pending!("SQLite only")` in upstream becomes `if Model.adapter.postgres?` / `if ....sqlite?` around the example body, with the `# it:` marker kept.
- Do not dodge the skip-marker check (no `SKIP`, no renamed pending helpers). Do not weaken, delete or merge assertions.
- Do not split a spec into many tiny children. One target per spec file is the default; split only a genuinely huge file, into a few children.
- Keep `doc/PORTING.md` short; do not journal there.

## Spec support modules (root of the repo)

- `spec_helper.iyi`: `CURRENT_ADAPTER`, `ADAPTER_URL`, `ADAPTER_REPLICA_URL`, `register_spec_connections` (upstream's top-level `Grant::Connections <<`), `restore_default_spec_connections`, `establish_spec_connection`. Models use `connection {{ (env("CURRENT_ADAPTER") || "sqlite").id }}` where upstream uses `adapter_literal`.
- `pool_spec_support.iyi` (`C02Support`) and `w6_c04_support.iyi` (`W6C04`, real per-name databases; PostgreSQL names are prefixed with the checkout database).
- `query_spec_helper.iyi`: stub `Model`, `builder`/`pg_builder`/`sqlite_builder`, `with_legacy_implicit_order`, `ignore_whitespace?(actual, expected)`, `same_entries?` (see iyi bugs).
- `transaction_crud_models.iyi`, `transaction_sql_recorder.iyi`: shared models and the statement recorder.

## Core layout

- `grant/base.iyi` holds `Grant::Base` and the `macro inherited`/`__process_columns` expansion. Subsystems add their model API as `pub macro model_methods(model)` in their own module and one line in `__process_columns` (see `grant/locking/pessimistic.iyi`). Keep base.iyi edits small and additive; put new code in new modules mirroring upstream `src/grant/x.cr` → `grant/x.iyi`.
- Adapters: `grant/adapter/base.iyi` (`open`, `open_pool_connection`, `with_connection`, `checkout`, `translate_exception`), `pg.iyi`/`pg_connection.iyi` (libpq, async: statements park the fiber on the socket), `sqlite.iyi`/`sqlite_connection.iyi`. Drivers sit under the abstract `grant/adapter/driver` (`Connection`, `ResultSet`, `Value`, `Row`, `Mutation`); `grant/adapter/drivers` picks the driver from the URL scheme.
- Errors: `grant/error_taxonomy.iyi` has the upstream taxonomy (StatementInvalid and subclasses, ReadOnlyError, Connection*); `grant/adapter/error_translator.iyi` classifies driver codes. `grant/error.iyi` has `ErrorBase` and `ArgumentError` (returned where upstream raises it).
- `Model.adapter` returns the `Adapter::Base`; `Model.connection` returns the `Grant::Connection` facade; `Model.__connection` is a raw driver connection (avoid in new code; use `Model.adapter.open(sql, binds) { |db| ... }`).

## Query core (grant/query/)

- `builder.iyi` `Builder(Model)`: upstream clause state (`where_fields` WhereField unions, `order_fields`, `group_fields`, `join_clauses`, `having_clauses`, `limit`, `offset`, `select_columns`, `lock_mode`, `distinct?`, `is_none?`), `own_*`/`clear_*`, `chain_copy`, `*_in_place` mutators and copying chain methods, terminals (`select`, `records`, `first`/`last`/`take`/ordinals, `count`, `exists?`, `pluck`, `pick`, `ids`, `delete`, `delete_all`, `update_all`, `sole`, `empty?`/`any?`/`many?`/`one?`). Upstream `and`/`or` are `and_where`/`or_where` (keywords).
- `assembler.iyi` `Base(Model, Query)` with `Pg` (`$n`) and `Sqlite` (`?`); `predicate_renderer.iyi`; `executor.iyi` (`List`, `Value`, `Grouped`, `Pluck`, `Aggregate`, `open_statement`); `where_field.iyi` (aliases, `Sort`); `join_support.iyi`; `bind_value.iyi` (`to_bind`/`to_value`).
- Upstream reopens Builder from many files. iyi has no open classes: put each part (finders, where_chain, typed_predicates, from_and_with, ...) in its own module as `pub trait X(Model)` plus `impl X(Model) for Builder(Model) forall Model` in that same module, and import the module from `grant/query/builder.iyi` only if nothing else loads it.
- Chain-time errors (unknown field, bad component) are deferred: `defer(ArgumentError.new(...))` and the terminal returns it.

## iyi notes

- A panic is `raise "message"`. `select` inside a method body parses as the select statement: call `self.select`. `and`, `or`, `group`, `import` are keywords.
- `!` cannot propagate out of module top-level code or out of a captured block (task/proc); use `.or_panic` there, or return the error as the block value.
- `Cancelled` is not an `ErrorBase`; adapter `open` can return it. Query results convert it with `Executor.open_statement`.
- `import std/text` for gsub/sub/split/to_i64; `std/math` `Math.min` is Float-only; Regex has no captures, lookaround or flags.
- Known iyi bugs (report, do not work around silently): NamedTuple `==` is always false (compare with `to_s`/`same_entries?`); metaclass `==` is always false, even `X == X` (compare `X.to_s`).
- Import alias syntax is unknown; use fully qualified names (`::Grant::Adapter::Base::Base`). Use `Program.args`, `std/env` `ENV`.
