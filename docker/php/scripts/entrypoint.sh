#!/bin/bash
# NOTE: No 'set -e' - we want the container to stay running even on errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Flag to track if setup completed successfully
SETUP_FAILED=false

# Wait for MySQL to be ready
wait_for_mysql() {
    log_info "Waiting for MySQL to be ready..."
    local max_attempts=60
    local attempt=1
    local db_host="${MYSQL_HOST:-db}"
    
    log_info "Database host: ${db_host}"
    log_info "Database name: ${MYSQL_DATABASE}"
    log_info "Database user: ${MYSQL_USER}"
    
    while [ $attempt -le $max_attempts ]; do
        # Try to connect and get detailed error
        local result=$(php -r "
            \$conn = @new mysqli('${db_host}', '${MYSQL_USER}', '${MYSQL_PASSWORD}', '${MYSQL_DATABASE}');
            if (\$conn->connect_error) {
                echo 'ERROR: ' . \$conn->connect_error;
                exit(1);
            }
            echo 'SUCCESS';
            \$conn->close();
            exit(0);
        " 2>&1)
        
        if [ $? -eq 0 ]; then
            log_info "MySQL is ready!"
            # Additional wait to ensure MySQL is fully stable
            sleep 5
            return 0
        fi
        
        log_info "MySQL not ready (attempt $attempt/$max_attempts): $result"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "MySQL did not become ready in time!"
    log_error "Last error: $result"
    SETUP_FAILED=true
    return 1
}

# Get the correct Moodle git branch based on version
get_moodle_branch() {
    local version=$1
    
    # Handle different version formats
    case $version in
        5|5.0)
            echo "MOODLE_500_STABLE"
            ;;
        4.5)
            echo "MOODLE_405_STABLE"
            ;;
        4.4)
            echo "MOODLE_404_STABLE"
            ;;
        4.3)
            echo "MOODLE_403_STABLE"
            ;;
        4.2)
            echo "MOODLE_402_STABLE"
            ;;
        4.1)
            echo "MOODLE_401_STABLE"
            ;;
        4|4.0)
            echo "MOODLE_400_STABLE"
            ;;
        3.11|3.11.*)
            echo "MOODLE_311_STABLE"
            ;;
        3.10|3.10.*)
            echo "MOODLE_310_STABLE"
            ;;
        3.9|3.9.*)
            echo "MOODLE_39_STABLE"
            ;;
        *)
            # Default to 3.11 stable for restore mode
            echo "MOODLE_311_STABLE"
            ;;
    esac
}

# Download Moodle
download_moodle() {
    if [ -f /var/www/html/version.php ]; then
        log_info "Moodle already downloaded. Skipping..."
        return 0
    fi
    
    local branch=$(get_moodle_branch "${MOODLE_VERSION}")
    log_info "Downloading Moodle version ${MOODLE_VERSION} (branch: ${branch})..."
    
    cd /var/www/html
    
    # Clone Moodle from GitHub
    if ! git clone --depth 1 --branch ${branch} https://github.com/moodle/moodle.git .; then
        log_error "Failed to download Moodle!"
        SETUP_FAILED=true
        return 1
    fi
    
    # Set proper permissions
    chown -R moodle:moodle /var/www/html
    chmod -R 755 /var/www/html
    
    log_info "Moodle downloaded successfully!"
    return 0
}

