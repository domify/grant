# Native validation rules

`Rules` in `grant/validation` collects typed `Validator` implementations.
Validation takes explicit attributes and a `Context`; it returns ordered
`Errors`. Use `errors.result` to obtain nil or `ValidationError` for a mapping's
validation contract. Model callback integration remains in `Repository`.

`Presence` supports presence/absence, `Length` counts Unicode characters,
`Inclusion` supports inclusion/exclusion, and `Confirmation` checks a matching
confirmation attribute. `Options` controls nil/blank skipping, context and a
custom message. Inclusion snapshots its accepted values.

Additional rules live in `grant/validators`:

```iyi
import grant/validation::{Rules}
import grant/validators::{Numericality, Constraint, Comparison, Format, Acceptance}
import std/regex::{Regex}

rules = Rules.new
rules.add(Numericality.new("quantity", [
  Constraint.new(Comparison::GreaterThan, 0_i64),
  Constraint.new(Comparison::LessThanOrEqual, 100_i64),
], only_integer: true))
rules.add(Format.new("code", Regex.compile("\\A[A-Z][0-9]+\\z")))
rules.add(Acceptance.new("terms"))
```

Numericality accepts finite Int64/Float64 values and numeric text. `only_numeric`
rejects text; `only_integer` rejects floats and text written as a float, even
`"8.0"`. Non-numeric inputs, NaN and infinity yield `not_a_number`. Every failed
comparison contributes an issue with its own code and count/value metadata.
Integer inputs and integer bounds remain Int64 during comparison; they are not
silently converted to Float64. Comparison kinds are greater/greater-or-equal,
less/less-or-equal, equal and other-than.

Odd/even follows the source behavior of truncating floats for the parity check.
Values outside Int64 range produce `out_of_range` instead of a conversion panic.
Non-finite comparison bounds produce `invalid_constraint`. Numeric validators
do not convert or mutate stored attributes and are not exact-decimal storage.

Format uses iyi's native regular-expression engine and search semantics. Anchor
with `\\A`/`\\z` for a complete-string requirement. `without: true` rejects
matches. The engine's supported syntax is described in `std/regex`; lookaround,
backreferences and other unsupported Crystal regex features are not emulated.

Acceptance accepts true or, by default, the case-insensitive text forms
`1`, `true`, `yes` and `on`, matching the imported Grant defaults. Nil is rejected
unless skipped by `Options`. Supply an explicit lowercase accepted list to
customize text values. The validator does not create virtual fields or database
columns; those belong to the application record.

