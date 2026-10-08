# The SQL a has_many collection reads its records with, written once for all
# collections. `AssociationCollection(Owner, Target)` is a type per
# association, so code in it is compiled again for each of them; here the
# target's table and quoting come in as values.
module Grant::AssociationSql
  alias Meta = Grant::AssociationRegistry::AssociationMeta

  # The `:through` association of *owner_name* and the source association on
  # its join model.
  def self.through_associations(owner_name : String, through : Symbol | String | Nil, source : String?) : Tuple(Meta, Meta)
    through_name = through || raise ArgumentError.new("Missing through association metadata")
    source_name = source || raise ArgumentError.new("Missing source association metadata")
    through_metadata = Grant::AssociationRegistry.get(owner_name, through_name.to_s) || raise ArgumentError.new("Cannot resolve through association #{owner_name}##{through_name}")
    source_metadata = Grant::AssociationRegistry.get(through_metadata[:target_class].name, source_name) || raise ArgumentError.new("Cannot resolve source association #{through_metadata[:target_class].name}##{source_name}")
    {through_metadata, source_metadata}
  end

  # The FROM ... WHERE part selecting the collection's records by the owner's
  # key (bound to its `?`), directly or through the join model.
  def self.query(target_table : String, quote : String -> String, foreign_key : String,
                 type_column : String?, through : Tuple(Meta, Meta)?) : String
    unless through
      type_predicate = type_column ? " AND #{target_table}.#{quote.call(type_column)} = ?" : ""
      return "WHERE #{target_table}.#{quote.call(foreign_key)} = ?#{type_predicate}"
    end

    through_metadata, source_metadata = through
    join_model = through_metadata[:target_class]
    join_table = join_model.quoted_table_name
    join_primary_name = join_model.primary_name || raise Grant::Querying::MissingPrimaryKeyError.new("#{join_model.name} has no primary key")
    join_primary_key = join_model.quote(join_primary_name)
    target_join = if source_metadata[:type] == :belongs_to
                    "#{target_table}.#{quote.call(source_metadata[:primary_key])} = #{join_table}.#{join_model.quote(source_metadata[:foreign_key])}"
                  else
                    "#{target_table}.#{quote.call(source_metadata[:foreign_key])} = #{join_table}.#{join_primary_key}"
                  end
    "JOIN #{join_table} ON #{target_join} WHERE #{join_table}.#{join_model.quote(through_metadata[:foreign_key])} = ?"
  end

  # The subquery restricting a `:through` collection's relation: the target
  # key to compare and the SELECT of the keys the owner reaches.
  def self.through_subquery(through : Tuple(Meta, Meta)) : Tuple(String, String)
    through_metadata, source_metadata = through
    if source_metadata[:type] == :belongs_to
      source_key = through_metadata[:target_class].quote(source_metadata[:foreign_key])
      target_key = source_metadata[:primary_key]
    else
      join_model = through_metadata[:target_class]
      primary_name = join_model.primary_name || raise Grant::Querying::MissingPrimaryKeyError.new("#{join_model.name} has no primary key")
      source_key = join_model.quote(primary_name)
      target_key = source_metadata[:foreign_key]
    end
    join_model = through_metadata[:target_class]
    join_table = join_model.quoted_table_name
    join_owner_key = join_model.quote(through_metadata[:foreign_key])
    {target_key, "SELECT #{source_key} FROM #{join_table} WHERE #{join_owner_key} = ?"}
  end

  SCOPE_OPERATORS = {"eq" => "=", "gteq" => ">=", "lteq" => "<=", "neq" => "!=", "ltgt" => "<>", "gt" => ">", "lt" => "<", "ngt" => "!>", "nlt" => "!<", "like" => "LIKE", "nlike" => "NOT LIKE"}

  # A scope's conditions and ORDER/LIMIT/OFFSET as SQL fragments: the AND
  # clause, its bound values and the modifiers.
  def self.scope_fragments(where_fields : Array(Grant::Query::WhereField),
                           order_fields : Array(NamedTuple(field: String, direction: Grant::Query::Builder::Sort)),
                           limit : Int64?, offset : Int64?, table : String, quote : String -> String) : Tuple(String, Array(Grant::Columns::Type), String)
    clauses = [] of String
    params = [] of Grant::Columns::Type

    where_fields.each do |field|
      if field.is_a?(NamedTuple(join: Symbol, field: String, operator: Symbol, value: Grant::Columns::Type))
        operator = SCOPE_OPERATORS[field[:operator].to_s]? || field[:operator].to_s
        column = field[:field]
        column = "#{quote.call(table)}.#{quote.call(column)}" unless column.includes?(".")
        clauses << "#{column} #{operator} ?"
        params << field[:value]
      elsif field.is_a?(NamedTuple(join: Symbol, stmt: String, value: Grant::Columns::Type))
        clauses << "(#{field[:stmt]})"
        params << field[:value] unless field[:value].nil?
      end
    end

    where_clause = clauses.empty? ? "" : "AND #{clauses.join(" AND ")}"
    modifiers = [] of String
    unless order_fields.empty?
      sql = order_fields.map do |order|
        field = order[:field]
        next field if order[:direction].raw?
        quoted = field.includes?(".") ? field.split(".").map { |part| quote.call(part) }.join(".") : quote.call(field)
        direction = order[:direction].sorts_descending? ? "DESC" : "ASC"
        "#{quoted} #{direction}"
      end
      modifiers << "ORDER BY #{sql.join(", ")}"
    end
    modifiers << "LIMIT #{limit}" if limit
    modifiers << "OFFSET #{offset}" if offset
    {where_clause, params, modifiers.join(" ")}
  end
end
