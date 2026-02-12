#!/usr/bin/env bash
set -euo pipefail

# ===========================================
# Step 2: Configure Nginx as Reverse Proxy
# ===========================================
# This script updates the nginx config to proxy requests to Moodle Docker container.
# Run this AFTER running 01-setup-nginx-ssl.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load configuration from .env file
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo "Error: .env file not found at $PROJECT_DIR/.env"
    echo "Please copy .env.example to .env and configure it."
    exit 1
fi

# Validate required variables
if [ -z "${DOMAIN:-}" ] || [ "$DOMAIN" = "moodle.example.com" ]; then
    echo "Error: Please set a valid DOMAIN in .env file"
    exit 1
fi

MOODLE_PORT="${MOODLE_PORT:-8080}"
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"

echo "=========================================="
echo "  Step 2: Configure Nginx Reverse Proxy"
echo "=========================================="
echo "Domain: $DOMAIN"
echo "Moodle Port: $MOODLE_PORT"
echo "Nginx Config: $NGINX_CONFIG"
echo "=========================================="
echo ""

# Check if nginx config exists
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Error: Nginx config not found at $NGINX_CONFIG"
    echo "Please run Step 1 first: sudo ./scripts/01-setup-nginx-ssl.sh"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Backup existing config
BACKUP_FILE="${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$NGINX_CONFIG" "$BACKUP_FILE"
echo "Backup created: $BACKUP_FILE"

# Create new location block content
LOCATION_BLOCK="        # Moodle reverse proxy configuration
        client_max_body_size 256M;

        location / {
                proxy_pass http://127.0.0.1:$MOODLE_PORT;
                proxy_http_version 1.1;
        # Use canonical host/proto to avoid redirect loops
        proxy_set_header Host $DOMAIN;
                proxy_set_header X-Real-IP \\\$remote_addr;
                proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $DOMAIN;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Ssl on;

                # Timeouts
                proxy_connect_timeout 300;
                proxy_send_timeout 300;
                proxy_read_timeout 300;
                send_timeout 300;

                # Buffering
                proxy_buffering on;
                proxy_buffer_size 128k;
                proxy_buffers 256 16k;
                proxy_busy_buffers_size 256k;
                proxy_redirect off;
        }"

# Use sed to replace the location block
# This handles both the original try_files and any existing proxy_pass configuration
echo "Updating nginx configuration..."

# Create a temporary file with the new config
python3 << EOF
import re

with open('$NGINX_CONFIG', 'r') as f:
    content = f.read()

# Pattern to match location / { ... } block (handles nested braces)
# We need to replace the entire location / block
pattern = r'(\s*location\s+/\s*\{[^}]*\})'

replacement = '''$LOCATION_BLOCK'''

# Find all server blocks and update the location in each
# Simple approach: replace try_files line pattern
new_content = re.sub(
    r'location\s*/\s*\{\s*try_files[^}]+\}',
    replacement.strip(),
    content
)

# If no try_files found, try replacing existing proxy_pass location
if new_content == content:
    new_content = re.sub(
        r'location\s*/\s*\{[^}]*proxy_pass[^}]+\}',
        replacement.strip(),
        content
    )

with open('$NGINX_CONFIG', 'w') as f:
    f.write(new_content)

print("Configuration updated successfully")
EOF

if ! grep -q "proxy_pass http://127.0.0.1:$MOODLE_PORT;" "$NGINX_CONFIG"; then
    echo "Error: Could not find expected proxy_pass after update."
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$NGINX_CONFIG"
    exit 1
fi

# Test nginx config
echo "Testing nginx configuration..."
if nginx -t; then
    echo "Nginx configuration is valid."
    
    # Reload nginx
    echo "Reloading nginx..."
    systemctl reload nginx
    
    echo ""
    echo "=========================================="
    echo "  Step 2 Complete!"
    echo "=========================================="
    echo ""
    echo "Nginx is now configured to proxy requests to Moodle."
    echo ""
    echo "Make sure your Moodle Docker containers are running:"
    echo "  cd $PROJECT_DIR && docker compose up -d"
    echo ""
    echo "Your Moodle site should be available at: https://$DOMAIN"
    echo ""
else
    echo "Error: Nginx configuration test failed!"
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$NGINX_CONFIG"
    echo "Backup restored. Please check the configuration manually."
    exit 1
fi
