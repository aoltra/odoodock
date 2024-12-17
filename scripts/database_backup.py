#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Instalación. El script requiere de la libreria python-dotenv
#    pip3 install python-dotenv
# Más info: https://pypi.org/project/python-dotenv/

from dotenv import load_dotenv
import xmlrpc.client
import argparse
import os, json
import shutil
from datetime import datetime

print('\033[1modoodock | database-backup. v1.1\033[0m')

parser = argparse.ArgumentParser(
  description = 'Crea un backup de la base de datos')

# argumentos
parser.add_argument('database', help = 'Base de datos. Requerido') 
parser.add_argument('-u', '--url', default = 'http://localhost', help = 'URL del servidor Odoo. Por defecto: http://localhost')
parser.add_argument('-p', '--port', default = '8069', help = 'Puerto del servidor Odoo. Por defecto: 8069')
parser.add_argument('-sr', '--user', default = 'admin', help = 'Usuario administrador Odoo. Por defecto: admin')
parser.add_argument('-ps', '--password', default = 'admin', help = 'Contraseña usuario administrador Odoo. Por defecto: admin')
parser.add_argument('-dbs', '--db_service', default = 'odoodock-db-1', help = 'Nombre del servicio de la base de datos. Por defecto: odoodock-db-1')
parser.add_argument('-pt', '--path', default = '', help = 'Carpeta donde se ubica el backup. Por defecto: . (carpeta de ejecución del script)')
parser.add_argument('-n', '--name', default = '', help = 'Nombre del fichero de backup. Por defecto: {database_name}_{D}-{M}-{Y}_{H}-{M}-{S}__by_odoodock')

args = parser.parse_args()

url = args.url + ':' + args.port
db = args.database
username = args.user
password = args.password
db_service = args.db_service
path = args.path
name = args.name

# end point xmlrpc/2/common permite llamadas sin autenticar
print('\033[0;32m[INFO]\033[0m Conectando con',url, ' -> ', db)
try:
  common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
  print('\033[0;32m[INFO]\033[0m Odoo server', common.version()['server_version'])
except Exception as e:
  print('\033[0;31m[ERROR]\033[0m ' + str(e))
  print('\033[0;31m[ERROR]\033[0m Compruebe que el servidor de Odoo esté arrancado')
  print(f'\033[0;32m[INFO]\033[0m Saliendo...')
  exit()

try:
  now = datetime.now()

  # autenticación
  uid = common.authenticate(db, username, password, {})

  # directorio temporal para almacenar la información de la base de datos
  os.makedirs('bckp_temp')

  print(f'\033[0;32m[INFO]\033[0m Generando manifiesto...') 
  models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))
  modules = models.execute_kw(db, uid, password, 'ir.module.module', 'search_read', [[('state','=','installed')]], { 'fields': ['name', 'latest_version']})

  dict_modules = dict( (mod['name'], mod['latest_version']) for mod in modules )
  
  stream = os.popen(f'docker exec -it {db_service} psql --version')
  output_pg_version = stream.read()
  pg_version = output_pg_version[output_pg_version.rfind(' '):output_pg_version.rfind('.')]
  
  dict_manifest = {
      'odoo_dump': '1',
      'db_name': db,
      'version': common.version()['server_version'],
      'version_info': common.version()['server_version_info'],
      'major_version': common.version()['server_serie'],
      'pg_version': f'{pg_version}.0',
      'modules': dict_modules,
    }
  
  manifest = json.dumps(dict_manifest, indent=4)

  with open("bckp_temp/manifest.json", "w") as outfile:
    outfile.write(manifest)
  print(f'\033[0;32m[INFO]\033[0m Manifiesto... OK') 

  # DUMP database
  print(f'\033[0;32m[INFO]\033[0m Generando dump de la base de datos...') 
  stream = os.system(f'docker exec -it {db_service} pg_dump -U odoo --no-owner -w {db} > bckp_temp/dump.sql')
  print(f'\033[0;32m[INFO]\033[0m Dump... OK') 

  # filestore
  # busca en su directorio o en los padres
  load_dotenv()

  print(f'\033[0;32m[INFO]\033[0m Generando filestore...') 
  odoo_version = common.version()["server_serie"]
  filestore_path = f'{os.getenv("DATA_PATH_HOST")}/odoo/{odoo_version[:odoo_version.find(".")]}/{os.getenv("ODOO_SERVER_NAME")}/filestore/{db}'
  shutil.copytree(os.path.expanduser(filestore_path), os.path.join('bckp_temp', 'filestore'))
  print(f'\033[0;32m[INFO]\033[0m Filestore... OK') 

  # Creando archivo de Backup
  print(f'\033[0;32m[INFO]\033[0m Generando ZIP') 
 
  if len(path) != 0:
    os.makedirs(path)

  if len(name) == 0:
    backup_name = f'{db}_{now.strftime("%d-%m-%Y")}_{now.strftime("%H-%M-%S")}__by_odoodock'
  else:
    backup_name = f'{name}'

  complete_backup_file = os.path.join(path, backup_name)

  shutil.make_archive(complete_backup_file, format='zip', root_dir='bckp_temp')
  print(f'\033[0;32m[INFO]\033[0m Backup realizado: {complete_backup_file}.zip') 

except KeyError as e:
  print('   \033[0;31m[ERROR]\033[0m Clave no encontrada.' + str(e))
except (xmlrpc.client.Fault) as e:
  print('   \033[0;31m[ERROR]\033[0m ' + e.faultString)
except Exception as e:
  print(str(e))

shutil.rmtree('bckp_temp')
