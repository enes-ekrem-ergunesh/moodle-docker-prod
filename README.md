# Moodle Docker Setup

A complete Docker-based installation of Moodle with Nginx, PHP-FPM, MySQL, and automatic SSL via Certbot.

## Features

- 🎓 **Moodle LMS** - Support for versions 4.0, 4.1, 4.2, 4.3, 4.4, 4.5, and 5.0+
- 🌐 **Nginx** - High-performance web server with optimized configuration
- 🐘 **PHP-FPM** - PHP 8.1 with all required Moodle extensions
- 🗄️ **MySQL 8.0** - Database with optimized settings
- 🔒 **Let's Encrypt SSL** - Automatic HTTPS with Certbot
- ⏰ **Cron** - Automated scheduled tasks
- 🐳 **Docker Compose** - Easy orchestration

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository (or copy the files)
cd omar-moodle-docker

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

# Database passwords (change these!)
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_PASSWORD=your_secure_moodle_password

# Moodle admin password
MOODLE_ADMIN_PASSWORD=YourSecure123!
```

### 3. Run Setup

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the setup script
./scripts/setup.sh
```

Or manually:

```bash
# Build containers
docker compose build

# Initialize SSL (for production with real domain)
./scripts/init-ssl.sh

# Start all services
docker compose up -d
```

### 4. Access Moodle

Wait a few minutes for the initial installation to complete, then access:

- **With SSL:** `https://your-domain.com`
- **Without SSL:** `http://your-domain.com`

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MOODLE_VERSION` | Moodle version to install | `4.5` |
| `DOMAIN` | Your domain name | (required) |
| `CERTBOT_EMAIL` | Email for Let's Encrypt | (required) |
| `ENABLE_SSL` | Enable HTTPS | `true` |
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
3. Replace nginx config:
   ```bash
   cp config/nginx/conf.d/default-nossl.conf.example config/nginx/conf.d/default.conf
   ```
4. Run `docker compose up -d`

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

```bash
docker run --rm -v omar-moodle-docker_moodledata:/data -v $(pwd):/backup alpine tar czf /backup/moodledata.tar.gz -C /data .
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
│           ├── default.conf              # HTTPS configuration
│           └── default-nossl.conf.example # HTTP-only (dev)
├── docker/
│   └── php/
│       ├── Dockerfile    # PHP-FPM image with Moodle
│       ├── config/
│       │   └── config.php.template  # Moodle config template
│       └── scripts/
│           ├── entrypoint.sh       # Container entrypoint
│           └── cron-entrypoint.sh  # Cron container entrypoint
└── scripts/
    ├── setup.sh          # Main setup script
    └── init-ssl.sh       # SSL initialization script
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

### SSL certificate issues

1. Ensure your domain points to your server
2. Ensure ports 80 and 443 are open
3. Re-run SSL initialization:
   ```bash
   ./scripts/init-ssl.sh
   ```

### Permission issues

Reset permissions:
```bash
docker compose exec moodle chown -R moodle:moodle /var/www/html /var/www/moodledata
```

## License

This Docker setup is provided as-is. Moodle is licensed under GPLv3.

## Support

For Moodle-specific issues, visit [Moodle.org](https://moodle.org/).
