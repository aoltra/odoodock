#!/bin/bash

# Imprime el mensaje de ayuda
usage() {                                
  echo "Uso: $0 [ -g URL ] | [ -s MODULE ] | [ -z NAME ] | [-h]" 1>&2
  echo 
  echo "\t-z: fichero zip que contiene el módulo"
  echo "\t-g: URL del repositorio git"
  echo "\t-s: nombre del módulo para hacer scaffolding"
}

exit_abnormal() {                 
  usage
  exit 1
}

if [ "$#" -ne 2 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m Es necesario indicar una opción y un parámetro"
  exit 1
fi

# OPTION es la variable que almacena el item en cada momento
while getopts "s:z:g:h:" OPTION; do
  case $OPTION in
    s)
      MODULE=$OPTARG
      command=`echo odoo scaffold $OPTARG /mnt/extra-addons`
      ;;
    z)
      FILE=$OPTARG
      if [ -f "$FILE" ]; then
        unzip $OPTARG -d /tmp 
        command=""
      else
        echo -e "\033[0;31m[ERROR]\033[0m $FILE no es un fichero"
      fi
      ;;
    g)
      URL=$OPTARG
      command=`echo git clone $OPTARG`
      ;;
    h)
      usage
      ;;
    ?)
      echo -e "\033[0;31m[ERROR]\033[0m No se ha indicado ninguna opción"
      exit_abnormal
      ;;
  esac
done

CONTAINER_RUNNING=1

docker volume ls 2>/dev/null | grep -q odoodock_odoo_addons
# grep devuelve 0 (éxito) si encuentra algo y 1 si no lo encuentra
if [ "$?" -ne 0 ]; then 
  echo -e "\033[0;31m[ERROR]\033[0m No se encuentra el volumen odoodock_oodo_addons."
  exit 2
else 
  echo -e "\033[0;32m[OK]\033[0m Volumen odoodock_oodo_addons encontrado."
fi

# comprobación de si el contenedor odoodock_web está arrancado
# y en ese caso se pausa
CONTAINER_RUNNING=0
docker compose ps 2>/dev/null | grep -q odoodock-web
if [ "$?" -eq 0 ]; then 
    CONTAINER_RUNNING=1
    echo -e "\033[0;32m[INFO]\033[0m Contenedor odoodock-web corriendo."
    error_msg=`trap 'exec docker compose stop web 2>&1' EXIT`
    # comprobación del código de error de salida
    if [ "$?" -ne 0 ]; then
        echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
        exit 3
    else
        echo -e "\033[0;32m[OK]\033[0m Contenedor odoodock-web parado."
    fi
fi

# ejecución de la operacióN
echo -e "\033[0;32m[INFO]\033[0m Ejecutando acción -> contenedor create_module_odoo"
error_msg=`trap 'docker run --rm --workdir="/mnt/extra-addons" --entrypoint /bin/bash --name create_module_odoo -v odoodock_odoo_addons:/mnt/extra-addons odoodock_web -c "$command"' EXIT`

# comprobación del código de error de salida
if [ "$?" -ne 0 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
# para detectar que la opción sea z nos basamos en la existencia de la variable FILE (con -z)
elif [ ! -z $FILE ]; then
  # obtención del nombre del fichero a partir de la ruta
  FILENAME_ZIP=$(basename -- "$FILE")
  echo -e "Copiando ficheros de HOST (/temp/${FILENAME_ZIP%zip}) -> CONTAINER (/mnt/extra/addons/${FILENAME_ZIP%zip})"
  error_msg=`trap 'docker cp /tmp/${FILENAME_ZIP%.zip} odoodock-web-1:/mnt/extra-addons' EXIT`
 
  if [ "$?" -ne 0 ]; then
    echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
  else
    echo -e "\033[0;32m[OK]\033[0m Acción ejecutada."
  fi
else
  echo -e "\033[0;32m[INFO]\033[0m Acción ejecutada."
fi

echo -e "\033[0;32m[INFO]\033[0m Eliminando contenedor create_module_odoo."

# reanuda el contenedor
if [ "$CONTAINER_RUNNING" -eq 1 ]; then
    error_msg=`trap 'exec docker compose up -d web 2>&1' EXIT`
    # comprobación del código de error de salida
    if [ "$?" -ne 0 ]; then
        echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
    else
        echo -e "\033[0;32m[OK]\033[0m Contenedor odoodock-web reiniciado."
    fi
fi