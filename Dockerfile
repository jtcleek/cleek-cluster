# PHP Dependency install via Composer.
FROM composer as vendor

COPY composer.json composer.json
COPY composer.lock composer.lock
COPY web/ web/

RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-dev \
    --prefer-dist

# Build the Docker image for Drupal.
FROM php:8.1-apache

RUN apt-get update && apt-get install -y \
    libpng-dev mariadb-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-enable opcache \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-source delete

# Security
RUN sed -ri -e 's!expose_php = On!expose_php = Off!g' $PHP_INI_DIR/php.ini-production \
    && sed -ri -e 's!ServerTokens OS!ServerTokens Minor!g' /etc/apache2/conf-available/security.conf \
    && sed -ri -e 's!ServerSignature On!ServerSignature Off!g' /etc/apache2/conf-available/security.conf \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN a2enmod rewrite 
    #&& a2dissite *

COPY vhost.conf /etc/apache2/sites-enabled/000-default.conf

ENV DRUPAL_MD5 aedc6598b71c5393d30242b8e14385e5

# Copy precompiled codebase into the container.
COPY --from=vendor /app/ /var/www/html/

# Copy other required configuration into the container.
COPY config/ /var/www/html/config/

# Make sure file ownership is correct on the document root.
RUN chown -R www-data:www-data /var/www/html/web

# Add Drush Launcher.
RUN curl -OL https://github.com/drush-ops/drush-launcher/releases/download/0.6.0/drush.phar \
 && chmod +x drush.phar \
 && mv drush.phar /usr/local/bin/drush

CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
