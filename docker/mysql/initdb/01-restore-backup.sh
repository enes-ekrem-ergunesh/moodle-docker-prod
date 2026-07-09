#!/bin/sh
set -eu

safe_done() {
    return 0 2>/dev/null || exit 0
}

is_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if ! is_true "${RESTORE_FROM_BACKUP:-false}"; then
    echo "[INITDB] RESTORE_FROM_BACKUP=false; skipping backup DB import"
    safe_done
fi

find_sql_backup() {
    for candidate in \
        /backup/mysql.sql \
        /backup/db.sql \
        /backup/backup.sql
    do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    first_sql="$(find /backup -maxdepth 2 -type f -name '*.sql' | sort | head -n 1 || true)"
    if [ -n "$first_sql" ]; then
        echo "$first_sql"
        return 0
    fi

    return 1
}

SQL_FILE="$(find_sql_backup || true)"

if [ -z "${SQL_FILE}" ]; then
    echo "[INITDB] RESTORE_FROM_BACKUP=true but no SQL backup found under /backup"
    echo "[INITDB] Expected e.g. /backup/mysql.sql, /backup/db.sql, or any *.sql file"
    safe_done
fi

echo "[INITDB] Importing SQL backup: ${SQL_FILE}"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" < "${SQL_FILE}"
echo "[INITDB] SQL backup import completed"
safe_done
