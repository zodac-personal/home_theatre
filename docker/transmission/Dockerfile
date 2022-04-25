ARG TRANSMISSION_VERSION
FROM linuxserver/transmission:${TRANSMISSION_VERSION}

COPY ./docker/transmission/config/unrar.sh /var/unrar.sh
RUN chmod 0777 /var/unrar.sh
