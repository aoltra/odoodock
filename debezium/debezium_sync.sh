#!/usr/bin/env bash
# =============================================================================
# debezium_sync.sh
# Sincronización de publicaciones Debezium
# =============================================================================
# Lee debezium_tables.yml y sincroniza las publicaciones en PostgreSQL.
# Se puede ejecutar tantas veces como se quiera: es idempotente.
#
# Uso:
#   ./debezium_sync.sh                  # usa variables de entorno del .env
#   ./debezium_sync.sh --dry-run        # muestra qué haría sin ejecutarlo
#   ./debezium_sync.sh --drop-removed   # elimina tablas quitadas del yml
#
# Requisitos en el host:
#   - docker compose levantado (contenedor db corriendo)
#   - python3 con pyyaml: pip install pyyaml  (solo para parsear el yml)
#   - El .env cargado en el entorno (o las variables POSTGRES_USER, etc.)
# =============================================================================

set -euo pipefail

# Colores 
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()    { echo -e "\n${CYAN}▶ $*${NC}"; }

# Cargar .env automáticamente 
# Busca el .env subiendo por el árbol de directorios desde la ubicación
# del script (máximo 4 niveles). No sobreescribe variables ya definidas
# en el entorno del shell.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 
_load_env() {
    info $1
    local dir="$1"
    local levels=0
    while [[ "$dir" != "/" && $levels -lt 4 ]]; do
        if [[ -f "$dir/.env" ]]; then
            # Extrae solo líneas KEY=VALUE ignorando comentarios y vacías
            while IFS= read -r line; do
                # Saltar comentarios y líneas vacías
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "${line// }" ]] && continue

                # Extraer nombre de variable
                local varname="${line%%=*}"
                # Solo cargar si la variable no está ya definida en el entorno
                if [[ -z "${!varname+x}" ]]; then
                    export "$line"
                fi
            done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$dir/.env" || true)
            info "Variables cargadas desde: $dir/.env"
            return 0
        fi
        dir="$(dirname "$dir")"
        (( ++levels ))
    done
    warn "No se encontró .env (buscado hasta 4 niveles desde $SCRIPT_DIR)"
    warn "Usando variables del entorno del shell o valores por defecto"
}
 
_load_env "$SCRIPT_DIR"

# Opciones 
DRY_RUN=false
DROP_REMOVED=false

for arg in "$@"; do
    case $arg in
        --dry-run)      DRY_RUN=true ;;
        --drop-removed) DROP_REMOVED=true ;;
        --help)
            echo "Uso: $0 [--dry-run] [--drop-removed]"
            echo "  --dry-run       Muestra los cambios sin ejecutarlos"
            echo "  --drop-removed  Elimina tablas que se hayan quitado del yml"
            exit 0 ;;
    esac
done

[[ "$DRY_RUN" == true ]] && warn "Modo DRY-RUN activo — no se ejecutará nada"

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TABLES_YML="${SCRIPT_DIR}/debezium_tables.yml"
DEBEZIUM_PASSWORD="${DEBEZIUM_DB_PASSWORD:-debezium_secret_change_me}"
PG_USER="${POSTGRES_USER:-odoodock}"
PG_CONTAINER="${COMPOSE_PROJECT_NAME:-odoodock}-db-1"

# Intentar detectar el nombre del contenedor si el default no funciona
if ! docker inspect "$PG_CONTAINER" &>/dev/null; then
    PG_CONTAINER=$(docker ps --format '{{.Names}}' | grep '-db' | head -1 || true)
fi

if [[ -z "$PG_CONTAINER" ]]; then
    error "No se encontró el contenedor PostgreSQL. ¿Está levantado el servicio db?"
    exit 1
fi

# Verificaciones 
step "Verificando prerequisitos"

if [[ ! -f "$TABLES_YML" ]]; then
    error "No se encontró $TABLES_YML"
    exit 1
fi
success "Fichero $TABLES_YML encontrado"

if ! docker inspect "$PG_CONTAINER" &>/dev/null; then
    error "Contenedor $PG_CONTAINER no está corriendo"
    exit 1
