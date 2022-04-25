ARG EMBY_VERSION
FROM linuxserver/emby:${EMBY_VERSION}

COPY ./docker/emby/scripts/entrypoint.sh /var/entrypoint.sh
RUN chmod 0777 /var/entrypoint.sh

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/var/entrypoint.sh"]
