# Odoodock

Odoodock es un entorno de desarrollo de Odoo para Docker que sigue la idea propuesta por laradock. 

## Características

- Creación de imagen personalizada con la instalación de varias herramientas de apoyo.
- Soporte para _odoo_, _odoo shell_ y _scaffolding_
- Soporte de varios servicios de apoyo:
  - Moodle
  - MariaDB (para Moodle)
- Cada servicio corre en un propio contenedor.
- Permite el desarrollo desde dentro del contenedor de Odoo.
- Configuración de serie para realizar depuración en Visual Studio Code
- Fácilmente configurable a través de variables de entorno.
- Pensado con fines académicos: código muy comentado
- Soporte para versión 14

## Cómo empezar

### Requerimientos

- [git](https://git-scm.com/downloads)
- [docker compose](https://docs.docker.com/compose/)
- [Visual Studio Code](https://code.visualstudio.com/)

## Licencia

Odoodock se distribuye bajo licencia GPL 3. Más información en [LICENSE](LICENSE)