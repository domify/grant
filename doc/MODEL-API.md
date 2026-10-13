# Model facade and local mapping macros

A package consumer can bring the common model API into scope with one import:

```iyi
import grant/model::*
```

`import grant/model` loads the module with qualified names instead. The facade
exports mapping/repository, query/table, attributes/row/scalars, database/error,
validation, lifecycle, timestamp and unit-of-work types. Adapters and specialized
association/locking APIs have their own imports. The existing package path
`import grant/grant/model::{Mapping, Repository}` remains supported.

Models can be sealed classes, with reference semantics, or structs for value
snapshots. A relationship between models does not require inheritance. Place
shared types in lower-level modules; imports must remain acyclic.

```iyi
module models/account

import grant/model::*

pub class Account
  table "accounts"

  field name : String = ""
  field id : Int64? = nil

  validates_presence "name"
  derive model
end

# The repository owns the database connection; the mapping is stateless.
repository = Repository(Account).new(database, Account.mapping)
```

`derive model` combines the field constructor, checked attribute mapping and a
stateless `Account.mapping` adapter implementing `Mapping(Account)`. Declare
`table "accounts"` before the derive; optionally set `primary_key: "key"`.
`validates_presence "name", "other"` declares all presence checks in one call
before the derive. Omitting it adds no validation. Unknown validation field names
and a missing table fail at compile time. Table/presence metadata belong to the
model declaration, not a global registry. The derive neither opens a connection
nor creates tables; schema, migrations and repository ownership remain explicit.

For models needing custom database-backed validation, normalization, readonly
columns or converters, the explicit mapping API below remains available:
`derive field_constructor, mapped_record`, a caller-owned mapping struct, and
`mapped Account, "accounts"` inside its `impl Mapping(Account)`.

`field name : String = ""` declares a typed read-only getter and a default
factory. `derive field_constructor` generates the matching typed positional and
keyword constructor. Put it after all fields, before `mapped_record`. Defaults
are evaluated for each construction, so mutable defaults are not shared. A
nullable field without a default uses `nil`; non-nullable fields require an
explicit default. Generated `__grant_field_default_*` methods are implementation
helpers. Use only `field` declarations with `field_constructor`; models needing
custom constructors can continue using `getter`/`property` and `mapped_record`
without the constructor derive.

`derive mapped_record` generates `to_attributes` and checked `from_attributes`.
Place it after the declared fields and constructor. Every field needs an explicit
type within Grant's `Value` union and a matching keyword constructor. Field names
are column names. Missing columns and invalid types return `DatabaseError`;
extra row columns are ignored. Integer booleans accept only 0/1, nullable fields
preserve NULL, and decimal/date/datetime hydration uses checked scalar decoders.
Float64 is never accepted as exact Decimal. Use an explicit mapping for custom
column names, converters, association caches or non-persisted instance fields;
unsupported field types fail at compile time.

`mapped Account, "accounts"` supplies table metadata, attribute extraction,
hydration and record rebuilding. Set `primary_key: "key"` for a different single
primary key, or `rebuild: false` and implement `with_attributes` yourself.
Validation is explicit: use `validates_presence` for this simple case or provide
typed `validate` methods for business rules. Normalization, readonly columns,
callbacks, authorization and account scopes remain application-owned policies.

Class properties can expose mutation; getters alone retain the application's
read-only field API. Repository operations still rebuild records and return the
saved record. Use that return value for generated IDs/timestamps. These macros
do not add an identity map, change tracking, instance `save`, automatic association
loading, callbacks or ActiveRecord-style inheritance.

The facade delegates its core contracts to `grant/record_repository.iyi` so
timestamp and association modules can depend on that lower-level contract
without creating import cycles. `model_api_test.iyi` imports a class and mapping
from `fixtures/model_api.iyi`. The source-free gate carries that producer as
`.iyimod` and compiles the consumer without producer source, verifying the
producer's expanded derive and generic trait implementation.
