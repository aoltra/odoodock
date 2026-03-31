---
layout: page
title: debezium
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

# Debezium

Debezium es una herramienta de **Change Data Capture (CDC)**. Monitoriza el WAL (*Write-Ahead Log*) de PostgreSQL — el registro interno de todas las operaciones de escritura — y publica un evento en RabbitMQ cada vez que se inserta, modifica o borra un registro en las tablas configuradas.

Debezium **solo lee**. Nunca escribe en ninguna base de datos. No modifica el comportamiento de PostgreSQL.


## Configuración

> La forma más correcta de poner en marcha Debezium es partiendo de un escenario en el que las bases de datos a monitorizar ya estén creadas. Ver la documentación sobre Postgres. 


1. Editar `debezium/debezium_tables.yml` con las bases de datos y tablas deseadas:

   ```yaml
   databases:
     odoo_db:
       # Formato: schema.tabla
       - public.res_users
       - public.hr_department
    
     main_db:
       - public.users_core
       - public.departments
   ```

2. Generar los ficheros de configuración

   ```bash
   python3 debezium/debezium_generate.py
   ```

   El script genera los tres ficheros automáticos y muestra un resumen:

   ```bash
   ▶ Leyendo debezium_tables.yml
   [INFO]  Bases de datos encontradas: 2
   [INFO]    odoo_db: 2 tabla(s)
   [INFO]    main_db: 2 tabla(s)

   ▶ Generando ficheros application.properties
   [OK]    odoo_db → debezium/conf/odoo_db/application.properties
   [OK]    main_db → debezium/conf/main_db/application.properties

   ▶ Generando docker-compose.debezium.yml
   [OK]    → docker-compose.debezium.yml

   ▶ Generando rabbitmq/definitions/debezium.yml
   [OK]    → rabbitmq/definitions/debezium.yml
   ```

3. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _debezium_.

4. Arrancar

   ```bash
   ./up.sh
   ```

   `up.sh` detecta `debezium` en `SERVICES` y automáticamente:

   * Comprueba si los ficheros generados están actualizados (y regenera si no)
   * Añade `-f docker-compose.debezium.yml` al comando de compose
   * Sustituye la palabra `debezium` por los servicios reales (por ejemplo, `debezium-odoo-db`, `debezium-main-db`)
   * Arranca todos los servicios

5. Verificar que wal_level es logical
  
   ```bash
   docker exec odoodock-db-1 psql -U odoodock -W --dbname postgres -c "SHOW wal_level;"
   ```

   Debe mostrar `logical`. Si muestra `replica` o `minimal`, PostgreSQL no recogió la configuración — revisar que el servicio `db` se reinició completamente.

6. Una vez que el servicio `db` está corriendo, ejecutar el script de sincronización. Este paso solo es necesario la primera vez o cuando se modifican las tablas monitorizadas:

   ```bash
   chmod +x ./debezium/debezium_sync.sh 
   ./debezium/debezium_sync.sh
   ```

   El script crea el rol `debezium_reader`, aplica los GRANTs necesarios en cada base de datos y crea las publicaciones PostgreSQL. Es idempotente — puede ejecutarse varias veces sin efecto secundario.

   ```bash
   ▶ Gestionando rol debezium_reader
   [OK]    Rol debezium_reader creado

   ▶ Sincronizando publicaciones
   [INFO]  ── Base de datos: odoo_db
   [OK]    Publicación debezium_odoo_db_pub creada
   [INFO]  ── Base de datos: main_db
   [OK]    Publicación debezium_main_db_pub creada
   ```

7. Inicializar colas en RabbitMQ

   ```bash
   docker exec odoodock-rabbitmq-1 bash /init-rabbit.sh \
    "$RABBITMQ_DEFAULT_USER" "$RABBITMQ_DEFAULT_PASSWORD"
   ```

   `init-rabbit.sh` escanea toda la carpeta `definitions/` y aplica todos los ficheros yml, incluido el `debezium.yml` generado en el paso 2.

8. Verificar que Debezium está funcionando

   ```bash
   # Ver logs del conector de odoo_db
   docker logs debezium-odoo-db --tail 30

   # Comprobar que el slot de replicación existe en PostgreSQL
   docker exec db psql -U "$POSTGRES_USER" -c \
    "SELECT slot_name, active FROM pg_replication_slots;"
   ```

Un arranque correcto muestra en los logs algo similar a:

```
INFO  Debezium version: 2.7.x
INFO  Creating replication slot debezium_odoo_db_slot
INFO  Snapshot step 1 - Snapshotting contents of 2 table(s)
INFO  Finished reading 1 record(s) from snapshotting table 'public.res_users'
INFO  Streaming changes from WAL position...
```

## Añadir una tabla nueva o una base de datos nueva a la monitorización

Este es el caso más frecuente durante el desarrollo: ya hay Debezium corriendo y se quiere monitorizar una tabla adicional. 

1. Detener los servicios

   ```bash
   docker compose down
   ```

2. Editar `debezium/debezium_tables.yml` con las bases de datos y tablas deseadas:

   ```yaml
   databases:
     odoo_db:
       # Formato: schema.tabla
       - public.res_users
       - public.hr_department
    
     main_db:
       - public.users_core
       - public.departments

     # nueva base de datos
     new_db: 
       - public.employee    
   ```

3. Regenerar configuraciones 

   ```bash
   python3 debezium/debezium_generate.py
   ```

4. Sincronizar _PostgreSQL_

   ```bash
   ./postgres/debezium_sync.sh
   ```

5. Actualizar colas en _RabbitMQ_ 

   ```bash
   docker exec rabbitmq bash /init-rabbit.sh "$RABBITMQ_DEFAULT_USER" "$RABBITMQ_DEFAULT_PASSWORD" --file /definitions/debezium.yml
   ```

6. Reiniciar el contenedor _Debezium_ afectado:

   El `application.properties` ha cambiado, por lo que _Debezium_ necesita reiniciarse para leerlo: 

   Si es una nueva base de datos:

   ```bash
   mkdir -p "$DATA_PATH_HOST/debezium/new_db"
   docker compose -f docker-compose.yml -f docker-compose.debezium.yml up -d debezium-new_db
   ```

   Si la tabla pertenece a una base de datos que ya existía:

   ```bash
   # la tabla pertenece a odoo_db
   docker compose -f docker-compose.yml -f docker-compose.debezium.yml restart debezium-odoo-db
   ```
