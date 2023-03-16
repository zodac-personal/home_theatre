ARG TANDOOR_VERSION
FROM vabene1111/recipes:${TANDOOR_VERSION}

COPY ./docker/tandoor/config/Recipes.conf /opt/recipes/nginx/conf.d/Recipes.conf

ARG TANDOOR_HOSTNAME
ARG TANDOOR_PORT
RUN cd /opt/recipes/ && \
    grep -rl '%TANDOOR_HOSTNAME%' . | xargs sed -i "s|%TANDOOR_HOSTNAME%|${TANDOOR_HOSTNAME}|g" && \
    grep -rl '%TANDOOR_PORT%' . | xargs sed -i "s|%TANDOOR_PORT%|${TANDOOR_PORT}|g"
