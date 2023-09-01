---
layout: page
title: Trabajando con contenedores
subtitle: Servicios
show_sidebar: false
hero_height: is-fullwidth
---

## Trabajando con los contenedores

### Parada

```
$ docker compose down
```

### Reconstrucción

Para reconstruir los contenedores a partir de los Dockerfile:

```
$ ./up.sh --build
```

### Mostrar logs

**O1. Mostrar los logs de todos los servicios arrancados**

```
$ docker compose logs
```

**O2. Mostrar en vivo los logs de todos los servicios arrancados**

```
$ docker compose logs --follow
```

**O3. Mostrar en vivo los logs de un único contenedor**

Por ejemplo, para el contenedor _odoodock-web-1_

```
$ docker logs --follow odoodock-web-1
```