#!/bin/bash

# Crea la infraestructura de Rabbit

# Capturamos los parámetros
ADMIN_USER=$1
ADMIN_PASS=$2

# Validación de parámetros
if [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASS" ]; then
    echo "ERROR: Faltan parámetros. Uso: ./init-rabbit.sh <usuario> <password>"
    exit 1
fi

echo "Iniciando configuración con usuario: $ADMIN_USER"

# Espero a que RabbitMQ esté listo (importante)
until rabbitmq-diagnostics -q check_port_connectivity; do
  echo "RabbitMQ aún no responde... reintentando en 2 segundos"
  sleep 2
done

# Tiempo de cortesía para la API de Management
sleep 4

# Función para simplificar la creación de colas con rabbitadmin
# Uso: crear_cola <vhost> <nombre_cola>
crear_cola() {
    local vhost=$1
    local nombre=$2
    local type=$3
    echo "Creando cola '$nombre' en vhost '$vhost'..."
    rabbitmqadmin --vhost "$vhost" --username "$ADMIN_USER" --password "$ADMIN_PASS" declare queue name="$nombre" queue_type="$type" durable=true
}

# Función para simplificar la creación de exchanges con rabbitadmin
# Uso: crear_exchange <vhost> <nombre_exchange>
crear_exchange() {
    local vhost=$1
    local nombre=$2
    local type=$3
    echo "Creando exchange '$nombre' en vhost '$vhost'..."
    rabbitmqadmin --vhost "$vhost" --username "$ADMIN_USER" --password "$ADMIN_PASS" declare exchange name="$nombre" type="$type" durable=true
}

# Función para enlazar exchanges con colas
# Uso: enlazar_exchange_con_cola <vhost> <nombre_exchange> <nombre_cola> <routing_key>
enlazar_exchange_con_cola() {
    local vhost=$1
    local nombre_exchange=$2
    local nombre_cola=$3
    local routing_key=$4
    echo "Creando enlace entre exchange '$nombre_exchange' y cola '$nombre_cola' en vhost '$vhost'..."

    rabbitmqadmin --vhost "$vhost" --username "$ADMIN_USER" --password "$ADMIN_PASS" declare binding source="$nombre_exchange" destination_type="queue" destination="$nombre_cola" routing_key="$routing_key"
}

echo "Configurando usuarios y vhosts..."

# Creación de Virtual Host
rabbitmqctl add_vhost notifications || true
rabbitmqctl add_vhost logs || true
rabbitmqctl add_vhost maya_sync || true

# Doy permisos al usuario administrador en los vhost para poder crear colas
rabbitmqctl set_permissions -p notifications "$ADMIN_USER" ".*" ".*" ".*"
rabbitmqctl set_permissions -p logs "$ADMIN_USER" ".*" ".*" ".*"

# Usuarios
# Se usa  '|| true' para que el script no se detenga si el usuario ya existe
rabbitmqctl add_user n8n_user n8n_password123 || true
rabbitmqctl set_user_tags n8n_user management
# usuario puede Crear colas, escribir, leer
rabbitmqctl set_permissions -p notifications n8n_user ".*" ".*" ".*"
rabbitmqctl set_permissions -p logs n8n_user ".*" ".*" ".*"

##
## COLAS
##
echo "Declarando colas..."

# Colas en /notifications
crear_cola "notifications" "dev.q.welcome.email.send" "classic"

# Colas en /logs
crear_cola "logs" "dev.q.message.logs" "classic"

##
## EXCHANGES
##
echo "Declarando exchanges..."

crear_exchange "logs" "dev.ex.message.logs" "topic"
enlazar_exchange_con_cola "logs" "dev.ex.message.logs" "dev.q.message.logs" "#.error"

echo "¡Configuración de RabbitMQ finalizada!"