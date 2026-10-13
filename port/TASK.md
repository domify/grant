# Task: fast structural port of Crystal Grant to native iyi

You (Codex) do Phase 0 and Phase 1 below yourself in this repository
(~/contribute/grant, branch native-iyi-fast-port). The supervisor then starts the
bin/port-loop you build. Do not ask questions; decide, document, continue.

## Paths
- Crystal source: crystal-upstream/ (read-only, never edit). Start commit:
  625ccd71358b00e552ec8b24562c4619f276d140 (write it to port/START_COMMIT).
- Previous native attempt (reference only, internals may be reused):
  ~/contribute/grant-iyi-first-port. Its port/coverage.rb (spec parser and
  PostgreSQL/MySQL exclusion logic) is on branch native-iyi of this repo:
  `git show native-iyi:port/coverage.rb`.
- Compiler: IYI=/home/priit/contribute/iyi/bin/iyi (patched; prefer it).
- Always set IYI_CACHE_DIR=$PWD/.iyi-cache. /tmp is a tmpfs with a 1M inode
  limit that a previous run exhausted.

## Strategy (decided, do not re-litigate)
The first attempt redesigned Grant (Repository(T), Mapping(T), no inheritance,
no macro DSL), so every spec had to be re-thought. That was the mistake.
Native iyi (no --crystal) supports class inheritance, `macro inherited`,
`macro finished`, `column`-style macros generating properties, annotations,
`@type.instance_vars`, `**args` and class variables. It has no exceptions.
- Port Grant STRUCTURALLY, 1:1: src/grant/x.cr -> grant/x.iyi, same class and
  module names where iyi's module namespacing allows, same public API
  (`class User < Base`, `column`, `table`, `connection`, `has_many`,
  `belongs_to`, `where`, `save`, `create`, `find`, `destroy`, ...).
- Errors: `raise` becomes a returned error union member (types implement the
  `Error` trait); `rescue` becomes a union check; transactions roll back when
  the block returns an error; Grant::Transaction::Rollback is an error value.
- `!` cannot end an iyi name (SPEC.md III.1.7). Naming rule, document it in
  doc/NAMING.md and apply mechanically:
  - raising variants (`find!`, `create!`, `save!`, `update!`, `first!`,
    `find_by!`, ...) -> `<name>_strict`, returning `T | Error`; call sites use
    `!` or `.or_panic`;
  - in-place relation mutators (`where!`, `order!`, `joins!`, `or!`, ...)
    -> `<name>_in_place`.
  - Crystal names that are iyi keywords (e.g. `import`) get a documented
    alias such as `import_records`.
- Specs are translated near line by line: spec/grant/x_spec.cr ->
  spec/grant/x_test.iyi (or a root-level x_test.iyi if `iyi test` requires it;
  verify once). Each original `it` becomes a section with a
  `# it: <exact original description>` comment above its assertions. Keep
  every assertion; `x.should eq(y)` -> `assert x == y`, `expect_raises(E)` ->
  assert the call returns an `E`.
- Scope: SQLite only. PostgreSQL/MySQL files and adapter-specific examples are
  excluded with reason adapter-out-of-scope; nothing else may be excluded.

## Phase 0: Spike (time-box 90 minutes)
An UNVERIFIED supervisor draft exists (uncommitted): iyi.mod, grant/errors.iyi,
grant/adapter/sqlite.iyi (copied SQLite C binding), grant/connections.iyi,
grant/base.iyi (Base with column/table/connection/after_destroy macros, CRUD,
transaction with instance-state restore). It type-checks as a module but has
never been compiled into a program. Use it, fix it or replace it.
Port Grant::Base, `column`, the SQLite adapter path, CRUD (`save`, `create`,
`find`, `destroy`, `where`) and the real spec
crystal-upstream/spec/grant/persistence/delete_spec.cr end to end (models from
persistence_regression_models.cr). Measure cold and warm build time and peak
RSS of its test (`/usr/bin/time -f "%e s %M KB"`), record them in
doc/PORTING.md. If a compiler limitation blocks the structural approach, write
a minimal reproduction to port/BLOCKER.md and stop. Otherwise commit.

## Phase 1: Harness
1. Generate port/manifest.yml by script (reuse the coverage.rb parser and
   exclusion logic): one entry per upstream spec file: source, target test,
   area, examples (count of in-scope `it`), status todo|done|excluded.
   Areas and order: transactions, query, associations, dirty_state, other.
2. bin/port-check:
   - fails if any non-excluded entry is not done or its target is missing;
   - each done target must pass and contain one `# it:` marker for every
     in-scope original example of its source file (exact description match);
   - runs all *_test.iyi via `iyi test --json`; no skip/pending/TODO markers;
   - fails if crystal-upstream/ changed since port/START_COMMIT;
   - `--fast FILE...` runs only the given tests; full mode is the only
     completion result;
   - last line: `PORT <done>/<total> EXAMPLES <ported>/<total> AREA <area> OK|FAIL`.
3. AGENTS.md "Port loop rules": completion = bin/port-check exit 0; never end
   with a list of remaining work; never weaken or skip tests; never edit
   crystal-upstream/; split hard files into child entries; commit after each
   spec file; read port/HINTS.md first; this strategy and naming rule.
4. bin/port-loop (bash):
   - Stage A (serial, 1 worker): core modules everything imports (base,
     columns, adapter, query builder, transactions, callbacks, validations)
     until the transactions area is done.
   - Stage B (parallel): 3 workers, each in its own git worktree under
     port/worktrees/ on its own branch, owning one area (query /
     associations / dirty_state+other). After each worker iteration the loop
     rebases the branch onto native-iyi-fast-port, runs the full port-check on
     the result, and fast-forwards native-iyi-fast-port. A worker whose rebase
     conflicts or fails the gate restarts on the fresh branch with a hint.
   - each worker runs: `codex exec -p port -C <worktree> --output-last-message
     port/last-<worker>.txt "<prompt>" < /dev/null > port/codex-<worker>.log 2>&1`
     (stdin MUST be /dev/null or codex waits forever) with
     IYI_CACHE_DIR=<worktree>/.iyi-cache.
   - append each gate line with worker and iteration to port/status.log;
     exit 0 on pass, 2 if EXAMPLES is flat for 3 rounds, 3 after 60 rounds.
5. Run bin/port-check once (it must FAIL), commit everything, then STOP and
   write the manifest totals per area and the gate line as your final message.
   Do not start bin/port-loop yourself; the supervisor starts it.

## Pitfalls
- Never compile the whole Crystal spec suite (about 20 GB RAM).
- A full gate takes minutes; workers use --fast on their own files.
- Commit messages describe the change; no attribution trailers.
