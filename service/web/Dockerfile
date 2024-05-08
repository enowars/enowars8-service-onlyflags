FROM php:8.3-apache

RUN apt install mariadb-client

RUN docker-php-ext-install mysqli
RUN docker-php-ext-enable mysqli

COPY src/ /var/www/html/

