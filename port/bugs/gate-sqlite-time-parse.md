# SQLite timestamp coverage conventions — resolved

Source: `crystal-upstream/spec/grant/perf/w6_sqlite_time_parse_spec.cr`.

The reviewer confirmed that no parser or gate change is needed:

- Keep the parser's interpolated description verbatim: `# it: "reads #`. The loop underneath
  retains all nine input values and the original comparison assertion for each value.
- Keep the upstream PostgreSQL placeholder's marker and replace its empty pending body with a
  runtime guard assertion: `assert CURRENT_ADAPTER != "sqlite"`.

The native target follows both conventions and retains every original SQLite assertion. The
source, gate, and coverage generator remain unchanged.
