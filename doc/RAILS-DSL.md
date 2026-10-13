# Symbol-based model columns and SQLite schemas

The additional native API is `col :name, :type, **options`. It keeps names at the
same horizontal position while borrowing ActiveRecord's schema type/option
vocabulary. Typed `column name : String = ""` declarations remain available.
This is a native iyi implementation; it does not run Ruby or Rails.

```iyi
module models/account
import grant/model::*

pub class Account
  col :id, :primary
  col :name, :string, default: "", null: false, limit: 255
  col :default_locale, :string, default: "en", null: false
  col :root, :boolean, default: false, null: false
  col :settings, :json, default: {"enabled" => true}
  timestamps

  index :name, unique: true
  validates_presence :name
  derive model
end
```

Only `col` is a type-declaration macro: `:text`, `:string` and `:datetime` are
arguments, not macro names. Models can still expose an instance method `text`.
Declarations produce real typed properties, independently evaluated default
factories, constructors and the same stateless `Model.mapping` contract.
Constructor order follows declaration order; use keyword construction when
reordering model declarations.

## Types

| Schema type | Native value type | SQLite declaration/storage |
| --- | --- | --- |
| `:primary`, `:primary_key` | `Int64?` until saved | Generated INTEGER primary key |
| `:integer`, `:bigint` | `Int64` | INTEGER / BIGINT |
| `:string`, `:text` | `String` | VARCHAR / TEXT |
| `:boolean` | `Bool` | BOOLEAN, checked 0/1 hydration |
| `:float` | `Float64` | REAL |
| `:decimal`, `:numeric` | Grant `Decimal` | Exact TEXT, never REAL |
| `:date` | Grant `Date` | Checked ISO date in DATE |
| `:datetime`, `:timestamp` | Grant `DateTime` | RFC3339 text in DATETIME(p) |
| `:time` | `String` | Clock text in TIME(p); no native clock-only scalar yet |
| `:binary`, `:blob` | Grant `Binary` | BLOB |
| `:json` | `Std::Json::Any` | Encoded JSON in TEXT |

Except for primary keys, native nilability depends on construction as well as
SQL nullability. `null: false` is a database constraint, not an automatic model
presence validation. A field with no default starts as `nil` even when the
schema prohibits NULL; this also permits callbacks to populate timestamps.
With a non-null default and `null: false`, the native property is non-nullable.
With SQL `null: true` (the default for ordinary columns), the property remains nullable even if its
initial default is non-null. False, zero and explicit nil defaults are distinct
from an absent default. `default: nil, null: false` is rejected.

`as: String` is a native compatibility escape for date/datetime/time fields that
already expose text. CT Account uses DateTime directly. Otherwise,
datetime/date hydration uses the checked Grant scalars. JSON hydration rejects
malformed JSON; SQL NULL is native nil, whereas JSON `null` is `Any.new(nil)`.
JSON defaults allocate fresh arrays/objects for every record. In iyi, an empty
array must have an element type: `default: [] of String` (not bare Ruby `[]`).

## Options

- `default:` accepts literal scalar/JSON data. Decimal defaults use exact strings
  or integers; fractional integer defaults and floating-point decimal defaults
  are rejected. Arbitrary expression defaults remain available with `column`.
- `null:` and `primary_key:` accept literal booleans. Primary keys are currently
  single, generated Int64 keys, matching the existing Repository ID contract.
- `limit:` retains declared string/text/binary/integer sizes. String limits appear
  in VARCHAR(n). SQLite does not enforce declared lengths or integer byte sizes;
  the metadata is exposed by `Model.schema.fields`, not a new model validation.
- `precision:` is supported on decimal and temporal fields; `scale:` on decimal.
  Temporal precision is 0–6; typed DateTime serialization uses that precision.
  Decimal precision/scale remain schema metadata with exact TEXT storage. They
  do not silently round assignments or add SQLite decimal-size enforcement;
  the existing explicit DecimalPolicy is available for assignment rules.
