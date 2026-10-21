# Condition arrays: original explanatory comment trips the marker scan

With TMPDIR under build/, run:

```
bin/port-check --fast test/grant_validations_condition_arrays_test.iyi
```

The preserved upstream model comment starts with `# Skipped when any unless: term holds.`
It describes the intended conditional validation behavior, not a disabled example. All eleven
examples execute, including both true and false Symbol/Proc predicates and callback conditions.

The disabling-marker scan rejects that full-line comment. Keep the target `todo` until the
reviewer adjusts the gate; the upstream comment and assertions have not been removed.
