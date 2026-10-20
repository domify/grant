# PostgreSQL pool-reaper max-age timing

Command (both adapters, TMPDIR under build):

```
TMPDIR=$PWD/build/tmp IYI_CACHE_DIR=$PWD/.iyi-cache \
  bin/port-check --fast test/grant_connection_pool_reaper_test.iyi
```

SQLite passes. PostgreSQL fails the original `reaper.sweep == 3` assertion in
`retires idle connections that outlived max_age`. The manifest remains todo.

The original example creates three simultaneous connections with a 250 ms maximum age. Native
PostgreSQL connection startup takes long enough that the first connection is already 278 ms old
when `hold_connections` releases it. It correctly closes on return, as required by the next
upstream example. The other two connections are 3 ms and 1 ms old on return. The initial sweep
closes zero, and the sweep after the original 300 ms sleep closes two instead of three.

Temporary diagnostics established those ages and were removed. The original 250 ms and 300 ms
values and every assertion are preserved. No assertion is skipped or weakened. This needs
review of native PostgreSQL startup performance or the timing gate's assumptions.

The port also fixes concurrent lazy database initialization: PostgreSQL startup yields, so
simultaneous first checkouts previously created separate pools. Initialization now serializes,
and pool growth counts pending connection opens toward its configured capacity.
