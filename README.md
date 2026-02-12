# Moodle Docker Setup

A complete Docker-based installation of Moodle with Nginx, PHP-FPM, and MySQL. SSL is managed by the host server's nginx with Certbot. Supports both fresh installations and restoration from existing Moodle backups.

## Features

- 🎓 **Moodle LMS** - Support for versions 3.9, 3.10, 3.11, 4.0, 4.1, 4.2, 4.3, 4.4, 4.5, and 5.0+
- 🌐 **Nginx** - Internal container nginx proxied by host nginx
- 🐘 **PHP-FPM** - PHP 7.4 (for Moodle 3.x) or PHP 8.1 (for Moodle 4.x+)
- 🗄️ **MySQL** - 5.7 (for Moodle 3.x) or 8.0 (for Moodle 4.x+)
- 🔒 **SSL via Host Nginx** - Automatic HTTPS with Certbot on host server
- ⏰ **Cron** - Automated scheduled tasks
- 🐳 **Docker Compose** - Easy orchestration
- 📦 **Backup Restoration** - Easy restoration from existing Moodle backups

## Architecture

```
Internet → Host Nginx (SSL/443) → Docker Nginx (8080) → PHP-FPM → MySQL
```

- SSL termination happens at the host nginx level
- Docker containers expose Moodle on a configurable port (default: 8080)
- MySQL is exposed for debugging (default: 3306)

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repo-url>
cd moodle-docker-prod

# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

### 2. Configure Required Settings

Edit `.env` and set at minimum:

```env
# Moodle version (3.11 for legacy, 4.5 for latest)
MOODLE_VERSION=3.11

# PHP version (7.4 for Moodle 3.x, 8.1 for Moodle 4.x+)
PHP_VERSION=7.4

# MySQL version (5.7.33 for Moodle 3.x, 8.0 for Moodle 4.x+)
MYSQL_VERSION=5.7.33

# Your domain (must point to this server)
DOMAIN=moodle.yourdomain.com

# Email for SSL certificate
CERTBOT_EMAIL=your@email.com

# Port where Moodle will be exposed
MOODLE_PORT=8080

# Database passwords (change these!)
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_PASSWORD=your_secure_moodle_password

# Moodle admin password (min 8 chars, upper, lower, number, special char)
MOODLE_ADMIN_PASSWORD=YourSecure123!

# Set to 'true' if restoring from backup
RESTORE_MODE=true
```

### 3. Make Scripts Executable

```bash
chmod +x scripts/*.sh docker/php/scripts/*.sh
```

### 4. Start Docker Containers

```bash
./scripts/setup.sh
```

Or manually:

```bash
docker compose build
docker compose up -d
```

> ⚠️ **Important:** Starting Docker containers is **not enough** for domain access.  
> You must run the host nginx scripts in order (Step 5.1 then Step 5.2).

### 5. Set Up Host Nginx with SSL (Two-Step Process)

#### Step 1: Create Nginx Server Block and SSL Certificate

```bash
sudo ./scripts/01-setup-nginx-ssl.sh
```

**Important UFW Firewall Note:**
- This script temporarily disables UFW firewall for Certbot to work
- At the end, it re-enables UFW and you will see this prompt:
  ```
  Command may disrupt existing ssh connections. Proceed with operation (y|n)?
  ```
- **Type `y` and press `Enter`** to continue
- Your SSH connection will NOT be disrupted if UFW was properly configured before

#### Step 2: Configure Nginx as Reverse Proxy

After Step 1 completes successfully:

```bash
sudo ./scripts/02-configure-nginx-proxy.sh
```

This updates the nginx configuration to proxy requests to your Moodle Docker container.

It also sets forwarding headers to avoid common issues such as:
- `400 Bad Request` from missing/incorrect host forwarding
- HTTPS redirect loops behind Cloudflare or other proxies

### 6. Access Moodle

Wait a few minutes for the initial Moodle installation to complete, then access:

`https://your-domain.com`

Check installation progress with:
```bash
docker compose logs -f moodle
```

### 7. Final Verification Checklist (Do Not Skip)

Run these checks in order:

```bash
# 1) Containers are healthy
docker compose ps

# 2) Internal nginx config is valid
docker compose exec nginx nginx -t

# 3) Host nginx config is valid
sudo nginx -t

# 4) Host reverse proxy points to your configured MOODLE_PORT
curl -I -H "Host: your-domain.com" http://127.0.0.1:${MOODLE_PORT:-8080}/
```

