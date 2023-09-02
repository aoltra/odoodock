---
layout: page
title: moodle
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## moodle

Sistema de gestión de cursos online (CMS)

> Aunque es posible conectarla a otros sistemas gestores de bases de datos, como PostgreSQL, la configuración por defecto está destinada a trabajar con [mariadb](/odoodock/services/mariadb)

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _moodle_.

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

3. Abrir el navegador y acceder a la URL _http://locahost:8080_.

4. En la página de login usar como credenciales por defecto:

        Username : moodle 
        Password : secret

   > Es posible configurar el sevici pra que n se solicite usuario y contraseña asignando en el fichero .env el valor _True_ a la variable PGADMIN_CONFIG_SERVER_MODE
