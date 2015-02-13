#!/bin/bash

# Example script to split full table updates into chunks with a vacuum inbetween
# to try and avoid table bloat.
# Sometimes it's better to create a new table and swap them, but when that's not possible
# due to other complications something like this may do.

## CREATE TABLE test(ax integer PRIMARY KEY, bx text);
## INSERT INTO test SELECT i, 'SOME TEXT ' || i FROM generate_series(1,1000000) i;

psql_prefix="/usr/local/pgsql/bin"
user="pgcontrol"
database="SEE"
schema="public"
relation="test"
fields="bx"                             # Comma separated
values="'SOMETHING ELSE ' || ax"        # Comma separated
pk="ax"
skip_pk_vals="0"                        # Comma separated
chunks=50
sql="SELECT count(*)/$chunks FROM $schema.$relation WHERE $pk NOT IN ($skip_pk_vals) AND (($fields) IS NULL OR ($fields) <> ($values));"
chunk_size=`$psql_prefix/psql -U $user -d $database -tAc "$sql"`

echo "CHUNK SIZE $chunk_size"

for i in `seq 1 $(($chunks-1))`; do
        echo "CHUNK $i)"
        offset=$((($i-1)*$chunk_size))

        sql="$(cat <<-EOF
                UPDATE $schema.$relation a
                SET ($fields) = ($values)
                FROM (SELECT ctid FROM $schema.$relation WHERE $pk NOT IN ($skip_pk_vals) AND (($fields) IS NULL OR ($fields) <> ($values)) ORDER BY ctid LIMIT $chunk_size) b
                WHERE a.ctid = b.ctid
                AND (($fields) IS NULL OR ($fields) <> ($values));
EOF
        )"
        echo $sql
        result=`$psql_prefix/psql -U $user -d $database -c "$sql"`
        echo $result

        sql="VACUUM $schema.$relation;"
        echo $sql
        result=`$psql_prefix/psql -U $user -d $database -c "$sql"`
        echo $result
done

sql="UPDATE $schema.$relation SET ($fields) = ($values) WHERE ($fields) <> ($values);"
echo $sql
result=`$psql_prefix/psql -U $user -d $database -c "$sql"`
echo $result

sql="VACUUM ANALYZE $schema.$relation;"
echo $sql
result=`$psql_prefix/psql -U $user -d $database -c "$sql"`
echo $result

