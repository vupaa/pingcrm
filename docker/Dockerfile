FROM node:18-alpine as build
WORKDIR /app
COPY ["package.json", "package-lock.json", "./"]
RUN npm ci --silent
COPY ["postcss.config.js", "tailwind.config.js", "vite.config.js", "./"]
COPY resources /app/resources
COPY public /app/public
RUN npm run build

FROM alpine:latest
WORKDIR /var/www/html

RUN apk add --no-cache \
  php83 \
  php83-fpm \
  php83-bcmath \
  php83-ctype \
  php83-fileinfo \
  php83-json \
  php83-mbstring \
  php83-openssl \
  php83-pdo_pgsql \
  php83-pdo_mysql \
  php83-curl \
  php83-pdo \
  php83-tokenizer \
  php83-xml \
  php83-phar \
  php83-dom \
  php83-gd \
  php83-iconv \
  php83-xmlwriter \
  php83-xmlreader \
  php83-zip \
  php83-simplexml \
  php83-session \
  php83-opcache \
  php83-gd \
  php83-intl \
  php83-pcntl \
  php83-posix \
  php83-ftp \
  curl \
  nginx \
  supervisor \
  php83-redis \
  php83-sodium \
  php83-exif

# Link PHP binary
RUN ln -sf /usr/bin/php8.3 /usr/bin/php

# Create non-root user
RUN groupadd --gid 1000 www && \
    useradd --uid 1000 --gid 1000 --shell /bin/sh --create-home www

COPY --from=composer/composer:2-bin /composer /usr/bin/composer
COPY --chown=www:www composer*.json .
RUN composer install --optimize-autoloader --no-dev --no-interaction --no-progress --no-suggest --prefer-dist
COPY --chown=www:www . .

ADD docker/rootfs /

RUN rm -rf /var/www/html/docker && \
    rm -rf /var/www/html/resources/css && \
    rm -rf /var/www/html/resources/js && \
    mkdir -p /var/cache/nginx && \
    chown -R www:www /var/lib/nginx && \
    chown -R www:www /var/log/nginx && \
    php /var/www/html/artisan storage:link

COPY --from=build --chown=www:www /app/public/build /var/www/html/public/build

EXPOSE 80
ENTRYPOINT ["sh", "/sbin/boot.sh"]
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/fpm-ping
