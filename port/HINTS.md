# Hints

ScopeScope is SQLite and PostgreSQL. `bin/test` runs every `*_test.ri` with `CURRENT_ADAPTER=sqlite`
and `CURRENT_ADAPTER=pg`; `TEST_ADAPTERS=sqlite` limits a run and `bin/test FILE...` runs only
those. PostgreSQL runs in docker: `docker start grant-pg` (postgres:17, user grant/password,
127.0.0.1:5433); each checkout gets its own database `grant_<hash>`. Tests run in `TEST_JOBS`
parallel slots (default nproc/2), each with its own SQLite file, PostgreSQL database and TMPDIR.

Tests live in `test/`; each starts with `module test/<name>` and declares its models `pub`. Run
one test by hand from the repository root: `CURRENT_ADAPTER=sqlite IYI_CACHE_DIR=$PWD/.ris-cache
/home/priit/contribute/ris/bin/ris test test/file_test.ri`. After touching a shared module, also
run the tests that use it (`rg -l` the API in `test/`).

ec support modules (root of the repo)

- `test/spec_helper.ri`: `CURRENT_ADAPTER`, `ADAPTER_URL`, `ADAPTER_REPLICA_URL`, `register_spec_connections` (upstream's top-level `Grant::Connections <<`), `restore_default_spec_connections`, `establish_spec_connection`. Models use `connection {{ (env("CURRENT_ADAPTER") || "sqlite").id }}` where upstream uses `adapter_literal`.
- `test/pool_spec_support.ri` (`C02Support`) and `test/w6_c04_support.ri` (`W6C04`, real per-name databases; PostgreSQL names are prefixed with the checkout database).
- `test/query_spec_helper.ri`: stub `Model`, `builder`/`pg_builder`/`sqlite_builder`, `with_legacy_implicit_order`, `ignore_whitespace?(actual, expected)`, `same_entries?` (see ris bugs).
- `test/transaction_crud_models.ri`, `test/transaction_sql_recorder.ri`: shared models and the statement recorder.

## Core layout

- `grant/base.ri` holds `Grant::Base` and the `macro inherited`/`__process_columns` expansion. Subsystems add their model API as `pub macro model_methods(model)` in their own module and one line in `__process_columns` (see `grant/locking/pessimistic.ri`). Keep base.ri edits small and additive; put new code in new modules mirroring upstream `src/grant/x.cr` → `grant/x.ri`.
- Adapters: `grant/adapter/base.ri` (`open`, `open_pool_connection`, `with_connection`, `checkout`,
  `translate_exception`), `pg.ri`/`pg_connection.ri` (iyilang/pg, native protocol and async socket
  IO), `sqlite.ri`/`sqlite_connection.ri`. Drivers sit under the abstract `grant/adapter/driver`
  (`Connection`, `ResultSet`, `Value`, `Row`, `Mutation`); `grant/adapter/drivers` picks the driver
  from the URL scheme.
- Errors: `grant/error_taxonomy.ri` has the upstream taxonomy (StatementInvalid and subclasses, ReadOnlyError, Connection*); `grant/adapter/error_translator.ri` classifies driver codes. `grant/error.ri` has `ErrorBase` and `ArgumentError` (returned where upstream raises it).
- `Model.adapter` returns the `Adapter::Base`; `Model.connection` returns the `Grant::Connection` facade; `Model.__connection` is a raw driver connection (avoid in new code; use `Model.adapter.open(sql, binds) { |db| ... }`).

## Query core (grant/query/)

- `builder.ri` `Builder(Model)`: upstream clause state (`where_fields` WhereField unions, `order_fields`, `group_fields`, `join_clauses`, `having_clauses`, `limit`, `offset`, `select_columns`, `lock_mode`, `distinct?`, `is_none?`), `own_*`/`clear_*`, `chain_copy`, `*_in_place` mutators and copying chain methods, terminals (`select`, `records`, `first`/`last`/`take`/ordinals, `count`, `exists?`, `pluck`, `pick`, `ids`, `delete`, `delete_all`, `update_all`, `sole`, `empty?`/`any?`/`many?`/`one?`). Upstream `and`/`or` are `and_where`/`or_where` (keywords).
- `assembler.ri` `Base(Model, Query)` with `Pg` (`$n`) and `Sqlite` (`?`); `predicate_renderer.ri`; `executor.ri` (`List`, `Value`, `Grouped`, `Pluck`, `Aggregate`, `open_statement`); `where_field.ri` (aliases, `Sort`); `join_support.ri`; `bind_value.ri` (`to_bind`/`to_value`).
- Upstream reopens Builder from many files. ris has no open classes: put each part (finders, where_chain, typed_predicates, from_and_with, ...) in its own module as `pub trait X(Model)` plus `impl X(Model) for Builder(Model) forall Model` in that same module, and import the module from `grant/query/builder.ri` only if nothing else loads it.
- Chain-time errors (unknown field, bad component) are deferred: `defer(ArgumentError.new(...))` and the terminal returns it.

## ris notes

- A panic is `raise "message"`. `select` inside a method body parses as the select statement: call `self.select`. `and`, `or`, `group`, `import` are keywords.
- `!` cannot propagate out of module top-level code or out of a captured block (task/proc); use `.or_panic` there, or return the error as the block value.
- `Cancelled` is not an `ErrorBase`; adapter `open` can return it. Query results convert it with `Executor.open_statement`.
- `import std/text` for gsub/sub/split/to_i64; `std/math` `Math.min` is Float-only; Regex has no captures, lookaround or flags.
- Known ris bugs (report, do not work around silently): NamedTuple `==` is always false (compare with `to_s`/`same_entries?`); metaclass `==` is always false, even `X == X` (compare `X.to_s`).
- Import alias syntax is unknown; use fully qualified names (`::Grant::Adapter::Base::Base`). Use `Program.args`, `std/env` `ENV`.
