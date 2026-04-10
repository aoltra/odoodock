---
layout: page
title: keycloak
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## Keycloak

[**Keycloak**](https://www.keycloak.org/) es un sistema de gestión de identidades y accesos (IAM) de código abierto que permite a los desarrolladores integrar capacidades avanzadas de autenticación y autorización sin necesidad de desarrollar estas funciones desde cero.

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _keycloak_.

2. Crear la base de datos en el servicio *db* (postgres) taly como se explica [aquí](/odoodock/services/db)

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

3. Abrir el navegador y acceder a la URL _http://locahost:8080/auth_.

> MUY IMPORTANTE. Si se utiliza el servicio db para dar soporte éste, si para crear la bd no se ha reconstruido la imagen de _postgres_ es posible que el servicio no arranque correctamente ya que la base de datos no estaría creada. La solución más sencilla consiste en reiniciar los contenedores.

### Configuración de providers

Es posible extender _keycloak_ con extensiones proporcionadas por proveedores de servicios.

Su configuración consiste en:

1. Modificar el fichero _.system-providers_ para añadir por cada fila el nombre y la url de descarga del plugin.

2. Modificar el fichero _.system-providers-variables-example_ para añadir, en formato _.env_ (`NOMBRE_VARIABLE=valor`), las variables de configuración del plugin.

3. Dar permisos de ejecución al fichero `./keycloak/setup_spis.sh`

   ```bash
   chmod +x ./keycloak/setup_spis.sh 
   ```

4. Ejecutar el script.

   ```bash
   cd keycloak
   ./setup_spis.sh 
   ```

> IMPORTANTE. En modo desarrollo (_start-dev_) _keycloak_ recarga la configuración y los providers cada vez que reinicia el contenedor.

> Ciertos plugins pueden requerir de configuraciones previas de otros ervicvios, por ejemplo de colas de Rabbit. Sin esas configuraciones los plugins pueden dar errores. En ese caso es conveniente visualizar el log.

