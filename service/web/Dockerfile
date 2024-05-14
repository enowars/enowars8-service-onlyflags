FROM php:8.3-apache

RUN docker-php-ext-install pdo pdo_mysql
RUN docker-php-ext-enable pdo pdo_mysql

RUN apt update
RUN apt install -y mariadb-client

COPY src/ /var/www/html/

