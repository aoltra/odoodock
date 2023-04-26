ARG ODOO_VERSION
FROM odoo:${ODOO_VERSION}

LABEL maintainer="Alfredo Oltra <alfredo.ptcf@gmail.com>"

USER root

# disponible sólo en elproceso de construcción de la imagen
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update 
RUN apt-get install -y --no-install-recommends apt-utils iputils-ping telnet 

# instalación de Oh My ZSH
ARG ODOO_SHELL_OH_MY_ZSH=false
RUN if [ ${ODOO_SHELL_OH_MY_ZSH} = true ]; then \
    apt-get install -y zsh \
;fi

# instalación git
ARG ODOO_INSTALL_GIT=false
RUN if [ ${ODOO_INSTALL_GIT} = true ]; then \
    apt-get install -y --no-install-recommends \
    git \
;fi

# instalación ssh
ARG ODOO_INSTALL_SSH=false
RUN if [ ${ODOO_INSTALL_SSH} = true ]; then \
    apt-get install -y --no-install-recommends \
    ssh \
;fi

# instalación pdftk
ARG ODOO_INSTALL_PDFTK=false
RUN if [ ${ODOO_INSTALL_PDFTK} = true ]; then \
    apt-get install -y --no-install-recomends \ 
    pdftk \
;fi

# instalación openssl dev
ARG ODOO_INSTALL_SSL_DEV=false
RUN if [ ${ODOO_INSTALL_SSL_DEV} = true ]; then \
    apt-get install -y \ 
    python3-dev build-essential libcurl4-openssl-dev libssl-dev \
;fi

# Se crea un usuario odoo junto con su directorio home
# y asigno permisos
RUN useradd -ms /bin/bash odoo \
    && chown -R odoo:odoo /etc/odoo /var/log/odoo

USER odoo

# copio el fichero de configuraciones 
COPY ./odoo.conf /etc/odoo/
ENV ODOO_RC /etc/odoo/odoo.conf

# puerto por el que escucha conexiones
EXPOSE 8069
# fichero a ejecutar al arrancar
ENTRYPOINT ["/entrypoint.sh"]
# Parámetro del entrypoint
CMD ["odoo"]

