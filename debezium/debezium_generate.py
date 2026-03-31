#!/usr/bin/env python3
# =============================================================================
# debezium_generate.py
# Maya AQSS — Generador de configuraciones Debezium
# =============================================================================
# Lee debezium_tables.yml y genera:
#   - Un application.properties por base de datos en debezium/conf/<db>/
#   - Un docker-compose.debezium.yml con un servicio por base de datos
#   - rabbitmq/definitions/debezium.yml con exchanges, colas y bindings CDC
#
# Un solo fichero fuente de verdad (debezium_tables.yml) genera todo lo demás.
# Los ficheros generados van en .gitignore — se regeneran en cada máquina.
#
# Uso:
#   python3 debezium/debezium_generate.py
#   python3 debezium/debezium_generate.py --dry-run
#   python3 debezium/debezium_generate.py --compose-out docker-compose.debezium.yml
#   python3 debezium/debezium_generate.py --rabbit-out rabbitmq/definitions/debezium.yml
# =============================================================================

import yaml
import os
import sys
import argparse
from pathlib import Path

# Rutas base 
SCRIPT_DIR   = Path(__file__).parent
TABLES_YML   = SCRIPT_DIR / "debezium_tables.yml"
CONF_DIR     = SCRIPT_DIR / "conf"
# Ruta por defecto del fichero RabbitMQ generado (relativa al proyecto)
RABBIT_OUT_DEFAULT = SCRIPT_DIR.parent / "rabbitmq" / "definitions" / "debezium.yml"

# Colores para terminal 
GREEN  = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE   = "\033[0;34m"
CYAN   = "\033[0;36m"
RED    = "\033[0;31m"
NC     = "\033[0m"

def info(msg):    print(f"{BLUE}[INFO]{NC}  {msg}")
def success(msg): print(f"{GREEN}[OK]{NC}    {msg}")
def warn(msg):    print(f"{YELLOW}[WARN]{NC}  {msg}")
def error(msg):   print(f"{RED}[ERROR]{NC} {msg}", file=sys.stderr)
def step(msg):    print(f"\n{CYAN}▶ {msg}{NC}")

# Plantilla application.properties 
# Parámetros que se sustituyen:
#   {db_name}        nombre de la base de datos
#   {topic_prefix}   prefijo para routing keys (= db_name sin guiones)
#   {slot_name}      nombre del slot de replicación
#   {pub_name}       nombre de la publicación PostgreSQL
#   {table_list}     lista de tablas separadas por coma
#   {data_dir}       directorio de offsets dentro del contenedor
APPLICATION_PROPERTIES_TEMPLATE = """\
# =============================================================================
# application.properties — Debezium Server
# Base de datos: {db_name}
# Generado automáticamente por debezium_generate.py
# NO editar manualmente — edita debezium_tables.yml y regenera
# =============================================================================

# -----------------------------------------------------------------------------
# SINK: RabbitMQ
# -----------------------------------------------------------------------------
debezium.sink.type=rabbitmq
debezium.sink.rabbitmq.connection.host=${{RABBITMQ_HOST:-rabbitmq}}
debezium.sink.rabbitmq.connection.port=${{RABBITMQ_PORT:-5672}}
debezium.sink.rabbitmq.connection.username=${{RABBITMQ_DEFAULT_USER}}
debezium.sink.rabbitmq.connection.password=${{RABBITMQ_DEFAULT_PASSWORD}}

# Exchange donde Debezium publica. Routing key: <prefix>.<schema>.<tabla>
debezium.sink.rabbitmq.exchange=${{DEBEZIUM_RABBITMQ_EXCHANGE:-dev.ex.debezium.cdc}}

# -----------------------------------------------------------------------------
# SOURCE: PostgreSQL — {db_name}
# -----------------------------------------------------------------------------
debezium.source.connector.class=io.debezium.connector.postgresql.PostgresConnector
debezium.source.database.hostname=${{POSTGRES_HOST:-db}}
debezium.source.database.port=${{POSTGRES_PORT:-5432}}
debezium.source.database.user=debezium_reader
debezium.source.database.password=${{DEBEZIUM_DB_PASSWORD}}
debezium.source.database.dbname={db_name}

# Prefijo lógico — aparece en el routing key: {topic_prefix}.<schema>.<tabla>
debezium.source.topic.prefix={topic_prefix}

debezium.source.plugin.name=pgoutput
debezium.source.slot.name={slot_name}
debezium.source.publication.name={pub_name}
# never: no intenta crear la publicación (ya la crea debezium_sync.sh)
debezium.source.publication.autocreate.mode=never

# Tablas monitorizadas (generado desde debezium_tables.yml)
debezium.source.table.include.list={table_list}

# -----------------------------------------------------------------------------
# TRANSFORMACIONES
# -----------------------------------------------------------------------------
debezium.transforms=unwrap
debezium.transforms.unwrap.type=io.debezium.transforms.ExtractNewRecordState
debezium.transforms.unwrap.delete.handling.mode=rewrite
debezium.transforms.unwrap.add.fields=op,ts_ms,db
debezium.transforms.unwrap.drop.tombstones=true

# Formato JSON limpio para n8n
debezium.format.value=json
debezium.format.key=json
debezium.format.schemas.enable=false

# -----------------------------------------------------------------------------
# OFFSETS y SCHEMA HISTORY (persistencia entre reinicios)
# -----------------------------------------------------------------------------
debezium.source.offset.storage=org.apache.kafka.connect.storage.FileOffsetBackingStore
debezium.source.offset.storage.file.filename={data_dir}/offsets.dat
debezium.source.offset.flush.interval.ms=10000

debezium.source.schema.history.internal=io.debezium.storage.file.history.FileSchemaHistory
debezium.source.schema.history.internal.file.filename={data_dir}/schema-history.dat

# -----------------------------------------------------------------------------
# COMPORTAMIENTO
# -----------------------------------------------------------------------------
debezium.source.snapshot.mode=initial
debezium.source.tombstones.on.delete=false
debezium.source.max.batch.size=500
debezium.source.max.queue.size=8192
debezium.source.heartbeat.interval.ms=10000
"""

