# Port loop rules

Do not pollute commit messages with co authored by Agents.

Wrap documentation lines at 100 characters maximum.

Read `port/HINTS.md` first, then `doc/NAMING.md`. `port/TASK.md` is the historical Phase 0/1 brief;
read `doc/PORTING.md` only by searching it for the area at hand.

Completion means a full `bin/port-check` exits 0. `--fast FILE...` validates only those tests and
never establishes completion. Never end a port worker response with a list of remaining work. Never
weaken, delete, skip, mark pending, or replace assertions just to pass a gate. Never edit
`crystal-upstream/`.

Port structurally, 1:1: `src/grant/x.cr` to `grant/x.iyi`, preserving class inheritance, names,
modules where iyi permits, `macro inherited`, `macro finished`, annotations, `column`, `table`,
`connection`, associations, and the public API. Do not redesign around repositories or mappings.
The first port did exactly that, so every spec became a design question and it reached under 1%
upstream coverage. Idiomatic iyi refactors (derive instead of `__process_columns`, precise error
unions, traits) wait until a full `bin/port-check` exits 0, and even then keep translated tests
and the public API unchanged, one area at a time.
SQLite and PostgreSQL are in scope; only MySQL-only files and examples may be excluded, solely as
`adapter-out-of-scope`. Every test runs under both `CURRENT_ADAPTER=sqlite` and `CURRENT_ADAPTER=pg`
(PostgreSQL 17 in the `grant-pg` docker container on 127.0.0.1:5433); keep upstream adapter branches
(`if CURRENT_ADAPTER == "pg"`, `adapter.postgres?`) as runtime branches.

Translate each upstream spec near line by line, preserving every assertion. Each original in-scope
`it` has an exact `# it: <original description>` marker. Generated target paths are root-level to
resolve module imports. Error types implement `Error`; raises become returned error union members,
rescues become union checks, and transactions roll back on error block results. Rollback itself is
an error value.

Apply `doc/NAMING.md` mechanically: raising `foo!` becomes `foo_strict`, returning `T | Error`;
callers use postfix `!` or `.or_panic`. In-place relation `foo!` becomes `foo_in_place`. Keyword
names receive documented aliases, starting with `import_records` for `import`.

Split hard files into child entries under the source manifest entry: each child has `target`,
`status: todo|done`, and `examples`, an array of original example IDs from `CoverageGen.parse_spec`.
Children must partition all original in-scope examples exactly once. The parent is done only when
every child is done. Preserve assertions and exact description markers in each child target.

Commit after each spec file, with a descriptive message and no attribution trailers. One Codex
worker ports in the main checkout; the loop runs `bin/port-check --integrate` itself between rounds
and hands regressions back as the first task. Shared-core signature changes are allowed when a
spec needs them, provided every affected test is updated in the same commit. Always use
`/home/priit/contribute/iyi/bin/iyi` unless `IYI` explicitly overrides it, and set
`IYI_CACHE_DIR=$PWD/.iyi-cache`. Do not compile the Crystal suite.
