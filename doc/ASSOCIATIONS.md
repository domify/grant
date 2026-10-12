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

## Singular replacement and dependent destruction

`CollectionWriter.replace_one(owner_id, record_or_nil, removal)` implements
direct `has_one` replacement, including saving an unsaved replacement. It
displaces the existing target before attaching the replacement, allowing a
unique foreign-key index. Assigning nil removes the existing target. A failed
replacement restores it. More than one current target returns an error rather
than silently repairing an invalid one-to-one association.

`remove_all(owner_id, removal)` applies a removal strategy to the entire scoped
collection. Neither operation supports an unsaved owner cache.

Register `Dependency(O, C)` from `grant/dependent` on an owner's `BeforeDestroy`
event to implement dependent behavior:

```iyi
import grant/dependent::{Dependency, Action}
import grant/lifecycle::{Event}

# Both repositories must have been constructed with the same UnitOfWork.
rule = Dependency(Account, Bank).new(accounts, banks, "account_id", Action::Destroy)
account_events.add(rule, [Event::BeforeDestroy])
```

`Action` supports `Nullify`, `Delete`, `Destroy` and `Restrict`. Restrict returns
a base validation error. Nullify/delete skip child model callbacks; destroy
runs them. Every action preserves the target scope. Pagination and different
transaction sessions are rejected before modifying children. Registering a
rule on another event has no effect. Callback order follows pipeline insertion
order; these rules all execute before deleting the owner.

An owner error after dependent writes rolls back the owner and children,
including inside an outer transaction that handles the error and continues.
Cyclic destruction is rejected and the cycle guard is cleared after a failed
operation. Child panic/cancellation is reported as `DatabaseError` so it fits
the callback error contract and triggers rollback.

Repository insert/update/destroy now use savepoints when nested, keeping each
operation atomic independently of an outer caller catching its error. A
successful scoped update hydrates the updated record by primary key even if a
changed column no longer matches the original filter; the mutation itself
still uses every original scope predicate.

## Belongs-to assignments and staged saves

`BelongsToWriter(O, T)` uses an application Reference(O) implementation to rebuild
the owner's sealed record with a nullable target key. `assign(owner, target)`
returns an explicit Assignment containing the rebuilt owner and target; it
writes nothing. An unsaved target is retained with a nil key until save. This
replaces the source's mutable loaded-association cache. Original records stay
unchanged.

The two repositories must share one UnitOfWork and database. `save(assignment)`
saves a new target, reconstructs the owner's foreign key and saves the owner in
one atomic savepoint. Existing targets are hydrated within their permitted scope
and are not written by default; `autosave: true` explicitly saves their pending
fields. Model validation and lifecycle callbacks run on every repository write.
Commit callbacks wait for the outer commit. A target or owner outside its scope,
validation/SQL/callback error or changed reference key rolls back both writes.

`create_target(owner, new_target)` mirrors the source create_<association> helper:
only the target is persisted, and the returned Assignment's owner remains
unsaved with its new foreign key. It requires an unsaved target. `assign(owner,
nil)` clears the staged foreign key; saving it clears the persisted association
without deleting the old parent.

Owner/target Int64 keys and foreign key transformations are verified against the
mapping. Missing persisted owners are rejected before creating targets. Target
and owner scopes preserve tenant predicates; paginated writes and different
sessions are rejected. This writer uses plain repositories and does not install
an optimistic version policy implicitly. Association-wide locking, inverse
caches and general recursive autosave require separate integration.

`belongs_to_write_test.iyi` covers staging, nil assignment, target-only creation,
new/saved target behavior, autosave, callback order, tenant scopes, invalid links,
session rejection and failures caught inside an outer transaction. It is included
in the source-free artifact gate.

General recursive autosave, nested attributes, through/polymorphic
relations, composite/string keys, asynchronous destruction and counter caches
remain pending. Database
foreign-key actions implemented in `Schema` are separate from model callbacks.
The source-free artifact compiler issue is fixed by iyi commit a03fc3438;
the gate verifies these APIs with the local fixed compiler.
