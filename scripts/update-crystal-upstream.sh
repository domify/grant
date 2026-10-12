#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo 'Usage: scripts/update-crystal-upstream.sh CRYSTAL_REPOSITORY BRANCH_OR_TAG' >&2
  exit 2
fi

grant_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$grant_root"
repository=$1
source_ref=$2
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo 'Commit or preserve working-tree changes before importing upstream.' >&2
  exit 1
fi
if [ ! -d crystal-upstream ]; then
  echo 'The initial crystal-upstream subtree has not been installed.' >&2
  exit 1
fi

git fetch --no-tags -- "$repository" "$source_ref"
source_commit=$(git rev-parse --verify 'FETCH_HEAD^{commit}')
if ! git cat-file -e "$source_commit:shard.yml" 2>/dev/null ||
   ! git cat-file -e "$source_commit:src/grant.cr" 2>/dev/null ||
   ! git cat-file -e "$source_commit:spec/spec_helper.cr" 2>/dev/null; then
  echo 'Source is not the Grant Crystal root layout; refusing to import it.' >&2
  exit 1
fi
imported_commit=$(git log -1 --format=%B --grep='^git-subtree-dir: crystal-upstream$' |
  sed -n 's/^git-subtree-split: //p')
if [ "$source_commit" = "$imported_commit" ]; then
  echo "Crystal revision $source_commit is already imported."
  exit 0
fi

git subtree merge --prefix=crystal-upstream --squash "$source_commit"
echo "Imported $source_commit. Review and port its behavior separately; see UPSTREAM.md."
