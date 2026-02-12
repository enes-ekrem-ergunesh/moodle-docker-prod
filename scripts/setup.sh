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
    echo "  - PHP_VERSION"
    echo "  - MYSQL_VERSION"
    echo "  - DOMAIN"
    echo "  - CERTBOT_EMAIL"
    echo "  - MOODLE_PORT"
    echo "  - MYSQL_ROOT_PASSWORD"
    echo "  - MYSQL_PASSWORD"
    echo "  - MOODLE_ADMIN_PASSWORD"
    echo "  - RESTORE_MODE (set to 'true' if restoring from backup)"
    echo ""
    exit 1
fi

# Load environment variables
source .env

log_step "Validating configuration..."

# Validate Moodle version (support 3.x and 4.x+)
MOODLE_MAJOR_VERSION=$(echo $MOODLE_VERSION | cut -d. -f1)
if [ "$MOODLE_MAJOR_VERSION" -lt 3 ]; then
    log_error "Moodle version must be 3 or higher. You specified: $MOODLE_VERSION"
    exit 1
fi

# Validate domain
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "moodle.example.com" ]; then
    log_error "Please set a valid DOMAIN in .env file"
    exit 1
fi

# Check restore mode
RESTORE_MODE=${RESTORE_MODE:-false}
if [ "$RESTORE_MODE" = "true" ]; then
    log_info "RESTORE MODE: Enabled"
    
    # Create backup directories if they don't exist
    mkdir -p backup/moodle
    mkdir -p backup/moodledata
    mkdir -p backup/database
    
    # Check if backup files are present
    if [ ! -f backup/moodle/version.php ] && [ ! -d backup/moodle/lib ]; then
        log_warn "No Moodle code found in backup/moodle/"
        log_warn "Please copy your Moodle code folder contents to: backup/moodle/"
    fi
    
    if [ -z "$(ls -A backup/moodledata 2>/dev/null)" ]; then
        log_warn "No moodledata found in backup/moodledata/"
        log_warn "Please copy your moodledata folder contents to: backup/moodledata/"
    fi
    
    if [ -z "$(ls backup/database/*.sql 2>/dev/null)" ]; then
        log_warn "No SQL file found in backup/database/"
        log_warn "Please copy your database dump (.sql file) to: backup/database/"
        log_warn "The SQL file will be automatically imported on first startup."
    fi
fi

log_info "Configuration validated!"
log_info "  Moodle Version: $MOODLE_VERSION"
log_info "  PHP Version: ${PHP_VERSION:-7.4}"
log_info "  MySQL Version: ${MYSQL_VERSION:-5.7.33}"
log_info "  Domain: $DOMAIN"
log_info "  Moodle Port: ${MOODLE_PORT:-8080}"
log_info "  MySQL Port: ${MYSQL_PORT:-3306}"
log_info "  SSL Enabled: ${ENABLE_SSL:-true}"
log_info "  Restore Mode: ${RESTORE_MODE:-false}"

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
if [ "$RESTORE_MODE" = "true" ]; then
    log_info "RESTORE MODE: The container will use your backup files."
    log_info ""
    log_info "IMPORTANT: After first startup, you may need to:"
    log_info "  1. Update config.php with correct database credentials"
    log_info "  2. Update the wwwroot URL in config.php to match your domain"
    log_info "  3. Run: docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php"
    log_info ""
else
    log_info "NEXT STEP: Set up host nginx in this exact order:"
    log_info "  1) sudo ./scripts/01-setup-nginx-ssl.sh"
    log_info "  2) sudo ./scripts/02-configure-nginx-proxy.sh"
fi
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
