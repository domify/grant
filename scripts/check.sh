#!/bin/sh
set -eu

grant_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$grant_root"
IYI_CACHE_DIR=${IYI_CACHE_DIR:-/tmp/iyi-grant-native-cache}
export IYI_CACHE_DIR
mkdir -p "$IYI_CACHE_DIR"
grant_compiler=${IYI:-iyi}
"$grant_compiler" check grant.iyi
"$grant_compiler" fmt --check grant fixtures grant.iyi model.iyi ./*_test.iyi
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
for grant_case in has_many_model_test model_api_test model_test lifecycle_test transaction_callback_test transaction_timing_test referential_integrity_test standalone_validation_test validation_context_test callback_conditions_test condition_arrays_test format_convenience_test format_model_test normalization_model_test uniqueness_test dependent_test binary_test locking_test timestamps_test touch_test scalars_test dynamic_validation_test comparison_validation_test comparison_model_test around_test belongs_to_write_test schema_alter_test schema_snapshot_test schema_constraints_test schema_catalog_test schema_constraint_removal_test schema_metadata_test partial_update_test bulk_test decimal_policy_test; do
  grant_case_dir="$grant_check_dir/$grant_case"
  mkdir -p "$grant_case_dir/consumer"
  "$grant_compiler" build "$grant_case.iyi" --emit-iyimod "$grant_case_dir/mods" -o "$grant_case_dir/from-source"
  cp "$grant_case.iyi" "$grant_case_dir/consumer/$grant_case.iyi"
  printf 'module consumer\n' > "$grant_case_dir/consumer/iyi.mod"
  "$grant_compiler" build "$grant_case_dir/consumer/$grant_case.iyi" --use-iyimod "$grant_case_dir/mods" -o "$grant_case_dir/from-artifacts"
  if [ "$grant_case" = schema_snapshot_test ]; then
    # Compile the native source factory emitted by the artifact consumer too.
    # This verifies SQL escaping, not just an in-memory snapshot replay.
    mkdir -p "$grant_case_dir/consumer/snapshot_fixture"
    "$grant_case_dir/from-artifacts" > "$grant_case_dir/consumer/snapshot_fixture/schema.iyi"
    printf 'module snapshot_fixture\n' > "$grant_case_dir/consumer/iyi.mod"
    cat > "$grant_case_dir/consumer/roundtrip.iyi" <<'IYI'
module snapshot_fixture/roundtrip

import snapshot_fixture/schema::{snapshot}
import grant/adapters/sqlite::{Connection}
import grant/schema_snapshot::{Dumper}

database = Connection.open(":memory:").or_panic
original = snapshot
original.apply(database).or_panic
assert original.version == 7_i64
assert Dumper.new(database).snapshot.or_panic.to_iyi.or_panic == original.to_iyi.or_panic
database.execute("INSERT INTO z_parent(score) VALUES(5)").or_panic
assert database.query("SELECT doubled FROM scores").or_panic[0]["doubled"] == 10_i64
assert database.query("SELECT name FROM z_parent").or_panic[0]["name"] == "literal \#{escaped} \"quotes\" \\ slash"
assert database.query("SELECT COUNT(*) AS count FROM audit").or_panic[0]["count"] == 2_i64
database.close.or_panic
IYI
    "$grant_compiler" build "$grant_case_dir/consumer/roundtrip.iyi" --use-iyimod "$grant_case_dir/mods" -o "$grant_case_dir/from-generated-snapshot"
    "$grant_case_dir/from-generated-snapshot"
    printf 'generated schema consumer passed\n'
  else
    "$grant_case_dir/from-artifacts"
  fi
  printf 'artifact consumer passed: %s\n' "$grant_case"
done
