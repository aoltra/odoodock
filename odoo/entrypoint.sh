#!/bin/bash

set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

# En caso de que no se haya definido en enviroment de docker los parámetros de la base de datos
# los asigna a partir de DB_PORT_5432_TCP_ADDR, DB_PORT_5432_TCP_PORT
# DB_ENV_POSTGRES_USER y DB_ENV_POSTGRES_PASSWORD y en caso de que no estén 
# los toma por defecto
: ${HOST:=${ODOO_POSTGRESS_HOST:='db'}}
: ${PORT:=${ODOO_POSTGRESS_PORT:=5432}}
: ${USER:=${ODOO_POSTGRESS_USER:='odoodock'}}}
: ${PASSWORD:=${ODOO_POSTGRESS_PASSWORD:='secret123'}}}

# ============================================================
# VARIABLES DE CONFIGURACIÓN PARA INICIALIZACIÓN AUTOMÁTICA
# ============================================================
# Se leen desde variables de entorno (definidas en .env)
: ${ODOO_VERSION:=19}
: ${ODOO_DB_NAME:=odoo}
: ${ODOO_MASTER_PASSWORD:=admin}
: ${ODOO_DB_LANGUAGE:=en_US}
: ${ODOO_DB_COUNTRY:=ES}
: ${ODOO_ADMIN_EMAIL:=admin}
: ${ODOO_ADMIN_PASSWORD:=admin}
: ${ODOO_DB_WITH_DEMO:=false}
: ${ODOO_GIT_REPOS:=""}
: ${ODOO_INIT_MODULES:=""}

# Directorio donde se clonarán los repos (volumen mapeado a /mnt/extra-addons)
ADDONS_DIR="/mnt/extra-addons"
# Flag para saber si ya se inicializó (persiste en el volumen de datos)
INIT_FLAG="/var/lib/odoo/.odoo_initialized"

