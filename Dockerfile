# Stage 1: front-end assets (laravel-mix 5 / webpack 4 needs the legacy OpenSSL provider on Node 17+)
FROM node:20-alpine AS assets
WORKDIR /app
COPY package.json package-lock.json webpack.mix.js .babelrc ./
RUN npm install
COPY resources ./resources
COPY public ./public
COPY src/HistoryGraph.js resources/js/components/Graphics/HistoryGraph.js
COPY src/TableRow.js resources/js/components/Graphics/TableRow.js
RUN NODE_OPTIONS=--openssl-legacy-provider npm run production

# Stage 2: PHP dependencies. composer.json still says php ^7.2.5, so platform checks are disabled.
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer config platform-check false \
 && composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs --prefer-dist --no-interaction
COPY . .
RUN composer dump-autoload --no-dev --optimize --no-scripts --ignore-platform-reqs

# Stage 3: runtime, official PHP 8.3 on Alpine (php-fpm) + nginx
FROM php:8.3-fpm-alpine

RUN apk add --no-cache nginx bash tini su-exec tzdata

# Fail the build if the PHP version is older than the PHP2Shell fix (8.3.36)
RUN php -r 'echo PHP_VERSION, PHP_EOL; exit(version_compare(PHP_VERSION, "8.3.36", ">=") ? 0 : 1);'

# Application code (the entrypoint copies it to /config/www on every start, same as before)
COPY --from=vendor /app /site
COPY --from=assets /app/public /site/public
COPY src/HomepageDataController.php /site/app/Http/Controllers/HomepageDataController.php
RUN rm -rf /site/src /site/docker /site/Dockerfile /site/docker-compose.yml

# Ookla Speedtest CLI (statically linked). The old image downloaded it on first start;
# it is now part of the image so a fresh /config works without network access to install.speedtest.net.
ARG OOKLA_VERSION=1.2.0
ARG TARGETARCH
RUN set -e; \
    case "${TARGETARCH:-amd64}" in \
        amd64) arch=x86_64 ;; \
        arm64) arch=aarch64 ;; \
        arm) arch=armhf ;; \
        386) arch=i386 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    wget -qO /tmp/speedtest.tgz "https://install.speedtest.net/app/cli/ookla-speedtest-${OOKLA_VERSION}-linux-${arch}.tgz"; \
    tar -xzf /tmp/speedtest.tgz -C /site/app/Bin speedtest; \
    rm /tmp/speedtest.tgz; \
    chmod +x /site/app/Bin/speedtest

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/zzz-app.conf /usr/local/etc/php-fpm.d/zzz-app.conf
COPY docker/app.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME /config
EXPOSE 80

# The php-fpm base image sets STOPSIGNAL SIGQUIT; the entrypoint traps TERM/INT
STOPSIGNAL SIGTERM

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
