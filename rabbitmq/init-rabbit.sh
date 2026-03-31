#!/bin/bash
# =============================================================================
# init-rabbit.sh — Maya AQSS
# Inicializa RabbitMQ leyendo ficheros de definición en definitions/
# =============================================================================
# Uso (desde dentro del contenedor o desde el host vía docker exec):
#   ./init-rabbit.sh <admin_user> <admin_pass> [--dry-run] [--file fichero.yml]
#
# El script escanea todos los .yml en definitions/ y aplica:
#   - Vhosts
#   - Usuarios y permisos
#   - Exchanges
#   - Colas (con argumentos opcionales: DLQ, delivery-limit, TTL...)
#   - Bindings exchange → cola
#
# Es idempotente: puede ejecutarse varias veces sin efecto secundario.
# Para aplicar solo un fichero: --file definitions/maya_sync.yml
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

# Parámetros
ADMIN_USER="${1:-}"
ADMIN_PASS="${2:-}"
DRY_RUN=false
SINGLE_FILE=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)        DRY_RUN=true ;;
        --file)           SINGLE_FILE="$2"; shift ;;
        --help)
            echo "Uso: $0 <admin_user> <admin_pass> [--dry-run] [--file fichero.yml]"
            exit 0 ;;
    esac
    shift
done

