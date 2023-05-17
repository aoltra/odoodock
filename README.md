# Odoodock

**Odoodock** es un entorno de desarrollo de _Odoo_ para _Docker_ pensado con fines eductivos, que sigue la idea propuesta por [laradock](https://laradock.io/introduction/). 

## Características

- Creación de imagen personalizada con la instalación de varias herramientas de apoyo.
- Soporte para _odoo_, _odoo shell_ y _scaffolding_
- Soporte de varios servicios de apoyo:
  - Moodle
  - MariaDB (para Moodle)
- Cada servicio corre en un propio contenedor.
- Scripts para la generación automática de módulos por _scaffolding_, clonado de repositorios _git_, descompresión de paquetes.
- Permite el desarrollo desde dentro del contenedor de Odoo.
- Configuración de serie para realizar depuración en Visual Studio Code.
- Fácilmente configurable a través de variables de entorno.
- Pensado con fines académicos: código muy comentado.
- Soporte para Odoo versión 14.

## Cómo empezar

### Requisitos

- [git](https://git-scm.com/downloads)
- [Visual Studio Code](https://code.visualstudio.com/)
- Docker
   - Opción 1: [Docker Engine](https://docs.docker.com/engine/) >= 23.0.0 con [Docker Compose plugin](https://docs.docker.com/compose/) >= 2.17.0
   - Opción 2: [Docker Desktop](https://docs.docker.com/desktop/)


### Instalación

> A lo largo del documento, el prompt **$** indica comando a introducir en el host, mientras que el prompt **>** indica comando a introducir en el contenedor.

1. Crear la carpeta que contendrá todo lo necesario para el desarrollo los módulos de Odoo, por ejemplo _odoo_dev_

   ```
   $ mkdir odoo_dev
   ```

   > Hay que tener en cuenta que esta carpeta define un servidor de Odoo, en el que puede haber varios módulos en desarrollo.


2. Clonar en su interior _odoodock_

   ```
   $ cd odoo_dev
   $ git clone git@github.com:aoltra/odoodock.git
   ```

3. Entrar en la carpeta _odoodock_

   ```
   $ cd odoodock
   ```

4. Copiar el fichero _.env-example_ a _.env_

   ```
   $ cp .env-example .env
   ```

4. Modificar el fichero _.env_ para adapartalo a nuestras necesidades   

5. Copiar el fichero _.services-example_ a _.services_

   ```
   $ cp .services-example .services
   ```

6. Modificar el fichero _.services_ para incluir los servicios que deseamos arrancar. Los servicios se separan por espacios y van entrecomillados. 

   > El servicio _web_ es obligatorio para arrancar _odoo_

7. Asignar permisos de ejecución para el usuario al fichero _up.sh_ y _create-module.sh_

   ```
   $ chmod u+x ./up.sh
   $ chmod u+x ./create-module.sh
   ```

8. Arrancar los servicios

   ```
   $ ./up.sh
   ```

9. Para comprobar que todo ha ido correctamente, acceder desde un navegador a _localhost:8069_, donde debe aparecer la página del selector de la base de datos.

<center>

![Selector base de datos](./DOCUMENTATION/static/odoo_database_init.png)

</center>

10. Configurar los valores y crear la base de datos

   > Es recomendable almacenar el _master password_ en un fichero aparte

11. Si todo ha ido correctamente, una vez finalizada la creación de la base de datos, deberá cargarse en el navegador la página _Aplicaciones_

![Selector base de datos](./DOCUMENTATION/static/odoo_app_init.png)

## Creando módulos

Existen dos opciones: mediante el uso de _create-module.sh_ o mediante el uso directo de comandos docker.

### Usando el script _create-module.sh_

_create-module.sh_ permite la creación desde fuera del contenedor de un módulo de diferentes formas: a través de la opción scaffold, desde un repo remoto medienta la extracción de un fichero .zip

**O1. Crear un módulo con _odoo scaffold_**

   Ejecutar el script _create-module.sh_ con la opción _-s_. Por ejemplo, desde la carpeta _odoodock_
     
   ```
   $ ./create-module.sh -s mimodulo
   ```

**O2. Clonar un módulo desde un repo existente**

   Ejecutar el script _create-module.sh_ con la opción _-g_. Por ejemplo, desde la carpeta _odoodock_
     
   ```
   $ ./create-module.sh -g https://github.com/user/mimodulo.git
   ```

   > Si el repo es público y todavía no se ha configurado el acceso por _ssh_, lo más rápido es utilizar _https_. Si el acceso se quiere realizar por _ssh_ será necesario configurarlo. Más información en [Configuración git/ssh](#configuración-gitssh)

**O3. Crear un módulo a partir de un fichero zip**

   Ejecutar el script _create-module.sh_ con la opción _-z_. Por ejemplo, desde la carpeta _odoodock_
     
   ```
   $ ./create-module.sh -z ~/downloads/mimodulo.zip
   ```

   > Para el funcionamiento correcto de esta opción es necesario que en el host esté instalado _unzip_

### Mediante comandos docker

Siempre es posible entrar dentro del contendor _odoodck-web-1_ y ejecutar los comandos necesarios.

> ¡Atención!. La ejecución de estos comandos requiere que el proceso de [depuración](#cómo-depurar-módulos-con-vscode) esté en marcha. En caso contrario hay que tener en cuenta que es posible que el contenedor pare su ejecución ya que el proceso que se ejecuta es interrumpido. Al cabo de unos segundos debería volver a reiniciarse de manera automática, aunque siempre es posible forzar el reinicio con _docker compose up -d web_

**O1. Crear un módulo con _odoo scaffold_**

   ```
   $ docker exec -it odoodock-web-1 bash
   > odoo scaffold [nombre_del_modulo] /mnt/extra-addons
   ```
**O2. Clonar un módulo desde un repo existente**

   ```
   $ docker exec -it odoodock-web-1 bash
   > cd /mnt/extra-addons
   > git clone [url_repo]
   ```
> Si el repo es público y todavía no se ha configurado el acceso por _ssh_, lo más rápido es utilizar _https_. Si el acceso se quiere realizar por _ssh_ será necesario configurarlo. Más información en [Configuración git/ssh](#configuración-gitssh)

**O3. Crear un módulo a partir de un fichero zip**

   ```
   $ docker cp [nombre_del_modulo].zip odoodock-web-1:/mnt/extra-addons
   $ docker exec -it odoodock-web-1 bash
   > cd /mnt/extra-addons
   > unzip [nombre_del_modulo].zip
   ```

## Configuración git/ssh

Tanto la instalación de _git_ como la de _ssh_ se configuran desde fichero _.env_ (por defecto se realizan ambas). 

En general, la forma más sencilla de trabajar con un remoto es mediante _ssh_. Para ello, es necesario que en el _home_ del contenedor (en este caso _/var/lib/home_) se almacene la clave privada del usuario y que se tenga permisos sobre ella:

```
$ docker cp ~/.ssh/id_rsa odoodock-web-1:/var/lib/odoo/.ssh
$ docker run --rm --entrypoint /bin/bash -u root -v odoodock_odoo_data:/var/lib/odoo odoodock-web -c "chown odoo:odoo /var/lib/odoo/.ssh/id_rsa"
```
donde _id_rsa_ es el fichero que contiene la clave privada del usuario.

Por último hay que añadir el repo remoto al fichero _known_hosts_. Por ejemplo si el remoto es _github.com_ :

```
$ docker run --rm --entrypoint /bin/bash -v odoodock_odoo_data:/var/lib/odoo odoodock-web -c "ssh-keyscan -t rsa github.com >> ~/.ssh/known_host"
```

> Si _git_ está configurado de manera global en el host (fichero _~/.gitignore_), los datos serán copiados automáticamente al contenedor se arranque el desarrollo remoto (Ver [Cómo depurar módulos con VSCode](#cómo-depurar-módulos-con-vscode))

## Cómo depurar módulos con VSCode

La depuración de módulos se realiza aprovechando la características Remote Development de VSCode. Para utilizarla con Docker es necesario instalar [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers). El acceso se realiza a través del icono <img style="vertical-align:middle" src="./DOCUMENTATION/static/icon_remote_containers.png" width="35" height="39" alt="icono acceso Remote Development"> y, al acceder, muestra en el panel vertical los contenedores y los volúmenes existentes. 

El proceso para poder depurar consiste:

 1. Adjuntar a Visual Studio Code el contenedor _odoodock-web-1_. Esa operación abrirá una nueva instancia de VSCode que será desde la que se trabajará.

 2. Instalar la extensión _Python_
 
 3. Acceder al _Explorer_ y abrir una carpeta (_Open Folder_)

 3. Seleccionar la carpeta _/mnt/extra-addons_

 4. Arrancar desde _Run & Debug_ la configuración _Python: Odoo attach debug_

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
$ docker composer logs
```

**O2. Mostrar en vivo los logs de todos los servicios arrancados**

```
$ docker composer logs --follow
```

**O3. Mostrar en vivo los logs de un único contenedor**

Por ejemplo, para el contenedor _odoodock-web-1_

```
$ docker logs --follow odoodock-web-1
```

## Preguntas frecuentes

* **En ocasiones el contenedor _contenedor odoodock-web-1_ cae o se reinicia**

    Generalmente el problema viene por la modificación (nuevo fichero, modificación de alguno de los existentes...) del directorio de _/mnt/extra-addons_ sin haber lanzado el proceso de [depuración](#cómo-depurar-módulos-con-vscode). En general el contenedor debería reinciarse por si solo y sólo requeriría reacargar la ventana del VSCode, pero una opción más sencilla es tener arrancado el proceso de depuración.

* **¿ Es posible arrancar dos servicios Odoo de manera simultánea?**

   Sí. Para ello únicamente hay que crear otra carpeta y seguir los pasos del proceso de [instalación](#instalación). 
   
   A la hora de configurar el sistema existen dos opciones: compartiendo el mismo SGBD o en diferentes SGBD. 
   
   La configuración del _.env_ usando dos instancias del SGBD (postgres) debe tener en cuenta:

   - Elegir nombres de servidores (ODOO_SERVER_NAME) diferentes en cada carpeta
   - Elegir puertos de Odoo y de ssh (ODOO_PORT, OSOO_SSH_PORT) diferentes en cada carpeta
   - Elegir puertos en los que escucha postgres (ODOO_POSTGRESS_PORT, POSTGRES_PORT) diferentes en cada carpeta
   - Indicar el nombre del contenedor de la base de datos correcto (ODOO_POSTGRESS_HOST)

   > Hay que tener en cuenta que en el caso de más de una instancia los contenedores irán sufijados por números enteros secuenciales: odoodock_web_1, odoodock_web_2, odoodock_db_1, odoodock_db_2...

## Licencia

Odoodock se distribuye bajo licencia GPL 3. Más información en [LICENSE](LICENSE)