- `collation:` is a literal SQLite collation name for string/text fields.
- `as:` currently permits String temporal compatibility, not arbitrary converters.

A typed `column` can coexist with `col`. For a mixed model, schema generation
infers an unambiguous SQL scalar type and nullability for typed columns; their
constructor defaults remain model defaults rather than invented SQL defaults.
Ambiguous union/custom types require explicit schema/mapping instead. A model
using only the original typed column API retains its original behavior; it does
not automatically acquire the schema DSL.

## Reference columns

```iyi
col :account_id, belongs_to: :account
col :org_id, belongs_to: :org

# Compatible positional reference spelling:
col :org_id, :ref, to: :org
col :reviewer_id, :ref, to: :user
col :legacy_org_id, :ref, to: :org, to_table: "old_orgs"
```

`col :account_id, belongs_to: :account` is the preferred reference spelling.
It accepts no positional type, and is equivalent to `col :account_id, :ref, to: :account`.
`:ref` (alias `:reference`) is a reference role using nullable Int64/BIGINT storage.
It infers the target table from `<name>_id` as `<name>s`, and declares a foreign key
plus an index. `to:` accepts the singular model-name symbol and overrides the inferred stem.
Target naming follows the current model default: name plus s. `to_table:`
accepts a literal table name or symbol for custom/irregular table names. `index: false`
omits the generated index. These options are valid only on reference columns.
Normal col defaults, nullability and validation options still apply. A ref cannot
also be a primary key. Schema fields expose Role::Reference.

The declaration produces a schema plan; it does not create or alter a database,
load an associated object or infer model validation. SQLite enforces its foreign
key only when the schema is applied and foreign-key enforcement is enabled.
Caller-owned mapping validation and existing migrations remain explicit.

## Indexes, references and checks

```iyi
references :account, foreign_key: true, null: false
references :attachable, polymorphic: true
index [:account_id, :name], unique: true, name: "unique_account_name"
index :name, where: "name IS NOT NULL", order: :desc
foreign_key :accounts, column: :account_id, on_delete: :cascade
check_constraint "balance >= 0", name: "nonnegative_balance"
```

`index` accepts one symbol or an array of symbols; options are `name`, `unique`,
`where`, `order` (:asc or :desc for all columns), and `if_not_exists`. Default
names are `index_<table>_on_<columns joined by _and_>`. Partial index predicates
are trusted SQL expressions authored in source, not input from web requests.

`foreign_key` accepts a literal table name or symbol. Options are `column`,
`primary_key`, `name`, `on_delete`, and `on_update`. Column/key lists may be
composite. Actions are :cascade, :restrict, :nullify/:set_null, :set_default,
and :no_action. The default target key is :id. Target tables are not created
implicitly. Composite schema references do not add composite Repository IDs.

`references` (alias `belongs_to`) is a **storage declaration**, not an association
loader: it adds `<name>_id`, an index by default, and an optional foreign key.
Options are `type` (:integer/:bigint), `null`, `index`, `foreign_key`,
`polymorphic`, `to_table`, `on_delete`, and `on_update`. A polymorphic reference
adds `<name>_type` and a compound type/id index; a single-table foreign key is
rejected for it. Default target naming is `<name>s`; use `to_table` for irregular
or legacy names. Explicit association readers/writers remain the existing API.

`col :created_at, :timestamp` uses a role bundle, analogous to `:primary`:
DateTime storage, NOT NULL and precision 6. It rejects `null: true`; use
`:datetime` for nullable event times. Schema fields expose `Role::Timestamp`
or `Role::PrimaryKey` in `field.role`. These declarations do not register callbacks;
the caller-owned Timestamps callback fills standard timestamps. Custom timestamp
fields require explicit callback configuration.

