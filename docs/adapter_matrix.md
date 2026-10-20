# Adapter matrix

SQLite and PostgreSQL capabilities at the reference versions below.
Refresh the table with `GRANT_WRITE_ADAPTER_MATRIX=1` and the targeted native test.
MySQL is adapter-out-of-scope for the native port.

<!-- capabilities:start -->
| Predicate | PostgreSQL 17 | SQLite 3.45 | Version gates |
| --- | --- | --- | --- |
| `supports_insert_returning?` | yes | yes | SQLite 3.35 |
| `supports_insert_on_duplicate_skip?` | yes | yes |  |
| `supports_insert_on_duplicate_update?` | yes | yes |  |
| `supports_ddl_transactions?` | yes | yes |  |
| `supports_partial_index?` | yes | yes |  |
| `supports_expression_index?` | yes | yes |  |
| `supports_check_constraints?` | yes | yes |  |
| `supports_foreign_keys?` | yes | yes |  |
| `supports_views?` | yes | yes |  |
| `supports_datetime_with_precision?` | yes | yes |  |
| `supports_json?` | yes | yes | SQLite 3.38 |
| `supports_common_table_expressions?` | yes | yes |  |
| `supports_virtual_columns?` | yes | yes | PostgreSQL 12; SQLite 3.31 |
| `supports_comments?` | yes | no |  |
| `supports_explain?` | yes | yes |  |
| `supports_optimizer_hints?` | no | no |  |
| `supports_advisory_locks?` | yes | no |  |
| `supports_bulk_alter?` | yes | no |  |
| `supports_concurrent_connections?` | yes | yes | SQLite: file databases only |
| `supports_restart_db_transaction?` | yes | no |  |
| `supports_disable_referential_integrity?` | yes | yes |  |
| `supports_nulls_not_distinct?` | yes | no | PostgreSQL 15 |
<!-- capabilities:end -->
