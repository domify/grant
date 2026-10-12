# Artifact trait-field layout regression (resolved locally)

Both compiler fixes are now published on
[priit/iyi:fix/artifact-witness-abi](https://github.com/priit/iyi/tree/fix/artifact-witness-abi),
based directly on upstream `e82ab0a16`. The ABI fix is cherry-picked as
`503752129`, followed by the compound-reference fix `84c438193`; the original
local `a03fc3438` is retained below as historical provenance. The branch excludes
the unrelated Vim editor commit. See [IYI-COMPILER-PR.md](IYI-COMPILER-PR.md) for
the complete PR description, reproduction and validation results.

The regression is fixed in the iyi compiler at commit `a03fc3438` in
`/home/priit/contribute/iyi`. The initial six Grant artifact consumers (model,
lifecycle, normalization, uniqueness, dependencies and binary data) passed with
the fixed compiler. The gate has since expanded to locking, timestamps, touch,
exact scalars, dynamic validation, around callbacks and belongs-to writes. The
minimal reproduction also passes. With the compound-reference regression below,
all 126 compiler artifact tests pass, including a generic forwarding body and a
trait-valued field. An older installed iyi binary still needs this fix.

The compiler now records producer witnesses that affect trait ABI even when no
carried instruction numbers them, and restores those witnesses in the consumer
before typing its bodies. Treating them only as an unmatchable type ID was
insufficient. Keep the artifact gate in `scripts/check.sh`. Set `IYI` to the
fixed compiler executable when running it; the installed default is not assumed
to have this unpublished local fix.

## Reproduction

Run `sh scripts/reproduce-artifact-layout.sh`. To use the current compiler
checkout, run:

```sh
IYI=/home/priit/contribute/iyi/bin/iyi sh scripts/reproduce-artifact-layout.sh
```

The script copies only native Grant source to a disposable producer project,
emits artifacts, and compiles a separate consumer using those artifacts. Both
programs open SQLite and execute `UnitOfWork.run { 42_i64 }`. The source program
prints `transaction completed`; the consumer must print the same and exit zero.

## Historical observations before the fix

- Installed iyi 0.16.2 refuses the model consumer because it cannot name
  `IyiDefTypeWitness_Grant_Database_Database` referenced by an artifact.
- The local compiler checkout (Crystal build `9f9f22af9`, 2026-10-10) accepts
  the missing witness as a phantom type but the resulting consumer exits 139.
- A temporary signal handler installed after runtime initialization obtained
  a stack showing `Connection#in_transaction?`, `Grant::Transaction`, and
  `UnitOfWork#run`. Debugger tracing itself is prohibited in this sandbox.
- Adding a fully typed consumer function accepting `Database` causes definition
  typing to recreate the synthetic witness; the minimal consumer then passes.
  This is diagnostic evidence, not an application workaround.

The producer's synthetic struct implements `Database` and participates in the
trait field representation. The consumer without that witness reconstructs a
different representation for `UnitOfWork.@database`; a call passing that field
to transaction code consequently supplies an invalid connection pointer.
Treating a missing witness only as a type ID that cannot match does not preserve
this layout. The fix preserves artifact field and call ABI across
definition-typing witnesses, including generic bodies recompiled by consumers.

The earlier core artifact check passed before the expanded transaction-session
path. This issue does not mean source builds have full Crystal behavior parity.
Live PostgreSQL behavior and the remaining ORM features are still pending.

## Ternary error-propagation export syntax

The belongs-to writer exposed a separate artifact AST-printing problem: a
ternary branch containing error propagation (`condition ? operation! : nil`)
was emitted as `condition ? __temp = operation`, which is not valid syntax in
that expression position. This is not the trait-field ABI regression above.
The native implementation uses explicit `if` branches for these operations.
The same source-free belongs-to consumer then compiles and executes. No
synthetic witnesses or source imports were added to consumers.

## Compound witness references in schema migration artifacts

The new schema migration consumer exposed another reference-resolution boundary.
At base commit `a03fc3438`, import was rejected with:

```text
"grant/migrations" matches against (Grant::Adapters::Sqlite::Connection | IyiDefTypeWitness_Grant_Database_Database), and this build cannot name it
```

The compiler was resolving match-only compound references during its initial
top-level pass, before restoring definition witnesses. The earlier layout fix
handled direct witness IDs but not witnesses nested in a union or generic type.
The local compiler now gathers these names from carried references, restores the
needed witnesses and strictly resolves deferred match references after consumer
typing. A missing real union member is still rejected; a whole union must not
be replaced by an unmatchable phantom.

The patch is preserved at `scripts/compiler-witness-union.patch` and applied in
`/home/priit/contribute/iyi` on top of `a03fc3438`; it is currently a local working
tree change. The regression fails without the patch and passes with it, covering
union and generic references and rejection of a missing ordinary type. All 126
compiler artifact specs pass. The rebuilt canonical compiler also passes all
twenty-two Grant artifact test consumers and the generated schema factory consumer.
The installed default executable is not assumed to contain these local fixes.

Schema editing also exposed error-propagation AST export limitations: indexed
assignments containing `operation!` could emit invalid source, and conditions
such as `if operation!.nil?` could lose the condition's intended evaluation.
The native scanner/rebuild code uses explicit local result assignments before
index writes, conditions and interpolation. Both source and artifact programs
exercise identical schema data and constraints. No synthetic witness declarations
or source imports are added to application consumers.
