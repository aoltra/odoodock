---
layout: page
title: Preguntas frecuentes
subtitle:
show_sidebar: false
hero_height: is-fullwidth
---

### Preguntas frecuentes

<br>

* **En ocasiones el contenedor _contenedor odoodock-web-1_ cae o se reinicia**

    Generalmente el problema viene por la modificación (nuevo fichero, modificación de alguno de los existentes...) del directorio de _/mnt/extra-addons_ sin haber lanzado el proceso de [depuración](#cómo-depurar-módulos-con-vscode). En general el contenedor debería reinciarse por si solo y sólo requeriría reacargar la ventana del VSCode, pero una opción más sencilla es tener arrancado el proceso de depuración.

<br>

* **¿ Es posible depurar dentro del código de Odoo?**

   Sí. Por defecto la configuración para la depuración no lo permite por razones de simplicidad, pero es posible hacerlo modificando el fichero _/mnt/extra-addons/.vscode/launch.json_ del contenedor de tal manera que para la configuración _Python: Odoo attach debug_ incluya la opción _justMyCode_ a False

   ```
      {
         "name": "Python: Odoo attach debug",
         "type": "python",
         "request": "attach",
         "connect": {
               "host": "localhost",
               "port": 5678
            },
         "justMyCode": False
      },
   ```
<br>

* **¿ Es posible arrancar dos servicios Odoo de manera simultánea?**

   Sí. Para ello únicamente hay que crear otra carpeta y seguir los pasos del proceso de [instalación](#instalación). 
   
   A la hora de configurar el sistema existen dos opciones: compartiendo el mismo SGBD o en diferentes SGBD. 
   
   La configuración del _.env_ usando dos instancias del SGBD (postgres) debe tener en cuenta:

   - Elegir nombres de servidores (ODOO_SERVER_NAME) diferentes en cada carpeta
   - Elegir puertos de Odoo y de ssh (ODOO_PORT, OSOO_SSH_PORT) diferentes en cada carpeta
   - Elegir puertos en los que escucha postgres (ODOO_POSTGRESS_PORT, POSTGRES_PORT) diferentes en cada carpeta
   - Indicar el nombre del contenedor de la base de datos correcto (ODOO_POSTGRESS_HOST)

   > Hay que tener en cuenta que en el caso de más de una instancia los contenedores irán sufijados por números enteros secuenciales: odoodock_web_1, odoodock_web_2, odoodock_db_1, odoodock_db_2...
