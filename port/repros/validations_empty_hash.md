# Empty hash equality

`IYI_CACHE_DIR=$PWD/.ris-cache /home/priit/contribute/ris/bin/ris run
port/repros/validations_empty_hash.ri` panics on equal empty hashes. The errors API translation
compares their complete string representations until native Hash equality is available.
