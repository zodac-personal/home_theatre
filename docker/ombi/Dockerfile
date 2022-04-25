ARG OMBI_VERSION
FROM linuxserver/ombi:${OMBI_VERSION}

RUN mkdir -p /config
WORKDIR /config
COPY ./docker/ombi/config/database.json ./database.json

ARG DB_NAME
ARG DB_USERNAME
ARG DB_PASSWORD
RUN grep -rl '%DB_NAME%' database.json | xargs sed -i "s|%DB_NAME%|${DB_NAME}|g" && \
    grep -rl '%DB_USERNAME%' database.json | xargs sed -i "s|%DB_USERNAME%|${DB_USERNAME}|g" && \
    grep -rl '%DB_PASSWORD%' database.json | xargs sed -i "s|%DB_PASSWORD%|${DB_PASSWORD}|g"

RUN cp ./database.json /etc/database.json && \
    cp ./database.json /opt/ombi/database.json
