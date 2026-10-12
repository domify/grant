# SQLite schema changes and snapshots

`Schema` creates tables and indexes and reads SQLite columns through
`table_xinfo`, including generated columns. `rename_column` delegates to SQLite's
native rename operation. Identifiers supplied to builders use Grant's checked
identifier API. These APIs do not constitute the full original schema DSL.

## Column changes

Configure an `AlterTable` before applying it:

```iyi
import grant/schema::{Column, ColumnType}
import grant/schema_alter::{AlterTable}

plan = AlterTable.new(database, "people")
plan.add(Column.new("rank", ColumnType::Integer, default: 0_i64))
plan.change_null("email", false, "unknown")
plan.change_default("rank", 1_i64)
plan.remove("legacy", if_exists: true)
plan.apply.or_panic
```

`add`, `remove`, `change_type`, `change_null`, `change_default`,
`change_default_sql` and `remove_default` combine into one transactional table
rebuild. `add(..., if_not_exists: true)` and `remove(..., if_exists: true)` are
explicit guards. Adding a non-null column without a usable default to a populated
table fails rather than manufacturing a value. `change_null` backfills nulls
only when tightening nullability and a backfill value is supplied. It also works
for a column added by the same plan. Removing then adding the same name creates
a new column whose values come from its new default, rather than the old column.

SQL default expressions are authored SQL, not application input. A SQL default
and a `Column.default` cannot both be supplied. Typed Decimal and Binary defaults
retain SQLite TEXT/BLOB storage. Type changes use SQLite's ordinary affinity
conversion; they are not custom data conversions.

The scanner preserves original catalog SQL outside the changed clauses:
collations, checks, foreign keys, generated definitions, conflict clauses,
composite primary keys and table suffixes such as `WITHOUT ROWID` survive.
Generated columns are recalculated instead of copied. Existing explicit indexes
and triggers are recreated, except objects referring to a removed column. Views
keep their references to the original table name. Table constraints mentioning a
removed column are removed; removing a member of a table-level primary key is
rejected. If another surviving definition requires a removed column, SQLite
rejects the rebuild and the transaction restores the original table.

AUTOINCREMENT tables retain their sequence, including previously deleted high
IDs. Ordinary implicit rowids without a declared integer primary key are not
stable identifiers across a rebuild. Plans read the current catalog at apply
time; configure and use them with one exclusively owned connection.

## Keys and named constraints

`Definition` accepts an explicit `primary_key: ["account_id", "member_id"]`
or derives the key from columns flagged `primary_key: true`. Do not combine
these two declarations. Composite members become non-null and one table-level
primary key is emitted. `without_rowid: true` requires a key and excludes
AUTOINCREMENT. `ColumnInfo.primary_position` reports SQLite's one-based primary
key order (zero for other columns). These are table-level capabilities;
`Repository` still uses single Int64 model IDs.

Use `Check`, `Unique` and `Reference` from `grant/schema_constraints` with the
`Constraint` union in `Definition.constraints`. Names are explicit. For example:

```iyi
import grant/schema_constraints::{Constraint, Check, Unique, Reference, Action}

constraints = [
  Check.new("positive_price", "price > 0"),
  Unique.new("account_sku", ["account_id", "sku"]),
  Reference.new("account_owner", ["account_id"], "accounts", ["id"],
                on_delete: Action::Cascade, on_update: Action::Cascade),
] of Constraint
```

Key lists must be nonempty, distinct and refer to declared source columns.
Foreign-key source/target lists have equal lengths. Actions include Restrict,
Cascade, SetNull, SetDefault and NoAction. Check expressions are application-
authored SQL. Definition and constraint key collections are copied at construction
and when returned. These extended definitions currently target SQLite only.

`AlterTable.add_constraint` adds named table-level checks, unique constraints and
foreign keys. Existing data must pass the new constraints; failure rolls back
the rebuild and restores all data. Duplicate names, including inline names, are
rejected.

