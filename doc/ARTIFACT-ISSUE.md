# Source-free artifact consumption: trait field layout

The expanded native Grant currently passes source execution but fails the
source-free artifact consumer gate. Do not publish these artifacts as a working
package or remove the gate from `scripts/check.sh`.

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

## Observations on 2026-10-12

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
this layout. The compiler must preserve artifact field and call ABI across
definition-typing witnesses, including generic bodies recompiled by consumers.

The earlier core artifact check passed before the expanded transaction-session
path. This issue does not mean source builds have full Crystal behavior parity.
Live PostgreSQL behavior and the remaining ORM features are still pending.
