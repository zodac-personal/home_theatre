ARG AUTOKUMA_VERSION=latest
FROM ghcr.io/bigboot/autokuma:${AUTOKUMA_VERSION}

COPY ./docker/autokuma/config/monitor /var/static/monitor/

ARG QBITTORRENT_MONITOR_URL
ARG SYNOLOGY_MONITOR_URL
# Replace templates with environment variables in any file in this directory that contains the template value
RUN sed -i "s|%QBITTORRENT_MONITOR_URL%|${QBITTORRENT_MONITOR_URL}|g" /var/static/monitor/torrent.toml && \
    sed -i "s|%SYNOLOGY_MONITOR_URL%|$(printf '%s\n' "${SYNOLOGY_MONITOR_URL}" | sed 's/[\/&]/\\&/g')|g" /var/static/monitor/synology.toml
