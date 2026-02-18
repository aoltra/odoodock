FROM docker.n8n.io/n8nio/n8n:latest-debian
USER root

# instalación python3
ARG N8N_INSTALL_PYTHON=false
RUN if [ ${N8N_INSTALL_PYTHON} = true ]; then \
    apt-get update && \
    apt-get install -y python3 python3-pip python3-full && \
    rm -rf /var/lib/apt/lists/* \
;fi

USER node