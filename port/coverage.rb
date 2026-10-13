# Coverage map generator for the Crystal Grant -> native iyi port.
#
#   ruby port/coverage.rb generate   # (re)write port/coverage.yml, keeping status/iyi_ref/children
#   ruby port/coverage.rb stats      # counts per area and status
#
# bin/port-check loads this file and compares port/coverage.yml with
# CoverageGen.generate, so the generated fields cannot be edited by hand.
require "digest"
require "json"
require "yaml"

module CoverageGen
  ROOT = File.expand_path("..", __dir__)
  UPSTREAM = File.join(ROOT, "crystal-upstream")
  YML = File.join(ROOT, "port", "coverage.yml")
  AREAS = %w[transactions query associations dirty_state other].freeze
  EXCLUDE_REASON = "adapter-out-of-scope".freeze

  # Whole upstream files that only exist for PostgreSQL or MySQL.
  ADAPTER_FILE = %r{(^|/)(pg|mysql|pg_[a-z_]+|mysql_[a-z_]+|jsonb|gin_index)(_spec)?\.cr$}

  AREA_RULES = [
    ["transactions", /transaction|savepoint|commit|rollback|atomicit|pessimistic|advisory_lock/i],
    ["dirty_state", /dirty|optimistic|lock_version|partial[_ ]update|previous_change|saved_change|will_save|in_database|changed\?|_changed|_was\b|_change\b/i],
    ["associations", /association|has_many|has_one|belongs_to|through|polymorphic|habtm|has_and_belongs|nested_attributes|autosave|dependent|inverse_of|eager_load|preload|includes|counter_cache|delegated_type/i],
    ["query", /quer|where|relation|scop|pluck|aggregat|select|order|group|having|join|limit|offset|finder|find_by|\bfind\b|batch|sanitiz|raw_sql|exists|calculat|\bcount\b|\bsum\b|minimum|maximum|average|distinct|from_and_with|tuple|predicate|assembler|executor|\bor\b|\bnot\b|comparison/i],
  ].freeze

  module_function

  def classify(path, text)
    base = File.basename(path, ".cr").sub(/_spec$/, "")
    [base, File.dirname(path), text].each do |subject|
      AREA_RULES.each { |area, re| return area if subject =~ re }
    end
    "other"
  end

  def sid(prefix, *parts)
    "#{prefix}-#{Digest::SHA1.hexdigest(parts.join("\u0001"))[0, 10]}"
  end

  def heredoc_terms(line)
    line.scan(/<<[-~]["']?([A-Z_][A-Z0-9_]*)["']?/).flatten
  end

  # Is the current macro / runtime adapter branch PostgreSQL or MySQL only?
  def branch_excluded?(conds, in_else)
    current = conds.last
    if in_else
      return conds.any? { |c| c =~ /==\s*"sqlite"/ || c =~ /sqlite\?/ }
    end
    return true if current =~ /==\s*"(pg|mysql)"/ && current !~ /sqlite/ && current !~ /includes\?/
    return true if current =~ /(postgres|mysql)\?/
    return true if current =~ /!=\s*"sqlite"/
    return true if current =~ /^\s*unless\b.*==\s*"sqlite"/
    false
  end

  def adapter_cond?(cond)
    cond =~ /CURRENT_ADAPTER|adapter\.(postgres|mysql|sqlite)\?/
  end

  def spec_files
    Dir.glob(File.join(UPSTREAM, "spec", "**", "*_spec.cr")).sort
  end

  def src_files
    Dir.glob(File.join(UPSTREAM, "src", "**", "*.cr")).sort
  end

  def parse_spec(file)
    rel = file.delete_prefix(ROOT + "/")
    urel = file.delete_prefix(UPSTREAM + "/")
    whole_excluded = urel =~ ADAPTER_FILE
    entries = []
    describes = []   # [indent, name]
    macro = []       # {conds:, else:, adapter:}
    runtime = []     # {indent:, conds:, else:}
    heredoc = []
    seen = Hash.new(0)
    File.foreach(file).with_index(1) do |line, no|
      unless heredoc.empty?
        heredoc.shift if line.strip == heredoc.first
        next
      end
      next if line =~ /^\s*#/
      # Macro conditionals ({% if %} ... {% end %}), possibly several per line.
      line.scan(/\{%\s*(if|unless|for|begin|elsif|else|end)\b(.*?)%\}/) do |kw, rest|
        case kw
        when "if", "unless" then macro << {conds: ["#{kw} #{rest}"], else: false, adapter: adapter_cond?(rest)}
        when "for", "begin" then macro << {conds: [kw], else: false, adapter: false}
        when "elsif"
          if (top = macro.last)
            top[:conds] << "if #{rest}"
            top[:adapter] ||= adapter_cond?(rest)
          end
        when "else" then macro.last && (macro.last[:else] = true)
        when "end" then macro.pop
        end
      end
      indent = line[/^\s*/].size
      # Runtime adapter blocks: `if CURRENT_ADAPTER == "pg"` on its own line.
      if line =~ /^\s*(if|unless)\s+(CURRENT_ADAPTER\s*[!=]=\s*"\w+"|adapter\.\w+\?)\s*$/
        runtime << {indent: indent, conds: ["#{$1} #{$2}"], else: false}
      elsif (top = runtime.last) && top[:indent] == indent
        if line =~ /^\s*elsif\s+(.*)$/ then top[:conds] << "if #{$1}"
        elsif line =~ /^\s*else\s*$/ then top[:else] = true
        elsif line =~ /^\s*end\b/ then runtime.pop
        end
      end
      if (d = line.match(/^(\s*)(describe|context)\b\s*\(?\s*(.+?)\)?\s+do\b/))
        describes.pop while describes.any? && describes.last[0] >= d[1].size
        describes << [d[1].size, (d[3][/\A"((?:[^"\\]|\\.)*)"/, 1] || d[3]).strip]
      elsif line !~ /^\s*it\s*[.=]/ && (m = line.match(/^(\s*)(it|pending|xit)(?![!?\w])(?:\s*\(?\s*(.*?))?\s*(?:\bdo\b.*|\{.*)?$/))
        ind, kw, arg = m[1].size, m[2], (m[3] || "")
        describes.pop while describes.any? && describes.last[0] >= ind
        desc = arg[/\A"((?:[^"\\]|\\.)*)"/, 1] || arg.sub(/,\s*\w+:.*\z/, "").strip
        desc = "(unnamed)" if desc.empty?
        chain = describes.map(&:last).join(" > ")
        key = [urel, chain, desc]
        n = (seen[key] += 1)
        excluded = whole_excluded ||
          macro.any? { |m| m[:adapter] && branch_excluded?(m[:conds], m[:else]) } ||
          runtime.any? { |r| branch_excluded?(r[:conds], r[:else]) } ||
          "#{chain} #{desc}" =~ /\b(postgres(ql)?|mysql|mariadb)\b/i && "#{chain} #{desc}" !~ /sqlite/i
        entries << {
          "id" => sid("T", *key, n), "kind" => "test",
          "source_ref" => "#{rel}:#{no}", "area" => classify(urel, "#{chain} #{desc}"),
          "name" => [chain, desc].reject(&:empty?).join(" > ") + (kw == "it" ? "" : " [upstream #{kw}]"),
          "status" => excluded ? "excluded" : "todo",
          "exclusion_reason" => excluded ? EXCLUDE_REASON : nil,
          "_indent" => ind,
        }
      elsif line =~ /\bpending!\s*\(?\s*"([^"]*)"/ && $1 =~ /(postgres\w*|mysql|mariadb)\b[^"]*\bonly\b/i &&
            (last = entries.last) && indent > last["_indent"]
        # `pending!("PostgreSQL only")` inside an example makes that example adapter specific.
        last["status"] = "excluded"
        last["exclusion_reason"] = EXCLUDE_REASON
      end
      heredoc.concat(heredoc_terms(line))
    end
    entries.each { |e| e.delete("_indent") }
  end

  def parse_src(file)
    rel = file.delete_prefix(ROOT + "/")
    urel = file.delete_prefix(UPSTREAM + "/")
    excluded = urel =~ ADAPTER_FILE
    owners = []      # [indent, name, private?]
    heredoc = []
    found = {}
    File.foreach(file).with_index(1) do |line, no|
      unless heredoc.empty?
        heredoc.shift if line.strip == heredoc.first
        next
      end
      next if line =~ /^\s*#/
      indent = line[/^\s*/].size
      if line =~ /^(\s*)(private\s+)?(abstract\s+)?(module|class|struct|enum|lib)\s+([A-Z][\w:]*)/
        owners.pop while owners.any? && owners.last[0] >= $1.size
        owners << [$1.size, $5, !$2.nil? || $4 == "lib"]
      elsif line =~ /^(\s*)(private\s+|protected\s+)?(abstract\s+)?(def|macro)\s+(self\.)?([^\s(:]+)/
        ind, vis, kind, selfp, name = $1.size, $2, $4, $5, $6
        owners.pop while owners.any? && owners.last[0] >= ind
        next if vis || name.include?("{{") || name.start_with?("_") || owners.any? { |o| o[2] }
        owner = owners.map { |o| o[1] }.join("::")
        owner = "(top-level)" if owner.empty?
        name = "new" if name == "initialize"
        sep = selfp || name == "new" ? "." : "#"
        label = "#{owner}#{sep}#{name}#{kind == "macro" ? " (macro)" : ""}"
        if found[label]
          found[label]["overloads"] += 1
        else
          found[label] = {
            "id" => sid("A", urel, label), "kind" => "api",
            "source_ref" => "#{rel}:#{no}", "area" => classify(urel, label),
            "name" => label, "overloads" => 1,
            "status" => excluded ? "excluded" : "todo",
            "exclusion_reason" => excluded ? EXCLUDE_REASON : nil,
          }
        end
      end
      heredoc.concat(heredoc_terms(line))
    end
    found.values
  end

  # Deterministic, generated part of every entry, ordered by area priority then source.
  def generate
    tests = spec_files.flat_map { |f| parse_spec(f) }
    apis = src_files.flat_map { |f| parse_src(f) }
    (tests + apis).each_with_index.sort_by { |e, i| [AREAS.index(e["area"]), i] }.map(&:first)
  end

  GENERATED_KEYS = %w[id kind source_ref area name overloads].freeze

  def load_yml
    return [] unless File.exist?(YML)
    YAML.safe_load(File.read(YML)) || []
  end

  def child_of(id)
    id[/\A([TA]-[0-9a-f]{10})\.\d+(\.\d+)*\z/, 1]
  end

  def merge(generated, existing)
    by_id = existing.to_h { |e| [e["id"], e] }
    children = existing.select { |e| child_of(e["id"].to_s) }.group_by { |e| child_of(e["id"]) }
    generated.flat_map do |g|
      old = by_id[g["id"]] || {}
      e = g.dup
      e["iyi_ref"] = old["iyi_ref"]
      unless g["status"] == "excluded"
        e["status"] = %w[todo done].include?(old["status"]) ? old["status"] : "todo"
      end
      [e] + (children[g["id"]] || [])
    end
  end

  FIELD_ORDER = %w[id kind source_ref area name overloads iyi_ref status exclusion_reason].freeze

  def dump(entries)
    lines = ["# Generated by port/coverage.rb; edit only status, iyi_ref and child entries (id <parent>.<n>).",
             "# One entry per line. Child entries split a hard item: {id: T-xxxxxxxxxx.1, kind: child, name: ..., area: ..., iyi_ref: ..., status: todo}."]
    entries.each do |e|
      keys = FIELD_ORDER.select { |k| e.key?(k) } + (e.keys - FIELD_ORDER)
      body = keys.map { |k| "#{k}: #{e[k].nil? ? "null" : e[k].is_a?(Integer) ? e[k] : e[k].to_s.to_json}" }
      lines << "- {#{body.join(", ")}}"
    end
    lines.join("\n") + "\n"
  end

  def stats(entries)
    rows = Hash.new { |h, k| h[k] = Hash.new(0) }
    entries.each { |e| rows[e["area"]][e["status"]] += 1; rows[e["area"]]["#{e["kind"]}"] += 1 }
    AREAS.each do |a|
      r = rows[a]
      puts format("%-13s total %5d  (tests %4d, api %4d, child %3d)  done %5d  todo %5d  excluded %4d",
                  a, r["done"] + r["todo"] + r["excluded"], r["test"], r["api"], r["child"], r["done"], r["todo"], r["excluded"])
    end
    puts format("%-13s total %5d", "ALL", entries.size)
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV[0]
  when "generate"
    entries = CoverageGen.merge(CoverageGen.generate, CoverageGen.load_yml)
    File.write(CoverageGen::YML, CoverageGen.dump(entries))
    CoverageGen.stats(entries)
  when "stats"
    CoverageGen.stats(CoverageGen.load_yml)
  else
    warn "usage: ruby port/coverage.rb generate|stats"
    exit 64
  end
end