# Configure Moodle
configure_moodle() {
    if [ -f /var/www/html/config.php ]; then
        log_info "Moodle config already exists. Skipping configuration..."
        log_info "To regenerate config, delete /var/www/html/config.php and restart"
        return 0
    fi
    
    log_info "Configuring Moodle..."
    
    local db_host="${MYSQL_HOST:-db}"
    
    # Determine wwwroot based on SSL setting
    if [ "${ENABLE_SSL}" = "true" ]; then
        WWWROOT="https://${DOMAIN}"
        SSLPROXY="true"
    else
        WWWROOT="http://${DOMAIN}"
        SSLPROXY="false"
    fi
    
    log_info "Config values:"
    log_info "  DB Host: ${db_host}"
    log_info "  DB Name: ${MYSQL_DATABASE}"
    log_info "  DB User: ${MYSQL_USER}"
    log_info "  WWW Root: ${WWWROOT}"
    log_info "  SSL Proxy: ${SSLPROXY}"
    
    # Copy and configure config.php
    if [ ! -f /tmp/config.php.template ]; then
        log_error "Config template not found at /tmp/config.php.template!"
        SETUP_FAILED=true
        return 1
    fi
    
    cp /tmp/config.php.template /var/www/html/config.php
    
    # Escape special characters for sed replacement
    # & is special in sed (means "matched string"), \ and | also need escaping
    escape_for_sed() {
        printf '%s' "$1" | sed 's/[&/\]/\\&/g'
    }
    
    local escaped_password=$(escape_for_sed "${MYSQL_PASSWORD}")
    local escaped_db_host=$(escape_for_sed "${db_host}")
    local escaped_db_name=$(escape_for_sed "${MYSQL_DATABASE}")
    local escaped_db_user=$(escape_for_sed "${MYSQL_USER}")
    local escaped_wwwroot=$(escape_for_sed "${WWWROOT}")
    
    sed -i "s|%%MYSQL_HOST%%|${escaped_db_host}|g" /var/www/html/config.php
    sed -i "s|%%MYSQL_DATABASE%%|${escaped_db_name}|g" /var/www/html/config.php
    sed -i "s|%%MYSQL_USER%%|${escaped_db_user}|g" /var/www/html/config.php
    sed -i "s|%%MYSQL_PASSWORD%%|${escaped_password}|g" /var/www/html/config.php
    sed -i "s|%%WWWROOT%%|${escaped_wwwroot}|g" /var/www/html/config.php
    sed -i "s|%%SSLPROXY%%|${SSLPROXY}|g" /var/www/html/config.php
    
    chown moodle:moodle /var/www/html/config.php
    chmod 644 /var/www/html/config.php
    
    log_info "Moodle configuration complete!"
    return 0
}

