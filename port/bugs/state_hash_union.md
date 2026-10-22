# Union-valued Hash equality

Run from the checkout with the required compiler and cache:

```sh
IYI_CACHE_DIR=$PWD/.ris-cache /home/priit/contribute/ris/bin/ris run port/bugs/state_hash_union.ri
```

Expected: three true values. Actual: false, true, true.

Two independently allocated hashes with identical String keys and scalar union values compare
unequal, although their corresponding values compare equal. Attribute introspection tests retain
the complete hash assertions by checking size, key membership and each value explicitly.