fi
success "Contenedor PostgreSQL: $PG_CONTAINER"

# Verificar python3 + pyyaml para parsear el yml
if ! python3 -c "import yaml" 2>/dev/null; then
    error "Se necesita python3 con pyyaml. Instala con: pip3 install pyyaml"
    exit 1
fi

# Helper: ejecutar SQL en un contenedor sobre una BD concreta
run_sql() {
    local db="$1"
    local sql="$2"
    local description="${3:-}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "    ${YELLOW}[DRY-RUN]${NC} En '$db': $sql"
        return 0
    fi

    docker exec -i "$PG_CONTAINER" \
        psql -U "$PG_USER" -d "$db" -q -c "$sql" 2>&1
}

# Helper: ejecutar SQL y capturar resultado
query_sql() {
    local db="$1"
    local sql="$2"
    docker exec -i "$PG_CONTAINER" \
        psql -U "$POSTGRES_USER" -d "$db" -t -A -c "$sql" 2>/dev/null || echo ""
}

# Parsear el YAML con Python
step "Leyendo $TABLES_YML"

# Genera pares "base_de_datos tabla" línea por línea
DB_TABLE_PAIRS=$(python3 - <<EOF
import yaml, sys
with open('$TABLES_YML') as f:
    config = yaml.safe_load(f)
databases = config.get('databases', {}) or {}
for db, tables in databases.items():
    if tables:
        for table in tables:
            print(f"{db} {table}")
EOF
)

if [[ -z "$DB_TABLE_PAIRS" ]]; then
    warn "No hay bases de datos definidas en $TABLES_YML"
    exit 0
fi

# Construir lista de bases de datos únicas
DATABASES=$(echo "$DB_TABLE_PAIRS" | awk '{print $1}' | sort -u)

info "Bases de datos a monitorizar:"
for db in $DATABASES; do
    tables=$(echo "$DB_TABLE_PAIRS" | awk -v db="$db" '$1==db {print "      · " $2}')
    echo -e "  ${CYAN}$db${NC}"
    echo "$tables"
done

# Crear rol debezium_reader
step "Gestionando rol debezium_reader"

ROLE_EXISTS=$(query_sql "postgres" \
    "SELECT 1 FROM pg_roles WHERE rolname='debezium_reader';" | xargs)

if [[ "$ROLE_EXISTS" == "1" ]]; then
    success "Rol debezium_reader ya existe"
else
    info "Creando rol debezium_reader..."
    run_sql "postgres" \
        "CREATE ROLE debezium_reader WITH LOGIN REPLICATION PASSWORD '$DEBEZIUM_PASSWORD';"
    success "Rol debezium_reader creado"
fi

# Procesar cada base de datos
step "Sincronizando publicaciones"

