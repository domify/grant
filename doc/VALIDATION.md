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
