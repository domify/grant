# Destroyed-record guard needs returned errors

`persistence/destroyed_guard_spec.cr` cannot pass while preserving the existing signatures:
`Base#save`, model `update`, and `Base#destroy` return `Bool`. The eight upstream examples
require those methods to return `RecordDestroyedError` for destroyed receivers. The reviewer
instruction forbids changing those signatures. The spec remains todo; no assertions are removed.

A translated draft and additive support patch are retained in this checkout under `build/tmp/`:
`grant_persistence_destroyed_guard_test.iyi` and `destroyed-guard-support.patch`.
