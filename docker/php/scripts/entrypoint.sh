#!/bin/bash
set -e

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

# Wait for MySQL to be ready
wait_for_mysql() {
    log_info "Waiting for MySQL to be ready..."
    while ! php -r "new mysqli('db', '${MYSQL_USER}', '${MYSQL_PASSWORD}', '${MYSQL_DATABASE}');" 2>/dev/null; do
        log_info "MySQL is not ready yet. Waiting..."
        sleep 5
    done
    log_info "MySQL is ready!"
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
        *)
            # Default to latest stable
            echo "MOODLE_405_STABLE"
            ;;
    esac
}

# Download Moodle
download_moodle() {
    if [ -f /var/www/html/version.php ]; then
        log_info "Moodle already downloaded. Skipping..."
        return
    fi
    
    local branch=$(get_moodle_branch "${MOODLE_VERSION}")
    log_info "Downloading Moodle version ${MOODLE_VERSION} (branch: ${branch})..."
    
    cd /var/www/html
    
    # Clone Moodle from GitHub
    git clone --depth 1 --branch ${branch} https://github.com/moodle/moodle.git .
    
    # Set proper permissions
    chown -R moodle:moodle /var/www/html
    chmod -R 755 /var/www/html
    
    log_info "Moodle downloaded successfully!"
}

# Configure Moodle
configure_moodle() {
    if [ -f /var/www/html/config.php ]; then
        log_info "Moodle config already exists. Skipping configuration..."
        return
    fi
    
    log_info "Configuring Moodle..."
    
    # Determine wwwroot based on SSL setting
    if [ "${ENABLE_SSL}" = "true" ]; then
        WWWROOT="https://${DOMAIN}"
        SSLPROXY="true"
    else
        WWWROOT="http://${DOMAIN}"
        SSLPROXY="false"
    fi
    
    # Copy and configure config.php
    cp /tmp/config.php.template /var/www/html/config.php
    
    sed -i "s|%%MYSQL_DATABASE%%|${MYSQL_DATABASE}|g" /var/www/html/config.php
    sed -i "s|%%MYSQL_USER%%|${MYSQL_USER}|g" /var/www/html/config.php
    sed -i "s|%%MYSQL_PASSWORD%%|${MYSQL_PASSWORD}|g" /var/www/html/config.php
    sed -i "s|%%WWWROOT%%|${WWWROOT}|g" /var/www/html/config.php
    sed -i "s|%%SSLPROXY%%|${SSLPROXY}|g" /var/www/html/config.php
    
    chown moodle:moodle /var/www/html/config.php
    chmod 644 /var/www/html/config.php
    
    log_info "Moodle configuration complete!"
}

# Install Moodle via CLI
install_moodle() {
    # Check if Moodle is already installed by checking for existing tables
    if php -r "
        \$conn = new mysqli('db', '${MYSQL_USER}', '${MYSQL_PASSWORD}', '${MYSQL_DATABASE}');
        \$result = \$conn->query('SHOW TABLES LIKE \"mdl_config\"');
        exit(\$result->num_rows > 0 ? 0 : 1);
    " 2>/dev/null; then
        log_info "Moodle already installed. Skipping installation..."
        return
    fi
    
    log_info "Installing Moodle..."
    
    # Determine wwwroot based on SSL setting
    if [ "${ENABLE_SSL}" = "true" ]; then
        WWWROOT="https://${DOMAIN}"
    else
        WWWROOT="http://${DOMAIN}"
    fi
    
    # Run Moodle CLI installer
    php /var/www/html/admin/cli/install.php \
        --non-interactive \
        --lang=en \
        --wwwroot="${WWWROOT}" \
        --dataroot=/var/www/moodledata \
        --dbtype=mysqli \
        --dbhost=db \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --fullname="${MOODLE_SITE_FULLNAME}" \
        --shortname="${MOODLE_SITE_SHORTNAME}" \
        --adminuser="${MOODLE_ADMIN_USER}" \
        --adminpass="${MOODLE_ADMIN_PASSWORD}" \
        --adminemail="${MOODLE_ADMIN_EMAIL}" \
        --agree-license
    
    log_info "Moodle installation complete!"
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

# Main execution
main() {
    log_info "Starting Moodle container..."
    
    setup_moodledata
    wait_for_mysql
    download_moodle
    configure_moodle
    install_moodle
    
    log_info "Moodle is ready!"
    
    # Execute the main command (php-fpm)
    exec "$@"
}

main "$@"
