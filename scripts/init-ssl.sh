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

# Check if .env file exists
if [ ! -f .env ]; then
    log_error ".env file not found!"
    log_info "Please copy .env.example to .env and fill in your values:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "moodle.example.com" ]; then
    log_error "Please set a valid DOMAIN in .env file"
    exit 1
fi

if [ -z "$CERTBOT_EMAIL" ] || [ "$CERTBOT_EMAIL" = "admin@example.com" ]; then
    log_error "Please set a valid CERTBOT_EMAIL in .env file"
    exit 1
fi

log_step "Initializing SSL certificates for domain: $DOMAIN"

# Create required directories
mkdir -p ./certbot/conf
mkdir -p ./certbot/www

# Check if certificates already exist
if [ -d "./certbot/conf/live/$DOMAIN" ]; then
    log_warn "Certificates already exist for $DOMAIN"
    read -p "Do you want to regenerate them? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Keeping existing certificates"
        exit 0
    fi
fi

log_step "Creating dummy certificate for nginx startup..."

# Create a dummy certificate so nginx can start
mkdir -p "./certbot/conf/live/moodle"

docker run --rm \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    alpine sh -c "
        apk add --no-cache openssl && \
        mkdir -p /etc/letsencrypt/live/moodle && \
        openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
            -keyout '/etc/letsencrypt/live/moodle/privkey.pem' \
            -out '/etc/letsencrypt/live/moodle/fullchain.pem' \
            -subj '/CN=localhost'
    "

log_step "Starting nginx..."

# Start nginx with the dummy certificate
docker compose up -d nginx

log_step "Waiting for nginx to start..."
sleep 5

log_step "Removing dummy certificate..."

docker run --rm \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    alpine sh -c "rm -rf /etc/letsencrypt/live/moodle/*"

log_step "Requesting Let's Encrypt certificate..."

# Request the actual certificate
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN" \
    --cert-name moodle

log_step "Reloading nginx with new certificate..."

docker compose exec nginx nginx -s reload

log_info "SSL certificate successfully obtained for $DOMAIN!"
log_info ""
log_info "Certificate will auto-renew via the certbot container."
log_info "You can now start your Moodle with: docker compose up -d"
