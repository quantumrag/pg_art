make clean

make PG_CONFIG_PATH="/Library/PostgreSQL/18/bin/pg_config" CPPFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)" LDFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)"

sudo make PG_CONFIG_PATH="/Library/PostgreSQL/18/bin/pg_config" CPPFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)" LDFLAGS="-isysroot $(xcrun --sdk macosx --show-sdk-path)" install

psql -U postgres -d postgres -c "DROP EXTENSION IF EXISTS art CASCADE; CREATE EXTENSION art;"
psql -U postgres -d postgres -c "CREATE INDEX ON t USING art (k);"
psql -U postgres -d postgres -c "EXPLAIN (COSTS off) SELECT * FROM t WHERE k = md5('123');"
