# Explicit changed-column writes

`Repository.update_changed` writes differences against an application-supplied
persisted baseline, instead of writing all mapped columns. Use the attributes
captured when the record was loaded; comparing against a newly fetched row would
incorrectly treat a stale sibling field as an application change.

```iyi
baseline = repository.attributes(loaded)
candidate = repository.with_attributes(loaded, edited_attributes).or_panic
result = repository.update_changed(repository.query, id, candidate, baseline)
```

The baseline must contain the same mapped attribute names and the authoritative
persisted Int64 primary key. A candidate may carry a nil ID, but may not carry a
different ID. Missing/mismatched baseline fields and unknown forced fields return
`DatabaseError`. An optional `forced: ["title"]` writes that field even when its
value compares equal. Primary-key writes cannot be forced.

`State(Value)` can supply the baseline and forced fields directly:

```iyi
import grant/dirty::{State, ScalarSnapshot}
import grant/value::{Value}

state = State(Value).new(repository.attributes(loaded), ScalarSnapshot.new)
state.set("title", "edited").or_panic
candidate = repository.with_attributes(loaded, state.attributes).or_panic
result = repository.update_changed(repository.query, id, candidate, state)
```

The state overload checks that the candidate exposes the state's current values.
`baseline_attributes` and `forced_changes` return copies. Repository operations
do not advance or clear the caller's dirty state. This preserves pending edits
after validation/SQL/callback failure and after an outer transaction rolls back.
After the outer operation has committed, the application can replace its record
and dirty snapshot from the successful hydrated result. Automatic checkpointing,
saved-change reconciliation (including callback transformations and trigger
changes) and mutable serialized/array record integration remain pending. Calling
`changes_applied` before an outer commit would incorrectly acknowledge rolled-back
data; the repository does not do that for the caller.

## Callback and timestamp behavior

Normalization runs before validation and comparison. Validation and ordinary
save/update/around callbacks run even when no writable values differ. Callback
transformations made before the write participate in the comparison. A clean save
executes no UPDATE and performs no automatic timestamp clock read, while still
checking the original scope and row existence. It may execute transaction control
and a SELECT; it does not reproduce the source ORM's zero-statement lazy
transaction optimization. Missing/out-of-scope IDs return nil.

The native `WriteContext` in `grant/lifecycle` carries a copied baseline, forced
names, protected names and a timestamp flag. Existing `Callback(T)` implementations
keep their two-argument `call`. A callback needing operation metadata overrides
`call(event, record, context : WriteContext)`. Validation and save/update callbacks
receive that context; deferred commit/rollback observers retain their existing
callback contract. Around callbacks keep their single-use continuation API.

`Timestamps(T)` honors the context: it skips automatic update stamping when the
record is clean and accepts `skip_timestamps: true` on `update_changed`. Explicit
timestamp values supplied by the application still participate as ordinary
changes. A policy registered on BeforeUpdate acts at its configured pipeline
position. Register record-transforming BeforeUpdate callbacks before the timestamp
policy when their changes should trigger automatic stamping. This explicit
ordering differs from the source's implicit timestamp insertion stage.

`Mapping.readonly_attributes : Array(String)` declares columns writable on create
but protected on repository updates. Timestamp callbacks additionally protect
their configured creation columns. These protections apply to both ordinary
`update` and `update_changed`. Protected assignments are ignored in SQL and the
returned record is hydrated from the stored row. Unknown protected names are
configuration errors. Raw Query writes and explicit touch remain separate APIs.

## Atomicity and remaining scope

Only the selected row and changed writable columns are updated. The original scope
is retained, including filters on a field being changed; hydration follows the
updated row by its fixed primary key. SQL and model callbacks run inside the
repository's nested savepoint, preserving the outer unit of work if an inner
failure is caught. A successful clean save still registers ordinary commit hooks.

This is the plain repository's partial-write API. It does not add an optimistic
version guard: version-protected services must continue using `Optimistic(T)`.
Partial/no-op optimistic writes and automatic tracked-record sessions remain
pending. Ordinary `Repository.update` continues writing all writable fields.

`partial_update_test.iyi` uses SQLite UPDATE OF triggers to prove which fields were
written. It covers stale siblings, no-op callbacks/around callbacks, forced writes,
readonly and creation fields, explicit timestamp suppression, normalization,
dirty-state snapshots, failed validation/SQL/callbacks, scope/missing IDs and outer
rollback. It also runs as a source-free artifact consumer.
