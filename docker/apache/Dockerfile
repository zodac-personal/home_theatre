ARG APACHE_VERSION
FROM httpd:${APACHE_VERSION}-alpine

RUN mkdir --parents /usr/local/apache2/conf/sites/ && \
    mkdir --parents /var/www/html

COPY ./docker/apache/config/httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./docker/apache/sites/*.conf /usr/local/apache2/conf/sites