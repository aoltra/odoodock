ARG ODOO_VERSION
FROM odoo:${ODOO_VERSION}

LABEL maintainer="Alfredo Oltra <alfredo.ptcf@gmail.com>"

# Nos aseguramos de usar bash para todos los comandos RUN
SHELL ["/bin/bash", "-lc"]

USER root

# disponible sólo en el proceso de construcción de la imagen
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update 
RUN apt-get install -y --no-install-recommends apt-utils iputils-ping telnet git curl

# instalación de Oh My ZSH
ARG ODOO_SHELL_OH_MY_ZSH=false
RUN if [ ${ODOO_SHELL_OH_MY_ZSH} = true ]; then \
    apt-get install -y zsh \
;fi

# instalación nano
ARG ODOO_INSTALL_NANO=false
RUN if [ ${ODOO_INSTALL_NANO} = true ]; then \
    apt-get install -y --no-install-recommends \
    nano \
;fi

# instalación ssh
ARG ODOO_INSTALL_SSH=true
RUN if [ ${ODOO_INSTALL_SSH} = true ]; then \
    apt-get install -y --no-install-recommends \
    ssh && \
    # creación directorio .ssh de odoo (su home es /var/lib/odoo)
    mkdir -p /var/lib/odoo/.ssh \
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

# Instalación de ADSF
ARG ODOO_INSTALL_ASDF=false

# se instala para el usuario, no para root ni para todos los usuarios
USER odoo

RUN if [ ${ODOO_INSTALL_ASDF} = true ]; then \
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.12.0 && \
    echo '. ~/.asdf/asdf.sh' >> ~/.bashrc && \
    echo '. ~/.asdf/completions/asdf.bash' >> ~/.bashrc && \
    echo '. ~/.asdf/asdf.sh' >> ~/.zshrc && \
    echo '. ~/.asdf/completions/asdf.bash' >> ~/.zshrc \
;fi

USER root

# instalación dependencias plugin ruby para asdf
ARG ODOO_ASDF_INSTALL_PLUGIN_RUBY=false
RUN if [ ${ODOO_ASDF_INSTALL_PLUGIN_RUBY} = true ] && [ ${ODOO_INSTALL_ASDF} = true ]; then \
    apt-get install -y --no-install-recommends autoconf patch build-essential rustc libssl-dev libyaml-dev \ 
    libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev \ 
    libdb-dev uuid-dev \
;fi

USER odoo

# se añade el plugin de ruby para asdf y se añade a ~/.tool-versions la versión de ruby
ARG ODOO_ASDF_PLUGIN_RUBY_INSTALL_VERSION=latest
RUN if [ ${ODOO_ASDF_INSTALL_PLUGIN_RUBY} = true ] && [ ${ODOO_INSTALL_ASDF} = true ]; then \
    source ~/.bashrc && asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git && \
    echo ruby ${ODOO_ASDF_PLUGIN_RUBY_INSTALL_VERSION} >> ~/.tool-versions \
;fi

USER root

# instalacíón de todas las versiones definidas en ~/.tool-versions
RUN if [ ${ODOO_INSTALL_ASDF} = true ]; then \
    source ~/.bashrc && asdf install \
;fi

# instalacion del módulo debugpy
RUN pip3 install debugpy

# creación de la carpeta de almacenamiento de documentos
ARG REPO_PATH_CONTAINER=/mnt/odoo-repo
RUN mkdir -p ${REPO_PATH_CONTAINER}

# permito el acceso a la lectura de los logs desde el host 
RUN chmod 755 /var/log/odoo

# copio el fichero de configuraciones 
COPY odoo.conf /etc/odoo/
ENV ODOO_RC /etc/odoo/odoo.conf

# copio fichero de arranque de odoo
COPY ./runodoo.sh /
RUN chmod 777 /runodoo.sh

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 777 /entrypoint.sh

# sólo recomendable en desarrollo
RUN usermod -s /bin/bash odoo

# copio el fichero de configuraciones de ejecución de python
RUN mkdir /mnt/extra-addons/.vscode
COPY ./.vscode/launch.json /mnt/extra-addons/.vscode/launch.json

# Asigno propietario y grupo al directorio de configuración, addons
# y al de logs
RUN chown -R odoo:odoo /etc/odoo /var/log/odoo /mnt/extra-addons /var/lib/odoo ${REPO_PATH_CONTAINER} 

# puerto por el que escucha conexiones
EXPOSE 8069

USER odoo

# fichero a ejecutar al arrancar
ENTRYPOINT ["/entrypoint.sh"]
# Parámetro del entrypoint
# Son pasados posteriormente a odoo por lo que podria servir
# para arrancar odoo con parámetros no incluidos en enviroment
# por ejemplo CMD ["--pidfile=/odoo.pid"]
CMD []