# Plantilla servicio docker-compose 
COMPOSE_SERVICE_TEMPLATE = """\
  # Debezium — {db_name}
  # Generado automáticamente por debezium_generate.py
  debezium-{db_slug}:
    # Debezium Server: distribución standalone sin Kafka
    # Soporta RabbitMQ como sink directamente
    image: quay.io/debezium/server:${{DEBEZIUM_VERSION:-2.7}}

    # Debezium Server no expone puertos por defecto (no tiene API REST en esta imagen)
    # Hay una API pra métricas, descomentar:
    # ports:
    #   - "${{DEBEZIUM_PORT}}:8080"

    volumes:
      - ./debezium/conf/{db_name}/application.properties:/debezium/conf/application.properties:ro
      # Datos persistentes: offsets y schema history
      - ${{DATA_PATH_HOST}}/debezium/{db_name}:/debezium/data

    environment:
      - RABBITMQ_DEFAULT_USER=${{RABBITMQ_DEFAULT_USER}}
      - RABBITMQ_DEFAULT_PASSWORD=${{RABBITMQ_DEFAULT_PASSWORD}}
      - DEBEZIUM_DB_PASSWORD=${{DEBEZIUM_DB_PASSWORD}}
      - DEBEZIUM_RABBITMQ_EXCHANGE=${{DEBEZIUM_RABBITMQ_EXCHANGE:-dev.ex.debezium.cdc}}
      - POSTGRES_HOST=db

    depends_on:
      - db
      - rabbitmq

    restart: unless-stopped

    networks:
      - traefik_network
"""

# Plantilla RabbitMQ definitions/debezium.yml 
# El contenido dinámico (exchanges, queues, bindings) se construye en código.
RABBIT_HEADER = """\
# =============================================================================
# debezium.yml — Definiciones RabbitMQ para eventos CDC de Debezium
# Vhost: debezium_sync
# Generado automáticamente por debezium_generate.py
# NO editar manualmente — edita debezium_tables.yml y regenera
#
# Routing key de cada evento: <topic_prefix>.<schema>.<tabla>
# Ejemplo: odoo.public.res_users
# =============================================================================

vhost: debezium_sync

"""

#  Cabecera del docker-compose generado 
COMPOSE_HEADER = """\
# =============================================================================
# docker-compose.debezium.yml
# Servicios Debezium generados automáticamente por debezium_generate.py
# NO editar manualmente — edita debezium_tables.yml y regenera
#
# Uso: docker compose -f docker-compose.yml -f docker-compose.debezium.yml up
# =============================================================================

services:
"""

# ##########################

def load_tables_yml(path: Path) -> dict:
    with open(path) as f:
        config = yaml.safe_load(f)
    databases = config.get("databases", {}) or {}
    if not databases:
        error(f"No hay bases de datos definidas en {path}")
        sys.exit(1)
    return databases


def db_to_slug(db_name: str) -> str:
    """odoo_db → odoo-db  (válido para nombre de servicio docker)"""
    return db_name.replace("_", "-")


def db_to_prefix(db_name: str) -> str:
    """odoo_db → odoo  (prefijo de routing key limpio)"""
    return db_name.replace("_db", "").replace("_", ".")


