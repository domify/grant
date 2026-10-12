# Normalization at the model boundary

The application owns its sealed record constructors and assignments. A mapping
can declare `normalization : Plan?` and implement
`with_attributes(record, attributes) : T | DatabaseError` to rebuild a typed
record from normalized attribute values. Repository insert/update runs
`Mapping.normalize(record, context)` before BeforeValidation and validation.
The input record and attribute hash are not mutated.

The default `normalize` implementation applies the plan and calls
`with_attributes`. A mapping without a plan passes its record through. A mapping
with a plan but without `with_attributes` returns an explicit error. Hydration
uses `from_row` directly and never runs normalization, preserving legacy data
exactly as stored. Custom assignments must validate their resulting field types
and return `DatabaseError` for an invalid transformation.

```iyi
def normalization : Plan?
  @plan
end

def with_attributes(record : User, attributes : Attributes) : User | DatabaseError
  email = attributes["email"]
  if email.is_a?(String)
    User.new(email, record.id)
  else
    DatabaseError.new(20, "assignment", "email must remain text")
  end
end
```

Repository queries carry the mapping's plan. Equality, IN, inequality and
case-insensitive predicates normalize their input values when constructed.
Chaining ordering/pagination or removing order preserves the plan, without
reapplying normalization to already constructed predicates. A case-insensitive
normalizer must return text or nil. Configure plans before sharing them with
repositories; normalizer implementations should be deterministic.

`Plan.add` accepts a typed `Condition` and an optional `invert` flag. `apply`
first applies unconditional rules, then conditional rules in declaration order.
Conditions see the current normalized attributes and create/update context.
Conditional rules never run in `value_for` or query argument normalization;
queries have no record instance against which to evaluate them.

Nil values skip a normalizer by default; `apply_to_nil: true` allows an explicit
nil transformation. Absent attributes remain absent. A conditional transform
does not bypass either requirement.

This boundary replaces Crystal's generated model setters. Ordinary application
record construction does not automatically normalize: an application can call
the plan in its constructor/factory when it needs immediate canonical values.
Repository normalization runs once before validation; callbacks that construct
new attribute values afterward must apply the assignment policy themselves.
Raw `Query.insert`/`update` write supplied attributes directly; use the repository
for model normalization and lifecycle behavior.

`normalization_model_test.iyi` exercises SQLite insert/update, validation order,
conditional rules, automatic query coercion, unchanged inputs, legacy hydration
and invalid transformed field types. It is partial parity coverage, not a full
replacement for every imported normalization case.
