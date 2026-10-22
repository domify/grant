# Hash equality with database value union keys

The typed aggregation spec returns `Hash(Grant::Adapter::Driver::Value, Int64)` with
`{"a" => 2, "b" => 0}` on both SQLite and PostgreSQL. Comparing this hash with an equal
literal returns false, including after narrowing the result and annotating the literal with
`of Value => Int64`. Size and individual key lookups return the expected values.

Reproduction in `test/grant_query_aggregations_typed_test.ri`, after `prepare_records`:

```ris
actual = AtLedger.group_records(:kind).count(:note).or_panic.as(Hash(Value, Int64))
expected = {"a" => 2_i64, "b" => 0_i64} of Value => Int64
assert actual == expected
```

The translated equality assertion checks the exact size and both key/value pairs together,
which preserves the complete expected hash comparison without relying on the faulty operator.
