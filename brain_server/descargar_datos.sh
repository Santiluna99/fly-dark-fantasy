#!/bin/sh
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
# Descarga el conectoma FlyWire (v783, modelo de Shiu et al. 2023) y sus anotaciones: ~370 MB, una sola vez.
mkdir -p datos && cd datos || exit 1
[ -d Drosophila_brain_model ] || git clone --depth 1 https://github.com/philshiu/Drosophila_brain_model
[ -d flywire_annotations ] || git clone --depth 1 https://github.com/flyconnectome/flywire_annotations
echo "Datos listos."
