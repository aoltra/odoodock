---
layout: page
title: Scripts
show_sidebar: false
hero_height: is-fullwidth
---

_Odoodock_ trae de serie algunos scripts para facilitar la gestión de los contenedores en particular y del sistema en general.

## database_backup

El script __database_backup__, situado en la carpeta _scripts_, se encarga de crear un copia de seguridad de una de las bases de datos tal y como la crea _Odoo_ desde su ventana de gestión de bases de datos (formato zip).

> Esta copia incluye en su interior un _dump_ de la base de datos, junto con la carpeta _filestore_ y el manifiesto de definción de la copia.

El script trabaja vía _xmlrp_ y puede ser muy útil para la creación automática (apoyada en _cron_) de las copias de seguridad.

Puede obtenerse una ayuda más detallada de las opciones a través del comando:

```
database_backup -h
```