# Install Moodle via CLI
install_moodle() {
    local db_host="${MYSQL_HOST:-db}"
    
    # Check if Moodle is already installed by checking for existing tables
    local check_result=$(php -r "
        \$conn = @new mysqli('${db_host}', '${MYSQL_USER}', '${MYSQL_PASSWORD}', '${MYSQL_DATABASE}');
        if (\$conn->connect_error) {
            echo 'CONNECTION_ERROR: ' . \$conn->connect_error;
            exit(2);
        }
        \$result = \$conn->query('SHOW TABLES LIKE \"mdl_config\"');
        if (\$result === false) {
            echo 'QUERY_ERROR: ' . \$conn->error;
            exit(2);
        }
        if (\$result->num_rows > 0) {
            echo 'INSTALLED';
            exit(0);
        }
        echo 'NOT_INSTALLED';
        exit(1);
    " 2>&1)
    local check_status=$?
    
    if [ $check_status -eq 0 ]; then
        log_info "Moodle already installed. Skipping installation..."
        return 0
    elif [ $check_status -eq 2 ]; then
        log_error "Database check failed: $check_result"
        log_warn "Skipping installation due to database error. Container will continue running."
        log_warn "You can exec into the container to debug: docker compose exec moodle bash"
        SETUP_FAILED=true
        return 1
    fi
    
    log_info "Installing Moodle..."
    
    # Determine wwwroot based on SSL setting
    if [ "${ENABLE_SSL}" = "true" ]; then
        WWWROOT="https://${DOMAIN}"
    else
        WWWROOT="http://${DOMAIN}"
    fi
    
    # Run Moodle CLI installer
    if php /var/www/html/admin/cli/install.php \
        --non-interactive \
        --lang=en \
        --wwwroot="${WWWROOT}" \
        --dataroot=/var/www/moodledata \
        --dbtype=mysqli \
        --dbhost="${db_host}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --fullname="${MOODLE_SITE_FULLNAME}" \
        --shortname="${MOODLE_SITE_SHORTNAME}" \
        --adminuser="${MOODLE_ADMIN_USER}" \
        --adminpass="${MOODLE_ADMIN_PASSWORD}" \
        --adminemail="${MOODLE_ADMIN_EMAIL}" \
        --agree-license; then
        log_info "Moodle installation complete!"
        return 0
    else
        log_error "Moodle installation failed!"
        log_warn "Container will continue running. You can exec into it to debug."
        log_warn "Run: docker compose exec moodle bash"
        SETUP_FAILED=true
        return 1
    fi
}

# Ensure moodledata directory is properly set up
setup_moodledata() {
    log_info "Setting up moodledata directory..."
    
    mkdir -p /var/www/moodledata
    mkdir -p /var/www/moodledata/temp
    mkdir -p /var/www/moodledata/cache
    mkdir -p /var/www/moodledata/localcache
    mkdir -p /var/www/moodledata/sessions
    mkdir -p /var/www/moodledata/filedir
    
    chown -R moodle:moodle /var/www/moodledata
    chmod -R 777 /var/www/moodledata
    
    log_info "moodledata directory ready!"
}

# Setup permissions for restored moodle directory
setup_moodle_permissions() {
    log_info "Setting up Moodle directory permissions..."
    
    if [ -d /var/www/html ]; then
        chown -R moodle:moodle /var/www/html
        chmod -R 755 /var/www/html
        log_info "Moodle directory permissions set!"
    fi
}

# Main execution
main() {
    log_info "Starting Moodle container..."
    log_info "Container will stay running even if setup fails, for debugging purposes."
    
    # Handle signals gracefully
    trap 'log_info "Received shutdown signal. Stopping php-fpm..."; kill -TERM $PHP_PID 2>/dev/null; exit 0' SIGTERM SIGINT SIGQUIT
    
    # Check for restore mode
    if [ "${RESTORE_MODE}" = "true" ]; then
        log_info "=========================================="
        log_info "RESTORE MODE ENABLED"
        log_info "=========================================="
        log_info "Using existing Moodle files from backup."
        log_info "Skipping Moodle download and installation."
        log_info ""
        
        # Setup steps for restore mode
        setup_moodledata
        setup_moodle_permissions
        wait_for_mysql
        
        # Only configure Moodle if config.php doesn't exist
        if [ ! -f /var/www/html/config.php ]; then
            log_warn "No config.php found! You may need to copy your existing config.php"
            log_warn "or edit the generated one after startup."
            configure_moodle
        else
            log_info "Using existing config.php from backup."
            log_info "Make sure database credentials in config.php match your .env settings!"
        fi
        
        log_info "=========================================="
        log_info "Moodle restore setup complete!"
        log_info "=========================================="
    else
        # Normal fresh installation mode
        setup_moodledata
        wait_for_mysql
        download_moodle
        configure_moodle
        install_moodle
        
        if [ "$SETUP_FAILED" = "true" ]; then
            log_warn "=========================================="
            log_warn "SETUP COMPLETED WITH ERRORS!"
            log_warn "=========================================="
            log_warn "Some setup steps failed. Check the logs above."
            log_warn ""
            log_warn "The container will continue running so you can debug."
            log_warn "You can exec into this container with:"
            log_warn "  docker compose exec moodle bash"
            log_warn ""
            log_warn "From inside, you can:"
            log_warn "  - Check database connection manually"
            log_warn "  - Edit /var/www/html/config.php"
            log_warn "  - Run Moodle CLI scripts"
            log_warn ""
            log_warn "Useful commands:"
            log_warn "  - Test DB: php -r \"new mysqli('db', '\$MYSQL_USER', '\$MYSQL_PASSWORD', '\$MYSQL_DATABASE');\""
            log_warn "  - Check config: cat /var/www/html/config.php"
            log_warn "=========================================="
        else
            log_info "=========================================="
            log_info "Moodle setup complete!"
            log_info "=========================================="
        fi
    fi
    
    log_info "Starting php-fpm..."
    
    # Start php-fpm in foreground mode
    # Use exec to replace shell process if no errors, otherwise run in background
    # so we can keep the container alive
    if [ "$SETUP_FAILED" = "true" ]; then
        # Run php-fpm in background and wait
        php-fpm -F &
        PHP_PID=$!
        log_info "php-fpm started with PID $PHP_PID"
        log_info "Container is running. You can exec into it to debug issues."
        
        # Wait for php-fpm to exit (or signals)
        wait $PHP_PID
        exit_code=$?
        log_info "php-fpm exited with code $exit_code"
        
        # If php-fpm dies, keep container running
        log_warn "php-fpm stopped. Keeping container alive for debugging..."
        log_warn "Run: docker compose exec moodle bash"
        
        # Sleep indefinitely to keep container running
        while true; do
            sleep 3600
        done
    else
        # Normal case: exec replaces this process with php-fpm
        exec "$@"
    fi
}

main "$@"
