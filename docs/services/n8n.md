---
layout: page
title: n8n
subtitle: Servicios disponibles
menubar: services_menu
show_sidebar: false
hero_height: is-fullwidth
---

## n8n

Plataforma de automatización de flujos de trabajo de código abierto (open-source) y "low-code".

1. Comprobar que en el fichero _.services_ está descomentada la línea con el servicio _n8n_.

2. Ejecutar _./up.sh_ desde la carpeta _odoodock_.

3. Abrir el navegador y acceder a la URL _http://locahost:5678_.

4. Configurar usuario y contraseña

### Volumen compartido

Para el trabajo con ficheros locales se utiliza como carpeta local en el host `SSERVER_INFO_PATH_HOST/n8n_files`, que, por defecto apunta a la carpeta _.server-info/n8n_files_, almacenada en el mismo nivel que la carpeta _odoodock_.

> En el contenedor la carpeta equivale a _/home/node/.n8n-files/_, por lo que en los nodos los ficheros o carpetas a vigilar o grabar deben de apuntar a ese directorio.
