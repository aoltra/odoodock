ARG POSTGRES_IMAGE=alpine
ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}-${POSTGRES_IMAGE}

RUN apk update && \
    apk add nss_wrapper bash
    
COPY .databases /tmp/.databases

COPY init-databases.sh /docker-entrypoint-initdb.d/

# Aseguramos permisos de ejecución
RUN chmod +x /docker-entrypoint-initdb.d/init-databases.sh

CMD ["postgres"]

EXPOSE 5432
