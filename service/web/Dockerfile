FROM composer:latest as vendor

WORKDIR /var/www

COPY composer.json composer.lock .

RUN composer install --no-dev

FROM php:8.3-apache

RUN docker-php-ext-install pdo pdo_mysql
RUN docker-php-ext-enable pdo pdo_mysql

RUN apt update
RUN apt install -y mariadb-client

COPY --from=vendor /var/www/vendor /var/www/vendor

WORKDIR /var/www/
COPY . .
