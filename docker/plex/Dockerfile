ARG PLEX_VERSION
FROM linuxserver/plex:${PLEX_VERSION}

COPY ./docker/plex/config/entrypoint.sh /var/entrypoint.sh
COPY ./docker/plex/config/backup.sh /var/backup.sh
RUN chmod 0777 /var/entrypoint.sh /var/backup.sh

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/var/entrypoint.sh"]
