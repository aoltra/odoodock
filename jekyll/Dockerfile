FROM jekyll/jekyll:latest

LABEL maintainer="Alfredo Oltra <alfredo.ptcf@gmail.com>"

# se asignan el mismo UID y GID que el usuario odoo 
# del servicio web para que no haya problemas de permisos
RUN usermod -u 101 jekyll
RUN groupmod -g 101 jekyll

RUN chown -R jekyll /usr/gem/

EXPOSE 4000

ENTRYPOINT ["/bin/bash"]