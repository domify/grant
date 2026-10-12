# Explicit timestamp callbacks

`Timestamps(T)` in `grant/timestamps` implements the model callback contract.
Register the same policy on BeforeCreate and BeforeUpdate. Its repository must
have a mapping implementing `with_attributes` to rebuild the sealed record.
Mappings must expose all configured timestamp fields, including nil values.

The clock is a typed `Clock.now : Time`; `SystemClock` reads UTC. Supply another
implementation for tests. One clock reading stamps every pending column in an
operation. Created/updated column lists are copied on construction.

BeforeCreate fills only nil created and updated fields, preserving explicit
values. BeforeUpdate stamps updated fields and leaves created fields unchanged.
The input record and attributes remain unchanged. Set the policy's enabled flag
to false to disable stamping explicitly; there is no global model registry or
request-wide switch.

`*_on` columns store an ISO UTC date; other fields store UTC RFC3339 text. The
precision setting accepts 0 through 9 fractional digits and truncates rather
than rounds. Default precision is six digits. Invalid precision or missing
mapped fields returns DatabaseError before writing. Hydration reads stored
timestamp text directly.

The native `Time` value always represents UTC. Parsing an RFC3339 value with a
fixed offset converts it to UTC before stamping; date fields use that UTC date.
Named timezone configuration from Crystal is not implemented.

`timestamps_test.iyi` verifies every precision through SQLite storage and reload,
partial explicit values, disabled create/update stamping, UTC date rollover and
extended years. It also combines timestamps with `Optimistic(T)`: guarded
updates advance both timestamp and version, while stale writes, callback aborts
and an outer rollback leave the stored timestamp/version intact. The same test
is included in the source-free artifact gate.

SQLite examples use TEXT for instant timestamps and DATE for calendar columns.
Exact `DateTime` values are also available through `grant/scalars`; the callback
policy itself emits UTC text/date values. Raw Query writes
skip model callbacks and therefore skip timestamp stamping. Repository updates
stamp on ordinary full updates. `Repository.update_changed` supplies an explicit
write context so clean saves skip stamping, and accepts `skip_timestamps: true`.
The timestamp policy also declares creation columns readonly on repository updates.
Register record-transforming BeforeUpdate callbacks before the timestamp policy;
its position in the explicit pipeline determines which changes it sees.
See `PARTIAL-UPDATES.md`. Automatic tracked-record sessions, no-op optimistic saves,
touch_later, no_touching/suppression and named timezone settings remain pending.
`Timestamps.touch(scope, id, time, columns)` writes only the update timestamp
fields plus requested additional timestamp fields. Extra fields must be listed
in the policy's `touchable` configuration; created/update timestamp fields are
already declared by their respective column lists. The method bypasses
validation, normalization and save/update callbacks, running AfterTouch and
transaction callbacks. Explicit touch works even when automatic save stamping
is disabled. Missing/out-of-scope IDs return nil.

For optimistic locking, build values with `touch_attributes(record, time,
columns)` and call `Optimistic.touch(scope, id, record, values)`. The version
guard and increment are part of the same timestamp UPDATE. This API does not
write other attributes from the supplied record. Stale/missing targets return
StaleObjectError. Callback/SQL failures and an outer rollback restore both
version and timestamps. `touch_test.iyi` exercises these APIs as a source-free
artifact consumer too. Deferred touch and association touch cascades remain
pending.
