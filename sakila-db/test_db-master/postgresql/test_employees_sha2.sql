--  Test employees database integrity using SHA-256 checksums
--  PostgreSQL version using pgcrypto extension

\connect employees

SELECT 'TESTING INSTALLATION' AS info;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS expected_values, found_values;
CREATE TABLE expected_values (
    table_name VARCHAR(30) NOT NULL PRIMARY KEY,
    recs INT NOT NULL,
    crc_sha2 VARCHAR(100) NOT NULL
);

CREATE TABLE found_values (LIKE expected_values);

-- Expected SHA-256 checksums (same values as MySQL's SHA2(..., 256))
INSERT INTO expected_values VALUES
('employees',   300024, '21f5d003842f24853e251d3d5116798bafe257ec3d1bb448b5365b68deaabbf4'),
('departments',      9, '377c5d727383a32633e2973f8e3411beffe29e2f4cc297c586fa6b24aa7df9ba'),
('dept_manager',    24, '3a4e69723deec413a7d8a4f5ce55013830303fa617b6380ed2b0fd2d48b1c768'),
('dept_emp',    331603, '34548ee9989dd4d5e065168b43249c8d3eb48bfbbfb3f2fc1cf01be6658f6a75'),
('titles',      443308, 'a9e940ef9ba1029a8f0356fdbe495430bedc59eec5ceb4f71e0cc35ddcbf9980'),
('salaries',   2844047, '4e99e691a9ea98fefc0b4fec8ca4e758baeefba2967bd8d6474810a9a5f6e729');
SELECT table_name, recs AS expected_records, crc_sha2 AS expected_crc FROM expected_values;

-- Helper function: computes incremental SHA-256 over rows returned by query.
-- The query must return a single column named "row_text".
-- This replicates MySQL's @crc := SHA2(CONCAT_WS('#', @crc, ...), 256)
-- by using crc := encode(digest(crc || '#' || row_text, 'sha256'), 'hex')
CREATE OR REPLACE FUNCTION compute_table_sha256(p_query TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    crc TEXT := '';
    r RECORD;
BEGIN
    FOR r IN EXECUTE p_query LOOP
        crc := encode(digest(crc || '#' || r.row_text, 'sha256'), 'hex');
    END LOOP;
    RETURN crc;
END;
$$;

-- Compute checksums for each table
INSERT INTO found_values VALUES
('employees',
    (SELECT COUNT(*) FROM employees),
    (SELECT compute_table_sha256($$SELECT CONCAT_WS('#', emp_no, birth_date, first_name, last_name, gender, hire_date) AS row_text FROM employees ORDER BY emp_no$$))),

('departments',
    (SELECT COUNT(*) FROM departments),
    (SELECT compute_table_sha256($$SELECT CONCAT_WS('#', dept_no, dept_name) AS row_text FROM departments ORDER BY dept_no$$))),

('dept_manager',
    (SELECT COUNT(*) FROM dept_manager),
    (SELECT compute_table_sha256($$SELECT CONCAT_WS('#', dept_no, emp_no, from_date, to_date) AS row_text FROM dept_manager ORDER BY dept_no, emp_no$$))),

('dept_emp',
    (SELECT COUNT(*) FROM dept_emp),
    (SELECT compute_table_sha256($$SELECT CONCAT_WS('#', dept_no, emp_no, from_date, to_date) AS row_text FROM dept_emp ORDER BY dept_no, emp_no$$))),

('titles',
    (SELECT COUNT(*) FROM titles),
    (SELECT compute_table_sha256($$SELECT CONCAT_WS('#', emp_no, title, from_date, to_date) AS row_text FROM titles ORDER BY emp_no, title, from_date$$))),

('salaries',
    (SELECT COUNT(*) FROM salaries),
    (SELECT compute_table_sha256($$SELECT CONCAT_WS('#', emp_no, salary, from_date, to_date) AS row_text FROM salaries ORDER BY emp_no, from_date, to_date$$)));

SELECT table_name, recs AS found_records, crc_sha2 AS found_crc FROM found_values;

SELECT
    e.table_name,
    CASE WHEN e.recs=f.recs THEN 'OK' ELSE 'not ok' END AS records_match,
    CASE WHEN e.crc_sha2=f.crc_sha2 THEN 'ok' ELSE 'not ok' END AS crc_match
FROM
    expected_values e INNER JOIN found_values f USING (table_name);

SELECT 'CRC' AS summary,
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM expected_values e JOIN found_values f ON e.table_name=f.table_name WHERE f.crc_sha2 != e.crc_sha2
    ) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
SELECT 'count',
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM expected_values e JOIN found_values f ON e.table_name=f.table_name WHERE f.recs != e.recs
    ) THEN 'OK' ELSE 'FAIL' END;

DROP FUNCTION compute_table_sha256(TEXT);
DROP TABLE expected_values, found_values;
