ARG AUTOKUMA_VERSION
FROM ghcr.io/bigboot/autokuma:${AUTOKUMA_VERSION} AS autokuma_base
COPY ./docker/autokuma/config/monitors /var/monitor/static/

ARG EMBY_MONITOR_URL
# Replace templates with environment variables in any file in this directory that contains the template value
RUN grep -rl '%EMBY_MONITOR_URL%' /var/monitor/static/ | xargs sed -i "s|%EMBY_MONITOR_URL%|${EMBY_MONITOR_URL}|g"
