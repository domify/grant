# Explicit SQLite bulk writes

`Writer` in `grant/bulk` performs multi-row insert/upsert operations using stored
`Attributes` values. It bypasses model validation, normalization, per-record
callbacks and model hydration. Applications supply database-ready values; there
is no inherited model DSL or automatic converter/tenant discovery.

```iyi
import grant/bulk::{Writer}
import grant/query::{Table}
import grant/value::{Attributes, Value}

writer = Writer.new(database, Table.new("products"))
rows = [
  {"sku" => "first", "price" => exact_price} of String => Value,
  {"sku" => "second", "price" => another_price} of String => Value,
] of Attributes
result = writer.insert_all(rows, returning: ["id", "sku"]).or_panic
```

`insert_all` skips unique conflicts by default. `insert_raise` returns a database
error on conflicts. `upsert_all` updates conflicting rows, defaulting to the
table's actual primary key; it needs an explicit `unique_by` if there is no key.
`unique_by` accepts a nonempty column list or the name of an ordinary unique
index. A targeted conflict on a different unique key still fails. SQLite verifies
that the target is backed by an appropriate unique constraint/index.

Every input row must expose the same names, though hash order may differ. Names
must match declared stored columns; generated/hidden assignments and unknown
columns are rejected. Input hashes and configuration collections are copied.
Nonempty lists of empty attribute hashes are not supported as repeated DEFAULT
VALUES operations. An empty list returns zero affected rows without stamping.

## Results and chunking

`Result.affected` reports actual affected rows and `rows` returns an independent
array of lightweight returned `Row` values. Default RETURNING is the actual
primary-key list. Supply an explicit field list, or `returning: [] of String` to
disable returning. Tables without keys can use explicit fields or no returning.
SQLite does not promise RETURNING order; identify rows by their returned keys.
Generated fields can be returned. No missing row is manufactured for a skipped
conflict or a guard that prevented an update.

The SQLite adapter exposes the current `sqlite3_limit` bind cap through
`Database.parameter_limit`. Writers cap batches at 32766 parameters by default,
or an explicitly configured smaller/larger `batch_parameters`, always respecting
the actual connection limit. One row exceeding the effective budget returns an
error. All chunks share one transaction or nested savepoint, so a later error
undoes earlier chunks even if an outer unit of work catches the error. The caller
owns the connection exclusively. PostgreSQL bulk development remains deferred.

## Upsert fields, scopes and timestamps

An upsert ordinarily updates inserted fields except the primary key, conflict
target, configured readonly fields, creation timestamp fields and scope fields.
`update_only` narrows the update list. Unknown/noninserted/protected requested
fields are errors. An empty effective list becomes DO NOTHING.

Configure equality scope values on the writer:

```iyi
writer = Writer.new(database, Table.new("products"),
                    scope: {"tenant_id" => tenant_id} of String => Value)
```

Rows cannot contradict the scope; omitted scope fields are supplied explicitly.
Conflict updates additionally require the existing row's scope fields to match
the proposed row using SQLite's null-aware IS comparison. A global unique key
therefore cannot rewrite a different tenant's row. This is an explicit equality
scope, not a general relation/filter DSL or global tenant registry.

Timestamp columns are explicit constructor metadata: pass `created`, `updated`,
a typed `Clock` and optionally precision 0–9. With configured columns, one UTC
clock reading serves the entire call and all chunks. Insert fills missing/nil
timestamp values while preserving explicit values. Upsert refreshes configured
update timestamps and preserves existing creation timestamps. Automatic update
timestamps are appended to `update_only` unless protected. Names ending `_on`
receive UTC date text; other fields receive UTC RFC3339 text at declared precision.
`stamp: false` disables automatic stamping for the call. Scoped timestamp fields
cannot be automatically stamped. Clock panics are contained and roll back.

Int64, Decimal, Binary and other stored `Value` members use the adapter's normal
bound representation. No Float64 widening or text/BLOB conversion is introduced.
Exact decimal columns must use SQLite TEXT, as documented in `SCALARS.md`.

## Verified and pending

`bulk_test.iyi` verifies duplicate skip/raise and targeted conflicts, named indexes,
primary-key upserts, selected/protected updates, RETURNING, chunk rollback,
scope guards, timestamps, exact scalars/BLOBs, failed options and closed connections.
It also runs as a source-free artifact consumer.

Partial/expression unique-index targets, custom SQL update fragments, model-level
converter integration, automatic model metadata inference, bulk optimistic version
guards and PostgreSQL bulk behavior remain pending. Unsupported named partial/
expression indexes are rejected explicitly. Raw bulk operations do not run
`Optimistic(T)` guards or model callbacks; version-protected services must not
substitute them for guarded model writes.
