--  Additional objects for employees database
--  PostgreSQL version (PL/pgSQL)

\connect employees

DROP FUNCTION IF EXISTS emp_dept_id(INT);
DROP FUNCTION IF EXISTS emp_dept_name(INT);
DROP FUNCTION IF EXISTS emp_name(INT);
DROP FUNCTION IF EXISTS current_manager(CHAR(4));
DROP FUNCTION IF EXISTS employees_usage();
DROP FUNCTION IF EXISTS show_departments();
DROP PROCEDURE IF EXISTS employees_help();

--
-- returns the department id of a given employee
--
CREATE OR REPLACE FUNCTION emp_dept_id(employee_id INT)
RETURNS CHAR(4)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    max_date DATE;
    result CHAR(4);
BEGIN
    SELECT MAX(from_date) INTO max_date
    FROM dept_emp
    WHERE emp_no = employee_id;

    SELECT dept_no INTO result
    FROM dept_emp
    WHERE emp_no = employee_id AND from_date = max_date
    LIMIT 1;

    RETURN result;
END;
$$;

--
-- returns the department name of a given employee
--
CREATE OR REPLACE FUNCTION emp_dept_name(employee_id INT)
RETURNS VARCHAR(40)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT dept_name
        FROM departments
        WHERE dept_no = emp_dept_id(employee_id)
    );
END;
$$;

--
-- returns the employee name of a given employee id
--
CREATE OR REPLACE FUNCTION emp_name(employee_id INT)
RETURNS VARCHAR(32)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT concat(first_name, ' ', last_name) AS name
        FROM employees
        WHERE emp_no = employee_id
    );
END;
$$;

--
-- returns the manager of a department
-- choosing the most recent one
-- from the manager list
--
CREATE OR REPLACE FUNCTION current_manager(dept_id CHAR(4))
RETURNS VARCHAR(32)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    max_date DATE;
    result VARCHAR(32);
BEGIN
    SELECT MAX(from_date) INTO max_date
    FROM dept_manager
    WHERE dept_no = dept_id;

    SELECT emp_name(emp_no) INTO result
    FROM dept_manager
    WHERE dept_no = dept_id AND from_date = max_date
    LIMIT 1;

    RETURN result;
END;
$$;

--
--  selects the employee records with the
--  latest department
--
CREATE OR REPLACE VIEW v_full_employees
AS
SELECT
    emp_no,
    first_name, last_name,
    birth_date, gender,
    hire_date,
    emp_dept_name(emp_no) AS department
FROM
    employees;

--
-- selects the department list with manager names
--
CREATE OR REPLACE VIEW v_full_departments
AS
SELECT
    dept_no, dept_name, current_manager(dept_no) AS manager
FROM
    departments;

--
-- shows the departments with the number of employees
-- per department
--
CREATE OR REPLACE FUNCTION show_departments()
RETURNS TABLE(dept_no CHAR(4), dept_name VARCHAR(40), manager VARCHAR(32), count BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS department_max_date;
    DROP TABLE IF EXISTS department_people;

    CREATE TEMPORARY TABLE department_max_date
    (
        emp_no INT NOT NULL PRIMARY KEY,
        dept_from_date DATE NOT NULL,
        dept_to_date DATE NOT NULL
    );

    INSERT INTO department_max_date
    SELECT
        de.emp_no, MAX(de.from_date), MAX(de.to_date)
    FROM
        dept_emp de
    GROUP BY
        de.emp_no;

    CREATE TEMPORARY TABLE department_people
    (
        emp_no INT NOT NULL,
        dept_no CHAR(4) NOT NULL,
        PRIMARY KEY (emp_no, dept_no)
    );

    INSERT INTO department_people
    SELECT dmd.emp_no, de.dept_no
    FROM
        department_max_date dmd
        INNER JOIN dept_emp de
            ON dmd.dept_from_date=de.from_date
            AND dmd.dept_to_date=de.to_date
            AND dmd.emp_no=de.emp_no;

    RETURN QUERY
    SELECT
        v.dept_no, v.dept_name, v.manager::VARCHAR(32), COUNT(*)::BIGINT
    FROM v_full_departments v
        INNER JOIN department_people dp ON v.dept_no = dp.dept_no
    GROUP BY v.dept_no, v.dept_name, v.manager;

    DROP TABLE department_max_date;
    DROP TABLE department_people;
END;
$$;

CREATE OR REPLACE FUNCTION employees_usage()
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN '
    == USAGE ==
    ====================

    FUNCTION show_departments()

        shows the departments with the manager and
        number of employees per department
        (returns TABLE - use: SELECT * FROM show_departments();)

    FUNCTION current_manager (dept_id)

        Shows who is the manager of a given department

    FUNCTION emp_name (emp_id)

        Shows name and surname of a given employee

    FUNCTION emp_dept_id (emp_id)

        Shows the current department of given employee
';
END;
$$;

CREATE OR REPLACE PROCEDURE employees_help()
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT employees_usage() AS info;
END;
$$;
