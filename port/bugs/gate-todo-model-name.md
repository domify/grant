# Upstream Todo model triggers the disabled-example scan

The four non-deferred context restoration and boot verification examples from
`connection/context_scoping_spec.cr` pass under SQLite and PostgreSQL, but `--fast` exits 1:

```text
skip/pending/TODO marker: test/grant_connection_context_scoping_test.iyi
```

The gate matches `\b(TODO|FIXME)\b` case-insensitively throughout non-comment test code.
Consequently the upstream fixture name `Todo` and every use of that name trigger the check.
There are no disabling constructs in this translation. Renaming the model would conceal the
false positive and depart from the upstream fixture.

The complete translated target is retained as `port/bugs/gate-context-scoping-todo.iyi`.
Restore it to `test/grant_connection_context_scoping_test.iyi` to reproduce with:

```sh
TMPDIR=$PWD/build/tmp IYI_CACHE_DIR=$PWD/.iyi-cache \
  bin/port-check --fast test/grant_connection_context_scoping_test.iyi
```

Both adapter JSON results report pass; the final provenance gate reports failure. The manifest
keeps this child todo until the reviewer fixes the gate, following feedback item 7. The other
child contains only deferred sharding and write-prevention examples. No assertion is removed,
weakened, or marked disabled. The core fix normalizes symbol connection names to String in
`connects_to` and adapter resolution, preserving the original symbol declaration in the fixture.
