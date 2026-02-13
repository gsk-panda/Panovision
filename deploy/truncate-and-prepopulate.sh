#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PREPOPULATE_SCRIPT="${PREPOPULATE_SCRIPT:-$PROJECT_DIR/scripts/prepopulate.sql}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-panovision}"
DB_USER="${DB_USER:-postgres}"
PGPASSWORD="${PGPASSWORD:-}"

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Truncates database tables and runs the prepopulate script."
  echo ""
  echo "Options:"
  echo "  -s, --prepopulate PATH   Path to prepopulate script (default: scripts/prepopulate.sql)"
  echo "  -h, --host HOST          Database host (default: localhost)"
  echo "  -p, --port PORT          Database port (default: 5432)"
  echo "  -d, --database NAME      Database name (default: panovision)"
  echo "  -u, --user USER          Database user (default: postgres)"
  echo "  --help                   Show this help"
  echo ""
  echo "Environment variables: DB_HOST, DB_PORT, DB_NAME, DB_USER, PGPASSWORD, PREPOPULATE_SCRIPT"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--prepopulate) PREPOPULATE_SCRIPT="$2"; shift 2 ;;
    -h|--host)        DB_HOST="$2"; shift 2 ;;
    -p|--port)        DB_PORT="$2"; shift 2 ;;
    -d|--database)    DB_NAME="$2"; shift 2 ;;
    -u|--user)        DB_USER="$2"; shift 2 ;;
    --help)           usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ ! -f "$PREPOPULATE_SCRIPT" ]]; then
  echo "Error: Prepopulate script not found: $PREPOPULATE_SCRIPT"
  echo "Set PREPOPULATE_SCRIPT or use -s /path/to/script.sql"
  exit 1
fi

export PGPASSWORD
CONN="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

echo "Database: $DB_NAME @ $DB_HOST:$DB_PORT (user: $DB_USER)"
echo "Truncating tables..."

$CONN -c "
DO \$\$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
    EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' RESTART IDENTITY CASCADE';
  END LOOP;
END \$\$;
"

echo "Running prepopulate script: $PREPOPULATE_SCRIPT"
$CONN -f "$PREPOPULATE_SCRIPT"

echo "Done."
