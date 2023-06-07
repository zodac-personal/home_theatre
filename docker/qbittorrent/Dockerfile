ARG QBITTORRENT_VERSION
FROM linuxserver/qbittorrent:${QBITTORRENT_VERSION}-libtorrentv1 AS qbittorrent_base

ARG VUETORRENT_VERSION
RUN wget https://github.com/WDaan/VueTorrent/releases/download/v${VUETORRENT_VERSION}/vuetorrent.zip && \
    unzip vuetorrent.zip -d /app/ && \
    rm -rf vuetorrent.zip