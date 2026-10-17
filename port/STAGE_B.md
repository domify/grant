# Stage B worker brief

You are one of several parallel workers porting Crystal Grant (crystal-upstream/, read-only) to native iyi, structurally and 1:1. Read AGENTS.md, port/HINTS.md and doc/NAMING.md first; they are binding.

## Your assignment

- You own exactly the upstream spec files listed in `port/owners/<owner>.txt` (your owner name is in your prompt). Port them to their manifest `target` files, preserving every assertion and the exact `# it: <description>` markers, on both SQLite and PostgreSQL.
- Port the upstream source (`crystal-upstream/src/grant/...`) those specs need, as new modules mirroring the upstream file layout (`src/grant/x.cr` → `grant/x.iyi`, `src/grant/a/b.cr` → `grant/a/b.iyi`). Read the upstream implementation before writing yours; keep its class/module names, method names (with the doc/NAMING.md renames), defaults and behaviour.
- Work in priority order: files whose examples need the least new infrastructure first, but do not skip a hard file forever; build the infrastructure it needs.

## Shared code

- Other workers change the code base at the same time on their own branches. Keep edits to shared core files (`grant/base.iyi`, `grant/query/builder.iyi`, `grant/adapter/*.iyi`, `grant/transaction.iyi`, `spec_helper.iyi`, `bin/`, `port/coverage.rb`, `port/manifest.rb`) small and additive: new methods or one hook line, not rewrites or reorderings. Put your model DSL in your own module as `pub macro model_methods(model)` with one line in `__process_columns`, and Builder extensions in trait modules (see port/HINTS.md).
- Never change another owner's tests, the harness, the exclusion logic or AGENTS.md. If a shared module has a real bug, fix it minimally and say so in the commit message.

## Process

- Commit after each spec file (tests passing on both adapters, manifest entry set to `done`), with a descriptive message ending in the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` if you are Claude (Codex: no trailer).
- Check your files with `bin/port-check --fast <targets>`; never run the full gate; the reviewer runs `bin/port-check --integrate` after merging.
- Never edit crystal-upstream/. Never weaken, skip, delete or mark pending an assertion. Never flatten an adapter branch (port/HINTS.md).
- When you stop, report: commits made, spec files completed (examples), files attempted but not finished and what blocks them, any shared-core changes, and any iyi compiler bugs found (with a minimal reproduction).
