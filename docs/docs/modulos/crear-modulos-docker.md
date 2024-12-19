---
layout: page
menubar: docs_menu
title: Usando comandos Docker
subtitle: Creación de módulos
show_sidebar: false
hero_height: is-fullwidth
---

## Creando módulos

Existen dos opciones: mediante el uso de _create-module.sh_ o mediante el uso directo de comandos docker.

### Mediante comandos docker

Siempre es posible entrar dentro del contendor _[project_name]-web-1_ y ejecutar los comandos necesarios.

> Nota: _[project_name]_ es el nombre del proyecto (variable _PROJECT_NAME_) definido en el fichero _.env_.

> ¡Atención!. La ejecución de estos comandos requiere que el proceso de [depuración](/odoodock/docs/modulos/depurar-modulos) esté en marcha. En caso contrario hay que tener en cuenta que es posible que el contenedor pare su ejecución ya que el proceso que se ejecuta es interrumpido. Al cabo de unos segundos debería volver a reiniciarse de manera automática, aunque siempre es posible forzar el reinicio con _docker compose up -d web_

**O1. Crear un módulo con _odoo scaffold_**

   ```
   $ docker exec -it [project_name]-web-1 bash
   > odoo scaffold [nombre_del_modulo] /mnt/extra-addons
   ```
**O2. Clonar un módulo desde un repo existente**

   ```
   $ docker exec -it [project_name]-web-1 bash
   > cd /mnt/extra-addons
   > git clone [url_repo]
   ```
> Si el repo es público y todavía no se ha configurado el acceso por _ssh_, lo más rápido es utilizar _https_. Si el acceso se quiere realizar por _ssh_ será necesario configurarlo. Más información en [Configuración git/ssh](/odoodock/docs/como-empezar/configuracion-git-ssh)

**O3. Crear un módulo a partir de un fichero zip**

   ```
   $ docker cp [nombre_del_modulo].zip [project_name]-web-1:/mnt/extra-addons
   $ docker exec -it [project_name]-web-1 bash
   > cd /mnt/extra-addons
   > unzip [nombre_del_modulo].zip
   ```
