# Moodle Docker Setup

A complete Docker-based installation of Moodle with Nginx, PHP-FPM, and MySQL. SSL is managed by the host server's nginx with Certbot.

## Features

- 🎓 **Moodle LMS** - Support for versions 4.0, 4.1, 4.2, 4.3, 4.4, 4.5, and 5.0+
- 🌐 **Nginx** - Internal container nginx proxied by host nginx
- 🐘 **PHP-FPM** - PHP 8.1 with all required Moodle extensions
- 🗄️ **MySQL 8.0** - Database with optimized settings (port exposed for debugging)
- 🔒 **SSL via Host Nginx** - Automatic HTTPS with Certbot on host server
- ⏰ **Cron** - Automated scheduled tasks
- 🐳 **Docker Compose** - Easy orchestration

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
# Moodle version (4, 4.1, 4.2, 4.3, 4.4, 4.5, 5.0)
MOODLE_VERSION=4.5

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

# Install mode: false = fresh install, true = restore from ./backup
RESTORE_FROM_BACKUP=false
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

### 6. Access Moodle

Wait a few minutes for the initial Moodle installation to complete, then access:

`https://your-domain.com`

Check installation progress with:
```bash
docker compose logs -f moodle
```

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MOODLE_VERSION` | Moodle version to install | `4.5` |
| `RESTORE_FROM_BACKUP` | Restore from files in `./backup` (`true`/`false`) | `false` |
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

| Version | Branch |
|---------|--------|
| 5.0 | MOODLE_500_STABLE |
| 4.5 | MOODLE_405_STABLE |
| 4.4 | MOODLE_404_STABLE |
| 4.3 | MOODLE_403_STABLE |
| 4.2 | MOODLE_402_STABLE |
| 4.1 | MOODLE_401_STABLE |
| 4.0 | MOODLE_400_STABLE |

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

## Restore From Backup

To restore instead of running a fresh Moodle install:

1. Set `RESTORE_FROM_BACKUP=true` in `.env`
2. Place backup assets under `./backup`:
   - Moodle code: `./backup/moodle` (must contain `version.php`)
   - Moodle data: `./backup/moodledata`
   - Database dump: `./backup/mysql.sql` (or `db.sql`, `backup.sql`, or any `*.sql` in `./backup`)
3. Start the stack with `./scripts/setup.sh`

Behavior notes:
- `RESTORE_FROM_BACKUP=false` installs Moodle as a new site using CLI installer.
- `RESTORE_FROM_BACKUP=true` skips fresh install and expects DB tables from the SQL backup.

### Database Backup

```bash
docker compose exec db mysqldump -u root -p moodle > backup.sql
```

### Moodle Data Backup

```bash
docker run --rm -v moodle-docker-prod_moodledata:/data -v $(pwd):/backup alpine tar czf /backup/moodledata.tar.gz -C /data .
```

## Directory Structure

```
.
├── .env.example           # Example environment variables
├── docker-compose.yml     # Docker Compose configuration
├── config/
│   ├── mysql/
│   │   └── my.cnf        # MySQL configuration
│   └── nginx/
│       ├── nginx.conf    # Main Nginx configuration
│       └── conf.d/
│           └── default.conf  # Internal nginx config
├── docker/
│   └── php/
│       ├── Dockerfile    # PHP-FPM image with Moodle
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
3. Re-run nginx setup:
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
