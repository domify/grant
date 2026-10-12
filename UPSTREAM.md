# Crystal upstream tracking

The native iyi implementation is at the repository root. The complete tracked
Crystal source tree is imported under `crystal-upstream/` as a Git subtree.
Its source, specs, docs, and CI definitions retain their original relative paths.
Run Crystal commands from that directory. Only native tooling belongs at the root.

## Baseline and review cursor

Initial source: https://github.com/domify/grant at commit
`dfad8bfc89778a6d89e38ff481899db552e428b8` (Crystal Grant 0.23.4).

Last reviewed source commit:
`dfad8bfc89778a6d89e38ff481899db552e428b8`.

This cursor records review, not full behavioral parity. `doc/PORTING.md` records
implemented behavior and pending features. `doc/source-inventory.json` records
the original source hashes, rather than hashes of every future subtree revision.

The actual latest imported commit is recorded in Git's subtree metadata:

```sh
git log -1 --format=%B --grep='^git-subtree-dir: crystal-upstream$'
```

Use its `git-subtree-split` value. This imported cursor is separate from the
native review cursor above; importing code does not automatically port behavior.

## Importing updates

Use the developer's Crystal repository and its actual source branch or tag:

```sh
./scripts/update-crystal-upstream.sh <crystal-repository-url> <branch-or-tag>
```

The script requires a clean working tree, fetches the requested source, verifies
that it contains the original Grant Crystal layout, and imports it with
`git subtree merge --prefix=crystal-upstream --squash`. That creates a local
import commit. It does not push, edit native code, or advance the review cursor.
An already imported revision is a no-op.

The starting snapshot came from our fork. Do not assume its future `origin/main`
remains a Crystal source branch once the native layout is published there.
Supply the developer's actual source URL/ref explicitly; no upstream URL has
been guessed or configured. The script rejects a native-only root layout.

Review source changes from the cursor before porting their behavior:

```sh
git log --oneline <reviewed-commit>..<imported-commit> -- src spec
git diff <reviewed-commit>..<imported-commit> -- src spec
```

These source commits use the original paths (`src/`, `spec/`); the corresponding
files in this working tree are under `crystal-upstream/`.

1. Inspect the original code and relevant Crystal specs.
2. Port the behavior to native iyi with explicit module contracts and traits.
3. Add native parity cases and run appropriate checks.
4. Commit native changes separately from the subtree import.
5. Record deferred changes before advancing the review cursor, so imported
   revisions cannot hide work still pending in the iyi implementation.

## Ownership and publishing

Treat `crystal-upstream/` as an imported reference tree. Do not hand-edit it:
changes there create merge conflicts and differences from the imported commit.
Use the root `AGENTS.md` for native work and read the imported `CLAUDE.md` and
focused specs as reference. Ignore local build outputs within the subtree.

The original Git history remains intact. `main` at the time of conversion stays
on the original Crystal baseline; the new layout is on
`feature/phase-0-native-iyi`. No public default branch, tags, or remotes have
been changed. A Crystal shard installer expects a root `shard.yml`, so publish
this layout as an iyi branch/release and agree any default-branch change with
maintainers. Imported `.github` workflows are reference files and do not run
from their new subdirectory.
