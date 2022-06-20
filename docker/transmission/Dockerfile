ARG TRANSMISSION_VERSION
FROM linuxserver/transmission

COPY ./docker/transmission/config/unrar.sh /var/unrar.sh
RUN chmod 0777 /var/unrar.sh

COPY ./docker/transmission/config/settings.json /config/settings.json