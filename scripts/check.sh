#!/bin/sh
set -eu

grant_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$grant_root"
IYI_CACHE_DIR=${IYI_CACHE_DIR:-/tmp/iyi-grant-native-cache}
export IYI_CACHE_DIR
mkdir -p "$IYI_CACHE_DIR"
grant_compiler=${IYI:-iyi}
"$grant_compiler" check grant.iyi
"$grant_compiler" fmt --check grant grant.iyi ./*_test.iyi
# Active porting scope is SQLite; retain the PostgreSQL reference test on disk.
set --
for grant_test in ./*_test.iyi; do
  case "$grant_test" in
    ./postgresql_test.iyi) continue ;;
  esac
  set -- "$@" "$grant_test"
done
"$grant_compiler" test "$@"

grant_check_dir=$(mktemp -d /tmp/grant-iyi-check.XXXXXX)
trap 'rm -rf "$grant_check_dir"' EXIT HUP INT TERM
for grant_case in model_test lifecycle_test normalization_model_test uniqueness_test dependent_test binary_test; do
  grant_case_dir="$grant_check_dir/$grant_case"
  mkdir -p "$grant_case_dir/consumer"
  "$grant_compiler" build "$grant_case.iyi" --emit-iyimod "$grant_case_dir/mods" -o "$grant_case_dir/from-source"
  cp "$grant_case.iyi" "$grant_case_dir/consumer/$grant_case.iyi"
  printf 'module consumer\n' > "$grant_case_dir/consumer/iyi.mod"
  "$grant_compiler" build "$grant_case_dir/consumer/$grant_case.iyi" --use-iyimod "$grant_case_dir/mods" -o "$grant_case_dir/from-artifacts"
  "$grant_case_dir/from-artifacts"
  printf 'artifact consumer passed: %s\n' "$grant_case"
done
