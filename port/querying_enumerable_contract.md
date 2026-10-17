# Enumerable error contract

`querying/enumerable_spec.cr` retains all 37 original CoverageGen IDs across three children.
Collections (20 examples) and reductions/chaining (13 examples) preserve their original assertions.
The types child (four examples) stays unfinished. Its complete translation is retained in
`port/querying_enumerable_types_draft.iyi`, outside native test discovery.

The original `Builder includes Enumerable` assertion requires the standard Enumerable trait.
Its native `each` contract returns `Nil`. Grant's `each` must also return database errors, as
required by the port's error-union rule. iyi rejects that implementation because the union is
not a subtype of `Nil`. Returning errors as panics or substituting a different trait would
change the required API or assertion.

Reproduce from the repository root:

```sh
IYI_CACHE_DIR=$PWD/.iyi-cache /home/priit/contribute/iyi/bin/iyi \
  test port/repros/querying_enumerable_contract.iyi
```

Expected diagnostic: `this method must return Nil`, followed by the rejected error union.
The standalone reproduction has no database dependency. This is a trait contract limitation;
no compiler crash is involved. The parent manifest entry remains `todo`.
