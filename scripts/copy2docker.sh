#!/bin/bash

# Imprime el mensaje de ayuda
usage() {                                
  echo -e "Uso: $0 [ -s SERVICE ] [ -u USER ] SOURCE DEST | [ -h ]" 1>&2
  echo 
  echo -e "Copia en la carpeta DEST de un contenedor los ficheros definidos en SOURCE del host"
  echo -e "  -c: Nombre del servicio destino. Por defecto web"
  echo -e "  -u: ID del usuario con el que se realizará la copia. Por defecto 101 (odoo en ${PROJECT_NAME}-web-1)"
  echo
  echo -e "Ejemplo:"
  echo -e "   ./copy2docker.sh ~/data-test /mnt/extra-addons/my-module/extra/"
  echo -e "   ./copy2docker.sh -u 110 ~/data-test /mnt/extra-addons/my-module/extra/"
}

exit_abnormal() {   
  echo              
  usage
  exit 1
}

test ! -f ../.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }

# cargo las variables desde .env y .services
set -o allexport && source ../.env && set +o allexport

test -z $PROJECT_NAME && { echo -e "\033[0;31m[ERROR]\033[0m Variable PROJECT_NAME no definida en .env. Saliendo..." ; exit; }

SERVICE=web
IDUSER=101

# OPTION es la variable que almacena el item en cada momento
while getopts ":hs:u:" OPTION; do
  case $OPTION in
    s)
      SERVICE=$OPTARG
      ;;
    u)
      IDUSER=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      echo -e "\033[0;31m[ERROR]\033[0m La opción -${OPTARG} necesita un argumento."
      exit_abnormal
      ;;
    ?)
      echo -e "\033[0;31m[ERROR]\033[0m Opción no reconocida -${OPTARG}."
      exit_abnormal
      ;;
  esac
done

# retiramos las opciones ya procesadas
shift $((OPTIND-1))
if [ "$#" -ne 2 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m Es necesario indicar SOURCE y DEST."
  exit_abnormal
fi

SOURCE=$1
DEST=$2

if [ ! -f "$SOURCE" ] && [ ! -d "$SOURCE" ]; then
  echo -e "\033[0;31m[ERROR]\033[0m No se encuentra ${SOURCE}."
  exit_abnormal
fi

echo -e "\033[0;32m[INFO]\033[0m Copiando ficheros desde HOST (${SOURCE}) -> CONTAINER (${PROJECT_NAME}-${SERVICE}-1:${DEST})"
  error_msg=`trap 'docker cp ${SOURCE} ${PROJECT_NAME}-${SERVICE}-1:${DEST}' EXIT`
 
  if [ "$?" -ne 0 ]; then
    echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
  else
    echo -e "\033[0;32m[INFO]\033[0m Cambiando propietario"
    error_msg=`trap 'docker exec -u 0 -it ${PROJECT_NAME}-${SERVICE}-1 chown ${IDUSER}:${IDUSER} -R ${DEST}' EXIT`

    if [ "$?" -ne 0 ]; then
      echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
    else
      echo -e "\033[0;32m[OK]\033[0m Acción finalizada."
    fi
  fi