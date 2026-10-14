# Port hints

Scope is SQLite and PostgreSQL (2026-10-14). Only MySQL-only examples are excluded. `bin/port-check` runs every `*_test.iyi` with `CURRENT_ADAPTER=sqlite` and `CURRENT_ADAPTER=pg`; `PORT_ADAPTERS=sqlite` limits a local run. PostgreSQL runs in docker: `docker start grant-pg` (postgres:17, user grant/password, 127.0.0.1:5433); each checkout gets its own database `grant_<hash>`.

Drivers sit under the abstract `grant/adapter/driver` (`Connection`, `ResultSet`, `Value`, `Row`, `Mutation`); `grant/adapter/drivers` picks the driver from the URL scheme. Core code references only the driver types.

Use `ruby port/manifest.rb generate` to refresh generated metadata while retaining progress. Use `ruby port/manifest.rb stats` for totals. Use `bin/port-check --integrate` for merges; only full `bin/port-check` establishes completion.

In iyi, a panic is `raise "message"`; `select` inside a method body parses as the select statement, so call `self.select`.
