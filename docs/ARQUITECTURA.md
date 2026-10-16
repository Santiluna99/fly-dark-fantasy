# Arquitectura

Todo el juego se construye **por código**: `main.tscn` solo tiene un nodo raíz con `main.gd`, que genera el terreno, las estructuras, las luces, la interfaz y la población al arrancar (`_ready`). Los assets externos (texturas PNG, cabezas esculpidas `.mdl`, personajes `.glb`) son opcionales: si falta alguno hay un reemplazo procedural.

```
game/
├── main.gd            Mundo: terreno, biomas, castillo, aldeas, cascadas, faro, población, cámara, HUD, entrada
├── fly.gd             La mosca: sentidos, dolor/aprendizaje, movimiento con física, hambre
├── fly_brain.gd       Cerebro local: red LIF de 80 neuronas con dopamina
├── remote_brain.gd    Cerebro real: cliente TCP que hereda de FlyBrain (con espejo izquierda/derecha)
├── neuro_view.gd      Panel de actividad (80 cuadraditos)
├── mob.gd             IA de los mobs: facciones, combate, comercio, LOD, ahogamiento y reaparición
├── mob_model.gd       Modelos de mobs (primitivas o .glb con animaciones)
├── projectile.gd      Hechizos: fuego, escarcha, sombra, luz
├── daynight.gd        Ciclo día/noche, cielo, lluvia, antorchas
├── map_view.gd        Minimapa y mapa completo
├── assets.gd          Carga de texturas y cabezas con fallback procedural
├── ps1.gdshader       Shader de objetos: vértices temblorosos, paleta posterizada
├── post_ps1.gdshader  Post-proceso: dithering, viñeta, grano, tono apagado
├── sky.gdshader       Cielo con nubes, estrellas y luna
├── assets/            Texturas y modelos (.glb, .mdl)
├── tools/             Generadores de texturas y cabezas, escena de estudio, grabador de recorridos
└── tests/             Pruebas automáticas (ver docs/PRUEBAS.md)
```

## El mundo (`main.gd`)

- **Tamaño:** 256 × 256 m (`HALF = 128`), malla de 192 × 192 celdas con colisión sólida (trimesh).
- **Relieve** (`height_at(x, z)`): es la función central; terreno, árboles, mobs y mosca la usan. Combina un ruido simplex base (`elev`), deformación de dominio (`warp`), crestas (`ridge`) y detalle fino. El borde del mapa baja formando el mar; el castillo, las aldeas y las cascadas se aplanan a una altura de 1,5 m. El relieve es suave: máximo ~14 m, sin terrazas ni acantilados (ver [HISTORIAL](HISTORIAL.md)).
- **Agua:** plano animado a `WATER = -1`.
- **Biomas** (`biome_idx`): lecho, nieve (>10,5 m), pantano, bosque, páramo, llanura; deciden color, vegetación y dónde aparecen cosas.
- **Estructuras:** castillo central (torres, murallas con almenas, arcos), 4 aldeas (`VILLAGES`) con el laboratorio del lobo alquimista, cascadas con puente (`FALLS`), un faro y ruinas.
- **Sitios seguros:** `land_spot`, `is_safe_spot`, `safe_spot` y `spread_spot` eligen puntos de aparición en tierra firme, lejos de la orilla y de pendientes fuertes, y reparten los mobs salvajes por todo el mapa.
- **Entrada y cámara:** `_input` (teclas), `_process` (cámara con suavizado de rumbo y foco, HUD, parpadeo de antorchas).
- **Pantalla de muerte:** `flash_death(why)` oscurece la pantalla y muestra el motivo; así una muerte nunca parece un teletransporte.
- **Registro en pantalla:** `log_msg` solo acepta mensajes que empiezan por «Mosca».

## Mobs (`mob.gd`, `mob_model.gd`)

- **Facciones:** 0 aldeanos, 1 caballeros, 2 culto, 3 monstruos; ~66 en total. Pelean, huyen, comercian, hablan y lanzan hechizos (`SPELLS`).
- **Modelos:** 11 `mob_*.glb` y `char_wolf/owl/troll.glb`, con mallas unidas (una llamada de dibujo por personaje) y animaciones `idle`, `walk`, `attack`, `hit`, `death`; fundido de 0,25 s entre idle y walk, 0,08 s en golpes. Si falta el `.glb` se usan modelos de primitivas.
- **Muerte y reaparición:** al morir caen y desaparecen; reaparecen a los 10 s en un punto seguro al azar del mapa. Si caen al agua (`y < WATER - 0.3`) mueren ahogados y también reaparecen.
- **LOD por distancia a la cámara** (ver [RENDIMIENTO](RENDIMIENTO.md)): cuanto más lejos, menos frecuente es su IA y su física.

## La mosca (`fly.gd`)

`CharacterBody3D` que vuela. Cada tick de física: sentir → pensar → moverse → comer.

1. **Sentidos:** olor en dos antenas separadas 1,6 m (concentración sumada de todas las frutas, atenuada si hay un muro entre medias), amenaza (mobs y proyectiles hasta 8 m, a izquierda/derecha), hambre, bigotes (3 rayos de 9 m) y memoria de choques.
2. **Cerebro:** `brain.step(x)` con el vector de entradas; local o real (ver [CEREBRO](CEREBRO.md)).
3. **Movimiento:** giro por diferencia entre neuronas motoras, rebote suave tras un choque, retroceso si queda pegada a una pared, altura sobre el terreno, `move_and_slide`.
4. **Comer y morir:** come a < 1,5 m de una fruta (+35 de energía); muere por hambre (`HUNGER_RATE = 0.45`, ~220 s), por un manotazo de un mob o por un hechizo; renace conservando lo aprendido.

## Render

- Renderer **gl_compatibility** (funciona en casi cualquier GPU).
- `ps1.gdshader` aplica el aspecto PS1 a los objetos; `post_ps1.gdshader` es una pasada a pantalla completa con paleta reducida, dithering de Bayer, viñeta y grano; el cielo es un shader propio.
- Ventana de 1280 × 720 con `stretch/mode=viewport` y aspecto mantenido; F11 alterna pantalla completa.
- Texturas tileables a 128 px generadas por `tools/gen_textures.py` (con envejecimiento: desaturado, churretes de suciedad, humedad).
