# Integrate codegen cache directory disappears

`build/integrate.log:360` reports a PostgreSQL build failure for
`test/grant_persistence_w6_timestamps_test.ri` before its assertions execute:

```text
Error: a codegen thread failed: Error opening file with mode 'w':
.ris-cache/home-priit-contribute-grant-test-grant_persistence_w6_timestamps_test.ri/
P-ointer40U-I-nt841.o0.bc: No such file or directory (File::NotFoundError)
```

The same integrate run passes this target under SQLite. An unchanged targeted rerun passes
both adapters (2026-10-22):

```sh
TMPDIR=$PWD/build/tmp IYI_CACHE_DIR=$PWD/.ris-cache \
  bin/port-check --fast test/grant_persistence_w6_timestamps_test.ri
```

The integrate run uses eight parallel compiler processes and a shared `.ris-cache` root.
The missing output directory suggests cache cleanup during code generation; this is an inference,
not a reproduced root cause. The compiler cache implementation rotates build directories and
checks `compiler.lock` in `src/compiler/ris/codegen/cache_dir.cr`. Review that lifecycle and the
compiler version used by the gate. No assertion or gate implementation is changed, following
reviewer feedback item 7.
