FROM docker.io/library/composer:2 AS composer
FROM docker.io/library/php:8.0-cli AS runtime
RUN sed -i '/bullseye-security/d' /etc/apt/sources.list && \
	apt-get update && \
	apt-get install -y --no-install-recommends \
        libzip-dev \
	libonig-dev \
        unzip && \
	docker-php-ext-install -j"$(nproc)" \
	zip \
	mbstring \
	pdo \
	pdo_mysql \
	mysqli && \
	rm -rf /var/lib/apt/lists/*

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

WORKDIR /app

COPY laravel-8-ecommerce/composer.json laravel-8-ecommerce/composer.lock ./

RUN composer install \
	--no-dev \
	--prefer-dist \
	--no-interaction \
	--no-progress \
	--no-scripts \
	--optimize-autoloader

COPY laravel-8-ecommerce/ .

RUN mkdir -p \
	storage/app/public \
	storage/framework/cache \
	storage/framework/sessions \
	storage/framework/views \
	storage/logs \
	bootstrap/cache && \
	composer dump-autoload --no-dev --optimize && \
	php artisan package:discover --ansi && \
	php artisan storage:link && \
	chgrp -R 0 storage bootstrap/cache && \
	chmod -R g=u storage bootstrap/cache

EXPOSE 8000

ENTRYPOINT ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
