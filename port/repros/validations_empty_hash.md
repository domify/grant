# Empty hash equality

`IYI_CACHE_DIR=$PWD/.iyi-cache /home/priit/contribute/iyi/bin/iyi run
port/repros/validations_empty_hash.iyi` panics on equal empty hashes. The errors API translation
compares their complete string representations until native Hash equality is available.