`remove_constraint(name, if_exists: false)` removes named checks, unique
constraints and foreign keys at either table or column level. To select named or
unnamed constraints by their definition, use `remove_check(expression)`,
`remove_unique(columns)` or `remove_foreign_key(columns)`. These methods also
accept `if_exists: true`. Column selectors are ordered, case-insensitive and
copied when configuring the plan; they must be nonempty and distinct. All matching
constraints are removed. Unique indexes created separately from a constraint
are preserved; use `Schema.drop_index` to remove them.

CHECK expression matching ignores whitespace, comments, unquoted word case and
redundant enclosing parentheses. Quoted identifiers and string literal contents
remain exact; `note <> 'A'` does not select `note <> 'a'`. This is token matching,
not algebraic equivalence. Removing an inline REFERENCES clause also removes its
actions, MATCH and deferral modifiers, while retaining adjacent column clauses.
Named primary keys are protected. Other named column clauses such as NOT NULL or
DEFAULT require their dedicated column APIs. Missing constraints return an error
unless explicitly guarded; invalid selectors still fail even with a guard.

`schema_constraint_removal_test.iyi` covers these edits, constraint enforcement,
preserved defaults/collation/generated columns/indexes/triggers/views/sequences,
copied selectors, and failed-plan/outer-transaction rollback. The source-free
artifact gate runs the same consumer. Deferral options on new definitions and the
original naming DSL remain pending.

## Live SQLite catalog

`Catalog` from `grant/schema_catalog` reads main-schema metadata on each call:
`tables`, `table_exists?`, `primary_key`, `checks`, `uniques`, `foreign_keys` and
`indexes`. Unknown tables and SQL failures return `DatabaseError` (existence
queries instead return false). Table lists omit SQLite's internal tables and
views. Primary-key names follow key order, not column declaration order.

Check metadata includes named and unnamed inline/table checks and preserves the
original expression text. Unique metadata describes constraints, separately from
bare unique indexes, with ordered columns and optional names. Foreign-key rows
are grouped by key and source-column order and report update/delete actions.
`target_columns` contains nil members when SQL omitted the referenced column list;
SQLite uses the target's primary key, and the catalog does not invent target
names for a table that might not yet exist. SQLite foreign-key names and deferral
clauses are not recovered by this API.

Index metadata excludes the primary-key backing index, but includes unique
constraint backing indexes with origin `u` and nil SQL. Explicit indexes have
origin `c` and their original SQL. Terms report column names, expression markers,
ASC/DESC and collation, and indexes report uniqueness/partial status. Expression
terms have nil column names; consult the original SQL for the expression/predicate
text. Metadata collections are copied. Reads observe schema rebuilds without a
global cache. `schema_catalog_test.iyi` covers these APIs from source and artifacts.

`Schema.columns` includes one-based table `position`, `auto_increment` for SQLite
rowid aliases, `type_family`, character `limit` and decimal `precision`/`scale`.
`Catalog.columns` provides the same metadata for main-schema tables, and
`column_exists?(table, name, family)` optionally checks a declared type family.
Unknown tables/columns return false from existence checks; SQL failures remain
errors. `Schema.columns` additionally accepts main-schema views. All catalog
PRAGMAs explicitly read `main`, even if a temporary table shadows that name.

Type families describe declarations, separately from the `sqlite_affinity`
storage rule. For example, `FLOATING POINT` has integer affinity in SQLite.
Lengths/precision/scale are declarations, not enforced limits or inferred
mapping policies. Malformed, negative or overflowing size parameters return nil;
unrecognized declarations retain their raw `sql_type` and use family Other.
Exact native decimals stored as TEXT report family Text; this metadata never
converts them to floats or reconstructs a decimal policy. The affinity helper
describes ordinary SQLite affinity; STRICT tables' special ANY behavior is not
inferred from a type string alone.

`auto_increment` means SQLite can generate the INTEGER rowid alias; it does not
require the separate AUTOINCREMENT non-reuse clause. Inline INTEGER PRIMARY KEY
DESC, BIGINT keys, composite keys and WITHOUT ROWID keys are not rowid aliases.
Nullability follows SQLite's catalog plus the non-null rowid alias exception;
ordinary non-rowid primary keys may admit NULL. `schema_metadata_test.iyi`
verifies these differences, storage behavior, temporary shadowing and post-rebuild
metadata, and also runs against source-free artifacts.

