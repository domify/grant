# Native Hash equality

Native Hash has no value-equality overload. Two independently allocated maps with identical
entries compare unequal, for example `{"name" => "title"} == {"name" => "title"}`.

The alias-attribute spec uses `same_aliases?` to preserve upstream map equality: sizes must match
and every expected key must exist with its exact expected value. This covers both original map
assertions without relying on iteration order or string formatting.