# ============================================================
# FUNCIÓN: Comparar dos versiones numéricas
# Devuelve 0 (true) si version1 >= version2
# ============================================================
version_ge() {
    local v1="$1"
    local v2="$2"
    # Si alguna versión está vacía, considerarla como 0
    [ -z "$v1" ] && v1=0
    [ -z "$v2" ] && v2=0
    # Comparar como enteros
    if [ "$v1" -ge "$v2" ] 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# FUNCIÓN: Esperar a que PostgreSQL esté disponible
# ============================================================
wait_for_postgres() {
    echo "[entrypoint] Esperando a que PostgreSQL esté disponible en ${HOST}:${PORT}..."
    local max_attempts=60
    local attempt=0
    while ! PGPASSWORD="${PASSWORD}" pg_isready -h "$HOST" -p "$PORT" -U "$USER" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo "[entrypoint] ERROR: PostgreSQL no está disponible después de ${max_attempts} intentos."
            exit 1
        fi
        echo "[entrypoint] PostgreSQL no disponible aún, reintentando en 2s... (${attempt}/${max_attempts})"
        sleep 2
    done
    echo "[entrypoint] ✅ PostgreSQL está listo."
}

# ============================================================
# FUNCIÓN: Verificar si la base de datos ya existe
# ============================================================
db_exists() {
    local db_name="$1"
    local result
    result=$(PGPASSWORD="${PASSWORD}" psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" 2>/dev/null || echo "")
    [ "$result" = "1" ]
}

# ============================================================
# FUNCIÓN: Clonar repositorios Git en el directorio de addons
# ============================================================
clone_repos() {
    if [ -z "$ODOO_GIT_REPOS" ]; then
        echo "[entrypoint] No hay repositorios Git configurados para clonar."
        return 0
    fi

    echo "[entrypoint] Clonando repositorios de módulos en ${ADDONS_DIR}..."

    # Asegurar que el directorio existe
    mkdir -p "$ADDONS_DIR"

    # Convertir la lista separada por comas en un array
    IFS=',' read -ra REPOS <<< "$ODOO_GIT_REPOS"

    for repo_url in "${REPOS[@]}"; do
        # Limpiar espacios
        repo_url=$(echo "$repo_url" | xargs)

        if [ -z "$repo_url" ]; then
            continue
        fi

        # Extraer el nombre del repo de la URL
        repo_name=$(basename "$repo_url" .git)
        repo_path="${ADDONS_DIR}/${repo_name}"

        if [ -d "$repo_path" ]; then
            echo "[entrypoint]   📁 ${repo_name} ya existe"
            #, actualizando con git pull..."
            #(cd "$repo_path" && git pull --quiet) || echo "[entrypoint]   ⚠️ No se pudo actualizar ${repo_name}, continuando..."
        else
            echo "[entrypoint]   📥 Clonando ${repo_name} desde ${repo_url}..."
            git clone --quiet "$repo_url" "$repo_path" || {
                echo "[entrypoint]   ❌ ERROR al clonar ${repo_url}"
                continue
            }
            echo "[entrypoint]   ✅ ${repo_name} clonado correctamente."
        fi
    done
    
    echo "[entrypoint] Fin del clonado de los repos"
}

# ============================================================
# FUNCIÓN: Inicializar la base de datos (método clásico compatible)
# ============================================================
# NOTA: El comando "odoo db init" de Odoo 19 tiene un bug con el parser
# de argumentos cuando se mezclan --db_host, --language, etc.
# Usamos el método clásico: odoo -d DB --stop-after-init --no-http -i base
# que funciona en todas las versiones y crea + inicializa la DB automáticamente.
# ============================================================
init_database() {
    echo "[entrypoint] =========================================================="
    echo "[entrypoint] 🚀 INICIALIZANDO BASE DE DATOS POR PRIMERA VEZ"
    echo "[entrypoint] =========================================================="
    echo "[entrypoint]   Base de datos: ${ODOO_DB_NAME}"
    echo "[entrypoint]   Idioma:        ${ODOO_DB_LANGUAGE}"
    echo "[entrypoint]   País:          ${ODOO_DB_COUNTRY}"
    echo "[entrypoint]   Admin email:   ${ODOO_ADMIN_EMAIL}"
    echo "[entrypoint]   Admin pass:    ${ODOO_ADMIN_PASSWORD}"
    echo "[entrypoint]   Demo data:     ${ODOO_DB_WITH_DEMO}"
    echo "[entrypoint] =========================================================="

    # Detectar el ejecutable de Odoo
    if command -v odoo &> /dev/null; then
        ODOO_BIN="odoo"
    elif command -v odoo-bin &> /dev/null; then
        ODOO_BIN="odoo-bin"
    else
        ODOO_BIN="/usr/bin/odoo"
    fi

    # ============================================================
    # MÉTODO CLÁSICO (compatible con todas las versiones de Odoo)
    # ============================================================
    # -d DB_NAME: especifica la base de datos (Odoo la crea si no existe)
    # --stop-after-init: detiene el servidor tras inicializar
    # --no-http: no inicia el servidor web durante la inicialización
    # -i base: instala el módulo base (inicializa la estructura de la DB)
    # --load-language: carga el idioma especificado
    # --without-demo: controla si se instalan datos de demo
    # ============================================================

    local init_args=(
        "-d" "${ODOO_DB_NAME}"
        "--db_host=${HOST}"
        "--db_port=${PORT}"
        "--db_user=${USER}"
        "--db_password=${PASSWORD}"
        "--stop-after-init"
        "--no-http"
        "-i" "base"
        "--load-language=${ODOO_DB_LANGUAGE}"
    )

    # Añadir --with-demo si está activado
    if [ "$ODOO_DB_WITH_DEMO" = "true" ] || [ "$ODOO_DB_WITH_DEMO" = "True" ]; then
        init_args+=("--with-demo")
    else
        # En Odoo 19, --without-demo sin valor (o --without-demo=true) desactiva demo
        init_args+=("--without-demo")
    fi

    echo "[entrypoint] Ejecutando: ${ODOO_BIN} ${init_args[*]}"

    $ODOO_BIN "${init_args[@]}" || {
        echo "[entrypoint] ❌ ERROR: Falló la inicialización de la base de datos."
        exit 1
    }

    echo "[entrypoint] ✅ Base de datos '${ODOO_DB_NAME}' inicializada correctamente."
    echo "[entrypoint]    (Idioma: ${ODOO_DB_LANGUAGE}, País: ${ODOO_DB_COUNTRY})"

    # ============================================================
    # CONFIGURAR PAÍS DE LA COMPAÑÍA PRINCIPAL (res.company)
    # ============================================================
    # El método clásico no permite especificar --country directamente.
    # Configuramos el país de la compañía principal mediante un script Python.
    # ============================================================
    if [ -n "$ODOO_DB_COUNTRY" ] || [ -n "$ODOO_ADMIN_EMAIL" ] || [ -n "$ODOO_ADMIN_PASSWORD" ]; then
        echo "[entrypoint] Configurando país de la compañía y credenciales de admin..."

        python3 <<PYEOF
import sys
sys.path.insert(0, '/usr/lib/python3/dist-packages')

import odoo
from odoo import api, SUPERUSER_ID
from odoo.modules.registry import Registry

# Configurar conexión a PostgreSQL
odoo.tools.config['db_host'] = '${HOST}'
odoo.tools.config['db_port'] = '${PORT}'
odoo.tools.config['db_user'] = '${USER}'
odoo.tools.config['db_password'] = '${PASSWORD}'

# Obtener el registry de la base de datos (Odoo 19 usa Registry.new)
registry = Registry.new('${ODOO_DB_NAME}')

with registry.cursor() as cr:
    # Crear el Environment directamente
    env = api.Environment(cr, SUPERUSER_ID, {})

    # --- Configurar país de la compañía principal ---
    if '${ODOO_DB_COUNTRY}':
        country = env['res.country'].search([('code', '=', '${ODOO_DB_COUNTRY}')], limit=1)
        if country:
            company = env['res.company'].search([], limit=1, order='id')
            if company:
                vals = {'country_id': country.id}
                if country.currency_id:
                    vals['currency_id'] = country.currency_id.id
                company.write(vals)
                print(f"[entrypoint]    ✅ País configurado: {country.name} ({country.code})")
            else:
                print("[entrypoint]    ⚠️ No se encontró compañía principal")
        else:
            print(f"[entrypoint]    ⚠️ No se encontró país con código: ${ODOO_DB_COUNTRY}")

    # --- Configurar credenciales del administrador ---
    if '${ODOO_ADMIN_EMAIL}' != 'admin' or '${ODOO_ADMIN_PASSWORD}' != 'admin':
        user = env['res.users'].search([('login', '=', 'admin')], limit=1)
        if user:
            vals = {}
            if '${ODOO_ADMIN_EMAIL}' and '${ODOO_ADMIN_EMAIL}' != 'admin':
                vals['login'] = '${ODOO_ADMIN_EMAIL}'
                vals['email'] = '${ODOO_ADMIN_EMAIL}'
            if '${ODOO_ADMIN_PASSWORD}' and '${ODOO_ADMIN_PASSWORD}' != 'admin':
                vals['password'] = '${ODOO_ADMIN_PASSWORD}'

            if vals:
                user.write(vals)
                print(f"[entrypoint]    ✅ Admin actualizado: login={user.login}")
        else:
            print("[entrypoint]    ⚠️ No se encontró usuario admin")

    cr.commit()
PYEOF
    fi
}

# ============================================================
# FUNCIÓN: Instalar dependencias Python de los módulos
# Busca requirements.txt en cada módulo de ADDONS_DIR y los instala
# ============================================================
install_python_requirements() {
    echo "[entrypoint] 🐍 Buscando requirements.txt en módulos de ${ADDONS_DIR}..."

    local found=0

    # Buscar requirements.txt en la raíz de cada submódulo
    for dir in "$ADDONS_DIR"/*/; do
        local req_file="${dir}requirements.txt"
        if [ -f "$req_file" ]; then
            local module_name
            module_name=$(basename "$dir")
            echo "[entrypoint]   📄 Encontrado: ${req_file} (módulo: ${module_name})"
            echo "[entrypoint]   Instalando dependencias Python de '${module_name}'..."
            pip install --quiet --break-system-packages -r "$req_file" || {
                echo "[entrypoint]   ❌ ERROR instalando requirements de '${module_name}'."
                echo "[entrypoint]      Revisa ${req_file} y vuelve a intentarlo."
                exit 1
            }
            echo "[entrypoint]   ✅ Dependencias de '${module_name}' instaladas."
            found=$((found + 1))
        fi
    done

    # Buscar también requirements.txt en la raíz de ADDONS_DIR
    # (para repos que agrupan varios módulos con un requirements.txt común)
    if [ -f "${ADDONS_DIR}/requirements.txt" ]; then
        echo "[entrypoint]   📄 Encontrado: ${ADDONS_DIR}/requirements.txt (raíz de addons)"
        pip install --quiet --break-system-packages -r "${ADDONS_DIR}/requirements.txt" || {
            echo "[entrypoint]   ❌ ERROR instalando requirements de la raíz de addons."
            exit 1
        }
        echo "[entrypoint]   ✅ Dependencias de la raíz de addons instaladas."
        found=$((found + 1))
    fi

    if [ "$found" -eq 0 ]; then
        echo "[entrypoint]   ℹ️ No se encontró ningún requirements.txt en los módulos."
    else
        echo "[entrypoint] ✅ Dependencias Python instaladas (${found} requirements.txt procesados)."
    fi
}

# ============================================================
# FUNCIÓN: Instalar módulos adicionales
# ============================================================
install_modules() {
    if [ -z "$ODOO_INIT_MODULES" ]; then
        echo "[entrypoint] No hay módulos adicionales configurados para instalar."
        return 0
    fi

    echo "[entrypoint] =========================================================="
    echo "[entrypoint] 📦 INSTALANDO MÓDULOS: ${ODOO_INIT_MODULES}"
    echo "[entrypoint] =========================================================="

    # Construir addons-path incluyendo el directorio de addons extra
    local addons_path="/usr/lib/python3/dist-packages/odoo/addons"
    if [ -d "$ADDONS_DIR" ]; then
        # Añadir todos los subdirectorios de ADDONS_DIR que contengan __manifest__.py
        for dir in "$ADDONS_DIR"/*; do
            if [ -d "$dir" ] && [ -f "$dir/__manifest__.py" ]; then
                addons_path="${addons_path},${dir}"
            fi
        done
        # También añadir el propio ADDONS_DIR por si hay módulos sueltos
        addons_path="${addons_path},${ADDONS_DIR}"
    fi

    # Detectar el ejecutable de Odoo
    if command -v odoo &> /dev/null; then
        ODOO_BIN="odoo"
    elif command -v odoo-bin &> /dev/null; then
        ODOO_BIN="odoo-bin"
    else
        ODOO_BIN="/usr/bin/odoo"
    fi

    # NOTA: Los argumentos cortos (-d, -i) NO usan '=' en Odoo
    local install_args=(
        "-d" "${ODOO_DB_NAME}"
        "--db_host=${HOST}"
        "--db_port=${PORT}"
        "--db_user=${USER}"
        "--db_password=${PASSWORD}"
        "--addons-path=${addons_path}"
        "--stop-after-init"
        "--no-http"
        "-i" "${ODOO_INIT_MODULES}"
    )

    echo "[entrypoint] Ejecutando: ${ODOO_BIN} ${install_args[*]}"
    echo "[entrypoint] Addons path: ${addons_path}"

    $ODOO_BIN "${install_args[@]}" || {
        echo "[entrypoint] ❌ ERROR: Falló la instalación de módulos."
        exit 1
    }

    echo "[entrypoint] ✅ Módulos '${ODOO_INIT_MODULES}' instalados correctamente."
}

# ============================================================
# FUNCIÓN: Configurar el master password en odoo.conf
# ============================================================
configure_master_password() {
    local conf_file="/etc/odoo/odoo.conf"

    if [ -f "$conf_file" ]; then
        echo "[entrypoint] Configurando master password en ${conf_file}..."
        # Si ya existe admin_passwd, reemplazarlo; si no, añadirlo
        if grep -q "^admin_passwd" "$conf_file"; then
            sed -i "s/^admin_passwd.*/admin_passwd = ${ODOO_MASTER_PASSWORD}/" "$conf_file"
        else
            echo "admin_passwd = ${ODOO_MASTER_PASSWORD}" >> "$conf_file"
        fi
        echo "[entrypoint] ✅ Master password configurado."
    else
        echo "[entrypoint] ⚠️ No se encontró ${conf_file}, se creará uno básico."
        mkdir -p "$(dirname "$conf_file")"
        cat > "$conf_file" <<EOF
[options]
admin_passwd = ${ODOO_MASTER_PASSWORD}
db_host = ${HOST}
db_port = ${PORT}
db_user = ${USER}
db_password = ${PASSWORD}
addons_path = /mnt/extra-addons
EOF
    fi
}

# ============================================================
# BLOQUE PRINCIPAL: Lógica de inicialización
# ============================================================

# Esperar a que PostgreSQL esté listo
wait_for_postgres

# Verificar si la versión de Odoo soporta inicialización automática (>= 19)
if version_ge "$ODOO_VERSION" 19; then
    echo "[entrypoint] ℹ️ Versión de Odoo detectada: ${ODOO_VERSION} (soporta inicialización automática)"

    # Si no existe el flag de inicialización, ejecutar setup
    if [ ! -f "$INIT_FLAG" ]; then
        echo "[entrypoint] 🔧 Primera ejecución detectada. Iniciando configuración automática..."

        # 1. Configurar master password en odoo.conf
        configure_master_password

        # 2. Clonar repositorios de módulos
        clone_repos

        # 3. Instalar dependencias Python de los módulos (requirements.txt)
        install_python_requirements

        # 4. Crear e inicializar la base de datos (solo si no existe)
        if ! db_exists "$ODOO_DB_NAME"; then
            init_database

            # 5. Instalar módulos adicionales
            install_modules
        else
            echo "[entrypoint] ℹ️ La base de datos '${ODOO_DB_NAME}' ya existe. Saltando inicialización."
        fi

        # 6. Crear flag para no repetir en futuros reinicios
        touch "$INIT_FLAG"
        echo "[entrypoint] ✅ Configuración inicial completada."
        echo "[entrypoint] =========================================================="
    else
        echo "[entrypoint] ℹ️ El contenedor ya fue inicializado previamente (flag: ${INIT_FLAG})."
        echo "[entrypoint]    Si quieres forzar la re-inicialización, elimina el flag:"
        echo "[entrypoint]    docker compose exec web rm ${INIT_FLAG}"
        echo "[entrypoint]    Y reinicia el contenedor: docker compose restart web"
    fi
else
    echo "[entrypoint] ⚠️ Versión de Odoo detectada: ${ODOO_VERSION}"
    echo "[entrypoint]    La inicialización automática de base de datos solo está disponible"
    echo "[entrypoint]    para Odoo 19 o superior. Saltando setup automático."
    echo "[entrypoint]    Deberás crear la base de datos manualmente desde la interfaz web."
fi

# ============================================================
# EJECUTAR ODOO (pasando a runodoo.sh)
# ============================================================
echo "[entrypoint] 🚀 Arrancando Odoo..."
exec /runodoo.sh "$@"
