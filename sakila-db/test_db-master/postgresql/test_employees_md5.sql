--  Test employees database integrity using MD5 checksums
--  PostgreSQL version

\connect employees

SELECT 'TESTING INSTALLATION' AS info;

DROP TABLE IF EXISTS expected_values, found_values;
CREATE TABLE expected_values (
    table_name VARCHAR(30) NOT NULL PRIMARY KEY,
    recs INT NOT NULL,
    crc_sha VARCHAR(100) NOT NULL,
    crc_md5 VARCHAR(100) NOT NULL
);


CREATE TABLE found_values (LIKE expected_values);

INSERT INTO expected_values VALUES
('employees',   300024,'4d4aa689914d8fd41db7e45c2168e7dcb9697359',
                        '4ec56ab5ba37218d187cf6ab09ce1aa1'),
('departments',      9,'4b315afa0e35ca6649df897b958345bcb3d2b764',
                       'd1af5e170d2d1591d776d5638d71fc5f'),
('dept_manager',    24,'9687a7d6f93ca8847388a42a6d8d93982a841c6c',
                       '8720e2f0853ac9096b689c14664f847e'),
('dept_emp',    331603, 'd95ab9fe07df0865f592574b3b33b9c741d9fd1b',
                       'ccf6fe516f990bdaa49713fc478701b7'),
('titles',      443308,'d12d5f746b88f07e69b9e36675b6067abb01b60e',
                       'bfa016c472df68e70a03facafa1bc0a8'),
('salaries',   2844047,'b5a1785c27d75e33a4173aaa22ccf41ebd7d4a9f',
                       'fd220654e95aea1b169624ffe3fca934');
SELECT table_name, recs AS expected_records, crc_md5 AS expected_crc FROM expected_values;

-- Helper function: computes incremental MD5 over rows returned by query.
-- The query must return a single column named "row_text".
-- This replicates MySQL's @crc := MD5(CONCAT_WS('#', @crc, col1, col2, ...))
-- by using crc := md5(crc || '#' || row_text) for each row.
CREATE OR REPLACE FUNCTION compute_table_md5(p_query TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    crc TEXT := '';
    r RECORD;
BEGIN
    FOR r IN EXECUTE p_query LOOP
        crc := md5(crc || '#' || r.row_text);
    END LOOP;
    RETURN crc;
END;
$$;

-- Compute checksums for each table
INSERT INTO found_values VALUES
('employees',
    (SELECT COUNT(*) FROM employees),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', emp_no, birth_date, first_name, last_name, gender, hire_date) AS row_text FROM employees ORDER BY emp_no$$)),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', emp_no, birth_date, first_name, last_name, gender, hire_date) AS row_text FROM employees ORDER BY emp_no$$))),

('departments',
    (SELECT COUNT(*) FROM departments),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', dept_no, dept_name) AS row_text FROM departments ORDER BY dept_no$$)),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', dept_no, dept_name) AS row_text FROM departments ORDER BY dept_no$$))),

('dept_manager',
    (SELECT COUNT(*) FROM dept_manager),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', dept_no, emp_no, from_date, to_date) AS row_text FROM dept_manager ORDER BY dept_no, emp_no$$)),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', dept_no, emp_no, from_date, to_date) AS row_text FROM dept_manager ORDER BY dept_no, emp_no$$))),

('dept_emp',
    (SELECT COUNT(*) FROM dept_emp),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', dept_no, emp_no, from_date, to_date) AS row_text FROM dept_emp ORDER BY dept_no, emp_no$$)),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', dept_no, emp_no, from_date, to_date) AS row_text FROM dept_emp ORDER BY dept_no, emp_no$$))),

('titles',
    (SELECT COUNT(*) FROM titles),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', emp_no, title, from_date, to_date) AS row_text FROM titles ORDER BY emp_no, title, from_date$$)),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', emp_no, title, from_date, to_date) AS row_text FROM titles ORDER BY emp_no, title, from_date$$))),

('salaries',
    (SELECT COUNT(*) FROM salaries),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', emp_no, salary, from_date, to_date) AS row_text FROM salaries ORDER BY emp_no, from_date, to_date$$)),
    (SELECT compute_table_md5($$SELECT CONCAT_WS('#', emp_no, salary, from_date, to_date) AS row_text FROM salaries ORDER BY emp_no, from_date, to_date$$)));

SELECT table_name, recs AS found_records, crc_md5 AS found_crc FROM found_values;

SELECT
    e.table_name,
    CASE WHEN e.recs=f.recs THEN 'OK' ELSE 'not ok' END AS records_match,
    CASE WHEN e.crc_md5=f.crc_md5 THEN 'ok' ELSE 'not ok' END AS crc_match
FROM
    expected_values e INNER JOIN found_values f USING (table_name);

SELECT 'CRC' AS summary,
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM expected_values e JOIN found_values f ON e.table_name=f.table_name WHERE f.crc_md5 != e.crc_md5
    ) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
SELECT 'count',
    CASE WHEN NOT EXISTS (
        SELECT 1 FROM expected_values e JOIN found_values f ON e.table_name=f.table_name WHERE f.recs != e.recs
    ) THEN 'OK' ELSE 'FAIL' END;

DROP FUNCTION compute_table_md5(TEXT);
DROP TABLE expected_values, found_values;
