# Historial de cambios

Todo lo que se hizo en el proyecto, en orden aproximado, con el porqué de cada decisión. Los números de pruebas están en [PRUEBAS.md](PRUEBAS.md).

## Fase 1: el mundo y los seres

- **Mundo procedural:** terreno por ruido con biomas, castillo, 4 aldeas, faro, cascadas con puente, luna, estrellas, lluvia y niebla; todo generado por código (`main.gd`).
- **Estética PS1:** shader de objetos (vértices que tiemblan, paleta posterizada, textura pixelada) y un post-proceso con dithering de Bayer, viñeta, grano y azules fríos pasados a gris verdoso.
- **Mobs:** cuatro facciones (aldeanos, caballeros, culto, monstruos) que pelean, huyen, comercian, hablan y lanzan hechizos (fuego, escarcha, sombra, luz).
- **Mosca con cerebro local:** red LIF de 80 neuronas con la arquitectura del olfato y el escape de *Drosophila*, con aprendizaje por dopamina que se conserva al renacer.

## Fase 2: assets propios y personajes

- **Texturas y cabezas esculpidas** generadas por scripts (`tools/gen_textures.py`, `tools/gen_models.py`) con envejecimiento (suciedad, humedad, desaturado) y píxel más grueso.
- **Mobs nuevos** estilo dark fantasy: esqueleto, necrófago, espectro y médico de la peste, además de retoques a los existentes (telas gastadas, acero oxidado, sin dorados emisivos).
- **Personajes de Blender** (`blender/`): lobo alquimista, búho y troll reconstruidos a partir de una hoja de personajes; el resto de mobs orgánicos se generaron por código con `mobgen.py`. Exportados a `.glb` con color de vértice, esqueleto y animaciones.
- **Antorchas y hogueras** con parpadeo, chispazos y luz que respira.
- **Ciclo de día y noche** (`daynight.gd`): mañana, día, tarde y noche con transición suave, paso automático, lluvia, cámara libre, minimapa y mapa completo.

## Fase 3: el cerebro real

- **Integración del conectoma de FlyWire** (138.639 neuronas) con un servidor Python (`brain_server/`) y un cliente TCP en Godot (`remote_brain.gd`). Tecla **B** para alternar; si el servidor no está, el juego sigue con el local.
- **Corrección de «la mosca da vueltas en el sitio»:** el lector olfativo se había calibrado solo con un contraste enorme y devolvía giros de ±0,3 a ±0,8 con olor simétrico. Se recalibró con las condiciones del juego (5 intensidades × 12 asimetrías, correlación 0,90 en validación), se suavizó la respuesta, se bajó el giro máximo a ~1,5 rad/s y se separaron las antenas a 1,6 m. Resultado: de 0 a 2-3 frutas por prueba y sin vueltas sobre el sitio.

## Fase 4: animación, rendimiento y pulido

- **Animación más rica:** codos, rodillas y pies (huesos `fore_*`, `shin_*`, `foot_*`) en todos los personajes y animaciones nuevas `idle`, `walk`, `attack`, `hit` y `death`, con fundidos entre estados. Las mangas del lobo siguen al brazo.
- **Integración y uso en PC:** cómo enlazar los personajes en Godot, cómo activar el cerebro real por consola (`--real-brain`) y pantalla completa con **F11**.
- **Rendimiento (2 → 165 FPS con el cerebro real):** LOD de mobs, mallas unidas, animaciones congeladas a distancia y otros ajustes (ver [RENDIMIENTO.md](RENDIMIENTO.md)).
- **Agua más calmada:** un solo color con manchas leves en el shader.
- **Marcadores del minimapa:** puntos amarillos y un cuadrado blanco fuera del mapa se debían a que no se recortaba el dibujo (`clip_contents`).
- **Lag al chocar con paredes:** el rebote pasó de un cambio brusco a un giro suave (`bump_turn`).
- **«Teletransportes» de la mosca:** eran muertes con renacimiento instantáneo. Ahora la pantalla se oscurece y muestra el motivo (`flash_death`).
- **Reparto de mobs:** `spread_spot` elige entre 40 candidatos válidos el más alejado de los ocupados; así se ven mobs a lo largo de todo el recorrido de la mosca.
- **Ahogamiento y reaparición:** los mobs mueren si caen al agua y reaparecen en un punto seguro al azar. Una primera versión provocó ahogamientos masivos (puntos de aparición empinados, mal *fallback* en el agua); se corrigió con `is_safe_spot` y `safe_spot`.
- **Vídeos de recorrido** alternando primera y tercera persona, con el cerebro local y con el real.

