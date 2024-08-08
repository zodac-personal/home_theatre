ARG QBITTORRENT_VERSION=latest
FROM linuxserver/qbittorrent:${QBITTORRENT_VERSION}-libtorrentv1 AS qbittorrent_base

# Install https://github.com/WDaan/VueTorrent/ for custom Web UI
ARG VUETORRENT_VERSION
RUN wget --progress=dot:giga https://github.com/WDaan/VueTorrent/releases/download/v${VUETORRENT_VERSION}/vuetorrent.zip && \
    unzip vuetorrent.zip -d /app/ && \
    rm -rf vuetorrent.zip
