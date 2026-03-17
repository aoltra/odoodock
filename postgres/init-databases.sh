#!/bin/bash
set -e

# Función para procesar cada línea
process_database_line() {
    local line=$1
    
    # Dividir la línea usando el separador :
    IFS=':' read -r dbname dbuser dbpass <<< "$line"
    
    # Limpiar espacios en blanco accidentales
    dbname=$(echo "$dbname" | xargs)
    dbuser=$(echo "$dbuser" | xargs)
    dbpass=$(echo "$dbpass" | xargs)

    if [ -z "$dbname" ] || [ -z "$dbuser" ] || [ -z "$dbpass" ]; then
        echo "  [!] Línea mal formada u omitida: $line"
        return
    fi

    echo "  Configurando: DB=$dbname | USER=$dbuser"

    # 1. Crear el usuario si no existe y actualizar su contraseña
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$dbuser') THEN
                CREATE ROLE "$dbuser" WITH LOGIN PASSWORD '$dbpass';
            ELSE
                ALTER ROLE "$dbuser" WITH PASSWORD '$dbpass';
            END IF;
        END
        \$\$;
EOSQL
    # 2. Crear la base de datos si no existe
    DB_EXISTS=$(psql -U "$POSTGRES_USER" --dbname "postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='$dbname'")
    if [ "$DB_EXISTS" != '1' ]; then
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
            CREATE DATABASE "$dbname" OWNER "$dbuser";
EOSQL
    else
        echo "    Base de datos '$dbname' ya existe."
    fi

    # 3. Asegurar privilegios
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
        GRANT ALL PRIVILEGES ON DATABASE "$dbname" TO "$dbuser";
        ALTER DATABASE "$dbname" OWNER TO "$dbuser";
EOSQL
}

# Leer el archivo .databases
if [ -f /tmp/.databases ]; then
    echo "--- Iniciando provisión de bases de datos y usuarios ---"
    while IFS= read -r line || [ -n "$line" ]; do
        # Ignorar líneas vacías o comentarios que empiecen por #
        [[ -z "$line" || "$line" == \#* ]] && continue
        process_database_line "$line"
    done < /tmp/.databases
    echo "--- Proceso finalizado correctamente ---"
else
    echo "Error: No se encontró el archivo /tmp/.databases"
fi