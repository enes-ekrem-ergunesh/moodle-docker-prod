#!/bin/bash
# Take a one-shot Moodle backup into ./backup
#
# Usage:
#   ./scripts/backup.sh                 # backup while site stays online
#   ./scripts/backup.sh --maintenance   # put Moodle in maintenance mode during backup
set -euo pipefail

cd "$(dirname "$0")/.."

MAINTENANCE=false
for arg in "$@"; do
    case "$arg" in
        --maintenance) MAINTENANCE=true ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

mkdir -p backup 2>/dev/null || true

maintenance() {
    docker compose exec -T -u moodle moodle php /var/www/html/admin/cli/maintenance.php "--$1" >/dev/null
}

if [ "$MAINTENANCE" = "true" ]; then
    echo "[BACKUP] Enabling maintenance mode..."
    maintenance enable
    trap 'echo "[BACKUP] Disabling maintenance mode..."; maintenance disable || true' EXIT
fi

docker compose run --rm -e BACKUP_OWNER="$(id -u):$(id -g)" backup