if [[ -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
    error "Faltan parámetros. Uso: $0 <admin_user> <admin_pass>"
    exit 1
fi

[[ "$DRY_RUN" == true ]] && warn "Modo DRY-RUN — no se ejecutará nada"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS_DIR="${SCRIPT_DIR}/definitions"

# Esperar a RabbitMQ 
step "Esperando a que RabbitMQ esté disponible"
until rabbitmq-diagnostics -q check_port_connectivity 2>/dev/null; do
    echo "  RabbitMQ aún no responde... reintentando en 2s"
    sleep 2
done
sleep 4  # margen para la API de management
success "RabbitMQ disponible"

# Verificar python3 + pyyaml
if ! python3 -c "import yaml" 2>/dev/null; then
    error "Se necesita python3 con pyyaml dentro del contenedor."
    error "Añade al Dockerfile de rabbitmq: RUN pip3 install pyyaml"
    exit 1
fi

# Resolver variables de entorno en valores del yml 
# Sustituye ${VAR} por el valor de la variable de entorno correspondiente
resolve_env() {
    echo "$1" | python3 -c "
import sys, os, re
text = sys.stdin.read()
def replace(m):
    var = m.group(1)
    val = os.environ.get(var, '')
    if not val:
        import sys
        print(f'[WARN] Variable de entorno {var} no definida', file=sys.stderr)
    return val
print(re.sub(r'\$\{(\w+)\}', replace, text))
"
}

#  Helper: rabbitmqadmin con vhost 
rmq() {
    local vhost="$1"; shift
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "    ${YELLOW}[DRY-RUN]${NC} rabbitmqadmin --vhost=$vhost $*"
        return 0
    fi
    rabbitmqadmin \
        --username="$ADMIN_USER" \
        --password="$ADMIN_PASS" \
        --vhost="$vhost" \
        "$@" 2>&1 | grep -v "^$" || true
}

rmq_ctl() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "    ${YELLOW}[DRY-RUN]${NC} rabbitmqctl $*"
        return 0
    fi
    rabbitmqctl "$@" 2>&1 | grep -v "^$" || true
}

# Parsear y aplicar un fichero de definición 
apply_definition() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    echo ""
    step "Aplicando: ${CYAN}$filename${NC}"

    # Leer y parsear el YAML con Python
    # Genera comandos de shell que luego ejecutamos
    # Python parsea el YAML completo y emite líneas de comandos estructuradas.
    # Los argumentos de cola se pasan como JSON en una sola línea codificada
    # en base64 para evitar problemas con espacios y caracteres especiales.
    local parsed
    parsed=$(python3 - "$file" <<'PYEOF'
import yaml, sys, json, base64, os, re

with open(sys.argv[1]) as f:
    raw = f.read()

def resolve(text):
    def rep(m):
        val = os.environ.get(m.group(1), '')
        if not val:
            print(f"WARN variable_no_definida {m.group(1)}", file=sys.stderr)
        return val
    return re.sub(r'\$\{(\w+)\}', rep, text)

config   = yaml.safe_load(resolve(raw))
vhost    = config.get('vhost', '/')
users    = config.get('users',    []) or []
exchanges= config.get('exchanges',[]) or []
queues   = config.get('queues',   []) or []
bindings = config.get('bindings', []) or []

# VHOST siempre lo primero para que esté creado antes de usarlo
print(f"VHOST {vhost}")

for u in users:
    name = u['name']
    pw   = u.get('password', '')
    tags = u.get('tags', '')
    print(f"USER {name} {pw} {tags}")
    for p in u.get('permissions', []):
        # Asegurar que el vhost del permiso también se crea
        pv = p['vhost']
        print(f"ENSURE_VHOST {pv}")
        print(f"PERM {pv} {name} {p.get('configure','.*')} {p.get('write','.*')} {p.get('read','.*')}")

for e in exchanges:
    print(f"EXCHANGE {e['name']} {e.get('type','topic')} {str(e.get('durable',True)).lower()}")

for q in queues:
    args     = q.get('arguments', {}) or {}
    # Codificar args en base64 para evitar problemas con espacios en la línea
    args_b64 = base64.b64encode(json.dumps(args).encode()).decode()
    qtype    = q.get('type', 'classic')
    durable  = str(q.get('durable', True)).lower()
    print(f"QUEUE {q['name']} {qtype} {durable} {args_b64}")

for b in bindings:
    print(f"BINDING {b['exchange']} {b['queue']} {b.get('routing_key','#')}")
PYEOF
)

    local vhost="/"
    while IFS= read -r line; do
        read -ra parts <<< "$line"
        case "${parts[0]}" in

            VHOST)
                vhost="${parts[1]}"
                info "Vhost: $vhost"
                rmq_ctl add_vhost "$vhost" 2>/dev/null || true
                rmq_ctl set_permissions -p "$vhost" "$ADMIN_USER" ".*" ".*" ".*"
                success "Vhost '$vhost' configurado"
                ;;

            # Crea un vhost adicional referenciado en permisos de usuario
            ENSURE_VHOST)
                local ev="${parts[1]}"
                if [[ "$ev" != "$vhost" ]]; then
                    rmq_ctl add_vhost "$ev" 2>/dev/null || true
                    rmq_ctl set_permissions -p "$ev" "$ADMIN_USER" ".*" ".*" ".*"
                fi
                ;;

            USER)
                local uname="${parts[1]}"
                local upass="${parts[2]}"
                local utags="${parts[3]:-}"
                info "Usuario: $uname (tags: ${utags:-none})"
                rmq_ctl add_user "$uname" "$upass" 2>/dev/null || \
                    rmq_ctl change_password "$uname" "$upass" 2>/dev/null || true
                if [[ -n "$utags" && "$utags" != '""' ]]; then
                    rmq_ctl set_user_tags "$uname" "$utags" || true
                fi
                success "Usuario '$uname' listo"
                ;;

            PERM)
                local pvhost="${parts[1]}"
                local puname="${parts[2]}"
                local pconfigure="${parts[3]}"
                local pwrite="${parts[4]}"
                local pread="${parts[5]}"
                rmq_ctl set_permissions -p "$pvhost" "$puname" \
                    "$pconfigure" "$pwrite" "$pread" 2>/dev/null || true
                success "Permisos '$puname' en '$pvhost'"
                ;;

            EXCHANGE)
                local ename="${parts[1]}"
                local etype="${parts[2]}"
                local edurable="${parts[3]}"
                info "Exchange: $ename (type=$etype)"
                rmq "$vhost" declare exchange \
                    name="$ename" \
                    type="$etype" \
                    durable="$edurable"
                success "Exchange '$ename' declarado"
                ;;

            QUEUE)
                local qname="${parts[1]}"
                local qtype="${parts[2]}"
                local qdurable="${parts[3]}"
                local qargs_b64="${parts[4]:-}"
                info "Cola: $qname (type=$qtype)"

                # Decodificar argumentos desde base64
                local qargs_json="{}"
                if [[ -n "$qargs_b64" ]]; then
                    qargs_json=$(echo "$qargs_b64" | base64 -d 2>/dev/null || echo "{}")
                fi

                # rabbitmqadmin acepta argumentos x-* solo mediante
                # el parámetro "arguments" como JSON entre comillas simples
                if [[ "$qargs_json" != "{}" ]]; then
                    if [[ "$DRY_RUN" == true ]]; then
                        echo -e "    ${YELLOW}[DRY-RUN]${NC} rabbitmqadmin declare queue name=$qname queue_type=$qtype durable=$qdurable arguments='$qargs_json'"
                    else
                        rabbitmqadmin \
                            --username="$ADMIN_USER" \
                            --password="$ADMIN_PASS" \
                            --vhost="$vhost" \
                            declare queue \
                            name="$qname" \
                            queue_type="$qtype" \
                            durable="$qdurable" \
                            arguments="$qargs_json" 2>&1 | grep -v "^$" || true
                    fi
                else
                    rmq "$vhost" declare queue \
                        name="$qname" \
                        queue_type="$qtype" \
                        durable="$qdurable"
                fi
                success "Cola '$qname' declarada"
                ;;

            BINDING)
                local bexchange="${parts[1]}"
                local bqueue="${parts[2]}"
                local bkey="${parts[3]}"
                info "Binding: $bexchange → $bqueue (key=$bkey)"
                rmq "$vhost" declare binding \
                    source="$bexchange" \
                    destination_type="queue" \
                    destination="$bqueue" \
                    routing_key="$bkey"
                success "Binding '$bkey' creado"
                ;;

            WARN)
                warn "Variable de entorno no definida: ${parts[2]:-}"
                ;;
        esac
    done <<< "$parsed"
}

