#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_DIR="$(dirname "$SCRIPT_DIR")"
PSQL="${PSQL:-psql}"

echo "Creating database schema..."
"$PSQL" -f "$SCRIPT_DIR/employees.sql"

echo "LOADING departments"
sed 's/`//g' "$DUMP_DIR/load_departments.dump" | "$PSQL" -d employees -q

echo "LOADING employees"
sed 's/`//g' "$DUMP_DIR/load_employees.dump" | "$PSQL" -d employees -q

echo "LOADING dept_emp"
sed 's/`//g' "$DUMP_DIR/load_dept_emp.dump" | "$PSQL" -d employees -q

echo "LOADING dept_manager"
sed 's/`//g' "$DUMP_DIR/load_dept_manager.dump" | "$PSQL" -d employees -q

echo "LOADING titles"
sed 's/`//g' "$DUMP_DIR/load_titles.dump" | "$PSQL" -d employees -q

echo "LOADING salaries"
sed 's/`//g' "$DUMP_DIR/load_salaries1.dump" | "$PSQL" -d employees -q
sed 's/`//g' "$DUMP_DIR/load_salaries2.dump" | "$PSQL" -d employees -q
sed 's/`//g' "$DUMP_DIR/load_salaries3.dump" | "$PSQL" -d employees -q

echo "Done loading employees database."
