Native Hash equality compares two equal role maps as unequal. Reproduce from the repository:

    IYI_CACHE_DIR=$PWD/.ris-cache /home/priit/contribute/ris/bin/ris test \
      port/repros/connection_hash_equality.ri

Observed on 2026-10-17: assertion failure. The role-hash translation compares the complete map's
string representation, retaining both entries and their original order.
