ARG DOZZLE_VERSION
ARG DEBIAN_VERSION
FROM debian:${DEBIAN_VERSION}-slim AS auth_builder

RUN --mount=type=cache,target=/var/cache/apt apt-get update && apt-get upgrade -y && \
    apt-get install -yqq --no-install-recommends \
      libdigest-sha-perl \
    && \
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG ADMIN_EMAIL_ADDRESS
ARG ADMIN_USERNAME
ARG ADMIN_PASSWORD
COPY ./docker/dozzle/config/users.yml /tmp/users.yml
RUN sed -i -e "s|%ADMIN_EMAIL_ADDRESS%|${ADMIN_EMAIL_ADDRESS}|g" /tmp/users.yml && \
    sed -i -e "s|%ADMIN_USERNAME%|${ADMIN_USERNAME}|g" /tmp/users.yml && \
    sed -i -e "s|%ADMIN_PASSWORD%|$(echo -n ${ADMIN_PASSWORD} | shasum -a 256  | cut -f 1 -d " ")|g" /tmp/users.yml

FROM amir20/dozzle:${DOZZLE_VERSION} AS dozzle_base
COPY --from=auth_builder /tmp/users.yml /data/users.yml
