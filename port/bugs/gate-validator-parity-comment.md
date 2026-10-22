# Validation parity: upstream comment trips the disabling-marker scan

Command, with TMPDIR under build/ and the native compiler cache:

```
bin/port-check --fast test/grant_validators_parity_test.ri
```

Both SQLite and PostgreSQL report the target as passing, with zero skipped tests.
The gate then rejects the original explanatory comment in the last example:

```
assert m.valid?.or_panic # skipped
```

Upstream `spec/grant/validators/parity_spec.cr` uses this comment to explain that the
`unless:` predicate suppresses a presence validation. The example itself runs and asserts
both predicate outcomes; it does not disable any test. All 26 original markers and every
assertion are translated. The manifest remains `todo` pending reviewer gate correction.