## DDL transaction ownership

SQLite cannot disable foreign keys inside an already open transaction.
Rebuilding inside a normal unit of work with enforcement enabled therefore
returns `DatabaseError`. Open the outer DDL transaction explicitly instead:

```iyi
import grant/schema_transaction::{ddl_transaction}

result = ddl_transaction(database, rebuilds: true) do
  first = AlterTable.new(database, "people").change_default("rank", 2_i64).apply
  next first if first.is_a?(Error)
  AlterTable.new(database, "people").remove("old_flag").apply
end
result.or_panic
```

The owner disables enforcement before beginning and checks `foreign_key_check`
before committing. Nested rebuilds use savepoints and defer the final integrity
check to that owner. A manually opened transaction with enforcement already off
may also contain rebuilds; that transaction's caller owns its final integrity
check. The previous foreign-key and legacy-alter settings are restored after
success and failure. Returned errors, contained panics and cancellation roll
back the transaction.

A typed `Migration` performing rebuilds overrides `rebuilds : Bool` to return
true. `SQLMigration` accepts `rebuilds: true`. `Runner` then opens the required
DDL transaction before invoking up/down. DDL and version/checksum bookkeeping
commit together. The rebuild flag participates in the SQL migration checksum;
existing migrations with the default false flag keep their previous checksum.

## Native snapshots

`Dumper.new(database).snapshot` captures the SQLite **main** schema in one
transaction. A `Snapshot` holds immutable copies of catalog objects and native
migration checksums. It contains schema, not application rows or current
AUTOINCREMENT counters. It preserves SQLite SQL verbatim, including composite
keys, defaults, generated columns, expression/partial indexes, views and triggers.
Both cyclic foreign keys and children sorted before parents can be restored.

```iyi
import grant/schema_snapshot::{Dumper}

snapshot = Dumper.new(source_database).snapshot.or_panic
snapshot.apply(empty_database).or_panic
native_source = snapshot.to_iyi("my_schema/current").or_panic
```

Save `native_source` as an iyi module and compile/import its public `snapshot`
factory. Applying a snapshot is explicit: there is no global registration or
runtime interpretation of iyi files. Escaped SQL strings retain Unicode, quotes,
backslashes, interpolation-looking text and trigger semicolons. Constructors
accept application-authored catalog SQL; they are not an untrusted file loader.

`apply` rejects existing-object conflicts by default. `apply(..., replace: true)`
explicitly replaces the objects named in the snapshot and clears their data.
Replacement and migration bookkeeping are atomic. A final foreign-key check
rejects replacement that would strand rows in tables outside the snapshot.
Objects not named in a snapshot remain outside its replacement scope.

The default native tracking table is `grant_schema_migrations`; supply its actual
name to `Dumper` when using a custom `Runner` table. Applied versions and their
checksums are replayed, so an unchanged `Runner` does not repeat migrations after
loading. Original Crystal/Rails tool tables `schema_migrations` and
`ar_internal_metadata` are omitted, and their metadata is not translated.
Snapshots without a native tracking table do not invent one. Public collection
getters return copies. Catalog names with spaces, quotes and Unicode are retained,
although the builder APIs intentionally accept stricter identifiers.

## Verification and remaining scope

`schema_alter_test.iyi` exercises rebuild data preservation, failure rollback,
defaults/backfills, generated columns, indexes, collations, views, triggers,
sequences, foreign keys, nested DDL ownership and migration bookkeeping.
`schema_snapshot_test.iyi` exercises catalog round trips, constraints, cycles,
explicit replacement, rollback, protected external references, copied state and
native migration checksums. The artifact gate also compiles and executes the
generated snapshot factory without the Grant source tree.

Virtual tables require module-specific snapshot/rebuild support and are rejected.
Attached and temporary database schemas, selected-table dumps, arbitrary SQL-file
loading, environment metadata/protection, reversible command recording,
column collation/comment metadata, DDL size/precision options, broader index options and
a composite-key repository API remain pending. Creating or preserving a composite
table key is not the same as supporting composite model IDs. PostgreSQL schema development and live
verification remain deferred.
