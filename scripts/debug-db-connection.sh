#!/bin/bash
# Debug script to check and fix Moodle database configuration
# Run this from the project directory

echo "=========================================="
echo "  Moodle Database Connection Debug"
echo "=========================================="

# Load .env
source .env

echo ""
echo "Environment variables:"
echo "  MYSQL_HOST: ${MYSQL_HOST:-db}"
echo "  MYSQL_DATABASE: $MYSQL_DATABASE"
echo "  MYSQL_USER: $MYSQL_USER"
echo "  MYSQL_PASSWORD: [hidden]"
echo ""

# Check if moodle container exists
if docker compose ps moodle &>/dev/null; then
    echo "Checking current config.php in container..."
    
    # Stop the container first to prevent restarts
    echo "Stopping moodle container..."
    docker compose stop moodle
    
    # Get the config.php content
    echo ""
    echo "Current dbhost setting in config.php:"
    docker compose run --rm --entrypoint="" moodle cat /var/www/html/config.php 2>/dev/null | grep -A1 "dbhost"
    
    echo ""
    echo "To fix the config, choose an option:"
    echo "1. Delete config.php and let it regenerate (recommended)"
    echo "2. Manually update dbhost in config.php"
    echo ""
    read -p "Enter choice (1 or 2): " choice
    
    case $choice in
        1)
            echo "Removing config.php..."
            docker compose run --rm --entrypoint="" moodle rm -f /var/www/html/config.php
            echo "Config.php removed. Restarting container..."
            docker compose up -d moodle
            echo "Container restarted. Check logs with: docker compose logs -f moodle"
            ;;
        2)
            echo "Creating fix script..."
            docker compose run --rm --entrypoint="" moodle sh -c "
                sed -i \"s/\\\$CFG->dbhost.*=.*/\\\$CFG->dbhost    = 'db';/\" /var/www/html/config.php
            "
            echo "Config updated. Restarting container..."
            docker compose up -d moodle
            echo "Container restarted. Check logs with: docker compose logs -f moodle"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    echo "Moodle container not found. Run 'docker compose up -d' first."
fi
