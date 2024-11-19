ARG AUTOKUMA_VERSION=latest
FROM ghcr.io/bigboot/autokuma:${AUTOKUMA_VERSION}

COPY ./docker/autokuma/config/monitor /var/static/monitor/

ARG EMBY_MONITOR_URL
ARG QBITTORRENT_MONITOR_URL
ARG SYNOLOGY_MONITOR_URL
# Replace templates with environment variables in any file in this directory that contains the template value
RUN sed -i "s|%EMBY_MONITOR_URL%|${EMBY_MONITOR_URL}|g" /var/static/monitor/emby.toml && \
    sed -i "s|%QBITTORRENT_MONITOR_URL%|${QBITTORRENT_MONITOR_URL}|g" /var/static/monitor/torrent.toml && \
    escaped_synology_monitor_url=$(printf '%s\n' "${SYNOLOGY_MONITOR_URL}" | sed 's/[\/&]/\\&/g') && \
    sed -i "s|%SYNOLOGY_MONITOR_URL%|${escaped_synology_monitor_url}|g" /var/static/monitor/synology.toml
