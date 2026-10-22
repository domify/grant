# Public API composite association return types

Resolved: all four examples of `public_api_return_types_spec.cr` are translated, preserving
all original type assertions. The manifest children partition the original CoverageGen IDs.

`test/grant_public_api_return_types_associations_test.iyi` covers generated direct,
polymorphic and composite reader return types, including each reload reader. Native reload
readers return query errors in their unions; the assertions unwrap errors before comparing
successful types. The composite collection retains its owner, key columns, scope and cache.
Its single-owner tuple is matched with one equality per key column. Composite preloading
batches owner tuples into a single bound query and reload readers refresh the owner's cache.

Supplemental checks exercise both owner-key components, assignment into built records,
cache reset, database filtering, reload, and explicit strict-loading guards with cached reads.
The target and 27 existing association and query targets pass under SQLite and PostgreSQL.
