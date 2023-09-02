---
layout: page
title: web
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## web (odoo)

El servicio web es el que se encarga de arrancar odoo. 

> Es el servicio principal de _Odoodock_, por lo que siempre debe arrancarse.

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _web_.

2. Configurar el fichero _.env_ para activar o desactivar [utilidades](#utilidades) internas a instalar.

   > Parte de estas utilidades pueden ser arrancadas como contenedores docker. La decisión del método a utilizar depende del propósito del servicio.

3. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

4. Abrir el navegador y acceder a la URL _http://locahost:8069_.

### Utilidades

El servicio permite la instalación de herramientas adicionales de ayuda al desarrollo. En general, el acceso a ellas se realiza accediendo al _bash_ del contenedor mediante el comando _exec_. Por ejemplo:

```
   $ docker exec -it odoodock-web-1 bash
   > jekyll new mi_site
   ```

#### Oh My ZSH

_Z-Shell (ZSH)_ es una shell que aporta mejoras sobre bash. _Oh My ZSH_ es un framework sobre ZHS que aporta, entre otras, mejoras de autocompletado de comandos _git_.

#### nano

Editor de texto en línea de comandos. Simplifica la modificación de ficheros internos del contenedor.

#### ssh

_ssh_ puede ser muy útil sobre todo para la conexión con repositorios remotos como github

#### Open SSL

Librería para administrar funciones de criptografía. Puede ser necesaria para interconectar diferentes servicios.

#### pdftk

Herramienta que permite manipular documentos pdf. Requiere ampliar, dentro del fichero _odoo.conf_, el _limit_memory_hard_ al menos a 8684354560

#### asdf

[asdf](https://asdf-vm.com/) es un gestor de de versiones de diferentes lenguajes de programación. Puede ser utilizado para desarrollo software de apoyo a los módulos en otros lenguajes diferentes a python. Además, su instalación es necesaria para la posterior ejecución de otras herramientas como Jekyll (que requiere ruby).

> En caso de que se reconstruya (_build_) la imagen del servicio una vez ya creada para incluir _asdf_, es necesario añadir en el fichero _~/.bashrc_ las líneas  _. /opt/asdf/asdf.sh_ y _. /opt/asdf/completions/asdf.bash_ (¡Atención! el . va separado de la ruta)

##### Plugins para asdf

Tanto la instalación de plugins (runtimes de lenguajes de programación) como la de diferentes versiones se realiza a través de diferentes variables de entorno.

Para ruby: 
```
  ODOO_ASDF_INSTALL_PLUGIN_RUBY=false
  ODOO_ASDF_PLUGIN_RUBY_INSTALL_VERSION=3.0.0
```

> Es posible instalar varias versiones de un runtime incluyendolas en una cadena separadas por espacios.Por ejemplo: "3.0.0 2.7.1"

#### Jekyll

[Jekyll](https://jekyllrb.com/) es un generador estático de páginas web. Es recomendado su uso en combinación con Github Pages para poder publicar sitios web a partir de documentos md

> Para su uso es necesario instalar [asdf](#asdf) junto con el plugin de _Ruby_ y la versión 3.0.0 o superior.

> Es posible utilizar [Jekyll](/odoodock/services/jekyll) como un servicio externo.