# Seleccionar ficheros a procesar
step "Buscando ficheros de definición"

if [[ -n "$SINGLE_FILE" ]]; then
    if [[ ! -f "$SINGLE_FILE" ]]; then
        error "Fichero no encontrado: $SINGLE_FILE"
        exit 1
    fi
    FILES=("$SINGLE_FILE")
    info "Aplicando solo: $SINGLE_FILE"
else
    if [[ ! -d "$DEFINITIONS_DIR" ]]; then
        error "Directorio no encontrado: $DEFINITIONS_DIR"
        exit 1
    fi
    mapfile -t FILES < <(find "$DEFINITIONS_DIR" -name "*.yml" | sort)
    info "Encontrados ${#FILES[@]} fichero(s) en $DEFINITIONS_DIR"
    for f in "${FILES[@]}"; do
        echo "  · $(basename "$f")"
    done
fi

# Aplicar cada fichero
for file in "${FILES[@]}"; do
    apply_definition "$file"
done

# Resumen 
echo ""
step "Resumen de la configuración aplicada"

if [[ "$DRY_RUN" != true ]]; then
    echo ""
    info "Vhosts:"
    rabbitmqctl list_vhosts 2>/dev/null | tail -n +2 | awk '{print "  · "$1}'

    echo ""
    info "Usuarios:"
    rabbitmqctl list_users 2>/dev/null | tail -n +2 | awk '{print "  · "$1" ["$2"]"}'
fi

echo ""
success "¡Configuración de RabbitMQ completada!"
[[ "$DRY_RUN" == true ]] && warn "DRY-RUN: ningún cambio fue aplicado realmente"