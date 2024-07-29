ARG APACHE_VERSION=latest
FROM httpd:${APACHE_VERSION}-alpine AS apache_base

RUN mkdir --parents /usr/local/apache2/conf/sites/ && \
    mkdir --parents /var/www/html

COPY ./docker/apache/config/httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./docker/apache/sites/ /usr/local/apache2/conf/sites/

ARG ADMIN_EMAIL_ADDRESS
RUN sed -i -e "s|%ADMIN_EMAIL_ADDRESS%|${ADMIN_EMAIL_ADDRESS}|g" /usr/local/apache2/conf/httpd.conf
