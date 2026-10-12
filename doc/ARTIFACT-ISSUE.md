# Artifact trait-field layout regression (resolved locally)

The regression is fixed in the iyi compiler at commit `a03fc3438` in
`/home/priit/contribute/iyi`. The fixed local compiler passes the six Grant artifact consumers (model,
lifecycle, normalization, uniqueness, dependencies and binary data) and the
minimal reproduction. All 125 compiler artifact tests
pass, including a regression exercising a generic forwarding body and a
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
