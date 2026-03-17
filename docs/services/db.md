---
layout: page
title: db
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## db (postgres)

Sistema gestor de base de datos.

La imagen está configurada para funcionar con el servicio [web](/odoodock/services/web) y [keycloak](/odoodock/services/keycloak), por lo tanto al arrancar cualquiera de estos, este arrancará automáticamente.

### Creación de bases de datos

**Odoo**

La base de datos de Odoo es creada por el servicio web la primera vez que se ejecuta, tras solicitar al usuario el nombre de las credenciales

**Resto de bbdd**

Para crear nuevas bases de datos es necesario incluirlas en el fichero _.databases_ que hay en el carpeta _/postgres_.

1. Si están los contendores arrancados, apagarlos

   ```bash
   $ docker compose down
   ```

2. Copiar el fichero _.databases-example_ a _.databases_

   ```bash
   $ cp .databases-example .databases
   ```

3. Modificar el fichero. Por ejemplo para añadir una base de datos para la gestión de Keycloak

   ```text
   # lista de bases de datos:usuario:contraseña a crear en el contenedor
   KEYCLOAK:keycloak:secret123
   ```
  donde:
  * KEYCLOAK: es el nombre de la base de datos
  * keycloak: el nombre del usuario con acceso total
  * secret213: contraseña del usuario (no se pueden utilizar los dos puntos ( : ) como parte de la contraseña)
  * Las líneas que empiezan por # se consideran comentarios

    > Importante: el nombre de la base de datos puede ser cualquiera, pero si es una base de datos creada para otro servicio de **odoodock** es necesario utilizar el mismo nombre que el utilizado en el fichero _.env_ de configuración. En este caso el definido en la variable `POSTGRES_KEYCLOAK_DB=KEYCLOAK`

    > Importante: el usuario que creará la base de datos es el definido en la variable `POSTGRES_USER` que suele estar asignada a _odoodock_. El usuario creado desde el fichero _.databases_ tendrá permisos totales pero solo sobre la base de datos asociada.

4. a. En el caso de que sea el primer arranque del servicio las bases de datos se crearan al crear la imagen

4. b. En el caso que se ya se haya arrancado previamente

   * 4b.1 Reconstruir la imagen. Desde la carpeta _odoodock_

     ```bash
     $ docker compose build db 
     ```

     o actualizar el fichero _databases_ de dentro del contenedor

    ```bash
    $ docker cp .databases db:/tmp/.databases
    ```

   * 4b.2 Ejecutar el fichero de creación de bases de datos. Desde la carpeta _odoodock_

     ```bash
     $ docker compose exec db bash /docker-entrypoint-initdb.d/init-databases.sh
     ```


5. Comprobar que la base de datos se ha creado correctamente

   ```bash
   $ docker exec -it odoodock-db-1 psql -U odoodock --dbname postgres
   postgres=# \l
   ```