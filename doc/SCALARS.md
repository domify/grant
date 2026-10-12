# Exact SQLite model values

`grant/scalars` defines sealed Decimal, Date and DateTime values. The Value
union accepts them; the SQLite adapter binds their canonical text. Raw SQLite
results remain storage values, so mappings use `decode_decimal`, `decode_date`
and `decode_datetime` from `grant/value` to hydrate the declared model type.
PostgreSQL rejects the new scalar parameters/defaults until its port resumes.

Decimal uses native iyi BigDecimal/BigInt arithmetic. Parsing accepts signed
decimal text and exponents, trims surrounding whitespace, and returns
DatabaseError for invalid input or an exponent/scale outside native BigDecimal's
representation. There is no additional ORM digit/precision cap. Integers decode exactly; Float64 is rejected,
because its original decimal digits cannot be recovered. Construction and the
`number` reader copy the bigint storage. Equality/hash agree across spellings
such as `1.10` and `11e-1`. Canonical database text removes redundant zeros.

Addition, subtraction and multiplication stay exact. `rounded(scale)` uses
ties away from zero, matching the reviewed Crystal assignment behavior; scales
are non-negative Int32 values. A mapping owns its scale policy and must apply it
explicitly when rebuilding its record. `DecimalPolicy` in `grant/decimal_policy`
provides that boundary: `assign` accepts exact decimal/text/integer values, rounds
to an optional nonnegative scale and can enforce optional precision after rounding.
Precision requires a declared scale, and checks the available integer digits;
carry from rounding can therefore cause an overflow error. Nullable policies
accept nil. Floating-point values are rejected. Precision enforcement is an
explicit native application policy, not SQLite's permissive NUMERIC affinity.

`hydrate` decodes exact stored values without rounding or precision alteration,
including legacy values outside the assignment policy. Mappings call `assign`
from `with_attributes`/their explicit normalize implementation and `hydrate`
from `from_row`. There is no model-global column registry or automatic per-column
precision/scale inference. `decimal_policy_test.iyi` verifies assignment, carries,
negative ties, nullable fields, huge values, precise repository storage/updates
and the separate legacy hydration boundary from source and artifacts.

Use Schema's Decimal column type, which creates TEXT on SQLite. A raw NUMERIC
column can coerce bound text to REAL and lose digits; the decoder rejects that
REAL rather than fabricating an exact value. Decimal equality and IN parameters
use canonical text. SQL ordering, comparison ranges and SUM on these text
columns are not yet exact numeric operations; do not use them for decimal
calculations until the dedicated exact SQL operations are implemented.

Date accepts YYYY-MM-DD for years 1 through 9999, checking Gregorian leap years
and month/day bounds. DateTime requires RFC3339 with an explicit timezone and
zero through nine fractional digits. It normalizes fixed offsets to UTC and
stores nine digits, preserving nanoseconds. A leap second denotes the second
after :59, as in native iyi Time. Named timezones are not yet implemented.

`scalars_test.iyi` covers arithmetic, rounding, checked parsing, large values,
nullable fields, schema defaults, bound equality/IN, storage type and typed
repository reload. It also runs as a source-free artifact consumer.
