# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview

- PostgreSQL index access method implementing an Adaptive Radix Tree (ART). Disk-persistent design tailored for PG. Current functionality is focused on INSERT and SCAN; VACUUM callbacks exist but are currently stubbed.

Essential commands

- Build against the default pg_config on PATH
  - make
- Build against a specific PostgreSQL installation
  - PG_CONFIG_PATH=/path/to/pg_config make
- Install the shared library, SQL, and control files into the PostgreSQL installation
  - make install
- Clean build artifacts
  - make clean
- Create the extension in a database (after make install)
  - psql -d <db> -c "CREATE EXTENSION art;"
- Drop and recreate during development
  - psql -d <db> -c "DROP EXTENSION IF EXISTS art; CREATE EXTENSION art;"

Notes on tests and linting

- No regression test suite is configured (Makefile sets REGRESS empty; there is a single SQL file at sql/art.sql but no expected files). There is no linter/formatter configuration in the repo.

Quick smoke demo

- After installing the extension:
  - psql -d <db> -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS art;"
  - psql -d <db> -c "CREATE TABLE t(k text, v int); INSERT INTO t SELECT md5(i::text), i FROM generate_series(1,1000) i;"
  - psql -d <db> -c "CREATE INDEX ON t USING art (k);"
  - psql -d <db> -c "EXPLAIN (COSTS off) SELECT * FROM t WHERE k = md5('123');"

Configuration switches (GUCs)

- art.update_parent_iptr (bool, default true): keep parent pointers updated during writes.
- art.page_leaf_insert_treshold (real 0.0–1.0, default 0.8): free space threshold when appending to leaf pages.
- art.build_max_memory (int MB, default 4000, min 4, max 32000): memory limit for index builds; triggers page flushing and page-hash reuse when exceeded.
- Example per-session change: psql -d <db> -c "SET art.build_max_memory = 256;"

Repository layout and big-picture architecture

- Makefile: PGXS-based build. Respects PG_CONFIG_PATH (falls back to pg_config) to locate headers/paths. On macOS, auto-detects the SDK via xcrun and adds `-isysroot` to PG_CPPFLAGS when available.
- art.control and art--0.1.sql: Defines the extension and the art access method; registers operator classes for int4, int8, date, and text (text uses bttextcmp). Module is loaded from $libdir/art.
- art.h: Central types, GUC externs, and function declarations. Key on-disk layout concepts:
  - Block 0: metadata page; block 1: root node page item; block 2: initial leaf page.
  - ArtDataPageOpaqueData carries page flags (node/leaf), counts, and right-link; ArtMetaDataPageOpaqueData caches last internal/leaf block numbers and a small page cache.
  - Node kinds: NODE_4, NODE_16, NODE_48, NODE_256, and NODE_LEAF, with prefix compression (MAX_PREFIX_KEY_LEN = 8). Leaves inline key bytes and a variable list of ItemPointers.
- art.c: Module entry (_PG_init) defines GUCs. arthandler wires the AM callbacks (build, buildempty, insert, scan, vacuum, cost estimate, validate, options) into PostgreSQL. artoptions currently returns NULL.
- art_insert.c: Bulk build and tuple insert path.
  - During CREATE INDEX: initializes metadata, creates root (NODE_256) and initial leaf pages, scans heap with table_index_build_scan, and incrementally inserts keys.
  - Manages memory pressure via build_max_memory: flushes pages to disk, recreates a page-lookup hash, and resumes with cached block numbers.
  - Handles leaf updates/splits and node promotions (4→16→48→256) with parent pointer maintenance and page placement via _get_page_with_free_space; performs in-place overwrite when space permits, otherwise relocates and repairs parent links.
- art_scan.c: Index scan implementation.
  - Translates ScanKey to an ArtTuple and traverses nodes, enforcing prefix checks and range constraints using a pairing heap queue. Collects matching leaf ItemPointers and returns heap TIDs via artgettuple.
- art_pageops.c: Low-level page lifecycle utilities.
  - Initialize data/metadata pages, buffer management (load/copy/flush), free-space decisions, and right-link updates. Provides a small in-memory page cache structure for build-time operations. Flush path handles both buffered and raw writes, computing data checksums when enabled.
- art_utils.c: Helpers for node allocation/sizing, prefix operations, SIMD-assisted searches on NODE_16 where available (SSE2 on x86/x86_64), and child selection for equal/range probes with fallbacks on other architectures.
- art_cost.c: Uses genericcostestimate to populate planner costs.
- art_vacuum.c: VACUUM support hooks (artbulkdelete, artvacuumcleanup) currently return NULL (no-op).
- art_validate.c: Stubbed validator; currently returns false.

Development tips specific to this codebase

- If you have multiple PostgreSQL versions installed, prefer PG_CONFIG_PATH=/opt/pgsql/X.Y/bin/pg_config make to ensure headers and install paths match the running server.
- On macOS, ensure Command Line Tools are installed; the Makefile will auto-set an SDK sysroot when available.
- After make install, restart the backend processes (or at least restart your psql session) before exercising new C changes in an already-loaded module.

Contributing and testing

- Build, install, and run tests against a running Postgres instance:
  - make
  - make install
  - make installcheck
- To point at a specific Postgres install:
  - PG_CONFIG_PATH=/path/to/pg_config make installcheck
- If your server isn’t on the default socket/port, set PGHOST/PGPORT before running tests.
- Tests live in `sql/` with matching outputs in `expected/`. The Makefile’s `REGRESS` controls which tests run; add names there to include more cases.
- The included smoke test covers CREATE EXTENSION, indexing int4/text, equality, and simple range filtering.

Continuous Integration

- GitHub Actions workflow at `.github/workflows/ci.yml` builds against PostgreSQL 16 and 17 on Ubuntu and runs `make installcheck`.
- It installs `postgresql-<version>` and `postgresql-server-dev-<version>`, starts the service, then builds/installs the extension with `PG_CONFIG_PATH` set accordingly.
