ARG EMBY_VERSION
FROM linuxserver/emby:${EMBY_VERSION}

COPY ./docker/emby/config/entrypoint.sh /var/entrypoint.sh
COPY ./docker/emby/config/backup.sh /var/backup.sh
RUN chmod 0777 /var/entrypoint.sh /var/backup.sh

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/var/entrypoint.sh"]
