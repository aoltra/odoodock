#!/bin/bash

# Abort script at first error, when a command exits with non-zero status 
set -e

# DB_ARGS almacena los argumentos del CLI de odoo relativos a la base de datos
DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
# comprueba si está definidos en odoo.conf y si lo están coge su valor
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

# ejecuta odoo a través del módulo debugpy para poder ser depurado con adjutando los módulos
# $@ es una lista con los parámetros que entran a este script 
exec python3 -m debugpy --listen 5678 /usr/bin/odoo "$@" "${DB_ARGS[@]}" --dev=all 
