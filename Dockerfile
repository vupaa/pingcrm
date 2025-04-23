FROM node:18-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --silent
COPY postcss.config.js tailwind.config.js vite.config.js ./
COPY resources ./resources
COPY public ./public
RUN npm run build

FROM alpine:latest
WORKDIR /var/www/html

# Install PHP, Nginx, Supervisor, and required extensions
RUN apk add --no-cache \
  php83 php83-fpm php83-bcmath php83-ctype php83-fileinfo php83-json \
  php83-mbstring php83-openssl php83-pdo_pgsql php83-pdo_mysql php83-curl \
  php83-pdo php83-tokenizer php83-xml php83-phar php83-dom php83-gd \
  php83-iconv php83-xmlwriter php83-xmlreader php83-zip php83-simplexml \
  php83-session php83-opcache php83-intl php83-pcntl php83-posix php83-ftp \
  php83-redis php83-sodium php83-exif curl nginx supervisor

# Link PHP binary
RUN ln -sf /usr/bin/php83 /usr/bin/php

# Create non-root user
RUN addgroup -g 1000 www && adduser -D -u 1000 -G www -s /bin/sh www

# Install Composer
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Copy application source
COPY --chown=www:www . .

# Install PHP dependencies
RUN composer install --optimize-autoloader --no-dev --no-interaction --no-progress --prefer-dist

# Copy built frontend assets
COPY --from=build --chown=www:www /app/public/build /var/www/html/public/build

# Add rootfs (nginx configs, scripts, etc.)
ADD docker/rootfs /

# Clean up unnecessary files and set permissions
RUN rm -rf /var/www/html/docker /var/www/html/resources/css /var/www/html/resources/js && \
    mkdir -p /var/cache/nginx && \
    chown -R www:www /var/lib/nginx /var/log/nginx /var/www/html/storage /var/www/html/bootstrap/cache && \
    php artisan storage:link

EXPOSE 80
ENTRYPOINT ["sh", "/sbin/boot.sh"]
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/fpm-ping
