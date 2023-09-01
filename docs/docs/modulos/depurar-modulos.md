---
layout: page
menubar: docs_menu
title: Cómo depurar módulos
subtitle: Módulos
show_sidebar: false
hero_height: is-fullwidth
---

## Cómo depurar módulos con VSCode

La depuración de módulos se realiza aprovechando la características Remote Development de VSCode. Para utilizarla con Docker es necesario instalar [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers). El acceso se realiza a través del icono <img style="vertical-align:middle" src="./DOCUMENTATION/assets/icon_remote_containers.png" width="35" height="39" alt="icono acceso Remote Development"> y, al acceder, muestra en el panel vertical los contenedores y los volúmenes existentes. 

El proceso para poder depurar consiste:

 1. Adjuntar a Visual Studio Code el contenedor _odoodock-web-1_. Esa operación abrirá una nueva instancia de _VSCode_ que será desde la que se trabajará.

 2. Instalar la extensión _Python_
 
 3. Acceder al _Explorer_ y abrir una carpeta (_Open Folder_)

 3. Seleccionar la carpeta _/mnt/extra-addons_

 4. Arrancar desde _Run & Debug_ la configuración _Python: Odoo attach debug_