def generate_properties(db_name: str, tables: list, dry_run: bool) -> Path:
    """Genera el application.properties para una base de datos."""
    topic_prefix = db_to_prefix(db_name)
    slot_name    = f"debezium_{db_name}_slot"
    pub_name     = f"debezium_{db_name}_pub"
    table_list   = ",".join(tables)
    data_dir     = f"/debezium/data"   # dentro del contenedor

    content = APPLICATION_PROPERTIES_TEMPLATE.format(
        db_name      = db_name,
        topic_prefix = topic_prefix,
        slot_name    = slot_name,
        pub_name     = pub_name,
        table_list   = table_list,
        data_dir     = data_dir,
    )

    out_dir  = CONF_DIR / db_name
    out_file = out_dir / "application.properties"

    if dry_run:
        print(f"\n{CYAN}── [{db_name}] application.properties ──{NC}")
        print(content)
        return out_file

    out_dir.mkdir(parents=True, exist_ok=True)
    out_file.write_text(content)
    return out_file


def generate_compose_fragment(databases: dict, out_path: Path, dry_run: bool):
    """Genera el fichero docker-compose.debezium.yml."""
    services_block = ""
    for db_name in databases:
        services_block += COMPOSE_SERVICE_TEMPLATE.format(
            db_name  = db_name,
            db_slug  = db_to_slug(db_name),
        )

    content = COMPOSE_HEADER + services_block

    if dry_run:
        print(f"\n{CYAN}── docker-compose.debezium.yml ──{NC}")
        print(content)
        return

    out_path.write_text(content)


# ─────────────────────────────────────────────────────────────────────────────

def generate_rabbit_definitions(databases: dict, out_path: Path, dry_run: bool):
    """
    Genera rabbitmq/definitions/debezium.yml con:
    - Un exchange CDC (dev.ex.debezium.cdc) compartido por todas las BDs
    - Una cola por tabla monitorizada
    - Una DLQ por cola
    - Los bindings correspondientes
    """

    # Recopilar todas las tablas con su prefijo de BD
    all_tables = []  # lista de (db_name, topic_prefix, schema, table)
    for db_name, tables in databases.items():
        if not tables:
            continue
        prefix = db_to_prefix(db_name)
        for full_table in tables:
            parts = full_table.split(".")
            schema = parts[0] if len(parts) > 1 else "public"
            table  = parts[1] if len(parts) > 1 else parts[0]
            all_tables.append((db_name, prefix, schema, table))

    if not all_tables:
        warn("Sin tablas para generar definiciones RabbitMQ")
        return

    # ── Construir el YAML como estructura de datos ────────────────────────────
    config = {
        "vhost": "debezium_sync",

        "exchanges": [
            {
                "name": "dev.ex.debezium.cdc",
                "type": "topic",
                "durable": True,
                "_comment": "Exchange CDC compartido por todos los conectores Debezium"
            },
            {
                "name": "dev.ex.dead.letter",
                "type": "direct",
                "durable": True,
                "_comment": "Dead letter exchange para mensajes CDC fallidos"
            }
        ],

        "queues": [],
        "bindings": []
    }

    for db_name, prefix, schema, table in all_tables:
        queue_name = f"dev.cdc.{prefix}.{schema}.{table}"
        dlq_name   = f"dev.dlq.{prefix}.{schema}.{table}"
        routing_key = f"{prefix}.{schema}.{table}"

        # Cola principal (quorum para durabilidad)
        config["queues"].append({
            "name": queue_name,
            "type": "quorum",
            "durable": True,
            "arguments": {
                "x-dead-letter-exchange": "dev.ex.dead.letter",
                "x-dead-letter-routing-key": dlq_name,
                "x-delivery-limit": 3
            }
        })

        # Dead letter queue
        config["queues"].append({
            "name": dlq_name,
            "type": "classic",
            "durable": True
        })

        # Binding CDC → cola principal
        config["bindings"].append({
            "exchange": "dev.ex.debezium.cdc",
            "queue": queue_name,
            "routing_key": routing_key
        })

        # Binding dead letter → DLQ
        config["bindings"].append({
            "exchange": "dev.ex.dead.letter",
            "queue": dlq_name,
            "routing_key": dlq_name
        })

    # Serializar a YAML con cabecera de comentario 
    # Eliminamos _comment antes de serializar (es solo para nosotros)
    def strip_comments(obj):
        if isinstance(obj, dict):
            return {k: strip_comments(v) for k, v in obj.items() if k != "_comment"}
        if isinstance(obj, list):
            return [strip_comments(i) for i in obj]
        return obj

    clean_config = strip_comments(config)

    # Serializar secciones por separado para añadir comentarios legibles
    exchanges_yaml = yaml.dump(
        {"exchanges": clean_config["exchanges"]},
        default_flow_style=False, allow_unicode=True, sort_keys=False
    )
    queues_yaml = yaml.dump(
        {"queues": clean_config["queues"]},
        default_flow_style=False, allow_unicode=True, sort_keys=False
    )
    bindings_yaml = yaml.dump(
        {"bindings": clean_config["bindings"]},
        default_flow_style=False, allow_unicode=True, sort_keys=False
    )

    # Insertar comentarios de sección
    db_list = ", ".join(databases.keys())
    content = (
        RABBIT_HEADER
        + f"# Bases de datos monitorizadas: {db_list}\n"
        + f"# Tablas totales: {len(all_tables)}\n"
        + f"# Colas generadas: {len(all_tables)} CDC + {len(all_tables)} DLQ\n\n"
        + "# ── Exchanges ────────────────────────────────────────────────────────────────\n"
        + exchanges_yaml
        + "\n# ── Colas (una por tabla + su DLQ) ──────────────────────────────────────────\n"
        + queues_yaml
        + "\n# ── Bindings ─────────────────────────────────────────────────────────────────\n"
        + bindings_yaml
    )

    if dry_run:
        print(f"\n{CYAN}── rabbitmq/definitions/debezium.yml ──{NC}")
        print(content)
        return

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content)


# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Genera configuraciones Debezium desde debezium_tables.yml"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Muestra lo que generaría sin escribir ficheros"
    )
    parser.add_argument(
        "--compose-out", default="docker-compose.debezium.yml",
        help="Ruta del docker-compose a generar (default: docker-compose.debezium.yml)"
    )
    parser.add_argument(
        "--rabbit-out", default=str(RABBIT_OUT_DEFAULT),
        help=f"Ruta del fichero RabbitMQ a generar (default: {RABBIT_OUT_DEFAULT})"
    )
    parser.add_argument(
        "--tables-yml", default=str(TABLES_YML),
        help=f"Ruta al fichero de tablas (default: {TABLES_YML})"
    )
    args = parser.parse_args()

    tables_path  = Path(args.tables_yml)
    compose_path = Path(args.compose_out)
    rabbit_path  = Path(args.rabbit_out)
    dry_run      = args.dry_run

    if dry_run:
        warn("Modo DRY-RUN — no se escribirá ningún fichero")

    # Leer el yml
    step("Leyendo debezium_tables.yml")
    if not tables_path.exists():
        error(f"No se encontró {tables_path}")
        sys.exit(1)

    databases = load_tables_yml(tables_path)
    info(f"Bases de datos encontradas: {len(databases)}")
    for db, tables in databases.items():
        info(f"  {CYAN}{db}{NC}: {len(tables or [])} tabla(s)")
        for t in (tables or []):
            print(f"    · {t}")

    # Generar application.properties por BD 
    step("Generando ficheros application.properties")
    generated = []
    for db_name, tables in databases.items():
        if not tables:
            warn(f"  {db_name}: sin tablas definidas, omitiendo")
            continue
        out_file = generate_properties(db_name, tables, dry_run)
        generated.append((db_name, out_file))
        if not dry_run:
            success(f"  {db_name} → {out_file}")

    # Generar docker-compose.debezium.yml 
    step("Generando docker-compose.debezium.yml")
    generate_compose_fragment(databases, compose_path, dry_run)
    if not dry_run:
        success(f"  → {compose_path}")

    # Generar rabbitmq/definitions/debezium.yml 
    step("Generando rabbitmq/definitions/debezium.yml")
    generate_rabbit_definitions(databases, rabbit_path, dry_run)
    if not dry_run:
        success(f"  → {rabbit_path}")

    # Resumen 
    if not dry_run:
        print()
        step("Resumen — ficheros generados")
        for db_name, out_file in generated:
            info(f"  {out_file}")
        info(f"  {compose_path}")
        info(f"  {rabbit_path}")
        print()
        print(f"{GREEN}Siguiente paso — sincronizar publicaciones en PostgreSQL:{NC}")
        print(f"  ./debezium/debezium_sync.sh")
        print()
        print(f"{GREEN}Siguiente paso — inicializar colas en RabbitMQ:{NC}")
        print(f"  docker exec rabbitmq bash /init-rabbit.sh $RABBIT_USER $RABBIT_PASS")
        print()
        print(f"{GREEN}Arrancar Debezium:{NC}")
        print(f"  docker compose -f docker-compose.yml -f {compose_path} up -d")


if __name__ == "__main__":
    main()