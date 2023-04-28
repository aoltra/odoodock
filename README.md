# Odoodock

Odoodock es un entorno de desarrollo de Odoo para Docker que sigue la idea propuesta por laradock

## Características

- Creación de imagen personalizada con la instalación de varias herramientas de apoyo.
- Soporte para _odoo_, _odoo shell_ y _scaffolding_
- Soporte de varios servicios de apoyo:
  - Moodle
  - MariaDB
- Imágenes de los servicios basadas en la imagen oficial.
- Cada servicio corre en un propio contenedor.
- Permite el desarrollo desde dentro del contenedor de odoo.
- Fácilmente configurable a través de variables de entorno.

## Cómo empezar

### Requerimientos

- [git](https://git-scm.com/downloads)
- [docker compose](https://docs.docker.com/compose/)

## Licencia

Odoodock se distribuye bajo licencia GPL 3. Más información en [LICENSE](LICENSE)