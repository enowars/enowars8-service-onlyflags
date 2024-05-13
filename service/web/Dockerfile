FROM php:8.3-apache

RUN docker-php-ext-install mysqli
RUN docker-php-ext-enable mysqli

RUN apt update
RUN apt install -y mariadb-client

COPY src/ /var/www/html/

