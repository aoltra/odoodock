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
    apt-get install -y \ 
    pdftk \
;fi

# instalación openssl dev
ARG ODOO_INSTALL_SSL_DEV=false
RUN if [ ${ODOO_INSTALL_SSL_DEV} = true ]; then \
    apt-get install -y \ 
    python3-dev build-essential libcurl4-openssl-dev libssl-dev \
;fi

# instalacion del módulo debugpy
RUN pip3 install debugpy

# Asigno permisos al directorio de configuración
# y al de logs
RUN chown -R odoo:odoo /etc/odoo /var/log/odoo

#USER odoo

# copio el fichero de configuraciones 
COPY odoo.conf /etc/odoo/
ENV ODOO_RC /etc/odoo/odoo.conf

# copio fichero de arranque de odoo
COPY ./runodoo.sh /
RUN chmod 770 /runodoo.sh

# copio el fichero de configuraciones de ejecución de python
RUN mkdir /mnt/extra-addons/.vscode
COPY ./.vscode/launch.json /mnt/extra-addons/.vscode/launch.json

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 770 /entrypoint.sh

# puerto por el que escucha conexiones
EXPOSE 8069

# fichero a ejecutar al arrancar
ENTRYPOINT ["/entrypoint.sh"]
# Parámetro del entrypoint
# Son pasados posteriormente a odoo por lo que podria servir
# para arrancar odoo con parametros no incluidos en enviroment
# por ejemplo CMD ["--pidfile=/odoo.pid"]
CMD []

