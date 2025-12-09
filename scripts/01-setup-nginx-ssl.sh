#!/usr/bin/env bash
set -euo pipefail

# ===========================================
# Step 1: Create Nginx Domain Block with SSL
# ===========================================
# This script creates an nginx server block and obtains SSL certificate via Certbot.
# Run this BEFORE running 02-configure-nginx-proxy.sh
#
# NOTE: This script will disable and re-enable UFW firewall.
# When UFW is being enabled, you will see a warning:
#   "Command may disrupt existing ssh connections. Proceed with operation (y|n)?"
# Type 'y' and press Enter to continue.

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

if [ -z "${CERTBOT_EMAIL:-}" ] || [ "$CERTBOT_EMAIL" = "admin@example.com" ]; then
    echo "Error: Please set a valid CERTBOT_EMAIL in .env file"
    exit 1
fi

echo "=========================================="
echo "  Step 1: Nginx Domain Block + SSL Setup"
echo "=========================================="
echo "Domain: $DOMAIN"
echo "Certbot Email: $CERTBOT_EMAIL"
echo "=========================================="
echo ""
echo "NOTE: This script will disable and re-enable UFW."
echo "When prompted about SSH connections, type 'y' and press Enter."
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# --- System updates ---
sudo apt update && sudo apt upgrade -y
sudo apt -o APT::Get::Always-Include-Phased-Updates=true full-upgrade -y

# --- Install nginx & certbot ---
sudo apt install -y nginx certbot python3-certbot-nginx

# --- Disable UFW temporarily ---
sudo ufw disable || true

# --- Create web root ---
sudo mkdir -p /var/www/$DOMAIN/html
sudo chown -R $USER:$USER /var/www/$DOMAIN/html
sudo chmod -R 755 /var/www/$DOMAIN

# --- Write HTML file ---
cat <<EOF | sudo tee /var/www/$DOMAIN/html/index.html > /dev/null
<html>
    <head>
        <title>Welcome to $DOMAIN!</title>
    </head>
    <body>
        <h1>Success! The $DOMAIN server block is working!</h1>
    </body>
</html>
EOF

# --- Write nginx config ---
cat <<EOF | sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null
server {
        listen 80;
        listen [::]:80;

        root /var/www/$DOMAIN/html;
        index index.html index.htm index.nginx-debian.html;

        server_name $DOMAIN;

        location / {
                try_files \$uri \$uri/ =404;
        }
}
EOF

# --- Enable site ---
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# --- Test and restart nginx ---
sudo nginx -t
sudo systemctl restart nginx

# --- Run certbot (non-interactive, no prompts) ---
sudo certbot --nginx -d $DOMAIN \
    --non-interactive --agree-tos --email $CERTBOT_EMAIL --redirect

# --- Re-enable UFW ---
echo ""
echo "=========================================="
echo "  Re-enabling UFW Firewall"
echo "=========================================="
echo "You will be prompted about SSH connections."
echo "Type 'y' and press Enter to continue."
echo ""
sudo ufw enable

echo ""
echo "=========================================="
echo "  Step 1 Complete!"
echo "=========================================="
echo ""
echo "Nginx server block created and SSL certificate obtained."
echo "You can verify by visiting: https://$DOMAIN"
echo ""
echo "NEXT: Run Step 2 to configure nginx as a reverse proxy:"
echo "  sudo ./scripts/02-configure-nginx-proxy.sh"
echo ""
