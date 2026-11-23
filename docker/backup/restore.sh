#!/bin/bash
# =============================================================
# Moodle one-shot restore
# -------------------------------------------------------------
# Reads a backup from /restore and OVERWRITES the current site:
#   - drops and recreates $MYSQL_DATABASE, then imports mysql.sql
#   - wipes the moodle code volume and replaces it
#   - wipes the moodledata volume and replaces it
#
# Accepted inputs in /restore (first match wins):
#   1. RESTORE_FILE=<name>  -> that archive in /restore
#   2. the newest *.tar.gz  in /restore
#   3. an extracted layout:  /restore/mysql.sql, /restore/moodle/, /restore/moodledata/
#
# Everything is validated BEFORE anything is deleted.
# Stop the moodle, cron and nginx containers before running this
# (scripts/restore.sh does that for you).
# =============================================================
set -Eeuo pipefail

DB_HOST="${MYSQL_HOST:-db}"
DB_NAME="${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
DB_USER="${MYSQL_USER:?MYSQL_USER is required}"
DB_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
IN_DIR="/restore"
DST_CODE="/target/moodle"
DST_DATA="/target/moodledata"
MOODLE_UID="${MOODLE_UID:-1000}"
MOODLE_GID="${MOODLE_GID:-1000}"

log()  { echo "[RESTORE] $(date '+%F %T') $*"; }
fail() { echo "[RESTORE] ERROR: $*" >&2; exit 1; }

is_true() {
    case "${1:-}" in true|TRUE|1|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac
}

WORK_DIR=""
cleanup() { [ -n "${WORK_DIR}" ] && rm -rf "${WORK_DIR}"; }
trap cleanup EXIT
trap 'fail "restore failed at line ${LINENO}"' ERR

export MYSQL_PWD="${DB_ROOT_PASSWORD}"

# --- Locate the backup -----------------------------------------
SRC=""
if [ -n "${RESTORE_FILE:-}" ]; then
    ARCHIVE="${IN_DIR}/$(basename "${RESTORE_FILE}")"
    [ -f "${ARCHIVE}" ] || fail "RESTORE_FILE=${RESTORE_FILE} not found in ./restore"
else
    ARCHIVE="$(find "${IN_DIR}" -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -n1 | cut -d' ' -f2- || true)"
fi

if [ -n "${ARCHIVE}" ]; then
    log "Using archive: ./restore/$(basename "${ARCHIVE}")"
    WORK_DIR="$(mktemp -d /tmp/restore.XXXXXX)"
    log "Extracting..."
    tar -C "${WORK_DIR}" -xzf "${ARCHIVE}"
    SRC="${WORK_DIR}"
    # Tolerate archives that wrap everything in one top-level folder.
    if [ ! -f "${SRC}/mysql.sql" ]; then
        inner="$(find "${SRC}" -mindepth 2 -maxdepth 2 -name mysql.sql -printf '%h\n' | head -n1)"
        [ -n "${inner}" ] && SRC="${inner}"
    fi
elif [ -f "${IN_DIR}/mysql.sql" ]; then
    log "Using extracted backup in ./restore"
    SRC="${IN_DIR}"
else
    fail "Nothing to restore. Put a moodle-backup-*.tar.gz (or mysql.sql + moodle/ + moodledata/) in ./restore"
fi

# --- Validate before touching anything -------------------------
[ -f "${SRC}/mysql.sql" ]          || fail "mysql.sql missing from backup"
[ -f "${SRC}/moodle/version.php" ] || fail "moodle/version.php missing from backup"
[ -d "${SRC}/moodledata" ]         || fail "moodledata/ missing from backup"
grep -q 'Dump completed' "${SRC}/mysql.sql" || fail "mysql.sql looks truncated (no 'Dump completed' footer)"

[ -f "${SRC}/manifest.txt" ] && { log "Backup manifest:"; sed 's/^/           /' "${SRC}/manifest.txt"; }

log "Waiting for MySQL at ${DB_HOST}..."
for i in $(seq 1 30); do
    if mysqladmin -h "${DB_HOST}" -u root ping --silent >/dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && fail "MySQL at ${DB_HOST} is not reachable"
    sleep 2
done

# Keep the current config.php if asked (useful when restoring a backup
# taken on another server with different DB credentials / wwwroot).
KEEP_CONFIG=""
if is_true "${RESTORE_KEEP_CONFIG:-false}" && [ -f "${DST_CODE}/config.php" ]; then
    KEEP_CONFIG="$(mktemp /tmp/config.php.XXXXXX)"
    cp -p "${DST_CODE}/config.php" "${KEEP_CONFIG}"
    log "RESTORE_KEEP_CONFIG=true: current config.php will be kept"
fi

log "All checks passed. Overwriting current site now."

# --- Database --------------------------------------------------
log "Recreating database '${DB_NAME}'..."
mysql -h "${DB_HOST}" -u root <<SQL
DROP DATABASE IF EXISTS \`${DB_NAME}\`;
CREATE DATABASE \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL

log "Importing mysql.sql ($(du -h "${SRC}/mysql.sql" | cut -f1))..."
mysql -h "${DB_HOST}" -u root --default-character-set=utf8mb4 "${DB_NAME}" < "${SRC}/mysql.sql"

# --- Moodle code -----------------------------------------------
log "Replacing Moodle code..."
find "${DST_CODE}" -mindepth 1 -delete
tar -C "${SRC}/moodle" -cf - . | tar -C "${DST_CODE}" -xf -
if [ -n "${KEEP_CONFIG}" ]; then
    cp -p "${KEEP_CONFIG}" "${DST_CODE}/config.php"
    rm -f "${KEEP_CONFIG}"
fi
chown -R "${MOODLE_UID}:${MOODLE_GID}" "${DST_CODE}"

# --- moodledata ------------------------------------------------
log "Replacing moodledata..."
find "${DST_DATA}" -mindepth 1 -delete
tar -C "${SRC}/moodledata" -cf - . | tar -C "${DST_DATA}" -xf -
mkdir -p "${DST_DATA}"/{cache,localcache,temp,sessions,filedir}
chown -R "${MOODLE_UID}:${MOODLE_GID}" "${DST_DATA}"
chmod -R u+rwX,g+rwX "${DST_DATA}"

log "Restore complete. Start the stack again: docker compose up -d"
