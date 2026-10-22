# Public API composite association return types

The first three examples of `public_api_return_types_spec.cr` are translated in
`test/grant_public_api_return_types_test.iyi`. The manifest partitions all four original
CoverageGen example IDs exactly once.

The generated association reader example (`T-d4727368c6`) includes composite-key collection
readers. Its child remains todo under the composite-keys category in reviewer feedback item 6.
The faithful translation draft, including all six original type assertions and composite model
fixtures, is retained in `build/tmp/grant_public_api_return_types_associations_test.iyi`.
