---
layout: page
title: traefik
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## Traefik

Traefik es un proxy inverso y balanceador de carga de código abierto, diseñado para entornos nativos en la nube y contenedores (como Docker o Kubernetes). Su función principal es actuar como la puerta de entrada a tu servidor, interceptando las peticiones web y redirigiéndolas automáticamente al servicio o contenedor correspondiente

### Configuración

1. Copia el fichero `./traefik/traefik-example.yml` a `./traefik/traefik.yml`

   ```bash
   cp ./traefik/traefik-example.yml ./traefik/traefik.yml 
   ```

   El fichero _./traefik/traefik-example.yml_, permite el acceso al dashboasrd sin autenticar y a aquellos servicios de docker que tienen la etiqueta _traefik.enable=true_

2. Añade en tu fichero `/etc/hosts` las dominios del fichero `/treafik/hosts` de aquellos servicios que se van a utilizar.

### Uso

Accede a los servicios a través de los nombre declarados en `/etc/hosts`, por ejemplo _odoo.local_.

Para acceder al dashboard de traefik `http://localhost:8888`