# Destroyed-record guard returned errors

Resolved following reviewer feedback item 14. `save`, instance `update`, and `destroy`
return `Bool | RecordDestroyedError`. Strict writes and direct persistence methods propagate
the same error through their existing error unions. Callers unwrap or propagate returned errors.

`test/grant_persistence_destroyed_guard_test.iyi` preserves all eight upstream examples and
their assertions, including frozen state, every guarded write, and allowed in-memory operations.
