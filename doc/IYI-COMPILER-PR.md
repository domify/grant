# Preserve definition-witness ABI across source-free module artifacts

When an artifact producer has a definition-typing witness for a trait, a
source-free consumer must restore that witness before typing its own bodies.
Otherwise the consumer can reconstruct a different representation for a
trait-valued field than the one used by the producer's object code. A program
that works when compiled from source can then fail to import, or compile and
crash when built against `.iyimod` artifacts.

This PR preserves the producer's witness dependencies and restores them in the
consumer. It also handles witness references nested in union matches and generic
arguments, while continuing to reject missing ordinary types.

## How we found it

We found this while porting [Grant to native iyi](https://github.com/domify/grant/tree/native-iyi).
The library uses explicit traits and typed records, rather than a Crystal ORM
bridge. Its `Database` trait is stored in a `UnitOfWork` object and forwarded
through generic transaction methods.

The Grant verification gate deliberately builds twice: first from source while
emitting `.iyimod` files, then in a separate consumer project that contains only
the consumer program and the emitted artifacts. Grant's native library source
is absent from that consumer project. The consumer must compile and execute the
same SQLite behavior as the source build.

The earlier CRUD consumers passed. Adding shared transaction sessions exposed
the boundary: the source program worked, but the source-free consumer either
refused an `IyiDefTypeWitness_Grant_Database_Database` reference or terminated
with exit status 139. This was not a SQLite SQL failure; the failing path passed
the stored database trait through `UnitOfWork.run` into transaction code.

The reduced Grant probe only opens an in-memory database and runs:

```iyi
unit = UnitOfWork.new(connection)
assert unit.run { 42_i64 }.or_panic == 42_i64
```

Both builds should print `transaction completed` and exit successfully.

A temporary signal handler showed the crashing path passing through
`Connection#in_transaction?`, transaction code and `UnitOfWork#run`. Adding an
otherwise unnecessary, fully typed consumer function taking `Database` made the
consumer work: it caused consumer-side definition typing to create the missing
witness. That was a diagnostic clue, not an acceptable application workaround.
Applications should not declare synthetic compiler witnesses or add unused
trait functions to repair an artifact's ABI.

## Root cause

Definition typing creates synthetic trait implementers named
`IyiDefTypeWitness_*`. These witnesses can affect a trait's representation even
when no carried object-code instruction directly requests their type IDs.

The producer laid out the trait-valued field with its witness among the trait's
implementers. The consumer lacked that implementer, so its recompiled generic
forwarding body could use a different representation for the same field/call.
The value passed to transaction code was consequently not the connection value
that code expected.

Treating an absent witness as an unmatchable phantom type ID can preserve a
dispatch comparison, but does not preserve field layout and calling ABI. The
consumer needs the actual witness declaration before its bodies are typed.

## A second failure at the same boundary

After fixing the trait-field case, source-free Grant schema-migration consumers
exposed compound references containing the same witness:

```text
"grant/migrations" matches against
(Grant::Adapters::Sqlite::Connection | IyiDefTypeWitness_Grant_Database_Database),
and this build cannot name it
```

The initial top-level artifact-reference pass ran before definition typing could
restore that witness. Handling only direct witness names was insufficient for a
union member or a generic argument. Replacing the whole compound reference with
a phantom would also be incorrect: it would discard real members or accept an
unresolved ordinary type.

## What changed

1. Artifact emission records witnesses belonging to traits declared by a module
   as ABI dependencies, even if no carried instruction numbers them. The emitted
   dependency names stay sorted and unique.
2. Consumer definition typing discovers those dependencies, recreates matching
   trait witnesses and registers restored witnesses for type numbering. Witness
   declarations are flushed even when the consumer contributes no ordinary
   definition-typing probes.
3. The initial artifact-reference pass defers unresolved match references that
   contain witness names. Restoration discovers witness names within compound
   references as well as direct dependencies.
4. Deferred matches are resolved strictly after the main typing pass and before
   cleanup. Resolving them there avoids changing overload/type specialization
   while consumer bodies are being typed. A missing ordinary union member still
   produces a compiler error.

The fix uses the existing artifact dependency/reference machinery; it does not
add a new artifact container section or require an application API change.

## Regression coverage

The new source-free round-trip spec needs no Grant, database or C library. It has
two modules: one declares a trait and its concrete implementation, and the other
stores that trait in a field and forwards it through a generic block-taking
function. A fully declared trait function creates the producer witness. The
consumer imports only the concrete type and holder, so it does not independently
create the witness by declaring a trait parameter.

The producer and consumer must both print `42`. The helper deletes the imported
module sources before building the artifact consumer, so source fallback cannot
hide the regression.

The compound-reference regression exercises semantic resolution of carried
references containing both a union witness member and a generic witness
argument. It also checks that a reference containing `MissingRealType` is still
rejected. This is an injected-reference compiler test; the Grant gate separately
exercises the real schema-migration artifact boundary.

## Reproducing the trait-field issue without Grant

Create `app/values.iyi`:

```iyi
module app/values

pub trait Value
  abstract def value : Int32
end

pub class Number
  getter value : Int32
  def initialize(@value : Int32)
  end
end

impl Value for Number
end

pub def check_value(value : Value) : Int32
  value.value
end
```

Create `app/holder.iyi`:

```iyi
module app/holder

import app/values::{Value}

pub def forward(value : Value, &block : Int32 -> T) : T forall T
  block.call(value.value)
end

pub class Holder
  @value : Value
  def initialize(@value : Value)
  end
  def apply(&block : Int32 -> T) : T forall T
    forward(@value) { |value| block.call(value) }
  end
end
```

Create `main.iyi`:

```iyi
module main

import app/values::{Number}
import app/holder::{Holder}

puts Holder.new(Number.new(40)).apply { |value| value + 2 }
```

Create `iyi.mod` with `module app`. Build `main.iyi` with `--emit-iyimod mods`
and run it; the output should be `42`. Copy only `main.iyi` and `iyi.mod` into a
separate directory and build that consumer with `--use-iyimod` pointing at the
producer's `mods` directory. Run it and compare the output. The consumer
directory must not contain `app/values.iyi` or `app/holder.iyi`.

For example, with the files above inside a `producer` directory:

```sh
cd producer
iyi build main.iyi --emit-iyimod ../mods -o ../from-source
../from-source
mkdir ../consumer
cp main.iyi iyi.mod ../consumer/
cd ../consumer
iyi build main.iyi --use-iyimod ../mods -o ../from-artifact
../from-artifact
```

Both executables must print `42`. Use a compiler built from this branch for the
fixed result.

The committed compiler regression implements this procedure through
`iyimod_round_trip` in `spec/compiler/iyimod_spec.cr`.

## Validation

Checks run from an isolated worktree based on upstream `e82ab0a16`:

- `make -j1`: passed; rebuilt iyi reports commit `84c438193`.
- `bin/crystal tool format --check src spec`: passed.
- The four compiler files listed in CONTRIBUTING (`iyimod_spec`,
  `iyi_import_spec`, `semantic/iyi_spec`, `compiler_spec`): **414 examples,
  413 passed, 1 failed, 0 errors**. Both new regressions passed, as did all 126
  artifact examples within this run.
- Control run of the artifact suite on unmodified upstream compiler source with
  the new tests copied in: **126 examples, 124 passed, 1 failure, 1 error**.
  Exactly the two new examples fail: the trait-field consumer returns an empty
  output instead of `42`, and the compound witness match cannot be named.
- The standalone CLI reproduction above: source and source-free artifact
  consumers both print `42` with the rebuilt PR compiler.
- `bash bench/samples_roundtrip.sh`: passed, including 12 sample output
  comparisons and its additional symbols, reachability and carried-body checks.
- Grant's `scripts/reproduce-artifact-layout.sh`: passed with the rebuilt PR
  compiler; source and artifact consumers both print `transaction completed`.

The remaining failure is `Compiler concurrency adds no undefined symbol for the
runtime`, which observes `PROCEDURE_LINKAGE_TABLE_` in the local symbol output.
Running the same concurrency group against **unmodified upstream `e82ab0a16`**
reproduces it (3 examples, 2 passed, 1 failed). The PR does not change that test
or the concurrency runtime and does not suppress this failure. Its underlying
cause has not been diagnosed here.

The full `make compiler_spec primitives_spec std_spec` sweep was not run; this
is not a claim that every CI target passes.

The fresh full Grant gate (`IYI=/path/to/this/branch/bin/iyi ./scripts/check.sh`)
passed with the rebuilt PR compiler: **35 SQLite programs, 22 source-free
artifact consumers and the generated schema-factory consumer**. The deliberate
panic cases in that suite verify rollback and are expected diagnostics.
PostgreSQL live behavior is outside that verification.

## Scope and compatibility

The source branch is
[priit/iyi:fix/artifact-witness-abi](https://github.com/priit/iyi/tree/fix/artifact-witness-abi),
targeting `iyilang/iyi:master`. It starts at upstream `e82ab0a16` and contains only
the two compiler fixes (`503752129` and `84c438193`). It does not include the local Vim editor plugin commit or Grant code.

Rebuild affected artifacts and consumers with the corrected compiler. Older
artifacts may not contain witness dependencies that the producer previously
omitted, so this PR does not claim to repair every old artifact automatically.

Grant also exposed separate AST export problems involving ternary error
propagation and indexed assignments. Those are not fixed by this PR; Grant uses
explicit temporary values/branches for those expression shapes. They should
be investigated separately from witness restoration and ABI preservation.
