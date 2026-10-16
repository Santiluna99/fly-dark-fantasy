#!/bin/sh
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
# Arranca el servidor del cerebro real (puerto 9009). Cierra con Ctrl+C.
[ -d datos/Drosophila_brain_model ] || sh descargar_datos.sh
python3 fly_server.py "$@"
