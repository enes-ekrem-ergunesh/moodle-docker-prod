#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[CRON]${NC} $1"
}

# Wait for Moodle to be installed
wait_for_moodle() {
    log_info "Waiting for Moodle to be installed..."
    
    while [ ! -f /var/www/html/config.php ]; do
        log_info "Moodle not configured yet. Waiting..."
        sleep 10
    done
    
    # Wait a bit more for installation to complete
    sleep 30
    
    log_info "Moodle config found!"
}

# Run cron job
run_cron() {
    log_info "Starting Moodle cron..."
    
    while true; do
        log_info "Running Moodle cron task at $(date)"
        php /var/www/html/admin/cli/cron.php || true
        
        # Run every minute
        sleep 60
    done
}

# Main execution
main() {
    wait_for_moodle
    run_cron
}

main