Implement `Condition.applies?(attributes, context)` and wrap a rule in
`When.new(validator, condition)` to apply it conditionally. The third boolean
argument inverts the condition (the source's `unless`). Context remains visible
to both the condition and the wrapped validator. No inherited callback lookup
or global macro expansion is used.

## SQLite uniqueness and database rules

`DatabaseRules` in `grant/database_validation` combines optional scalar `Rules`
with typed `DatabaseValidator` implementations. `validate` returns `Errors` or
`DatabaseError`; `check` returns nil, `ValidationError` or `DatabaseError`.
Failed SQL is propagated separately and never treated as a successful check or
a fabricated `taken` validation issue.

```iyi
import grant/database_validation::{DatabaseRules, Uniqueness}

# users is a Query. Existing query conditions are preserved.
checks = DatabaseRules.new(scalar_rules)
checks.add(Uniqueness.new("email", users, ["account_id"], case_sensitive: false))
result = checks.check(attributes, context)
```

Uniqueness adds bound equality conditions for the attribute and explicit scope
columns. Scope values may be nil; a missing scope attribute returns a mapping
error. Nil uniqueness values are skipped, matching the imported Grant behavior.
Options support nil/blank skipping, messages and contexts. Query conditions can
restrict the duplicate search, but LIMIT/OFFSET is rejected. Names are validated
and values remain SQL parameters.

Case-insensitive text uses SQLite `LOWER(column) = LOWER(?)`; its Unicode support
is whatever the linked SQLite build supplies. Case-sensitive checks use ordinary
equality and the column's configured collation. Non-text values cannot request
case-insensitive checking. Register a unique index matching the intended scope
and collation: validation alone cannot prevent concurrent duplicate inserts.
No database constraint is created automatically by this validator.

`Context.persisted_id` carries the authoritative Int64 update key. Repository
writes supply create/update contexts. A mapping with database rules should
implement the optional `validate(record, context)` overload and pass the context
to `checks.check`. The default overload calls the existing `validate(record)`
method for compatibility with simple mappings. `Mapping.validate` may now return
`DatabaseError` as well as nil or `ValidationError`.

Create context never excludes an input ID. Update context excludes the actual
target ID even if the input record's ID is nil. A standalone default save context
uses the attributes' key to exclude self; standalone update callers should pass
the persisted ID explicitly. Primary keys are bound values, not SQL fragments.

Wrap database rules in `DatabaseWhen.new(rule, condition, invert)` for typed
if/unless behavior using the same `Condition` trait as scalar `When`.

`Query.where_not` produces `!= ?` or `IS NOT NULL`. A non-null inequality follows
SQL's usual NULL semantics; it does not include NULL rows. `where_case_insensitive`
accepts text values. `exists?` honors offset and zero limit, rejecting negative
pagination, and queries only the first matching row.

## Dynamic numericality operands

`DynamicNumericality` from `grant/dynamic_validation` evaluates typed Operand
policies with the attributes and Context. `AttributeOperand` reads a named
attribute; application Operand implementations replace Crystal Proc/method
lookup. Each failed comparison carries the resolved bound as `count`, preserving
Int64 precision. Constraint arrays are copied; policies are evaluated afresh for
each eligible validation. Non-numeric values and only_integer failures stop
before operand evaluation, and options/conditions retain their usual meaning.

Use `CheckedRules` from `grant/validation` for rules whose evaluation may fail.
`DatabaseRules` and `DatabaseValidator` are compatibility aliases for CheckedRules
and CheckedValidator; SQLite uniqueness uses the same checked contract. This
allows one collection to combine scalar rules, dynamic operands and SQL rules.
A missing, nil or non-finite operand returns DatabaseError, adapting Crystal's
configuration exception. It does not become a fabricated validation failure or
a passing constraint. Ordinary failed comparisons remain ValidationError values.
Mappings return checked evaluation errors directly to Repository.

`dynamic_validation_test.iyi` verifies attribute/context operands, details and
ordering, nil/options/conditions, integer precision, SQLite writes with uniqueness
and validation, and savepoint rollback after caught operand errors. It is also a
source-free artifact consumer.

Still pending:
associated-record validation, strict error policies, translation/message
callbacks and the remaining imported behavior cases. Native rule coverage is
partial, not a claim of complete Crystal validator parity.

## Email and URL convenience rules

`Email.new(attribute, options: Options.new, without: false)` and
`Url.new(attribute, options: Options.new, without: false)` in `grant/validators`
wrap Format with the imported Grant common patterns. Default messages are
"is not a valid email" and "is not a valid URL"; issue code remains `invalid`,
including the supplied value. Nil/blank/context/custom message options and typed
When conditions retain Format semantics. These validators do not normalize,
parse or rewrite the stored value.

`email_pattern` and `url_pattern` return the reusable Regex patterns for explicit
Format rules. The native email pattern expands ASCII upper/lowercase pairs
because iyi Regex has no case-insensitive flag. The URL pattern preserves the
source's lowercase http/https scheme, 256-character host portion, 1–6-character
suffix and allowed path/query/fragment characters. It accepts port suffixes.
These are the source's conventional format checks, including its permissive
address/domain forms; they are not comprehensive email or URL parsers.

`format_convenience_test.iyi` translates email/URL cases from upstream
`spec/grant/validators/built_in_spec.cr` and adds anchored patterns, boundary
lengths, options, details, conditional rules and SQLite insert/update/rollback
checks. The source-free artifact gate includes it. Derived models support inline `col :email, :string, email: true` and
`col :website, :text, url: true`; see RAILS-DSL.md. Remaining general validators
are still pending.

## General comparison rules

`ComparisonRule` in `grant/comparison_validation` implements the source's
`validates_comparison_of` separately from Numericality. Register it in CheckedRules
with a copied array of `ValueConstraint(Comparison, Operand)` values. Use
`LiteralOperand(value)`, existing `AttributeOperand(name)` or an application
Operand policy evaluated against attributes/context. Unlike Numericality, it
does not parse numeric text or coerce strings to numbers.

Ordered comparisons support String/String, Date/Date, DateTime/DateTime, exact
Decimal/Decimal, Decimal/Int64 and finite Int64/Float64 combinations. Integer/float
comparisons preserve integer precision, including integers beyond 2^53 and Int64
boundaries. Decimal values never pass through Float64. Equality/other-than also
support the remaining Value types, with exact Decimal/Int64 equality. UTC
DateTime comparison uses the instant, independent of its parsed offset.

Nil input produces `blank` before operand evaluation. A resolved nil bound
produces a `comparison` issue. Each false comparison reports its own code, count
and value, using the standard imported messages or Options.message. Nil/blank,
context and checked conditional policies retain their usual semantics.
Operand evaluation failures and incompatible ordered types return DatabaseError;
this adapts source configuration errors without inventing a passing result.
Ordering non-finite floats, mixing decimal with float, or mixing Date with
DateTime is explicitly rejected. Convert with an application policy if intended.

`comparison_validation_test.iyi` ports the focused upstream age, attribute-bound
interval and other-than status cases and verifies string/temporal/exact-decimal
ordering, integer/float precision, issue details/order, nil bounds, evaluation
errors, options, copied constraints and SQLite validation rollback. It is also a
source-free artifact consumer. Derived models support inline comparison
declarations with literal or mapped field operands; see RAILS-DSL.md. Dynamic application Operand policies remain
explicit typed rules in mapping validation.

## Validator condition lists

`ConditionSet.new(if_all: [...], unless_any: [...])` implements Condition and
can be supplied to scalar When, checked DatabaseWhen or normalization Plan.add.
Every positive term must hold and every negative term must be false. Empty lists
pass. Evaluation short-circuits in list order; positive terms precede negative
terms. Lists are copied, policies remain caller-owned, and nested sets are valid.
Existing single-condition and inversion APIs remain compatible. Policies receive
the same attributes/Context as the rule; checked evaluation failures propagate
through eligible DatabaseWhen rules, and skipped rules execute no SQL.

`condition_arrays_test.iyi` ports focused cases from upstream
`spec/grant/validations/condition_arrays_spec.cr`: AND/UNLESS lists, combined
lists and custom rules, with additional copied-list, nesting, context, inversion,
normalization, conditional SQLite uniqueness and repository rollback cases.
A condition panic returns Panicked from repository writes and rolls back their
transaction; direct rule/plan calls retain the native panic semantics.

`format_model_test.iyi` verifies inline email/URL declarations in a separate
producer module, options and disabled declarations, create-only validation,
SQLite writes, rejected updates and nested transaction recovery. Both test
programs are included in the native and source-free artifact gates.

`comparison_model_test.iyi` repeats the focused upstream comparison cases through
separate derived-model declarations, checking unknown/incompatible operands,
options and nil bounds, exact decimal/date/time values and SQLite write rollback.
Inline comparison receives assigned typed values, preserving nanoseconds before
col timestamp storage precision is applied. Hydration still follows declared
storage precision. The test joins the native and source-free artifact gates.

## Explicit validation contexts

Context retains the write `operation` and authoritative `persisted_id`, separately
from its copied active `names`. Without an explicit name/list, the operation is
its active context. A supplied name or `contexts: ["create", "publish"]` replaces
that default; `name` exposes the first active name (empty string for an empty
list). Returned name lists are copies. Context.includes? matches literally.

Options.on accepts a string, copied string list, or nil. A rule runs if any of its
contexts match; nil and the rule context save run unconditionally. An explicit
active save context runs every rule, as in upstream Grant. Nil/blank skipping
still applies before context selection. An empty active list runs only
unconditional/save rules; an empty on list runs only for an explicit active save.

Repository insert/update/update_changed accept `validation_context: ["publish"]`.
An update still exposes operation update and the actual persisted ID to SQL rules,
even with a custom validation context and a nil input record ID. Before/after/
around validation callback filters use the same active names; see LIFECYCLE.md.
This replaces source record-local context mutation with an immutable caller-owned
value. Inline model declarations accept literal on arrays of symbols/strings, shared
or per rule. Standalone model and repository helpers are described below.

`validation_context_test.iyi` translates focused default/custom/array/save context
cases from upstream `spec/grant/validations/contexts_spec.cr`, and exercises actual
SQLite insert/update validation, callback ordering, nested rollback and source-free
consumption. Existing uniqueness tests cover persisted-ID exclusion.


## Standalone validation

`repository.validate(record, context: "publish")` returns the rebuilt `T` or
`ValidationError`, `DatabaseError`, `CallbackAbort`, `Panicked` or `Cancelled`.
It runs normalization, AroundValidation, BeforeValidation, mapping validators and
AfterValidation without saving or observing the record for transaction callbacks.
`context` accepts a string, copied string list or nil, with the same selection
rules as save validation. Default operation/context is create for a nil mapped
primary key and update for an Int64 key. A non-Int64 key fails explicitly while
composite/string model keys remain unported. A non-nil key is treated as persisted;
there is no hidden new-record flag. `persisted_id:` supplies an authoritative
update key for nil-ID inputs and uniqueness self-exclusion without fetching a row.
Validation does not check that the referenced row exists.

`repository.valid?` returns false only for evaluated ValidationError and true for
success. `invalid?` reverses that Boolean. SQL/configuration failures, callback
halts and task failures remain error values in both helpers. Callers can inspect
full validation messages via `validate`. No previous run's errors/context are
stored on the record. `skip_normalization: true` affects only this run; the default
applies the mapping's assignment policy and returns a rebuilt record. The original
input remains unchanged unless an application callback itself mutates a class.

Derived models offer `record.valid?(repository)`, `invalid?`, and the source
Boolean alias `validate`, accepting the same optional context, persisted ID and
normalization controls. `record.validated(repository)` returns the rebuilt record
or error, replacing the source's exception-raising validate! with a native error
union. Supplying the repository preserves the caller-owned connection/session
boundary; instance helpers do not discover or open a connection.

Standalone validation owns a nested savepoint through the repository UnitOfWork.
Callback SQL commits on successful validation and rolls back on validation errors,
halts, invalid continuations or panics, even when a caller catches the error in
an outer transaction. This strengthens the source's non-transactional standalone
callback behavior consistently with native save semantics. No save/create/update/
commit/rollback record callbacks are dispatched for validation itself. Callbacks
that deliberately save other records retain those records' usual lifecycle.

`standalone_validation_test.iyi` ports focused valid?/invalid?/context cases from
upstream `spec/grant/validations/contexts_spec.cr` and checks normalization/skip,
no persistence, explicit IDs, derived model helpers, uniqueness SQL failures,
conditional validation callbacks, panic/abort rollback, outer savepoint recovery
and mismatched contexts/sessions. It is registered in the source-free gate.
