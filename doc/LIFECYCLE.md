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
source-free artifact consumer. Transaction-action `on:` filters, deferred touch and initialization/find
callbacks remain pending. Validation-context filters are described below.

## Callback conditions

Implement `CallbackCondition(T).applies?(event, record)` and pass
`conditions: CallbackConditions(T).new(if_all: [...], unless_any: [...])` to
`Pipeline.add` or `add_around`. All positive conditions must return true and
all negative conditions must return false. Empty lists pass. Arrays are copied;
policy objects remain application-owned and can inspect current business state.
Typed policies replace Crystal Symbol/Proc lookup without reopening models.

Conditions short-circuit in declaration order, after event selection. They are
evaluated immediately before each callback against the current record, including
transformations by previous callbacks and outer wrappers. An ineligible around
wrapper proceeds to the next wrapper/operation without aborting. Commit/rollback
conditions run when the observer is dispatched using its registered record.
Readonly callback metadata remains unconditional so skipped policies cannot make
protected columns writable. Existing registrations retain their behavior.

`callback_conditions_test.iyi` translates the conditional cases from upstream
`spec/grant/callbacks/proc_conditions_spec.cr` and array semantics from
`src/grant/validation.cr`. It covers ordering, short-circuiting, copied lists,
record transformation, skipped wrappers, validation failures, conditional aborts,
transaction timing and panic rollback in SQLite and source-free artifacts.
This implements `if`/`unless` behavior. Transaction action filters and observer
action folding remain pending.

## Validation context filters

`Pipeline.add_validation(callback, events, on: ["create", "publish"])` registers
BeforeValidation/AfterValidation callbacks for any matching active context.
Other events return DatabaseError without changing the pipeline.
`add_around_validation(wrapper, on: ["publish"])` registers an AroundValidation
wrapper. Both accept prepend and the existing typed if/unless conditions. Event
and context selection precedes predicate evaluation; inactive wrappers proceed
with validation. Context arrays and event arrays are copied at registration.

Repository insert/update/update_changed accept `validation_context: ["publish"]`
or a context list. Omission selects create or update. Context filters match names
literally; an explicit save context runs every validator but only callbacks
registered for save. No active context leaks into later writes or other phases.
Custom contexts do not change the SQL operation or uniqueness self-exclusion ID.

Direct Pipeline.run/wrap callers can supply a typed `validation_context: Context`.
Callbacks continue receiving their current record and WriteContext; application
policies needing arbitrary context values can own those values explicitly.
Transaction action filters remain separate pending work.

`validation_context_test.iyi` ports the callback selection cases in upstream
`spec/grant/validations/contexts_spec.cr`, including copied arrays, skipped
predicates/wrappers, invalid event registration, failed validation and atomic
context-selected halts inside outer SQLite transactions. It runs from source
and source-free artifacts.

Standalone Repository.validate/valid?/invalid? and derived model helpers invoke
only the validation portion of this pipeline, with the same context filters,
conditions and continuation rules. A nested unit-of-work savepoint contains SQL
side effects of callbacks on failure; validating a record does not register that
record for commit/rollback observers. See VALIDATION.md for the returned record,
Boolean helpers and explicit repository ownership.
