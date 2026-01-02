ARG NETALERT_VERSION=latest
FROM ghcr.io/jokob-sk/netalertx:${NETALERT_VERSION} AS netalert_base

COPY ./docker/netalert/config/app.conf /tmp/app.conf.new

ARG DISCORD_NEW_NETWORK_DEVICE_WEBHOOK_URL
ARG DOMAIN_NAME
ARG NETALERT_PRIMARY_SUBNET
ARG TIMEZONE
RUN sed -i -e "s|%DISCORD_NEW_NETWORK_DEVICE_WEBHOOK_URL%|${DISCORD_NEW_NETWORK_DEVICE_WEBHOOK_URL}|g" /tmp/app.conf.new && \
    sed -i -e "s|%DOMAIN_NAME%|${DOMAIN_NAME}|g" /tmp/app.conf.new && \
    sed -i -e "s|%NETALERT_PRIMARY_SUBNET%|${NETALERT_PRIMARY_SUBNET}|g" /tmp/app.conf.new && \
    sed -i -e "s|%TIMEZONE%|${TIMEZONE}|g" /tmp/app.conf.new
