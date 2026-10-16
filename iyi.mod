module github.com/domify/grant

require github.com/iyilang/db v0.1.1 as db
require github.com/iyilang/sqlite v0.0.0-20261015191849-b0d89d58a814 as sqlite
require github.com/iyilang/pg v0.0.0-20261015182941-6e9e50d7fef4 as pg

replace github.com/iyilang/db => ../iyis/db
replace github.com/iyilang/sqlite => ../iyis/sqlite
replace github.com/iyilang/pg => ../iyis/pg
