#!/bin/sh
set -eu

grant_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$grant_root"
IYI_CACHE_DIR=${IYI_CACHE_DIR:-/tmp/iyi-grant-native-cache}
export IYI_CACHE_DIR
mkdir -p "$IYI_CACHE_DIR"
iyi check grant.iyi
iyi fmt --check grant grant.iyi ./*_test.iyi
# Active porting scope is SQLite; retain the PostgreSQL reference test on disk.
set --
for grant_test in ./*_test.iyi; do
  case "$grant_test" in
    ./postgresql_test.iyi) continue ;;
  esac
  set -- "$@" "$grant_test"
done
iyi test "$@"

grant_check_dir=$(mktemp -d /tmp/grant-iyi-check.XXXXXX)
trap 'rm -rf "$grant_check_dir"' EXIT HUP INT TERM
mkdir -p "$grant_check_dir/consumer"
iyi build model_test.iyi --emit-iyimod "$grant_check_dir/mods" -o "$grant_check_dir/from-source"
cp model_test.iyi "$grant_check_dir/consumer/model_test.iyi"
printf 'module consumer\n' > "$grant_check_dir/consumer/iyi.mod"
iyi build "$grant_check_dir/consumer/model_test.iyi" --use-iyimod "$grant_check_dir/mods" -o "$grant_check_dir/from-artifacts"
"$grant_check_dir/from-artifacts"
