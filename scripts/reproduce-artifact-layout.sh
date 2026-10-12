#!/bin/sh
set -eu

grant_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
grant_probe_dir=$(mktemp -d /tmp/grant-artifact-probe.XXXXXX)
trap 'rm -rf "$grant_probe_dir"' EXIT HUP INT TERM
grant_compiler=${IYI:-iyi}
mkdir -p "$grant_probe_dir/producer" "$grant_probe_dir/consumer"
cp -R "$grant_root/grant" "$grant_probe_dir/producer/grant"
printf 'module github.com/domify/grant\n' > "$grant_probe_dir/producer/iyi.mod"
printf 'module consumer\n' > "$grant_probe_dir/consumer/iyi.mod"
cat > "$grant_probe_dir/producer/probe.iyi" <<'IYI'
module probe

import grant/adapters/sqlite::{Connection}
import grant/unit_of_work::{UnitOfWork}

connection = Connection.open(":memory:").or_panic
unit = UnitOfWork.new(connection)
assert unit.run { 42_i64 }.or_panic == 42_i64
connection.close.or_panic
puts "transaction completed"
IYI
cp "$grant_probe_dir/producer/probe.iyi" "$grant_probe_dir/consumer/probe.iyi"
IYI_CACHE_DIR="$grant_probe_dir/source-cache" "$grant_compiler" build \
  "$grant_probe_dir/producer/probe.iyi" --emit-iyimod "$grant_probe_dir/mods" \
  -o "$grant_probe_dir/source"
"$grant_probe_dir/source"
IYI_CACHE_DIR="$grant_probe_dir/consumer-cache" "$grant_compiler" build \
  "$grant_probe_dir/consumer/probe.iyi" --use-iyimod "$grant_probe_dir/mods" \
  -o "$grant_probe_dir/consumer-bin"
"$grant_probe_dir/consumer-bin"
