ARG NETALERT_VERSION
FROM jokobsk/netalertx:${NETALERT_VERSION} as netalert_base

RUN mkdir -p /app/config/
COPY ./docker/netalert/config/app.conf /app.conf.new

ARG NETALERT_GMAIL_ADDRESS
ARG NETALERT_GMAIL_PASSKEY
ARG ADMIN_EMAIL_ADDRESS
ARG NETALERT_PRIMARY_SUBNET
ARG DOMAIN_NAME
RUN    sed -i -e "s|%NETALERT_GMAIL_ADDRESS%|${NETALERT_GMAIL_ADDRESS}|g" /app.conf.new && \
       sed -i -e "s|%NETALERT_GMAIL_PASSKEY%|${NETALERT_GMAIL_PASSKEY}|g" /app.conf.new && \
       sed -i -e "s|%ADMIN_EMAIL_ADDRESS%|${ADMIN_EMAIL_ADDRESS}|g" /app.conf.new && \
       sed -i -e "s|%NETALERT_PRIMARY_SUBNET%|${NETALERT_PRIMARY_SUBNET}|g" /app.conf.new && \
       sed -i -e "s|%DOMAIN_NAME%|${DOMAIN_NAME}|g" /app.conf.new