## Fase 5: dolor y aprendizaje

- **Dolor al chocar con paredes:** activa la amenaza del lado golpeado, deja una memoria del lugar y provoca un rebote suave.
- **Retroceso por contacto sostenido:** una primera versión solo con dolor empeoró algunos casos (una semilla quedó 70 s pegada). Si pasan 0,5 s seguidos en contacto, la mosca retrocede, sube y gira hacia afuera.
- **Aprendizaje de miedo a las paredes** con bigotes (3 rayos) y condicionamiento clásico, persistente entre vidas y sesiones. Actúa en las entradas del cerebro, no dentro de él.
- **Desde aquí todas las pruebas de comportamiento se hacen con el cerebro real y a tiempo real.**

## Fase 6: ajustes de octubre

- **Rendimiento (física):** se midió que los mobs consumían ~9 ms por tick; LOD de física por tramos, colocación directa sobre el terreno para los lejanos y tope de 5 ticks por frame.
- **Relieve suave:** menos montañas, sin terrazas ni acantilados; la mosca vuela más libre y choca menos. Se probó que la mosca anticipara el terreno y se descartó (peores resultados).
- **Registro en pantalla** reducido a la actividad de la mosca (olfatea, huye, tiene hambre, choca, come, muere).
- **Hambre duplicada:** la energía baja a la mitad de velocidad; la mosca aguanta ~220 s sin comer.
- **El olor ya no atraviesa muros:** una fruta tapada llega con el 15 % de fuerza (rayo mosca → fruta), lo que reduce el tiempo que pasa empujando contra una pared.
- **Los mobs lejanos ya no atraviesan muros:** error introducido por la optimización anterior, corregido con rayos antes de cada paso.
- **Sesgo a la izquierda:** medido (85–87 % del giro) y corregido con el espejo periódico del cerebro real y dos sesgos de código (borde del mapa, choque de frente).

## Fase 7: solo cerebro real

- **Se eliminó el cerebro local de 80 neuronas** (red LIF con aprendizaje por dopamina) del juego y del repositorio. Ahora el único cerebro es el conectoma de FlyWire, a través de `brain_server/`.
- `fly_brain.gd` pasó de ser la red neuronal a una interfaz mínima (80 grupos, `rate[]`, `step`, `reset`, colores del panel). `remote_brain.gd` ya no tiene fallback local; se quitaron la tecla **B**, el argumento `--real-brain`, `punish()`/`reward()` y la dopamina.
- **Sin servidor la mosca espera quieta** (sin hambre ni edad) y el HUD indica `SIN SERVIDOR`; se reintenta conectar cada 3 s. Tras conectar, la primera respuesta puede tardar unos segundos.
- Se perdió el aprendizaje por dopamina del cerebro local; queda el miedo aprendido a las paredes, que actúa en las entradas.
- Comprobación con el cerebro real tras el cambio: vuelo libre 180 s, 2 semillas, contacto con paredes 2,9 % y 3,4 %, y 5 y 2 frutas comidas.

## Ideas pendientes

- Música dentro del juego (pistas `.ogg` propias por momento del día; Spotify solo sería control remoto y su música no puede emitirse en directos de YouTube).
- Patrullas de mobs, variantes de vídeo (mixto guiado con cerebro real, más largo, empezando entre mobs y frutas).
- Origen exacto del sesgo izquierdo del cerebro real.
- Los aldeanos y caballeros reaparecen en su casa; solo los mobs salvajes reaparecen en un punto al azar.
- Informe de errores de Godot 4.7 del usuario sin reproducir (falta el texto del error).
