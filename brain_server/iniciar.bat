@echo off
if not exist datos\Drosophila_brain_model call descargar_datos.bat
python fly_server.py %*
