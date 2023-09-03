---
layout: page
title: pgadmin
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## pgadmin

Plataforma para la admnistración de _PostgreSQL_.

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _pgadmin_.

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

3. Abrir el navegador y acceder a la URL _http://locahost:5050_.

4. En la página de login usar como credenciales por defecto:

        Username : admin@admin.com 
        Password : secret

   > Es posible configurar el servicio para que no se solicite usuario y contraseña asignando en el fichero _.env_ el valor _False_ a la variable PGADMIN_CONFIG_SERVER_MODE

5. Configurar el servidor con los datos:

        Server: db
        Port: 5432
        User: odoo
        Password: odoo