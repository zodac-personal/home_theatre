ARG AUTOKUMA_VERSION=latest
FROM ghcr.io/bigboot/autokuma:${AUTOKUMA_VERSION}

COPY ./docker/autokuma/config/monitor /var/static/monitor/

ARG EMBY_MONITOR_URL
ARG SYNOLOGY_MONITOR_URL
# Replace templates with environment variables in any file in this directory that contains the template value
RUN grep -rl '%EMBY_MONITOR_URL%' /var/static/monitor/ | xargs sed -i "s|%EMBY_MONITOR_URL%|${EMBY_MONITOR_URL}|g" && \
    grep -rl '%SYNOLOGY_MONITOR_URL%' /var/static/monitor/ | xargs sed -i "s|%SYNOLOGY_MONITOR_URL%|${SYNOLOGY_MONITOR_URL}|g"
