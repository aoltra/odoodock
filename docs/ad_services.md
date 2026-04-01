---
layout: page
title: Servicios adicionales
subtitle: Servicios
show_sidebar: false
hero_height: is-fullwidth
---

## Uso de servicios adicionales

_Odoodock_ permite arrqncar servicios que no estén incluidos en su código. 

### Creación


La forma más habitual de añadir nuevos servicios es la creación de un repositorio git con uina esctrutura similar a la de _odoodock_. Por ejemplo, para un repo llamado `odoodock-additional-services`, con dos servicios (`servicio_1` y `servicios_2`).

odoodock-additional-services/
│
├── servicio_1/                            # Carpeta con información para el servicio 1
│   ├── Dockerfile                         # Dockerfile del servicio 1
│   └── serv1.conf                         # Ficheros extra necesarios para el servicios
│
├── servicio_2/                            # Carpeta con información para el servicio 2
|   └── Dockerfile                         # Dockerfile del servicio 2
│
├── .env                                   # Variables de entorno para los servicios
├── .services                              # Fichero de configuración de qué servicios deben arrancar
└── additional-services-compose.yml        # docker compose de los servicios del repositorio

#### additional-services-compose.yml

Su contenido es similar a cualquier fichero docker-compose.yml. Por ejemplo:

```yaml
services:

  #####################################
  ## SERVICIO_1 #################
  #####################################
  servicio_1:
    build:
      context: ./[ads]/servicio_1

    # puerto leido de la variable de entorno
    # por defecto 8099
    ports:
      - "${SERVICIO_1_PORT:-8099}:8000"

    environment:
      - LOG_LEVEL=${SERVICIO_1_LOG_LEVEL:-INFO}

    # se puede incluir dependencias de servicios incluidos en odoodock
    depends_on:
      - rabbitmq

    # se puede incluir redes definidas en odoodock
    networks:
      - traefik_network
```

> IMPORTANTE: El fichero tiene que llamarse obligatoriamente `dditional-services-compose.yml`.

> IMPORTANTE: El contexto del _build_ tiene que incluir la carpeta `[ads]`.


#### .env

Almacena las variables de entorno para los servicios del repo.

```yaml

### SERVICIO_1  ##############################################

SERVICIO_1_PORT=8099
SERVICIO_1_LOG_LEVEL=INFO

```

#### .services

Almacena una variable con los servicios del repo que se arrancan

```bash

ADSSERVICES=(
  servicio_1
  # servicio_2
)

```

### Instalación

El repo se añade en _odoodock_ como un submódulo.

```bash
# desde odoodock
git submodule add https://github.com/usuario/odoodock-additional-services.git '[ads]'
```

> Es muy importante renombra el repositorio a `[ads]`