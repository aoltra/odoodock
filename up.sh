#!/bin/bash

# Colores 
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

test ! -f ./.env && { error "No existe el fichero .env. Saliendo.." ; exit; }

# cargo las variables desde .env y .services, tanto del raiz como de los servicios adicionales
set -o allexport && source .env && source .services &>/dev/null && source ./[ads]/.env &>/dev/null && source ./[ads]/.services &>/dev/null && set +o allexport

test -z $SERVER_INFO_PATH_HOST && { error "Variable SERVER_INFO_PATH_HOST no definida en .env. Saliendo..." ; exit; }
test -z $APP_MODULE_PATH_HOST && { error "Variable APP_MODULE_PATH_HOST no definida en .env. Saliendo..." ; exit; }
test -z $DATA_PATH_HOST && { error "Variable DATA_PATH_HOST no definida en .env. Saliendo..." ; exit; }

# se crean, si no existen, los directorios de trabajo
mkdir -p $SERVER_INFO_PATH_HOST/odoo/{logs,repo,config}
mkdir -p $APP_MODULE_PATH_HOST
mkdir -p $DATA_PATH_HOST/odoo/$ODOO_VERSION/$ODOO_SERVER_NAME
mkdir -p $SERVER_INFO_PATH_HOST/n8n_files

test ! -f ./.services && info "No existe el fichero .services. Arrancando todos los servicios" 
test -z $SERVICES && info "Variable SERVICES no definida o sin servicios en .services.  Arrancando todos los servicios"

COMPOSE_FILES=("-f" "docker-compose.yml")   # ficheros compose a combinar

# pgadmin
if [[ " ${SERVICES[*]} " =~ " pgadmin " ]]; then
  mkdir -p $DATA_PATH_HOST/pgadmin
fi

# servicio adicionales
if [ -f "./[ads]/additional-services-compose.yml" ]; then
    info "Incluyendo servicios opcionales..."
    COMPOSE_FILES+=("-f" "./[ads]/additional-services-compose.yml")
else
    warn "No hay servicios adicionales..."
fi

# debezium
DEBEZIUM_COMPOSE_FILE="docker-compose.debezium.yml"
DEBEZIUM_GENERATE_SCRIPT="debezium/debezium_generate.py"

if [[ " ${SERVICES[*]} " =~ " debezium " ]]; then
    info "Debezium activado."
    export ENABLE_DEBEZIUM=true
 
    # Regenerar configuraciones si el script existe y el yml de tablas es más
    # reciente que el compose generado (o si el compose no existe todavía)
    if [[ -f "$DEBEZIUM_GENERATE_SCRIPT" ]]; then
        TABLES_YML="debezium/debezium_tables.yml"
        if [[ ! -f "$DEBEZIUM_COMPOSE_FILE" ]] || \
           [[ "$TABLES_YML" -nt "$DEBEZIUM_COMPOSE_FILE" ]]; then
            info "debezium_tables.yml modificado — regenerando configuraciones..."
            python3 "$DEBEZIUM_GENERATE_SCRIPT" \
                --tables-yml "$TABLES_YML" \
                --compose-out "$DEBEZIUM_COMPOSE_FILE"
        else
            info "Configuraciones Debezium actualizadas, no es necesario regenerar."
        fi
    fi
 
    # Verificar que el fichero compose de Debezium existe
    if [[ ! -f "$DEBEZIUM_COMPOSE_FILE" ]]; then
        error "No se encontró $DEBEZIUM_COMPOSE_FILE."
        error "Ejecuta primero: python3 $DEBEZIUM_GENERATE_SCRIPT"
        exit 1
    fi
 
    # Añadir el fichero compose de Debezium a la lista
    COMPOSE_FILES+=("-f" "$DEBEZIUM_COMPOSE_FILE")
 
    # Crear directorios de datos para cada servicio Debezium
    # Los lee directamente del compose generado para no hardcodear nada
    if command -v python3 &>/dev/null; then
        python3 - "$DEBEZIUM_COMPOSE_FILE" "$DATA_PATH_HOST" <<'EOF'
import yaml, sys, os
from pathlib import Path
 
compose_file = sys.argv[1]
data_path    = sys.argv[2]
 
with open(compose_file) as f:
    compose = yaml.safe_load(f)
 
services = compose.get("services", {})
for svc_name, svc in services.items():
    for vol in svc.get("volumes", []):
        # Los volúmenes de datos de Debezium tienen la forma:
        # ${DATA_PATH_HOST}/debezium/<db>:/debezium/data
        src = vol.split(":")[0] if isinstance(vol, str) else ""
        src = src.replace("${DATA_PATH_HOST}", data_path)
        if "/debezium/" in src and not src.startswith("./"):
            Path(src).mkdir(parents=True, exist_ok=True)
            print(f"  Directorio: {src}")
EOF
    fi
 
    # Quitar 'debezium' de SERVICES — no es un servicio real en el compose principal
    # Los servicios reales se llaman debezium-<db> y están en el compose generado
    SERVICES=("${SERVICES[@]/debezium/}")
    # Añadir todos los servicios Debezium del fichero generado
    DEBEZIUM_SERVICES=$(python3 -c "
import yaml, sys
with open('$DEBEZIUM_COMPOSE_FILE') as f:
    c = yaml.safe_load(f)
print(' '.join(c.get('services', {}).keys()))
" 2>/dev/null)
    SERVICES+=($DEBEZIUM_SERVICES)
    info "Servicios Debezium añadidos: $DEBEZIUM_SERVICES"
 
else
    export ENABLE_DEBEZIUM=false
fi
 
# Arrancando contenedores
info "Arrancando los servicios: ${SERVICES[*]} ${ADSSERVICES[*]}"
exec docker compose -p "$PROJECT_NAME" "${COMPOSE_FILES[@]}" up -d "$@" ${SERVICES[@]} ${ADSSERVICES[@]}
 