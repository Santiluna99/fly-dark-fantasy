@echo off
REM Hollowfly - Copyright (C) 2026 Santiluna99
REM Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
REM Descarga el conectoma FlyWire (v783) y sus anotaciones (~370 MB, una sola vez)
if not exist datos mkdir datos
cd datos
if not exist Drosophila_brain_model git clone --depth 1 https://github.com/philshiu/Drosophila_brain_model
if not exist flywire_annotations git clone --depth 1 https://github.com/flyconnectome/flywire_annotations
echo Datos listos.
