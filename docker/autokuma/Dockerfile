ARG AUTOKUMA_VERSION
FROM ghcr.io/bigboot/kuma:${AUTOKUMA_VERSION} AS kuma_base

ARG AUTOKUMA_VERSION
FROM ghcr.io/bigboot/autokuma:${AUTOKUMA_VERSION} AS autokuma_base

COPY ./docker/autokuma/config/status /var/static/status/
COPY ./docker/autokuma/config/monitor /var/static/monitor/
ARG EMBY_MONITOR_URL
# Replace templates with environment variables in any file in this directory that contains the template value
RUN grep -rl '%EMBY_MONITOR_URL%' /var/static/monitor/ | xargs sed -i "s|%EMBY_MONITOR_URL%|${EMBY_MONITOR_URL}|g"

# Copy kuma & jq executables from kuma_base, to be used in startup script to check status pages
COPY --from=kuma_base /usr/local/bin/kuma /usr/local/bin/kuma
COPY ./docker/autokuma/script/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
