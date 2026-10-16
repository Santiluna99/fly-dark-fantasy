@echo off
REM Hollowfly - Copyright (C) 2026 Santiluna99
REM Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
if not exist datos\Drosophila_brain_model call descargar_datos.bat
python fly_server.py %*
