FROM docker.io/library/composer:2.2 AS composer

FROM docker.io/library/php:7.2-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public \
    APACHE_RUN_DIR=/tmp/apache2 \
    APACHE_PID_FILE=/tmp/apache2/apache2.pid \
    APACHE_LOCK_DIR=/tmp/apache2 \
    APACHE_LOG_DIR=/tmp/apache2/logs \
    COMPOSER_ALLOW_SUPERUSER=1

# PHP 7.2 images are based on an EOL Debian release, so use Debian archive repositories.
RUN set -eux; \
    . /etc/os-release; \
    codename="${VERSION_CODENAME:-stretch}"; \
    printf 'deb http://archive.debian.org/debian %s main\n' "$codename" > /etc/apt/sources.list; \
    if [ "$codename" = "stretch" ]; then \
      printf 'deb http://archive.debian.org/debian-security stretch/updates main\n' >> /etc/apt/sources.list; \
    fi; \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git \
      unzip \
      libzip-dev \
      libicu-dev \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev; \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/; \
    docker-php-ext-install -j"$(nproc)" \
      pdo_mysql \
      mbstring \
      zip \
      gd \
      intl; \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN a2enmod rewrite \
    && sed -ri 's!Listen 80!Listen 8080!g' /etc/apache2/ports.conf \
    && sed -ri 's!<VirtualHost \*:80>!<VirtualHost *:8080>!g' /etc/apache2/sites-available/000-default.conf \
    && sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/000-default.conf \
    && printf '%s\n' \
      '<Directory /var/www/html/public>' \
      '    Options FollowSymLinks' \
      '    AllowOverride All' \
      '    Require all granted' \
      '</Directory>' \
      > /etc/apache2/conf-available/laravel.conf \
    && a2enconf laravel

WORKDIR /var/www/html

COPY perpus-laravel/ .

# The exercise explicitly asks for composer update. For a real production app,
# prefer committing a known-good composer.lock and using composer install.
RUN composer update \
      --no-dev \
      --prefer-dist \
      --no-interaction \
      --no-progress \
      --optimize-autoloader \
    && mkdir -p \
      storage/app/public \
      storage/framework/cache \
      storage/framework/sessions \
      storage/framework/views \
      storage/logs \
      bootstrap/cache \
      /tmp/apache2/logs \
    && chgrp -R 0 /var/www/html /tmp/apache2 \
    && chmod -R g=u /var/www/html /tmp/apache2

EXPOSE 8080

CMD ["apache2-foreground"]
