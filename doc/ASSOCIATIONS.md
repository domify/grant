# Explicit association readers

Association declarations are ordinary typed objects. The application owns its
record types and `Mapping(T)` implementations; Grant does not reopen models or
discover foreign keys through a registry. These APIs currently support Int64
keys and SQLite behavior.

```iyi
import grant/associations::{HasMany, HasOne, BelongsTo}

# banks is Repository(Bank); accounts is Repository(Account).
account_banks = HasMany(Bank).new(banks, "account_id", banks.query.order("id"))
rows = account_banks.load(account_id).or_panic
grouped = account_banks.preload([account_id, other_account_id]).or_panic

first_bank = HasOne(Bank).new(banks, "account_id", banks.query.order("id"))
bank = first_bank.load(account_id).or_panic

bank_account = BelongsTo(Account).new(accounts)
account = bank_account.load(bank_record.account_id).or_panic
```

`load(nil)` returns an empty collection or nil without querying. Missing saved
owners/targets have the same empty/nil result. Preload results include every
requested key, including missing ones, and deduplicate repeated keys. An empty
key list performs no query. A nonempty preload performs one SELECT using a
bound `IN` list; SQLite's parameter limit still applies to very large lists.

The optional target scope is preserved by ANDing the association keys with its
existing predicates. Repository reads validate table name, primary key and
database identity. Preloading rejects LIMIT/OFFSET because these would apply
to all requested owners together. Explicit ordering is preserved within each
collection. `HasOne` picks the first member using that ordering; enforce a
unique foreign-key index where the schema requires actual one-to-one ownership.

Mappings must expose the corresponding Int64 foreign/primary key in
`attributes(record)`. A mismatched or missing mapped key returns `DatabaseError`.
Results are explicit snapshots; there is no hidden association cache, inverse
installation or automatic refresh after a write.

`Query.where_in` binds each non-null value. An empty set matches no rows, while
a set containing nil also matches SQL NULL. Chaining preserves all earlier
predicates and copies the supplied value array.

Association writers, autosave, nested attributes, through/polymorphic relations,
composite/string keys and dependent callback behavior remain pending. Database
foreign-key actions implemented in `Schema` are separate from model callbacks.
The source-free artifact compiler issue remains unresolved.
