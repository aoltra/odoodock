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

La creación de vhost,exchanges y colas se puede realizar desde el script _/rabbitmq/init-rabbit.sh_.

La definición de los elementos a creaer se realiza desde la carpeta _/rabbitmq/definitions_, creando un fichero en formato _yml_ para cada infraestrutura de colas que se desee. _/rabbitmq/init-rabbit.sh_ leerá todos los los ficheros que existan en la carpeta.

> Debezium, crea su propio fichero de definiciones a través del fichero _debezium/debezium_generate.py_. Ver la [documentación de Debezium](/odoodock/services/debezium) para más información.

Cada fichero puede definir vhost, users, queues, exchanges y bindings.


El script se lanza el terminal del contenedor (no es neceasario reiniciarlo ni reconstruirlo).

```bash
# desde el contenedor
# admin admin es el usuario y contraseña del usuario que 
ddocker exec odoodock-rabbitmq-1 bash /init-rabbit.sh admin admin
``` 

> IMPORTANTE: el usuario debe tener permisos para crear colas en un _Virtual Host_ específico. No por ser administrador es posible crear colas en un _Virtual Host_ si no se ha espcificado explícitamente.

