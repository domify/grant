# Grant for iyi

A native iyi port of Grant (0.23.4, commit `625ccd7`), the Active Record ORM for Crystal.
The goal is a structural, 1:1 port: `src/grant/x.cr` becomes `grant/x.iyi`, with the same class
inheritance, model macro DSL (`table`, `column`, `connection`, callbacks, ...) and public API.
The upstream Crystal sources live read-only in `crystal-upstream/`.

**Status: work in progress, not released.** Expect breaking changes. SQLite and PostgreSQL are in
scope; MySQL is not.

## Progress (2026-10-17)

Upstream specs are translated near line by line, keeping every assertion. Each test runs against
both SQLite and PostgreSQL 17.

| Area         | Spec files | Examples    |
|--------------|-----------:|------------:|
| transactions |    45 / 53 |   429 / 496 |
| query        |   57 / 225 |  453 / 2564 |
| other        |    35 / 65 |   100 / 276 |
| associations |    9 / 109 |   70 / 1121 |
| dirty_state  |     2 / 27 |    14 / 279 |
| **total**    |  148 / 479 | 1066 / 4736 |

About 22% of the upstream examples are ported. The transaction and connection core is nearly
complete, and schema migrations (DDL, renames, references, reversible migrations, verification)
are largely done; associations, dirty tracking and most of the query surface are still to do.

## What you can use today

These parts are ported, tested on SQLite and PostgreSQL, and reasonably usable from an application:

- **Models**: `class User < Base`, `table`, `connection`, `column` (including custom primary keys
  and natural keys), timestamps, defaults, `to_h`, JSON/YAML serialization.
- **Persistence**: `create`, `save`, `update`, `destroy`, `touch`, `import_records` (bulk insert),
  `find` / `find_strict`, `reload`, read-only records.
- **Callbacks**: lifecycle callbacks (`before_*`, `after_*`, `around_*`), aborting via callbacks,
  `after_commit` / `after_rollback` with `on:` options and savepoint de-duplication.
- **Transactions**: nested transactions, savepoints (`requires_new`), joinable transactions,
  isolation levels, read-only transactions, `Rollback` as an error value, manual transaction
  handles, cross-database nesting, transaction notifications/events.
- **Locking**: pessimistic locking (`lock`, `with_lock`).
- **Queries**: `where` (hash, raw SQL, operators), `order`, `limit`, `offset`, `distinct`, `joins`,
  `group_records`, `having`, `first`/`last`/`take`, `all`, `count`, `exists?`, `pluck`, `pick`,
  `ids`, `update_all`, `delete_all`, default scopes, `unscoped`, `scoping`.
- **Connections**: connection registry, pools, `with_connection`, reconnect on idle/broken
  connections, reader/writer roles with replica routing, fiber-local connection context.
- **Errors**: upstream error taxonomy; driver errors are translated into `StatementInvalid`,
  `RecordNotUnique`, `NotNullViolation`, `InvalidForeignKey`, `Deadlocked`, `LockWaitTimeout` etc.
- **Encryption**: `encrypts` with AES-256-CBC + HMAC, deterministic and randomized modes, lazy
  decryption, `without_encryption`.
- **Schema**: `Model.migrator` for `create`, `drop` and `drop_and_create` of model tables.

Not usable yet: associations (`has_many`, `belongs_to`, `has_one`, polymorphic, eager loading),
dirty tracking API, most validations, sharding, counter caches, enum attributes, nested
attributes, query cache, MySQL.

## Example

Add Grant to your project's `iyi.mod`:

```
require github.com/domify/grant v0.0.0 as grant
```

The modules live under `grant/` inside the package, so an import names the
package's short name and then that directory:

```iyi
import grant/grant/base::{Base}
import grant/grant/connections::{Connections}
import grant/grant/adapter/sqlite::{Sqlite}

class User < Base
  table users
  connection sqlite
  column id : Int64, primary: true
  column name : String
end

Connections.register("sqlite", Sqlite.new("sqlite", "sqlite3:./app.db"))
User.migrator.drop_and_create.or_panic

user = User.create(name: "Ann")
user.name = "Anna"
user.save
found = User.find_strict(user.id).or_panic
users = User.where(name: "Anna").order(:id).select.or_panic
user.destroy
```

For PostgreSQL use `grant/grant/adapter/pg::{Pg}` with a `postgres://user:pass@host:port/db` URL.

## Differences from Crystal Grant

iyi has no exceptions and no `!` at the end of names, so (see [doc/NAMING.md](doc/NAMING.md)):

- `raise` becomes a returned error value (types implement `Error`); handle it with a union check,
  propagate it with postfix `!`, or unwrap with `.or_panic`.
- Raising variants `find!`, `save!`, `create!`, ... are `find_strict`, `save_strict`,
  `create_strict`, ...
- In-place relation mutators `where!`, `order!`, ... are `where_in_place`, `order_in_place`, ...
- Keyword clashes get aliases: `import` → `import_records`, `group` → `group_records`,
  `and`/`or` → `and_where`/`or_where`.
- A transaction rolls back when its block returns an error.

## Running the tests

Requires the iyi compiler and, for PostgreSQL, a local server
(`docker start grant-pg`, postgres:17 on `127.0.0.1:5433`, user `grant` / `password`).

```sh
export IYI_CACHE_DIR=$PWD/.iyi-cache
bin/port-check                          # all tests, SQLite and PostgreSQL, plus coverage
PORT_ADAPTERS=sqlite bin/port-check     # SQLite only
bin/port-check --fast test/grant_transaction_test.iyi
iyi test test/delete_test.iyi           # one test, SQLite, no coverage check
```

Tests live in `test/` and run from the repository root. iyi resolves imports from the
entry file's directory, so each test starts with a `module test/<name>` header that anchors
its imports at the root, and declares its models `pub` so Grant's macros can reach them.

`bin/port-check` exits 0 only when every in-scope upstream spec is ported, so today it reports
the remaining coverage as a failure even when all tests pass.

Porting rules: [doc/PORTING.md](doc/PORTING.md), [port/HINTS.md](port/HINTS.md).

## License

MIT, same as upstream Grant. See [LICENSE](LICENSE).

## Native iyi database dependencies

The native port uses the common types from `github.com/priit/db` and the drivers
`github.com/priit/sqlite` and `github.com/priit/pg`, pinned as pseudo-versions in `iyi.mod`:

```text
require github.com/priit/db v0.0.0-20261017121930-c46d53e18181 as db
require github.com/priit/sqlite v0.0.0-20261017121947-fb786eb14b5d as sqlite
require github.com/priit/pg v0.0.0-20261017121949-b2d033771d9f as pg
```

Grant keeps a compatibility facade for its observers, transaction materialization, SQL conventions
and public errors. Database connections, statement ownership, parameter binding and row decoding
belong to the drivers. No local checkouts or `replace` directives are needed; to develop against a
local driver checkout, add a `replace` in your own `iyi.mod` (replacements inside dependencies do
not apply).

Keep sources and logs outside `.iyi-cache`, which the compiler prunes.
