#!/bin/sh
# Arranca el servidor del cerebro real (puerto 9009). Cierra con Ctrl+C.
[ -d datos/Drosophila_brain_model ] || sh descargar_datos.sh
python3 fly_server.py "$@"
