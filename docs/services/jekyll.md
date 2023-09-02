---
layout: page
title: jekyll
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## jekyll

Permite la creación de sitios web estáticos a partir de documentos en formato markdown.

> Otra opción para utilizar esta herramienta es instalarla dentro del servicio [web](/odoodock/services/web#jekyll).

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _jekyll_.

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

### Crear sitios web

> El directorio de trabajo por defecto es la carpeta _/mnt/extra-addons_, que da acceso a todos los módulos que se están desarrollando. En general será necesario acceder a la subcarpeta del módulo para la gneneración de la documentación asociada. 

> Si se desea publicar en GitHub Pages, el código fuente del sitio debe almacenarse en la carpeta _docs_

Existen dos opciones:

**O1. Desde dentro del contenedor**

Desde la carpeta _odoodock_, ejecutar: 

```
docker exec -it odoodock-jekyll-1 bash
> cd MI_MODULO
> jekyll new docs
> cd docs
> add bundler webrick
```
donde _MI_MODULO_ es la carpeta que contiene el módulo y _docs_ la carpeta que contendrá el código jekyll del sitio. 

**O2. Desde fuera del contenedor**

Desde la carpeta _odoodock_, ejecutar: 

```
docker exec -it odoodock-jekyll-1 bash -c "cd MI_MODULO \ 
 && jekyll new docs \
 && cd docs \
 && bundler add webrick">   
```
donde _MI_MODULO_ es la carpeta que contiene el módulo y _docs_ la carpeta que contendrá el código jekyll del sitio. 

> El servicio _jekyll_ está pensado para dar soporte a un único site. En caso de querer crear más de uno, es necesario parar y volver a arrancar el contenedor o arrancar [tanto servicios como sites deseemos](/odoodock/faq#es-posible-utilizar-el-servicio-jekyll-para-trabajar-simultáneamente-con-más-de-un-sitio-web).

### Construir/servir el sitio

El proceso de construcción (build) o de servir (serve) el site es muy similar. La forma más sencilla es entrando en el contenedor.

Para construir:

```
docker exec -it odoodock-jekyll-1 bash
> cd MI_MODULO\docs
> jekyll build
```

Para servir:

```
docker exec -it odoodock-jekyll-1 bash
> cd MI_MODULO\docs
> jekyll server 
```