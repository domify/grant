# Native iyi names

Preserve Grant's inheritance, model macro DSL and public API wherever iyi permits it. Module paths replace Crystal namespaces: `grant/base` exports `Base` (qualified as `Grant::Base::Base`), `grant/adapter/sqlite` exports `Connection`, and `grant/errors` exports error values.

SPEC.md III.1.7 prohibits trailing `!` in declaration names. Raising variants (`find!`, `create!`, `save!`, `update!`, `first!`, `find_by!`, etc.) become `<name>_strict`, returning a normal result or an error implementing `Error`. Callers propagate with postfix `!` or unwrap with `.or_panic`.

In-place relation mutators (`where!`, `order!`, `joins!`, `or!`, etc.) become `<name>_in_place`.

Crystal names that are iyi keywords receive documented aliases: `import` becomes `import_records`; query `group` becomes `group_records` because iyi reserves `group` for task groups (the existing `group_by` API is also retained). Relation `and`/`or` (`builder.or(:age, :gt, 23)`) become `and_where`/`or_where`, and the in-place `and!`/`or!` become `and_in_place`/`or_in_place`. Add further keyword aliases here as encountered.

`raise` becomes a returned error union member; `rescue` becomes a union check. Transactions roll back if the block returns an error. Crystal `Grant::Transaction::Rollback` is currently exported as `Rollback` from `grant/errors`.

The native prelude has no `same?`; preserve identity assertions by comparing `object_id`.

Typed lazy encryption strict readers follow the same raising-variant rule: `email!` becomes `email_strict`, returning `String | ErrorBase` (including `NilAssertionError` for an absent value); ordinary and question-mark readers also return codec errors when decryption fails.

Seed registry `clear_definitions!` becomes `clear_definitions_in_place`.