`timestamps` adds created_at/updated_at datetime columns, defaulting to
`null: false, precision: 6`. It declares fields; the existing Timestamps
callback and caller-owned clock still own automatic stamping.
`check_constraint` accepts a nonempty SQL expression and optional literal `name`.

## Schema ownership and migrations

```iyi
sql = Account.schema.statements.or_panic
# Explicit creation on a disposable/new database:
Account.schema.create(database).or_panic
# Explicit idempotent table/index creation:
Account.schema.create(database, if_not_exists: true).or_panic
```

`derive model` never opens a connection, creates a table or alters an existing
schema. `schema` is an independent metadata snapshot; `statements` produces
SQLite DDL that can feed the existing checksum-verified SQLMigration/Runner.
`create` atomically creates the table, indexes and constraints in a DDL
transaction, rolling back table creation if any later statement fails. It
rejects other database dialects rather than guessing PostgreSQL semantics.
Unknown index/constraint columns and duplicate names fail explicitly.

Existing typed Schema/AlterTable, constraint removal, catalog snapshots and
migration reversal APIs remain available. No `force: :cascade`/automatic drop
behavior has been added to model declarations. Run `iyi run col_demo.iyi` for
an isolated in-memory example; it also shows real constraint failures and
atomic DDL rollback. Its producer model is in `examples/col_models.iyi`.

## Source and remaining scope

Reference: Rails **v8.1.4**, commit
`c3466ea00d7121798e3aa3144ffdf7174b81d8cb` (release published 2026-09-24).
Unmodified migration/schema source and the MIT license are retained under
`rails-reference/8.1.4/`; `SOURCE.json` records file/archive SHA-256 hashes.
The source reference is separate from the unchanged Crystal subtree.

The reviewed type list and column options come from
[ActiveRecord schema definitions](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb).
The native DSL adapts those declarations to sealed iyi models and explicit
connection/migration ownership; it is not a wholesale ActiveRecord port.

Still pending: virtual/generated column DSL, comments unsupported by SQLite,
SQL-function defaults, UUID/custom database types, PostgreSQL-specific options,
per-column index order/collation, index expression DSL, deferred references,
full Rails coercion, automatic associations, migration compatibility classes
and Ruby-style reversible command recording. Unsupported type/option names
are rejected during expansion; they are never silently discarded.

## Inline validation policies

The same declaration can specify validation without repeating the field name:

```iyi
col :name, :string, default: "", presence: true
col :username, :string, presence: true, uniq: {scope: :account_id}
col :title, :string, length: {minimum: 2, maximum: 255}
col :role, :string, inclusion: {in: ["reader", "writer"]}
col :reserved_name, :string, exclusion: {in: ["admin", "root"]}
col :contact_email, :string, email: true
col :website, :text, url: {allow_blank: true}
col :email, :string, format: {with: /\A[^@]+@[^@]+\z/}, allow_nil: true
col :started_at, :datetime
col :ended_at, :datetime, comparison: {greater_than: :started_at}, allow_nil: true
col :count, :integer, numericality: {only_integer: true, greater_than: 0}
col :accepted, :boolean, acceptance: true
col :unused, :string, absence: true
```

`null: false` excludes SQL NULL but accepts empty text; `presence: true`
excludes nil, empty/blank text and false and implies SQL NOT NULL. Combining
literal `presence: true` with `null: true` is a compile error. Named or conditional
presence policies keep the explicit schema nullability choice; NOT NULL alone
does not imply presence validation. Presence/absence also recognise empty JSON
arrays/objects and JSON null. A string `limit` is still schema metadata, not
an automatically inferred length validator. CT Account moves its existing
presence check onto its name declaration without adding a uniqueness rule.

