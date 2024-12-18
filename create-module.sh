#!/bin/bash

# Imprime el mensaje de ayuda
usage() {                                
  echo "Uso: $0 [ -g URL ] | [ -s MODULE ] | [ -z NAME ] | [-h]" 1>&2
  echo 
  echo "  -z: fichero zip que contiene el módulo"
  echo "  -g: URL del repositorio git"
  echo "  -s: nombre del módulo para hacer scaffolding"
}

exit_abnormal() {                 
  usage
  exit 1
}

resume_container() {
  # reanuda el contenedor
  if [ "$CONTAINER_RUNNING" -eq 1 ]; then
      error_msg=`trap 'exec docker compose up -d web 2>&1' EXIT`
      # comprobación del código de error de salida
      if [ "$?" -ne 0 ]; then
          echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
      else
          echo -e "\033[0;32m[OK]\033[0m Contenedor ${PROJECT_NAME}-web reiniciado."
      fi
  fi
}

test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }

# cargo las variables desde .env y .services
set -o allexport && source .env && set +o allexport

test -z $PROJECT_NAME && { echo -e "\033[0;31m[ERROR]\033[0m Variable PROJECT_NAME no definida en .env. Saliendo..." ; exit; }

# OPTION es la variable que almacena el item en cada momento
options=0
while getopts ":hs:z:g:" OPTION; do
  case $OPTION in
    s)
      ((options++))
      MODULE=$OPTARG
      command=`echo odoo scaffold $OPTARG /mnt/extra-addons`
      ;;
    z)
      ((options++))
      FILE=$OPTARG
      if [ -f "$FILE" ]; then
        unzip $OPTARG -d /tmp 
        command=""
      else
        echo -e "\033[0;31m[ERROR]\033[0m $FILE no es un fichero"
      fi
      ;;
    g)
      ((options++))
      URL=$OPTARG
      command=`echo git clone $OPTARG`
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

if [ "$options" -gt 1 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m Sólo se permite una opción."
  exit_abnormal
fi

CONTAINER_RUNNING=1

docker volume ls 2>/dev/null | grep -q ${PROJECT_NAME}_odoo_addons
# grep devuelve 0 (éxito) si encuentra algo y 1 si no lo encuentra
if [ "$?" -ne 0 ]; then 
  echo -e "\033[0;31m[ERROR]\033[0m No se encuentra el volumen ${PROJECT_NAME}_oodo_addons."
  exit 2
else 
  echo -e "\033[0;32m[OK]\033[0m Volumen ${PROJECT_NAME}_oodo_addons encontrado."
fi

# comprobación de si el contenedor ${PROJECT_NAME}-web está arrancado
# y en ese caso se pausa
CONTAINER_RUNNING=0
docker compose ps 2>/dev/null | grep -q ${PROJECT_NAME}-web
if [ "$?" -eq 0 ]; then 
    CONTAINER_RUNNING=1
    echo -e "\033[0;32m[INFO]\033[0m Contenedor ${PROJECT_NAME}-web corriendo."
    error_msg=`trap 'exec docker compose stop web 2>&1' EXIT`
    # comprobación del código de error de salida
    if [ "$?" -ne 0 ]; then
        echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
        exit 3
    else
        echo -e "\033[0;32m[OK]\033[0m Contenedor ${PROJECT_NAME}-web parado."
    fi
fi

# ejecución de la operación
echo -e "\033[0;32m[INFO]\033[0m Ejecutando acción -> contenedor create_module_odoo"
error_msg=`trap 'docker run --rm -u odoo --workdir="/mnt/extra-addons" --entrypoint /bin/bash --name create_module_odoo -v ${PROJECT_NAME}_odoo_addons:/mnt/extra-addons -v ${PROJECT_NAME}_odoo_data:/var/lib/odoo ${PROJECT_NAME}-web -c "$command"' EXIT`

# comprobación del código de error de salida
if [ "$?" -ne 0 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
# para detectar que la opción sea z nos basamos en la existencia de la variable FILE (con -z)
elif [ ! -z $FILE ]; then
  # obtención del nombre del fichero a partir de la ruta
  FILENAME_ZIP=$(basename -- "$FILE")
  echo -e "\033[0;32m[INFO]\033[0m Copiando ficheros de HOST (/tmp/${FILENAME_ZIP%.zip}) -> CONTAINER (/mnt/extra/addons/${FILENAME_ZIP%.zip})"
  error_msg=`trap 'docker cp /tmp/${FILENAME_ZIP%.zip} ${PROJECT_NAME}-web-1:/mnt/extra-addons' EXIT`
 
  if [ "$?" -ne 0 ]; then
    echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
  else
    # se ha realizado la copia, cambiando los permisos
    resume_container
    echo -e "\033[0;32m[INFO]\033[0m Cambiando propietario"
    error_msg=`trap 'docker exec -u 0 -it ${PROJECT_NAME}-web-1 chown 101:101 -R /mnt/extra-addons/${FILENAME_ZIP%.zip}' EXIT`

    if [ "$?" -ne 0 ]; then
      echo -e "\033[0;31m[ERROR]\033[0m" $error_msg
    else
      echo -e "\033[0;32m[OK]\033[0m Acción ejecutada."
    fi
  fi

  rm -rf /tmp/${FILENAME_ZIP%.zip}
else
  echo -e "\033[0;32m[INFO]\033[0m Acción ejecutada."
fi

echo -e "\033[0;32m[INFO]\033[0m Eliminando contenedor create_module_odoo."

resume_container