ARG HEIMDALL_VERSION
FROM linuxserver/heimdall:${HEIMDALL_VERSION}

COPY ./docker/heimdall/config/entrypoint.sh /var/entrypoint.sh
COPY ./docker/heimdall/config/environment.sh /var/environment.sh
RUN chmod 0777 /var/entrypoint.sh /var/environment.sh

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/var/entrypoint.sh"]
