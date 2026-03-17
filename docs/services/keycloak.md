---
layout: page
title: keycloak
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## Keycloak

[**Keycloak**](https://www.keycloak.org/) es un sistema de gestión de identidades y accesos (IAM) de código abierto que permite a los desarrolladores integrar capacidades avanzadas de autenticación y autorización sin necesidad de desarrollar estas funciones desde cero.

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _keycloak_.

2. Crear la base de datos en el servicio *db* (postgres) taly como se explica [aquí](/odoodock/services/db)

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

3. Abrir el navegador y acceder a la URL _http://locahost:8080/auth_.

