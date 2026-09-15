# =========================================================
# Stage 1 - Composer
# =========================================================
FROM docker.io/library/composer:2 AS composer


# =========================================================
# Stage 2 - Frontend assets
# =========================================================
FROM docker.io/library/node:20-bookworm-slim AS frontend

WORKDIR /app

# Dependency frontend dipisah agar nanti bisa memanfaatkan cache layer
COPY laravel-8-ecommerce/package.json laravel-8-ecommerce/package-lock.json* ./

RUN if [ -f package-lock.json ]; then \
        npm ci; \
    else \
        npm install; \
    fi

# Laravel Mix perlu source/config frontend
COPY laravel-8-ecommerce .

RUN npm run production


# =========================================================
# Stage 3 - Laravel runtime
# =========================================================
FROM docker.io/library/php:8.0-cli AS runtime

# PHP 8.0 image lama menggunakan Debian Bullseye.
# bullseye-security sudah expired pada environment kita.
RUN sed -i '/bullseye-security/d' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libzip-dev \
        libonig-dev \
        unzip \
    && docker-php-ext-install -j"$(nproc)" \
        mbstring \
        zip \
        pdo \
        pdo_mysql \
        mysqli \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

WORKDIR /app

# Composer dependency layer
COPY laravel-8-ecommerce/composer.json laravel-8-ecommerce/composer.lock ./

RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --no-scripts \
    --optimize-autoloader

# Application source
COPY laravel-8-ecommerce .

# Ambil hasil frontend build dari stage Node.
# Ini menimpa public/ dengan public/ yang sudah berisi hasil Laravel Mix.
COPY --from=frontend /app/public /app/public

RUN mkdir -p \
    storage/app/public \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

RUN composer dump-autoload --no-dev --optimize

RUN php artisan package:discover --ansi

RUN php artisan storage:link

RUN chgrp -R 0 storage bootstrap/cache \
    && chmod -R g=u storage bootstrap/cache

EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
