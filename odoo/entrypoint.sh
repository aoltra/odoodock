#!/bin/bash

if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

# En caso de que no se haya definido en enviroment de docker los parámetros de la base de datos
# los asigna a partir de DB_PORT_5432_TCP_ADDR, DB_PORT_5432_TCP_PORT
# DB_ENV_POSTGRES_USER y DB_ENV_POSTGRES_PASSWORD y en caso de que no estén 
# los toma por defecto
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

exec /runodoo.sh "$@"