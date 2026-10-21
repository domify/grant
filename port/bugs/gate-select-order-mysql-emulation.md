# MySQL-only order-emulation example remains in scope

Source: `crystal-upstream/spec/grant/query/select_order_expressions_spec.cr`.

`CoverageGen.parse_spec` excludes "emulates NULLS FIRST/LAST with ISNULL on MySQL" but retains
"qualifies the emulation when joins are present" as an in-scope example. The latter also constructs
only `Grant::Query::Assembler::Mysql` and asserts its MySQL-specific `ISNULL(...)` SQL rendering.
It exercises neither SQLite nor PostgreSQL.

The worker left this spec unmodified and todo rather than removing its assertion or changing the
coverage parser. Please classify the second emulation example as adapter-out-of-scope too, using
the existing MySQL-only example convention.
