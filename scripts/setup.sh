#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo "=========================================="
echo "     Moodle Docker Setup Script"
echo "=========================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    log_warn ".env file not found. Creating from template..."
    cp .env.example .env
    log_info "Created .env file. Please edit it with your settings."
    echo ""
    echo "Required settings to configure:"
    echo "  - MOODLE_VERSION"
    echo "  - DOMAIN"
    echo "  - CERTBOT_EMAIL"
    echo "  - MOODLE_PORT"
    echo "  - MYSQL_ROOT_PASSWORD"
    echo "  - MYSQL_PASSWORD"
    echo "  - MOODLE_ADMIN_PASSWORD"
    echo ""
    exit 1
fi

# Load environment variables
source .env

log_step "Validating configuration..."

is_true_or_false() {
    case "${1:-}" in
        true|false|TRUE|FALSE|1|0|yes|no|on|off|YES|NO|ON|OFF)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate Moodle version
MOODLE_MAJOR_VERSION=$(echo $MOODLE_VERSION | cut -d. -f1)
if [ "$MOODLE_MAJOR_VERSION" -lt 4 ]; then
    log_error "Moodle version must be 4 or higher. You specified: $MOODLE_VERSION"
    exit 1
fi

# Validate domain
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "moodle.example.com" ]; then
    log_error "Please set a valid DOMAIN in .env file"
    exit 1
fi

# Validate restore mode flag
if ! is_true_or_false "${RESTORE_FROM_BACKUP:-false}"; then
    log_error "RESTORE_FROM_BACKUP must be true/false (or 1/0, yes/no)"
    exit 1
fi

log_info "Configuration validated!"
log_info "  Moodle Version: $MOODLE_VERSION"
log_info "  Domain: $DOMAIN"
log_info "  Moodle Port: ${MOODLE_PORT:-8080}"
log_info "  MySQL Port: ${MYSQL_PORT:-3306}"
log_info "  SSL Enabled: ${ENABLE_SSL:-true}"
log_info "  Restore From Backup: ${RESTORE_FROM_BACKUP:-false}"

echo ""
log_step "Building Docker images..."

docker compose build

echo ""
log_step "Starting all services..."

docker compose up -d

echo ""
log_info "=========================================="
log_info "     Moodle Docker Setup Complete!"
log_info "=========================================="
echo ""
log_info "Moodle container is running on port: ${MOODLE_PORT:-8080}"
echo ""
log_info "NEXT STEP: Set up host nginx with SSL by running:"
log_info "  sudo ./scripts/setup-host-nginx.sh"
echo ""
log_info "Note: Initial setup may take several minutes as Moodle downloads and installs."
log_info "You can check the progress with: docker compose logs -f moodle"
echo ""
log_info "Admin credentials:"
log_info "  Username: ${MOODLE_ADMIN_USER:-admin}"
log_info "  Password: (as configured in .env)"
echo ""
log_info "Useful commands:"
log_info "  View logs:     docker compose logs -f"
log_info "  Stop:          docker compose down"
log_info "  Restart:       docker compose restart"
log_info "  Run cron:      docker compose exec moodle php /var/www/html/admin/cli/cron.php"
