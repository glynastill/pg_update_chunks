pg_chunk_update
===============

Quick and dirty pl/pgsql function to split full / large table updates into 
chunks and perform intermediate vacuums.

Connects via dblink to perform individual transactions.

Arguments
---------

	pg_chunk_update(
		in_nspname		-- Schema containing the table
		in_relname		-- Table name
		in_fields		-- The field names to update comma separated *
		in_values		-- The values for the corresponding field names *
		in_where_clause		-- Any where clause for the update *
		in_chunks		-- Break the update into this many chunks
		in_conninfo		-- database conninfo to pass to dblink
	)

* Arguments for in_fields, in_values and in_where_clause are plain text and not 
sanitized in any way, so ensure tight permissions to prevent sql injection.

Usage
-----
For vacuum to do it's work best we should not have a long running transaction
in the database containing the table, so best to switch to another database:

```sql
TEST=# \c postgres
You are now connected to database "postgres"
postgres=# SELECT pg_chunk_update('public', 'test', 'b', E'\'SOMETHING ELSE \' || a', 'a > 500000', 200, 'dbname=TEST user=glyn');
```

