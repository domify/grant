# Explicit associations

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

## Direct collection writes

`grant/association_writes` provides `CollectionWriter(T)`, `Link(T)` and
`Removal`. Implement `Link(T).with_owner(record, owner_id)` alongside the
application record. It returns a new typed record with the foreign key assigned;
it must preserve the primary key. Grant verifies the resulting mapping.

```iyi
import grant/association_writes::{CollectionWriter, Link, Removal}

struct BankLink
end

impl Link(Bank) for BankLink
  def with_owner(record : Bank, owner_id : Int64) : Bank | DatabaseError
    Bank.new(owner_id, record.name, record.id)
  end
end

writer = CollectionWriter(Bank).new(banks, "account_id", BankLink.new)
attached = writer.append(account_id, [new_bank, existing_bank]).or_panic
members = writer.replace_ids(account_id, [first_bank_id, second_bank_id]).or_panic
removed_count = writer.remove(account_id, [first_bank_id], Removal::Destroy).or_panic
```

Append saves new records and updates existing ones through the repository, with
model validation and lifecycle callbacks. Existing targets must be visible in
the writer's target scope before attaching; new targets must be visible after
saving. All results are hydrated from persisted data. Scoped tenant constraints
remain in force, including when moving a target between owners.

`replace_ids` verifies all requested target IDs before removing any current
members. IDs are deduplicated, results follow requested order, unchanged members
are not saved again, and missing IDs return an error. Empty IDs clear the scoped
collection. This API currently accepts saved targets only; append also accepts
unsaved targets.

Removal affects only keys belonging to that owner within the target scope:

- `Nullify` (default) clears the foreign key with a set-based update; the column
  must be nullable. It skips model callbacks, matching the source collection.
- `Delete` removes rows directly and skips model callbacks.
- `Destroy` uses repository destruction with model callbacks.

Every nonempty append and every remove/replace runs within the repository's
`UnitOfWork`, using a savepoint when nested. Validation, SQL or callback failure
rolls back the complete collection operation even if an outer caller handles
the error and continues. Commit callbacks wait for the outermost managed commit.
Pass the same `UnitOfWork` to repositories participating in a shared operation.

An owner must supply a non-null saved Int64 key; there is no implicit owner
lookup or deferred unsaved-owner cache. Enable SQLite foreign keys and declare
the database constraint to enforce owner existence. Target scope ordering is
removed for writes; pagination is rejected. Association-specific add/remove
hooks, inverse caching and counter caches are not implemented yet.

Singular association writers, autosave, nested attributes, through/polymorphic
relations, composite/string keys and automatic owner-destruction callbacks remain
pending. Database
foreign-key actions implemented in `Schema` are separate from model callbacks.
The source-free artifact compiler issue remains unresolved.