for db in $DATABASES; do
    echo ""
    info "── Base de datos: ${CYAN}$db${NC}"

    # Verificar que la base de datos existe
    DB_EXISTS=$(query_sql "postgres" \
        "SELECT 1 FROM pg_database WHERE datname='$db';")

    if [[ "$DB_EXISTS" != "1" ]]; then
        warn "La base de datos '$db' no existe todavía. Saltando (se aplicará cuando exista)."
        continue
    fi

    # Nombre de la publicación para esta BD
    PUB_NAME="debezium_${db}_pub"

    # Tablas definidas en el yml para esta BD
    DESIRED_TABLES=$(echo "$DB_TABLE_PAIRS" | awk -v db="$db" '$1==db {print $2}')

    # Grants de lectura (idempotentes)
    info "Aplicando GRANTs en $db..."
    run_sql "$db" "GRANT USAGE ON SCHEMA public TO debezium_reader;"
    run_sql "$db" "GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_reader;"
    run_sql "$db" \
        "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_reader;"
    run_sql "$db" "GRANT pg_monitor TO debezium_reader;"

    # Publicación
    PUB_EXISTS=$(query_sql "$db" \
        "SELECT 1 FROM pg_publication WHERE pubname='$PUB_NAME';")

    if [[ "$PUB_EXISTS" != "1" ]]; then
        # Crear publicación nueva con todas las tablas del yml
        TABLES_LIST=$(echo "$DESIRED_TABLES" | tr '\n' ',' | sed 's/,$//')
        info "Creando publicación $PUB_NAME con tablas: $TABLES_LIST"
        run_sql "$db" \
            "CREATE PUBLICATION $PUB_NAME FOR TABLE $TABLES_LIST;"
        success "Publicación $PUB_NAME creada"
    else
        # Publicación ya existe — sincronizar tablas
        info "Publicación $PUB_NAME ya existe. Sincronizando tablas..."

        # Tablas actualmente en la publicación
        CURRENT_TABLES=$(query_sql "$db" \
            "SELECT schemaname || '.' || tablename
             FROM pg_publication_tables
             WHERE pubname='$PUB_NAME'
             ORDER BY tablename;")

        # Tablas a añadir (en yml pero no en publicación)
        TABLES_TO_ADD=""
        for table in $DESIRED_TABLES; do
            if ! echo "$CURRENT_TABLES" | grep -qx "$table"; then
                TABLES_TO_ADD="$TABLES_TO_ADD $table"
            fi
        done

        # Tablas a quitar (en publicación pero no en yml)
        TABLES_TO_REMOVE=""
        for table in $CURRENT_TABLES; do
            if ! echo "$DESIRED_TABLES" | grep -qx "$table"; then
                TABLES_TO_REMOVE="$TABLES_TO_REMOVE $table"
            fi
        done

        # Añadir tablas nuevas
        for table in $TABLES_TO_ADD; do
            # Verificar que la tabla existe en la BD
            SCHEMA=$(echo "$table" | cut -d. -f1)
            TNAME=$(echo "$table" | cut -d. -f2)
            TABLE_EXISTS=$(query_sql "$db" \
                "SELECT 1 FROM information_schema.tables
                 WHERE table_schema='$SCHEMA' AND table_name='$TNAME';")

            if [[ "$TABLE_EXISTS" == "1" ]]; then
                info "  Añadiendo tabla $table a $PUB_NAME"
                run_sql "$db" \
                    "ALTER PUBLICATION $PUB_NAME ADD TABLE $table;"
                success "  $table añadida"
            else
                warn "  Tabla $table no existe en $db — saltando"
            fi
        done

        # Quitar tablas eliminadas del yml (solo si --drop-removed)
        if [[ -n "$TABLES_TO_REMOVE" ]]; then
            if [[ "$DROP_REMOVED" == true ]]; then
                for table in $TABLES_TO_REMOVE; do
                    info "  Eliminando tabla $table de $PUB_NAME"
                    run_sql "$db" \
                        "ALTER PUBLICATION $PUB_NAME DROP TABLE $table;"
                    success "  $table eliminada de la publicación"
                done
            else
                warn "  Tablas en publicación pero no en yml (usa --drop-removed para quitarlas):"
                for table in $TABLES_TO_REMOVE; do
                    echo "    · $table"
                done
            fi
        fi

        if [[ -z "$TABLES_TO_ADD" && -z "$TABLES_TO_REMOVE" ]]; then
            success "Publicación $PUB_NAME ya está sincronizada"
        fi
    fi
done

# Resumen
echo ""
step "Resumen del estado actual"

for db in $DATABASES; do
    DB_EXISTS=$(query_sql "postgres" \
        "SELECT 1 FROM pg_database WHERE datname='$db';")
    [[ "$DB_EXISTS" != "1" ]] && continue

    PUB_NAME="debezium_${db}_pub"
    echo -e "  ${CYAN}$db${NC} → publicación ${CYAN}$PUB_NAME${NC}:"

    CURRENT=$(query_sql "$db" \
        "SELECT '    · ' || schemaname || '.' || tablename
         FROM pg_publication_tables
         WHERE pubname='$PUB_NAME'
         ORDER BY tablename;")

    if [[ -n "$CURRENT" ]]; then
        echo "$CURRENT"
    else
        echo "    (sin tablas)"
    fi
done

echo ""
success "Sincronización completada"

if [[ "$DRY_RUN" == true ]]; then
    warn "DRY-RUN: ningún cambio fue aplicado realmente"
fi
