ARG POSTGRES_IMAGE=alpine
ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}-${POSTGRES_IMAGE}

RUN apk update && \
    apk add nss_wrapper

CMD ["postgres"]

EXPOSE 5432