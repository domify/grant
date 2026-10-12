# Optimistic locking on SQLite

`Optimistic(T)` wraps a repository with an explicit `Version(T)` policy. The
policy reads an Int64 version and returns a new sealed record with an assigned
version. The mapping must expose that same value in its attributes. Declare a
NOT NULL integer version column, usually with default 0.

Updates bind both the primary key and expected version in the SQL predicate,
and assign version+1 in that same UPDATE. A stale/missing/scoped-out row returns
`StaleObjectError`. Destroy also checks the expected version. Version overflow,
invalid policy transformations and changed stored versions return DatabaseError.
Identifier validation and parameter binding remain in force. Internal version
predicates use `where_stored`, bypassing argument normalization while retaining
all existing scope predicates.

Use wrapper update/destroy for every write that needs version protection. Raw
queries and the underlying plain repository intentionally have no version guard.
Version errors are union values, not Crystal exceptions. Each locked operation
uses a savepoint when nested, restoring all callback effects on a failure that
the outer caller handles. Successful commit callbacks remain deferred until the
outer managed commit.

The persisted version is checked after update callbacks. Destroy checks affected
rows; a callback that changes the expected version cannot report a successful
deletion of a row that was never deleted. The input record remains unchanged.

SQLite tests cover stale snapshots, update increment, stale destroy, validation
failures, scoped writes, nested caught errors, version overflow and a
before-destroy callback racing the version guard. The artifact gate also runs
the locking consumer without Grant source.

Touch integration, bulk version increments and pessimistic-lock APIs remain
pending. SQLite has no row-level FOR UPDATE; this wrapper does not simulate it.
