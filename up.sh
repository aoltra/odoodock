#!/bin/bash

test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }

# cargo las variables desde .env y .services
set -o allexport && source .env && source .services &>/dev/null && set +o allexport 

test -z $SERVER_INFO_PATH_HOST && { echo -e "\033[0;31m[ERROR]\033[0m Variable SERVER_INFO_PATH_HOST no definida en .env. Saliendo..." ; exit; }
test -z $APP_MODULE_PATH_HOST && { echo -e "\033[0;31m[ERROR]\033[0m Variable APP_MODULE_PATH_HOST no definida en .env. Saliendo..." ; exit; }
test -z $DATA_PATH_HOST && { echo -e "\033[0;31m[ERROR]\033[0m Variable DATA_PATH_HOST no definida en .env. Saliendo..." ; exit; }

# se crean, si no existen, los directorios de trabajo
mkdir -p $SERVER_INFO_PATH_HOST/odoo/{logs,repo,config}
mkdir -p $APP_MODULE_PATH_HOST
mkdir -p $DATA_PATH_HOST/odoo/$ODOO_VERSION/$ODOO_SERVER_NAME

test ! -f ./.services && echo -e "\033[0;32m[INFO]\033[0m No existe el fichero .services. Arrancando todos los servicios" 
test -z $SERVICES && echo -e "\033[0;32m[INFO]\033[0m Variable SERVICES no definida o sin servicios en .services.  Arrancando todos los servicios"

echo -e "\033[0;32m[INFO]\033[0m Arrancando los servicios: ${SERVICES[@]}"
exec docker compose up -d "$@" "${SERVICES[@]}"