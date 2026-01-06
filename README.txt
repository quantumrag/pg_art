make clean

make PG_CONFIG_PATH="/Library/PostgreSQL/18/bin/pg_config" CPPFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)" LDFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)"

sudo make PG_CONFIG_PATH="/Library/PostgreSQL/18/bin/pg_config" CPPFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)" LDFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)" install

# Testing Postgres access through ART extension
psql -U postgres -d postgres -c "DROP TABLE t_art;"
psql -U postgres -d postgres -c "DROP EXTENSION IF EXISTS art CASCADE; CREATE EXTENSION art;"
psql -U postgres -d postgres -c "CREATE TABLE t_art(k text, v int); INSERT INTO t_art SELECT md5(i::text), i FROM generate_series(1,10000000) i;"
psql -U postgres -d postgres -c "DROP INDEX IF EXISTS idx_t_art_k;"
psql -U postgres -d postgres -c "CREATE INDEX idx_t_art_k ON t_art USING art (k);"
time psql -U postgres -d postgres -c "EXPLAIN (COSTS off) SELECT * FROM t_art WHERE k = md5('10000');"

# Debug
# pg_dump -U postgres -t t_art postgres > healthy_postgres.sql
# psql -U postgres -d postgres -c "SELECT pg_relation_filepath(oid), relname FROM pg_class WHERE pg_relation_filepath(oid) LIKE '%/16759%';"

# Testing Postgres access through BTREE extension
psql -U postgres -d postgres -c "DROP TABLE t_btree;"
psql -U postgres -d postgres -c "CREATE TABLE t_btree(k text, v int); INSERT INTO t_btree SELECT md5(i::text), i FROM generate_series(1,10000000) i;"
psql -U postgres -d postgres -c "DROP INDEX IF EXISTS idx_t_btree_k;"
psql -U postgres -d postgres -c "CREATE INDEX idx_t_btree_k ON t_btree USING BTREE (k);"
time psql -U postgres -d postgres -c "EXPLAIN (COSTS off) SELECT * FROM t_btree WHERE k = md5('10000');"
