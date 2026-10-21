# SQLite timestamp spec coverage parsing

Source: `crystal-upstream/spec/grant/perf/w6_sqlite_time_parse_spec.cr`.

`CoverageGen.parse_spec` reports the interpolated example at line 40 as `"reads #` rather
than `reads #{text} exactly as the general parser does`. The test loops over nine stored values.
The manifest currently counts this as one example with the truncated description.

It also counts the PostgreSQL branch's upstream pending placeholder at line 64 as a required
in-scope example, `applies to the SQLite adapter only`. That branch contains no assertions.
The real four examples are explicitly SQLite-only in the upstream source.

Please correct the parser/coverage handling before marking this spec done. The worker left the
source, manifest status, gate, and coverage generator unchanged.

Reproduction:

```sh
ruby -r ./port/coverage -e \
  'CoverageGen.parse_spec("crystal-upstream/spec/grant/perf/w6_sqlite_time_parse_spec.cr").each{|e|p e}'
```
