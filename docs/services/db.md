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

2. Modificar el fichero _.databases_. Por ejemplo para añadir una base de datos para la gestión de _Keycloak_

   ```text
   # lista de bases de datos:usuario:contraseña a crear en el contenedor
   KEYCLOAK:keycloak:secret123
   ```
   donde:
  
   - _KEYCLOAK_: es el nombre de la base de datos
   - _keycloak:_ el nombre del usuario con acceso total
   - _secret213_: contraseña del usuario (no se pueden utilizar los dos puntos ( : ) como parte de la contraseña)
   - Las líneas que empiezan por # se consideran comentarios


   > Importante: el nombre de la base de datos puede ser cualquiera, pero si es una base de datos creada para otro servicio de **odoodock** es necesario utilizar el mismo nombre que el utilizado en el fichero _.env_ de configuración. En este caso el definido en la variable `POSTGRES_KEYCLOAK_DB=KEYCLOAK`

   > Importante: el usuario que creará la base de datos es el definido en la variable `POSTGRES_USER` que suele estar asignada a _odoodock_. El usuario creado desde el fichero _.databases_ tendrá permisos totales pero solo sobre la base de datos asociada.

4. Crear las bases de datos 

   > En el caso de que sea el primer arranque (la imagen no está contruida) del servicio las bases de datos se crearan al crear la imagen

   En el caso que se ya se haya arrancado previamente hay dos opciones:

   * a) Reconstruir la imagen. Desde la carpeta _odoodock_

     ```bash
     $ docker compose build db 
     ```
     
   * b) Actualizar el fichero _databases_ de dentro del contenedor

     ```bash
     $ docker cp .databases db:/tmp/.databases
     ```

     Ejecutar el fichero de creación de bases de datos. Desde la carpeta _odoodock_

     ```bash
     $ docker compose exec db bash /docker-entrypoint-initdb.d/init-databases.sh
     ```


5. Comprobar que la base de datos se ha creado correctamente

   ```bash
   $ docker exec -it odoodock-db-1 psql -U odoodock --dbname postgres
   > postgres=# \l
   ```

> MUY IMPORTANTE. Si se utiliza este servicio para dar soporte a otros servicios, por ejemplo _keycloak_, si para crear la bd no se ha reconstruido la imagen es posible que el servicio no arranque correctamente ya que la base de datos no estaría creada. La solución más sencilla consiste en reiniciar los contenedores.