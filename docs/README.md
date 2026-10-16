# Documentación

Aquí están las explicaciones **a fondo** de cómo funciona Nocturnia por dentro. Son más técnicas que los README de cada carpeta. Si solo quieres jugar, no hace falta leerlas: empieza por el [README principal](../README.md).

## Qué documento leer según lo que busques

| Si quieres saber… | Lee |
|---|---|
| Cómo está organizado el juego y qué hace cada archivo | [`ARQUITECTURA.md`](ARQUITECTURA.md) |
| Cómo funciona el cerebro de la mosca y cómo habla con el juego | [`CEREBRO.md`](CEREBRO.md) |
| Cómo encender y ajustar el cerebro, con todos sus detalles | [`SERVIDOR_CEREBRO.md`](SERVIDOR_CEREBRO.md) |
| Cómo se crearon los personajes en Blender | [`PERSONAJES_BLENDER.md`](PERSONAJES_BLENDER.md) |
| Cómo se consiguió que el juego vaya fluido (de 2 a 165 imágenes por segundo) | [`RENDIMIENTO.md`](RENDIMIENTO.md) |
| Cómo se prueba que todo funciona y qué resultados dio | [`PRUEBAS.md`](PRUEBAS.md) |
| La historia del proyecto: qué se hizo, en qué orden y por qué | [`HISTORIAL.md`](HISTORIAL.md) |
| Cómo era el proyecto al principio | [`README_ORIGINAL_DEL_PROYECTO.md`](README_ORIGINAL_DEL_PROYECTO.md) |

## Imágenes

La carpeta [`img/`](img) tiene capturas del juego y de los personajes que se usan en los README.

## Palabras que vas a encontrar

- **Conectoma:** el mapa completo de las neuronas de un cerebro y de cómo están conectadas.
- **Neurona:** la célula del cerebro que recibe señales y las pasa a otras.
- **FlyWire:** el proyecto científico que cartografió el cerebro de la mosca de la fruta.
- **Mob:** cualquier personaje del mundo que no es la mosca (aldeanos, caballeros, monstruos…).
- **Servidor:** el programa aparte donde vive el cerebro; el juego se conecta a él.
- **Godot:** el programa con el que está hecho el juego.
- **Shader:** un pequeño programa que decide cómo se pinta lo que se ve en pantalla.
- **FPS:** imágenes por segundo; cuantas más, más fluido se ve el juego.
