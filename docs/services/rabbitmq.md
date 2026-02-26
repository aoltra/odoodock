---
layout: page
title: rabbitmq
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## Rabbit MQ

Agente de mensajes (message broker) de código abierto, distribuido y de alto rendimiento que facilita la comunicación asíncrona entre aplicaciones.

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _rabbitmq_.

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

3. Abrir el navegador y acceder a la URL _http://locahost:15672_ que da aceso al panel de administración

4. En la página de login usar como credenciales por defecto:

        Username : admin 
        Password : admin

5. El puerto para la comunicación con las colas es por defecto el 5672 o el configurado en la variable `$RABBIT_PORT`


### Creación de colas

La creación de colas se puede realizar desde el script _/rabbitmq/init-rabbit.sh_.

El script permite:

* Crear Virtual Hosts

  ```bash
  # Creación de Virtual Host llamado notifications
  rabbitmqctl add_vhost notifications || true
  ``` 

* Crear usuarios

  ```bash
  # creación de un usuario n8n_user
  rabbitmqctl add_user n8n_user n8n_password123 || true
  ``` 

* Asignar permisos

  ```bash
  # asignación de permisos en el host notifications al usuario n89n_user
  # se le asignan pernmisos de creación, escritura y lectura
  rabbitmqctl set_permissions -p notifications n8n_user ".*" ".*" ".*"
  ``` 
   
* Creación de colas 

  ```bash
  # creación de la cola de tipo classic dev.welcome.email.send 
  # dentro del host notifications
  crear_cola "notifications" "dev.welcome.email.send" "classic"
  ``` 

* Creación y enlazado de exchanges

  ```bash
  # creación de un exchange tipo topic dev.ex.message.logs 
  # dentro del host logs
  crear_exchange "logs" "dev.ex.message.logs" "topic"

  # Enlace con la cola dev.q.message.logs con el filtro #.error (todos las etiquedas que acaben en .error)
  enlazar_exchange_con_cola "logs" "dev.ex.message.logs" "dev.q.message.logs" "#.error"
  ``` 

El fichero puede ser editado manualmente y lanzado desde el terminal del contenedor (no es neceasario reiniciarlo ni reconstruirlo).

```bash
docker exec -it odoodock-rabbitmq-1 bash
# desde el contenedor
# admin admin es el usuario y contraseña del usuario que creará los virtual host y las tablas
/bin/bash init-rabbit.sh admin admin
``` 

> IMPORTANTE: el usuario debe tener permisos para crear colas en un _Virtual Host_ específico. No por ser administrador es posible crear colas en un _Virtual Host_ si no se ha espcificado explícitamente.

