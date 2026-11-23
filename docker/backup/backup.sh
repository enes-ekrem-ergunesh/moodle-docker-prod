#!/bin/bash
# =============================================================
# Moodle one-shot backup
# -------------------------------------------------------------
# Runs once and exits. Produces a single archive in /backup:
#   moodle-backup-<timestamp>.tar.gz
#     ├── mysql.sql        (full dump of $MYSQL_DATABASE)
#     ├── moodle/          (Moodle code incl. config.php)
#     ├── moodledata/      (uploaded files, minus caches)
#     └── manifest.txt
#
# The layout matches what RESTORE_FROM_BACKUP and the restore
# container expect, so an archive can be dropped straight into
# ./restore.
# =============================================================
set -Eeuo pipefail

DB_HOST="${MYSQL_HOST:-db}"
DB_NAME="${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
DB_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
SRC_CODE="/source/moodle"
SRC_DATA="/source/moodledata"
OUT_DIR="/backup"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
NAME="moodle-backup-${TIMESTAMP}"
WORK_DIR="$(mktemp -d /tmp/backup.XXXXXX)"
STAGE="${WORK_DIR}/${NAME}"
ARCHIVE_TMP="${OUT_DIR}/.${NAME}.tar.gz.partial"
ARCHIVE="${OUT_DIR}/${NAME}.tar.gz"

log()  { echo "[BACKUP] $(date '+%F %T') $*"; }
fail() { echo "[BACKUP] ERROR: $*" >&2; exit 1; }

cleanup() {
    rm -rf "${WORK_DIR}"
    rm -f "${ARCHIVE_TMP}"
}
trap cleanup EXIT
trap 'fail "backup failed at line ${LINENO}"' ERR

export MYSQL_PWD="${DB_ROOT_PASSWORD}"

mkdir -p "${OUT_DIR}" "${STAGE}"

[ -f "${SRC_CODE}/version.php" ] || fail "Moodle code not found at ${SRC_CODE} (no version.php)"
[ -d "${SRC_DATA}" ]             || fail "moodledata not found at ${SRC_DATA}"

log "Waiting for MySQL at ${DB_HOST}..."
for i in $(seq 1 30); do
    if mysqladmin -h "${DB_HOST}" -u root ping --silent >/dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && fail "MySQL at ${DB_HOST} is not reachable"
    sleep 2
done

# --- Database --------------------------------------------------
log "Dumping database '${DB_NAME}'..."
mysqldump -h "${DB_HOST}" -u root \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    --events \
    --hex-blob \
    --no-tablespaces \
    --set-gtid-purged=OFF \
    --default-character-set=utf8mb4 \
    "${DB_NAME}" > "${STAGE}/mysql.sql"
grep -q 'Dump completed' "${STAGE}/mysql.sql" || fail "mysqldump output looks incomplete"
log "Database dump: $(du -h "${STAGE}/mysql.sql" | cut -f1)"

# --- Moodle code -----------------------------------------------
log "Copying Moodle code..."
mkdir -p "${STAGE}/moodle"
tar -C "${SRC_CODE}" -cf - . | tar -C "${STAGE}/moodle" -xf -

# --- moodledata (skip caches / temp / sessions, they are rebuilt) ---
log "Copying moodledata (excluding cache, localcache, temp, sessions, trashdir)..."
mkdir -p "${STAGE}/moodledata"
tar -C "${SRC_DATA}" \
    --exclude='./cache' \
    --exclude='./localcache' \
    --exclude='./temp' \
    --exclude='./sessions' \
    --exclude='./trashdir' \
    -cf - . | tar -C "${STAGE}/moodledata" -xf -

# --- Manifest --------------------------------------------------
MOODLE_RELEASE="$(sed -n "s/^\$release *= *'\([^']*\)'.*/\1/p" "${SRC_CODE}/version.php" | head -n1)"
MOODLE_RELEASE="${MOODLE_RELEASE:-unknown}"
cat > "${STAGE}/manifest.txt" <<EOF
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
database=${DB_NAME}
moodle_release=${MOODLE_RELEASE}
mysql_server=$(mysql -h "${DB_HOST}" -u root -N -e 'SELECT VERSION()')
EOF

# --- Archive ---------------------------------------------------
log "Creating archive..."
tar -C "${STAGE}" -czf "${ARCHIVE_TMP}" .
mv "${ARCHIVE_TMP}" "${ARCHIVE}"

if [ -n "${BACKUP_OWNER:-}" ]; then
    chown "${BACKUP_OWNER}" "${ARCHIVE}" || log "WARN: could not chown archive to ${BACKUP_OWNER}"
fi

log "Backup complete: ./backup/$(basename "${ARCHIVE}") ($(du -h "${ARCHIVE}" | cut -f1))"
