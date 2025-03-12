FROM php:8-fpm
RUN apt-get update && \
    apt-get install -y \
        libzip-dev \
        zip \
        unzip \
        && docker-php-ext-install zip pdo pdo_mysql mysqli
WORKDIR /app
COPY laravel-8-ecommerce/ .
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer update
RUN php artisan key:generate && \
    php artisan storage:link
EXPOSE 8000
ENTRYPOINT ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
