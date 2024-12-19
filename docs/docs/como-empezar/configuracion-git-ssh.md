---
layout: page
menubar: docs_menu
title: Configuración git/ssh
subtitle: Cómo empezar
show_sidebar: false
hero_height: is-fullwidth
---

## Configuración git/ssh

La instalación de _ssh_ se configura desde el fichero _.env_ (por defecto está activa). Por su parte, _git_ viene incluido ya en la imagen de _Odoo_. 

En general, la forma más sencilla de trabajar con un remoto es mediante _ssh_. Para ello, es necesario que en el _home_ del contenedor (en este caso _/var/lib/odoo_) se almacene la clave privada del usuario y que se tenga permisos sobre ella:

> Nota: _[project_name]_ es el nombre del proyecto (variable _PROJECT_NAME_) definido en el fichero _.env_.

```
$ docker cp ~/.ssh/id_rsa [project_name]-web-1:/var/lib/odoo/.ssh
$ docker run --rm --entrypoint /bin/bash -u root -v [project_name]_odoo_data:/var/lib/odoo [project_name]-web -c "chown odoo:odoo /var/lib/odoo/.ssh/id_rsa"
```
donde _id_rsa_ es el fichero que contiene la clave privada del usuario.

Por último hay que añadir el repo remoto al fichero _known_hosts_. Por ejemplo si el remoto es _github.com_ :

```
$ docker run --rm --entrypoint /bin/bash -v [project_name]_odoo_data:/var/lib/odoo [project_name]-web -c "ssh-keyscan -t rsa github.com >> ~/.ssh/known_host"
```

> Si _git_ está configurado de manera global en el host (fichero _~/.gitignore_), los datos serán copiados automáticamente al contenedor se arranque el desarrollo remoto (Ver [Cómo depurar módulos con VSCode](/odoodock/docs/modulos/depurar-modulos))