Expected behavior for the curl check is a Moodle response (often `303 See Other` to your HTTPS domain).

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MOODLE_VERSION` | Moodle version to install | `3.11` |
| `PHP_VERSION` | PHP version | `7.4` |
| `MYSQL_VERSION` | MySQL version | `5.7.33` |
| `RESTORE_MODE` | Use backup restoration mode | `false` |
| `DOMAIN` | Your domain name | (required) |
| `CERTBOT_EMAIL` | Email for Let's Encrypt | (required) |
| `MOODLE_PORT` | Port to expose Moodle | `8080` |
| `MYSQL_PORT` | Port to expose MySQL | `3306` |
| `ENABLE_SSL` | Use https in Moodle URLs | `true` |
| `MYSQL_ROOT_PASSWORD` | MySQL root password | (required) |
| `MYSQL_DATABASE` | Database name | `moodle` |
| `MYSQL_USER` | Database user | `moodleuser` |
| `MYSQL_PASSWORD` | Database password | (required) |
| `MOODLE_ADMIN_USER` | Admin username | `admin` |
| `MOODLE_ADMIN_PASSWORD` | Admin password | (required) |
| `MOODLE_ADMIN_EMAIL` | Admin email | (required) |
| `MOODLE_SITE_FULLNAME` | Site full name | `My Moodle Site` |
| `MOODLE_SITE_SHORTNAME` | Site short name | `Moodle` |
| `PHP_MEMORY_LIMIT` | PHP memory limit | `512M` |
| `PHP_UPLOAD_MAX_FILESIZE` | Max upload size | `256M` |
| `PHP_POST_MAX_SIZE` | Max POST size | `256M` |
| `PHP_MAX_EXECUTION_TIME` | Max execution time | `300` |
| `TIMEZONE` | Server timezone | `UTC` |

### Supported Moodle Versions

| Version | Branch | PHP | MySQL |
|---------|--------|-----|-------|
| 5.0 | MOODLE_500_STABLE | 8.1+ | 8.0 |
| 4.5 | MOODLE_405_STABLE | 8.1+ | 8.0 |
| 4.4 | MOODLE_404_STABLE | 8.1+ | 8.0 |
| 4.3 | MOODLE_403_STABLE | 8.1+ | 8.0 |
| 4.2 | MOODLE_402_STABLE | 8.1+ | 8.0 |
| 4.1 | MOODLE_401_STABLE | 8.0+ | 8.0 |
| 4.0 | MOODLE_400_STABLE | 8.0+ | 8.0 |
| 3.11 | MOODLE_311_STABLE | 7.4 | 5.7 |
| 3.10 | MOODLE_310_STABLE | 7.4 | 5.7 |
| 3.9 | MOODLE_39_STABLE | 7.4 | 5.7 |

## Restoring from Backup

This section explains how to restore Moodle from an existing backup, which is useful for migrating an existing Moodle installation to Docker.

### Prerequisites

You need three backup components:
1. **Moodle code folder** - Your Moodle installation files (the PHP code)
2. **Moodledata folder** - Your Moodle data files (can be large, e.g., 61GB)
3. **Database SQL file** - An SQL dump of your Moodle database

### Step 1: Prepare the Backup Directories

The repository includes three backup directories:

```
backup/
├── moodle/       # Place your Moodle code files here
├── moodledata/   # Place your moodledata files here
└── database/     # Place your SQL dump file here
```

### Step 2: Copy Your Backup Files

```bash
# Copy Moodle code (adjust paths to your backup location)
cp -r /path/to/your/moodle/* backup/moodle/

# Copy moodledata (this may take a while for large directories)
cp -r /path/to/your/moodledata/* backup/moodledata/

# Copy database dump
cp /path/to/your/database_backup.sql backup/database/
```

**Important Notes:**
- The SQL file in `backup/database/` will be automatically imported on first MySQL container startup
- If you have multiple SQL files, only the first one (alphabetically) will be imported
- For large databases, the import may take several minutes

### Step 3: Configure Environment

Edit your `.env` file with the following settings for Moodle 3.11.5:

```env
# Moodle 3.11.5 compatible settings
MOODLE_VERSION=3.11
PHP_VERSION=7.4
MYSQL_VERSION=5.7.33

# Enable restore mode
RESTORE_MODE=true

# Use the same database credentials as your original installation
# or update config.php after startup
MYSQL_DATABASE=moodle
MYSQL_USER=moodleuser
MYSQL_PASSWORD=your_moodle_password
MYSQL_ROOT_PASSWORD=your_root_password

# Your new domain
DOMAIN=your-new-domain.com
```

### Step 4: Update config.php

Before starting, update the `config.php` file in your `backup/moodle/` directory:

```php
<?php
// Update these values to match your Docker setup

$CFG->dbhost    = 'db';              // Docker MySQL container name
$CFG->dbname    = 'moodle';          // Must match MYSQL_DATABASE in .env
$CFG->dbuser    = 'moodleuser';      // Must match MYSQL_USER in .env
$CFG->dbpass    = 'your_password';   // Must match MYSQL_PASSWORD in .env

// Update the site URL
$CFG->wwwroot   = 'https://your-new-domain.com';  // Your new domain

// Keep these paths as-is for Docker
$CFG->dataroot  = '/var/www/moodledata';
```

### Step 5: Start the Containers

```bash
# Make scripts executable
chmod +x scripts/*.sh docker/php/scripts/*.sh

# Run setup script
./scripts/setup.sh
```

Or manually:

```bash
docker compose build
docker compose up -d
```

### Step 5.1 (Recommended for very large SQL backups)

If your `database_backup.sql` is very large and import takes a long time, start only the database first.
This avoids repeated connection/error logs from `moodle` and `cron` while MySQL is still restoring.

```bash
# Start only database
docker compose up -d db

# Follow database restore/import logs until complete
docker compose logs -f db
```

How to tell restore is complete:
- You no longer see active SQL import output in `docker compose logs -f db`
- `docker compose ps` shows `db` as healthy
- Table count stops changing between checks

```bash
# Quick table-count check (run a few times)
docker compose exec db mysql -u root -p -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodle';"
```

Optional heuristic for very large restores:
- Run `docker system df -v` twice (with a short delay) and verify the MySQL volume is no longer growing rapidly.

When import is finished and database is healthy, start the remaining services:

```bash
docker compose up -d moodle nginx cron
```

Optional full bring-up after DB is ready:

```bash
docker compose up -d
```

### Step 6: Post-Restoration Steps

After the containers are running:

```bash
# Check container logs
docker compose logs -f moodle

# Clear Moodle caches
docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php

# Fix permissions if needed
docker compose exec moodle chown -R moodle:moodle /var/www/html /var/www/moodledata

# If you need to run any database upgrades
docker compose exec moodle php /var/www/html/admin/cli/upgrade.php
```

### Troubleshooting Restoration

**Database Import Issues:**
```bash
# Check if database was imported
docker compose exec db mysql -u root -p -e "SHOW TABLES FROM moodle;"

# Manually import if needed
docker compose exec -T db mysql -u root -p moodle < backup/database/your_backup.sql
```

For very large SQL files, prefer staged startup:
1. `docker compose up -d db`
2. Wait until restore finishes in `docker compose logs -f db`
3. Confirm `db` is healthy and table count is stable
4. `docker compose up -d moodle nginx cron`

**Permission Issues:**
```bash
# Fix moodledata permissions
docker compose exec moodle chmod -R 777 /var/www/moodledata
```

**Config Issues:**
```bash
# Access container to edit config
docker compose exec moodle bash
nano /var/www/html/config.php
```

## Local Development (No SSL)

For local development without SSL:

1. Set `ENABLE_SSL=false` in `.env`
2. Set `DOMAIN=localhost` or your local domain
3. Access directly via `http://localhost:8080`
4. Skip the nginx setup scripts

## Common Commands

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f moodle
docker compose logs -f nginx
docker compose logs -f db

# Restart all services
docker compose restart

# Stop all services
docker compose down

# Stop and remove all data (destructive!)
docker compose down -v

# Run Moodle cron manually
docker compose exec moodle php /var/www/html/admin/cli/cron.php

# Access Moodle container shell
docker compose exec moodle bash

# Access MySQL
docker compose exec db mysql -u root -p

# Connect to MySQL from host
mysql -h 127.0.0.1 -P 3306 -u moodleuser -p
```

## Upgrading Moodle

1. Update `MOODLE_VERSION` in `.env`
2. Rebuild and restart:
   ```bash
   docker compose down
   docker compose build --no-cache
   docker compose up -d
   ```
3. Run upgrade script:
   ```bash
   docker compose exec moodle php /var/www/html/admin/cli/upgrade.php
   ```

## Backup

### Database Backup

```bash
docker compose exec db mysqldump -u root -p moodle > backup.sql
```

### Moodle Data Backup

Since the project uses bind mounts, you can directly back up the directories:

```bash
# Backup moodledata
tar czf moodledata_backup.tar.gz -C backup/moodledata .

# Backup moodle code
tar czf moodle_backup.tar.gz -C backup/moodle .
```

## Directory Structure

```
.
├── .env.example           # Example environment variables
├── docker-compose.yml     # Docker Compose configuration
├── backup/                # Backup directories for restoration
│   ├── moodle/           # Place Moodle code files here
│   ├── moodledata/       # Place moodledata files here (can be 61GB+)
│   └── database/         # Place SQL dump file here
├── config/
│   ├── mysql/
│   │   └── my.cnf        # MySQL configuration (5.7 compatible)
│   └── nginx/
│       ├── nginx.conf    # Main Nginx configuration
│       └── conf.d/
│           └── default.conf  # Internal nginx config
├── docker/
│   └── php/
│       ├── Dockerfile    # PHP-FPM image (supports PHP 7.4 and 8.1)
│       ├── config/
│       │   └── config.php.template  # Moodle config template
│       └── scripts/
│           ├── entrypoint.sh       # Container entrypoint
│           └── cron-entrypoint.sh  # Cron container entrypoint
└── scripts/
    ├── setup.sh                    # Docker setup script
    ├── 01-setup-nginx-ssl.sh       # Step 1: Create nginx block + SSL
    └── 02-configure-nginx-proxy.sh # Step 2: Configure reverse proxy
```

## Troubleshooting

### I forgot to run host nginx scripts

This is the most common cause of deployment issues.

Run these commands in order:

```bash
sudo ./scripts/01-setup-nginx-ssl.sh
sudo ./scripts/02-configure-nginx-proxy.sh
```

Then reload/restart services if needed:

```bash
sudo systemctl reload nginx
docker compose up -d --force-recreate nginx
```

### 400 Bad Request from nginx

Usually caused by reverse-proxy header/host mismatch.

Checklist:
1. Verify host nginx proxy is active (Step 1 + Step 2 both completed).
2. Confirm your site DNS points to this server.
3. Validate configs:
   - `sudo nginx -t`
   - `docker compose exec nginx nginx -t`

Inspect logs:

```bash
sudo tail -n 100 /var/log/nginx/error.log
docker compose logs --tail=200 nginx
```

### HTTPS redirect loop (too many redirects)

If using Cloudflare, set SSL mode to **Full (strict)** (not Flexible).

Ensure host nginx forwards canonical HTTPS headers to Docker upstream (handled by Step 2 script):
- `Host` = your domain
- `X-Forwarded-Proto` = `https`
- `X-Forwarded-Port` = `443`

### Container won't start

Check logs:
```bash
docker compose logs moodle
```

### Database connection issues

Ensure MySQL is healthy:
```bash
docker compose ps
docker compose logs db
```

Test MySQL connection from host:
```bash
mysql -h 127.0.0.1 -P 3306 -u moodleuser -p
```

### SSL certificate issues

1. Ensure your domain points to your server
2. Ensure ports 80 and 443 are open
3. Re-run nginx setup in order:
   ```bash
   sudo ./scripts/01-setup-nginx-ssl.sh
   sudo ./scripts/02-configure-nginx-proxy.sh
   ```

### UFW Firewall Issues

If you accidentally blocked yourself out via UFW:
- Access your server via console (not SSH)
- Run: `sudo ufw allow ssh` or `sudo ufw allow 22`
- Then: `sudo ufw enable`

### Permission issues

Reset permissions:
```bash
docker compose exec moodle chown -R moodle:moodle /var/www/html /var/www/moodledata
```

## License

This Docker setup is provided as-is. Moodle is licensed under GPLv3.

## Support

For Moodle-specific issues, visit [Moodle.org](https://moodle.org/).
