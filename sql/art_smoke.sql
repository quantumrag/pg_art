-- Minimal smoke test for ART extension: create, index, and basic scans
\pset format unaligned
\pset tuples_only on

CREATE EXTENSION art;

CREATE TABLE tx(i int4, t text);
INSERT INTO tx VALUES (1,'a'),(2,'b'),(3,'c');

CREATE INDEX ON tx USING art(i);
CREATE INDEX ON tx USING art(t);

-- equality on int4
SELECT count(*) FROM tx WHERE i = 2;

-- range on int4
SELECT array_agg(i ORDER BY i) FROM tx WHERE i >= 2;

-- equality on text
SELECT count(*) FROM tx WHERE t = 'b';
