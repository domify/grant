# Enum-valued Hash equality

The enum-options target exposed native Hash equality returning false for separately allocated
`Hash(String, EnoPost::Status)` values with identical keys and enum values. Both hashes contain
`draft => Draft`, `published => Published`, and `archived => Archived`; the member comparisons
succeed individually. This extends the previously recorded union-valued Hash equality problem.

The translated mapping assertion compares the complete mapping by size, key membership, and every
value. It retains the upstream assertion's meaning without relying on the faulty Hash operator.
The direct operator failure was observed under both adapters in the targeted fast gate.
