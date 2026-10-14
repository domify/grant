# Assigns every unfinished manifest entry to one Stage B owner.
#   ruby port/owners.rb   # writes port/owners/<owner>.txt and prints counts
require_relative "manifest"

OWNER_RULES = [
  ["validations", %r{spec/grant/(validations|validators|validation_helpers|errors|exceptions|error)/}],
  ["schema", %r{spec/grant/(schema|migrator|tasks)/}],
  ["associations", %r{spec/grant/(associations|eager_loading)/|nested_attributes|secure_password|serialization_multimodel|result_types|compile_target_}],
  ["connection", %r{spec/grant/(connection|sharding|scale|config|spec_support|notifications)/|spec/integration/|/(connection_[a-z_]*|sharding[a-z_]*|geo_sharding|range_sharding|prevent_writes|multi_database_unit|advanced_multi_database|fiber_connection_context|simple_connection|schema_tenant_reset_error|test_fixtures|public_api_return_types|parity_tracker|secure_features_integration|conventions_regressions)_spec\.cr$}],
  ["state", %r{spec/grant/(dirty|locking|persistence|attributes|types|columns|converters|callbacks|sti|composite|encryption)/|/(value_objects|normalization|attribute_api|serialized_column|encryption[a-z_]*|enum_attributes|composite_primary_key|secure_token|signed_id|token_for)_spec\.cr$}],
  ["query", %r{spec/grant/(query|querying|scoping|select)/}],
  ["query_api", %r{.}],
]

entries = Manifest.load.reject { |e| %w[done excluded].include?(e["status"]) }
owners = Hash.new { |h, k| h[k] = [] }
entries.each do |entry|
  owner = OWNER_RULES.find { |_, re| entry["source"] =~ re }[0]
  owner = "state" if owner == "query" && entry["area"] == "dirty_state"
  owner = "associations" if owner == "query" && entry["area"] == "associations"
  owners[owner] << entry
end
Dir.mkdir(File.join(CoverageGen::ROOT, "port/owners")) unless Dir.exist?(File.join(CoverageGen::ROOT, "port/owners"))
owners.each do |owner, list|
  File.write(File.join(CoverageGen::ROOT, "port/owners/#{owner}.txt"), list.map { |e| e["source"] }.sort.join("\n") + "\n")
  puts "#{owner}: #{list.size} files #{list.sum { |e| e["examples"] }} examples"
end
