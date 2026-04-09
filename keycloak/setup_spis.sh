#!/bin/bash
# =============================================================================
# download-spi.sh — Odoodock
# Descarga los Service Provider Interfaces (SPIs) de Keycloak
# =============================================================================
# Uso desde fuera del contenedor
#   ./download-spi.sh 
#
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

# Configuración
INPUT_FILE=".system-providers"
CONFIG_FILE=".system-providers-variables"
TARGET_DIR="./providers"
ENV_FILE=".env-keycloak"

info "Sistema de configuración de providers para keycloak"
info "---------------------------------------------------"

# Crear la carpeta si no existe
if [ ! -d "$TARGET_DIR" ]; then
  info "Creando el directorio $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
fi

# Verificar si el fichero de entrada existe
if [ ! -f "$INPUT_FILE" ]; then
  error "El archivo $INPUT_FILE no existe."
  exit 1
fi

# Verificar si el fichero de variables existe
if [ ! -f "$CONFIG_FILE" ]; then
  error "El archivo $CONFIG_FILE no existe."
  exit 1
fi

info "Iniciando descarga de plugins..."
info "--------------------------------"

# 1. Descarga de Plugins
while IFS="|" read -r nombre url || [ -n "$nombre" ]; do
  # Ignorar líneas vacías o comentarios
  [[ -z "$nombre" || "$nombre" =~ ^# ]] && continue

  info "Descargando: $nombre..."
  
  # Descarga con curl
  # -L: Sigue redirecciones (necesario para GitHub)
  # -s: Modo silencioso
  # -o: Especifica el destino del archivo
  curl -L -s -o "$TARGET_DIR/$nombre" "$url"

  if [ $? -eq 0 ]; then
    success "Guardado en $TARGET_DIR/$nombre"
  else
    error "Error descargando $nombre de $url"
  fi

done < "$INPUT_FILE"

# 2. Volcado de configuración al archivo .env
if [ -f "$CONFIG_FILE" ]; then
    info "Generando archivo $ENV_FILE a partir de $CONFIG_FILE..."
    
    # Escribimos una cabecera para que el usuario sepa que es generado
    echo "" >> "$ENV_FILE"
    echo "##########################################################" >> "$ENV_FILE"
    echo "# CÓDIGO GENERADO AUTOMÁTICAMENTE - NO EDITAR MANUALMENTE" >> "$ENV_FILE"
    echo "# Basado en $CONFIG_FILE" >> "$ENV_FILE"
    echo "##########################################################" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
    
    # Volcamos el contenido del provider al .env
    cat "$CONFIG_FILE" >> "$ENV_FILE"
    
    success "Archivo $ENV_FILE actualizado correctamente."
else
    warn "No se encontró $CONFIG_FILE. El .env no se ha actualizado."
fi


info "--------------------------------"
info "Proceso finalizado."