Supported rules are presence, absence, length, inclusion, exclusion, format, email, url,
comparison, numericality, acceptance, confirmation and `uniq`. Each accepts true/false or
literal named options; rules needing bounds/lists/patterns require those options.
Common `allow_nil`, `allow_blank`, `on`, and `message` options may appear on the
col or inside an individual rule; the individual rule takes precedence.
`on` accepts one operation/context symbol or string, or a literal array such
as `[:create, "publish"]`. Shared options and per-rule overrides use the same
context matching. Invalid array elements fail compilation.
Messages are literal strings. Unknown/unsupported configurations fail explicitly.

- Length accepts minimum/maximum or is, measured in string characters. It is
  currently for string/text columns; numeric size limits do not become length.
- Inclusion/exclusion accept a literal scalar array under `in` for primitive
  string/boolean/integer/float fields (use a typed empty array if needed). Ranges,
  dynamic providers and Date/Decimal/Binary list conversion are not supported.
- Format accepts with or without, as a literal string or unflagged regex. It
  compiles the source through native std/regex; flags, interpolation and engine
  features outside that engine's supported syntax are not silently emulated.
- Email/URL use the shared Crystal Grant conventional format patterns and
  default messages. They support common rule options on string/text columns,
  including nullable or blank values when explicitly allowed. `false` disables
  the declaration. Incompatible column types and unknown rule options fail
  compilation. The rules preserve stored input text; they do not normalize it.
- Numericality accepts only_integer, only_numeric, odd/even, greater_than,
  greater_than_or_equal_to, less_than, less_than_or_equal_to, equal_to and
  other_than with literal signed bounds. Native numeric/text fields are supported;
  exact Decimal rules remain the explicit DecimalPolicy/dynamic validation API.
- Comparison accepts the six comparison keys with literal signed numbers,
  strings, booleans or nil, or a mapped-field symbol. Symbols refer to declared
  attributes, with unknown fields rejected during model derivation. Rules use
  typed assigned scalars before timestamp storage precision is applied, preserving
  exact decimals and nanosecond instants during validation. Numeric text is not
  parsed. Nil bounds report comparison failure, while incompatible ordered types
  return DatabaseError. Serialized JSON comparisons are rejected explicitly.
  Dynamic method/Proc policies use explicit ComparisonRule.
- Acceptance defaults to the exact values "1" and true and skips nil by default.
  `accept` can supply literal scalar value(s); no string/boolean coercion is added.
- Confirmation requires a declared mapped `<name>_confirmation` field; it skips
  absent/nil confirmation and supports case_sensitive. This does not introduce
  virtual model attributes or automatically persist an undeclared confirmation.

`uniq` is the application spelling. `uniqueness` and `uniquness` are compatibility
aliases, and using more than one spelling on the same col is rejected. Options
are scope (symbol or symbol array), case_sensitive, and the common rule options.
Unknown scope fields are rejected at derive time. Case-insensitive rules require
string/text columns. The existing native uniqueness validator skips nil values.

Repository supplies its own Database and the authoritative update ID to model
validation, keeping Model.mapping stateless. Unchanged updates exclude their own
persisted row even when the supplied object's id is nil. Direct Mapping.validate
without a database returns DatabaseError when an applicable non-nil uniqueness
value needs a query. SQL failures propagate as DatabaseError, not a false "taken"
message. Existing custom mappings continue using their existing context overload.

`uniq` is a model validation, not a concurrency guarantee or implicit schema
migration. Declare the matching unique index separately for database enforcement:

```iyi
col :username, :string, uniq: {scope: :account_id}
index [:account_id, :username], unique: true
```

Choose matching database collation/index semantics for case-insensitive rules.
The validator does not silently manufacture an index with different semantics.
Standalone validates_presence remains supported for legacy declarations and
explicit mappings; Account no longer needs it. Run `iyi run
inline_validation_demo.iyi` for an isolated example of accumulated errors,
scoped/case-insensitive uniqueness, update self-exclusion, context rules,
confirmation, JSON presence, and SQL error propagation. Its producer model also
works when consumed from source-free artifacts. No Rails environment is loaded.
