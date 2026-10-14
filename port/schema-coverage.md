# Schema coverage parser mismatch

`CoverageGen.parse_spec` truncates the final example of
`crystal-upstream/spec/grant/schema/pg_enum_extension_spec.cr`:

- Original: `treats extensions as a no-op where they do not exist`
- Parsed: `"treats extensions as a no-op where they`

Reproduce without compiling Crystal:

```sh
ruby -Iport -rcoverage -e \
  'p CoverageGen.parse_spec("crystal-upstream/spec/grant/schema/pg_enum_extension_spec.cr").last'
```

The translated target retains the full original description in an adjacent comment and uses the
parser's description for its gate marker. All assertions and the runtime adapter branch remain.
The worker has not changed the shared coverage parser or harness.
