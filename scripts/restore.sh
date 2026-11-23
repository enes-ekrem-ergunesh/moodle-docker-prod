#!/bin/bash
# Restore Moodle from ./restore, OVERWRITING the database, Moodle code and moodledata.
#
# Usage:
#   ./scripts/restore.sh                         # newest *.tar.gz in ./restore (or extracted layout)
#   ./scripts/restore.sh moodle-backup-X.tar.gz  # a specific archive in ./restore
#   ./scripts/restore.sh -y                      # skip the confirmation prompt
#   RESTORE_KEEP_CONFIG=true ./scripts/restore.sh  # keep the current config.php
set -euo pipefail

cd "$(dirname "$0")/.."

ASSUME_YES=false
FILE=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=true ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        -*) echo "Unknown option: $arg" >&2; exit 1 ;;
        *) FILE="$arg" ;;
    esac
done

if [ ! -d restore ] || [ -z "$(ls -A restore 2>/dev/null)" ]; then
    echo "[RESTORE] ./restore is empty. Copy a backup archive there first, e.g.:" >&2
    echo "          cp backup/moodle-backup-YYYYmmdd-HHMMSS.tar.gz restore/" >&2
    exit 1
fi

echo "=================================================================="
echo " This will ERASE the current Moodle database, code and moodledata"
echo " and replace them with the backup in ./restore${FILE:+/$FILE}."
echo "=================================================================="
if [ "$ASSUME_YES" != "true" ]; then
    read -r -p "Type 'restore' to continue: " answer
    [ "$answer" = "restore" ] || { echo "Aborted."; exit 1; }
fi

echo "[RESTORE] Stopping moodle, cron and nginx..."
docker compose stop moodle cron nginx

status=0
docker compose run --rm -e RESTORE_FILE="$FILE" restore || status=$?

echo "[RESTORE] Starting stack..."
docker compose up -d

if [ "$status" -ne 0 ]; then
    echo "[RESTORE] Restore FAILED (exit $status). Check the output above." >&2
    exit "$status"
fi
echo "[RESTORE] Done."
