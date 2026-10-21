# Native tuple-valued dirty Hash equality

In `grant_dirty_dirty_control_test.iyi`, `post.saved_changes.inspect` is exactly
`{"title" => {"a", "b"}}`, but comparing it to that literal returns false. Giving the
literal the exact `Hash(String, Tuple(F01Post::SavedValue, F01Post::SavedValue))` type
also returns false. Both SQLite and PostgreSQL runs reproduce this independently of the driver.

The translated assertions use `same_changes?`: equal sizes, every expected key present, and
both tuple members equal. This preserves full map equality, including unexpected keys, rather
than relying on formatting or checking only selected entries.
