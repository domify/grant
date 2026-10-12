# Native model lifecycle

Application-owned Pipeline(T) instances collect typed Callback(T) and Around(T)
implementations. `add` registers before/after/transaction callbacks; `add_around`
registers AroundValidation, AroundSave, AroundCreate, AroundUpdate and
AroundDestroy wrappers. Registration arrays are copied and `prepend: true`
makes a newly registered wrapper outermost. There is no inherited macro lookup
or global callback registry.

Around.call receives an Event, a sealed record and a Continuation(T). Call
`continuation.call(record)` once and return its result after any wrapping work.
The record passed to the continuation can be explicitly rebuilt by the policy.
It returns a record, nil for a missing scoped update/destroy, or an error value.

Validation wrapping encloses BeforeValidation, mapping validation and
AfterValidation. Mapping normalization runs before that phase. AroundSave
encloses BeforeSave, the create/update wrapper and AfterSave. Create/update
wrappers enclose their respective before callback, SQL write, hydration and
after callback. AroundDestroy encloses BeforeDestroy, deletion and AfterDestroy.
AfterCommit occurs only after the outer managed transaction commits. Savepoints
make callback errors atomic even when an outer caller catches them.

Not invoking the continuation is CallbackAbort. A continuation may run once and
only while its wrapper is active; a repeated call aborts the whole operation and
escaped calls are rejected. Operation errors and missing scoped targets cannot
be replaced with successful records by wrappers. Returning nil after a successful
write aborts it. These are explicit native adaptations of source exception/abort
behavior, rather than silently accepting skipped operations as successes.

Wrapper panics are contained to close continuations and return Panicked; the
repository rolls back the write. AfterRollback follows the existing observer
registration semantics. Arbitrary external callback side effects cannot be
rolled back by SQL and remain the application's responsibility.

`around_test.iyi` verifies nesting/order, phase selection, prepend, validation
halt/error behavior, repeated and escaped calls, missing targets, abort after
SQL, caught nested errors and panic rollback. The same program runs as a
source-free artifact consumer. Conditional callback metadata, deferred touch
and initialization/find callbacks remain separate pending features.
