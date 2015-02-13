Test example
============
In reality we'd only be bothered with this on large tables

Create a test table:

```sql
TEST=# CREATE TABLE test(a integer PRIMARY KEY, b text);
CREATE TABLE
Time: 3.793 ms

TEST=# INSERT INTO test SELECT i, 'SOME TEXT ' || i FROM generate_series(1,1000000) i;
INSERT 0 1000000
Time: 11630.081 ms

TEST=# \dt+ test
                    List of relations
 Schema | Name | Type  |   Owner   | Size  | Description
--------+------+-------+-----------+-------+-------------
 public | test | table | pgcontrol | 50 MB |
(1 row)
```

Update half the table, and attempt a vacuum:
```sql
TEST=# UPDATE test SET b = 'SOMETHING ELSE ' || a WHERE a > 500000;
UPDATE 500001
Time: 7729.968 ms

TEST=# VACUUM TEST;
VACUUM
Time: 528.894 ms

TEST=# \dt+ test
                    List of relations
 Schema | Name | Type  |   Owner   | Size  | Description
--------+------+-------+-----------+-------+-------------
 public | test | table | pgcontrol | 78 MB |
(1 row)
```

We've got some bloat we can't remove easily.  If we use the function to split 
the update into chunks with intermediate vacuums we should have less bloat.

Reset our test table:

```sql
TEST=# TRUNCATE TABLE test;

TEST=# INSERT INTO test SELECT i, 'SOME TEXT ' || i FROM generate_series(1,1000000) i;
INSERT 0 1000000
Time: 11541.353 ms

TEST=#  \dt+ test
                    List of relations
 Schema | Name | Type  |   Owner   | Size  | Description
--------+------+-------+-----------+-------+-------------
 public | test | table | pgcontrol | 50 MB |
(1 row)
```

For vacuum to do it's work best we should not have a long running transaction
in the database containing the table, so best to switch to another database
before running our function:

```sql
TEST=# \c postgres
You are now connected to database "postgres"

postgres=# SELECT pg_chunk_update('public', 'test', 'b', E'\'SOMETHING ELSE \' || a', 'a > 500000', 200, 'dbname=TEST user=glyn');
NOTICE:  2012-02-25 12:36:18.155259: Starting update; chunks = 200 chunk_size = 2500
NOTICE:  Equiv' full SQL:
        UPDATE public.test SET (b)=('SOMETHING ELSE ' || a) WHERE a > 500000;
NOTICE:  2012-02-25 12:36:18.156007+00: Updating chunk 1 of 200 (elapsed time: 0.001303s est' remainig time: ?s)
NOTICE:  2012-02-25 12:36:20.159222+00: Chunk 1 status : UPDATE 2500 OK / VACUUM OK
NOTICE:  2012-02-25 12:36:20.159369+00: Updating chunk 2 of 200 (elapsed time: 2.004122s est' remainig time: 398.372727s)
NOTICE:  2012-02-25 12:36:22.061396+00: Chunk 2 status : UPDATE 2500 OK / VACUUM OK
NOTICE:  2012-02-25 12:36:22.061473+00: Updating chunk 3 of 200 (elapsed time: 3.906225s est' remainig time: 376.601544s)
NOTICE:  2012-02-25 12:36:23.968849+00: Chunk 3 status : UPDATE 2500 OK / VACUUM OK
NOTICE:  2012-02-25 12:36:23.968938+00: Updating chunk 4 of 200 (elapsed time: 5.813693s est' remainig time: 375.756421s)

<snip>

NOTICE:  2012-02-25 12:41:36.605952+00: Updating chunk 198 of 200 (elapsed time: 318.450704s est' remainig time: 5.009034s)
NOTICE:  2012-02-25 12:41:38.275669+00: Chunk 198 status : UPDATE 2500 OK / VACUUM OK
NOTICE:  2012-02-25 12:41:38.275774+00: Updating chunk 199 of 200 (elapsed time: 320.120526s est' remainig time: 3.339504s)
NOTICE:  2012-02-25 12:41:39.947854+00: Chunk 199 status : UPDATE 2500 OK / VACUUM OK
NOTICE:  2012-02-25 12:41:39.947938+00: Updating chunk 200 of 200 (elapsed time: 321.79269s est' remainig time: 1.672085s)
NOTICE:  2012-02-25 12:41:41.62008+00: Chunk 200 status : UPDATE 2500 OK / VACUUM OK
NOTICE:  2012-02-25 12:41:41.620295+00: Final update pass (elapsed time: 323.465235s est' remainig time: 0s)
NOTICE:  2012-02-25 12:41:42.520855+00: Chunk 201 status : UPDATE 0 OK / VACUUM OK
 pg_chunk_update
-----------------

(1 row)

Time: 324902.578 ms

postgres=# \c test

TEST=# \dt+ test
                  List of relations
 Schema | Name | Type  | Owner  | Size  | Description
--------+------+-------+--------+-------+-------------
 public | test | table | admins | 54 MB |
(1 row)

```

It took a lot longer but we'd have had less blocking, and we've got less bloat; vacuum did it's work.
