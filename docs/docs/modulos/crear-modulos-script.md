---
layout: page
menubar: docs_menu
title: Usando create-module.sh
subtitle: Creación de módulos
show_sidebar: false
hero_height: is-fullwidth
---

## Creando módulos

Existen dos opciones: mediante el uso de _create-module.sh_ o mediante el uso directo de comandos docker.

### Usando el script _create-module.sh_

_create-module.sh_ permite la creación desde fuera del contenedor de un módulo de diferentes formas: a través de la opción scaffold, desde un repo remoto medienta la extracción de un fichero .zip

**O1. Crear un módulo con _odoo scaffold_**

   Ejecutar el script _create-module.sh_ con la opción _-s_. Por ejemplo, desde la carpeta _odoodock_
     
   ```
   $ ./create-module.sh -s mimodulo
   ```

**O2. Clonar un módulo desde un repo existente**

   Ejecutar el script _create-module.sh_ con la opción _-g_. Por ejemplo, desde la carpeta _odoodock_
     
   ```
   $ ./create-module.sh -g https://github.com/user/mimodulo.git
   ```

   > Si el repo es público y todavía no se ha configurado el acceso por _ssh_, lo más rápido es utilizar _https_. Si el acceso se quiere realizar por _ssh_ será necesario configurarlo. Más información en [Configuración git/ssh](#configuración-gitssh)

**O3. Crear un módulo a partir de un fichero zip**

   Ejecutar el script _create-module.sh_ con la opción _-z_. Por ejemplo, desde la carpeta _odoodock_
     
   ```
   $ ./create-module.sh -z ~/downloads/mimodulo.zip
   ```

   > Para el funcionamiento correcto de esta opción es necesario que en el host esté instalado _unzip_

