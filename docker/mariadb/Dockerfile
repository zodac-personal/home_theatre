ARG MARIADB_VERSION
FROM linuxserver/mariadb:${MARIADB_VERSION}

COPY ./docker/mariadb/config/init-db.sql /docker-entrypoint-initdb.d/init-db.sql
