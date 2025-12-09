ARG PHP_VERSION=8.1

FROM php:${PHP_VERSION}-fpm-alpine

# Build arguments
ARG MOODLE_VERSION=4.5
ARG PHP_MEMORY_LIMIT=512M
ARG PHP_UPLOAD_MAX_FILESIZE=256M
ARG PHP_POST_MAX_SIZE=256M
ARG PHP_MAX_EXECUTION_TIME=300
ARG TIMEZONE=UTC

# Environment variables
ENV MOODLE_VERSION=${MOODLE_VERSION}
ENV PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT}
ENV PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE}
ENV PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE}
ENV PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME}
ENV TZ=${TIMEZONE}

# Install system dependencies
RUN apk add --no-cache \
    # Basic utilities
    bash \
    curl \
    wget \
    git \
    unzip \
    tzdata \
    # For GD
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    # For intl
    icu-dev \
    # For zip
    libzip-dev \
    # For xml
    libxml2-dev \
    # For ldap
    openldap-dev \
    # For soap
    libxml2-dev \
    # For opcache
    linux-headers \
    # For cron
    busybox-suid \
    # For image processing
    ghostscript \
    graphviz \
    aspell \
    aspell-en

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        mysqli \
        pdo \
        pdo_mysql \
        opcache \
        zip \
        soap \
        exif \
        ldap \
        pcntl

# Install additional PHP extensions via PECL
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Configure PHP
RUN { \
    echo "memory_limit = ${PHP_MEMORY_LIMIT}"; \
    echo "upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}"; \
    echo "post_max_size = ${PHP_POST_MAX_SIZE}"; \
    echo "max_execution_time = ${PHP_MAX_EXECUTION_TIME}"; \
    echo "max_input_time = ${PHP_MAX_EXECUTION_TIME}"; \
    echo "max_input_vars = 5000"; \
    echo "date.timezone = ${TIMEZONE}"; \
    echo "opcache.enable = 1"; \
    echo "opcache.memory_consumption = 128"; \
    echo "opcache.max_accelerated_files = 10000"; \
    echo "opcache.revalidate_freq = 60"; \
    echo "opcache.use_cwd = 1"; \
    echo "opcache.validate_timestamps = 1"; \
    echo "opcache.save_comments = 1"; \
    echo "opcache.enable_file_override = 0"; \
    } > /usr/local/etc/php/conf.d/moodle.ini

# Configure PHP-FPM
RUN { \
    echo "[www]"; \
    echo "pm = dynamic"; \
    echo "pm.max_children = 50"; \
    echo "pm.start_servers = 5"; \
    echo "pm.min_spare_servers = 5"; \
    echo "pm.max_spare_servers = 35"; \
    echo "pm.max_requests = 500"; \
    } > /usr/local/etc/php-fpm.d/zz-moodle.conf

# Create moodle user and directories
RUN addgroup -g 1000 -S moodle \
    && adduser -u 1000 -S moodle -G moodle \
    && mkdir -p /var/www/html \
    && mkdir -p /var/www/moodledata \
    && chown -R moodle:moodle /var/www

# Copy configuration files
COPY config/config.php.template /tmp/config.php.template
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/cron-entrypoint.sh /usr/local/bin/cron-entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/cron-entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
