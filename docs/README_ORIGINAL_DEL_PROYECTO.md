> **Nota:** documento histórico. Menciona el cerebro local de 80 neuronas y la tecla **B**, que ya se eliminaron: el único cerebro es el conectoma real (ver [`CEREBRO.md`](CEREBRO.md)).

# Nocturnia (Godot 4.3+)

Abre la carpeta con Godot 4.3 o superior y pulsa F5. No hay assets: todo se genera por código.
Probado en Godot 4.3 y 4.7 (headless y OpenGL por software); Vulkan no se pudo probar en mi entorno.

## Controles
- **C**: primera persona → tercera persona → cámara libre
- **N**: siguiente ser a seguir (mosca, aldeanos, caballeros, culto, monstruos)
- **F**: volver a la mosca · **V**: velocidad ×1/×3/×8
- Arrastrar con el ratón: mirar alrededor · Cámara libre: WASD, Q/E

## Novedades (v3)
- Relieve: dominio deformado + ruido ridged (montañas, acantilados en terrazas), color por pendiente con estratos de roca, rocas, hierba, árboles apilados y árboles muertos en el pantano.
- Piedra con ladrillos (juntas, musgo), almenas, ventanas ojivales, puertas con arco, cascadas animadas con puente, agua animada.
- Cielo con shader propio (nubes azules, estrellas, luna creciente).
- Personajes con rostro y animación; lobo alquimista con laboratorio (caldero, pociones, hogar) en cada aldea.
- Se necesita importar el proyecto una vez (abrirlo en el editor) para registrar los `class_name`.

## Assets propios (v4)
Las texturas y cabezas esculpidas se generan con scripts y el juego las usa tal cual:
- `python tools/gen_textures.py` -> `assets/textures/*.png` (piedra de ladrillo, roca con estratos, pasto, tierra, corteza, hojas, tablones, pizarra, pelaje, tela, metal, piel). Son tileables.
- `python tools/gen_models.py` -> `assets/models/head_*.mdl` (lobo, búho, cabra, ogro). Cabezas esculpidas con campos de distancia + marching cubes (requiere `numpy`, `scikit-image`).
- `assets.gd` las carga. Si falta un archivo, el juego usa el fallback procedural.
- Si exportas el juego, añade `*.mdl,*.json` a los filtros de exportación (recursos no importados).
- Puedes sustituir cualquier PNG por arte propio con el mismo nombre (256x256, tileable).

## Qué hay
- `ps1.gdshader`: vértices que "tiemblan", paleta posterizada, textura pixelada. El look de baja resolución viene de `stretch/mode=viewport` a 640×360.
- `main.gd`: terreno por ruido (biomas), castillo, 4 aldeas, faro, luna, estrellas, lluvia, niebla.
- `mob.gd`: 4 facciones (aldeanos, caballeros, culto, monstruos). Pelean, huyen, comercian, hablan, reaparecen.
- `projectile.gd`: magia con fuego, escarcha (ralentiza), sombra (roba vida) y luz (cura).
- `fly.gd` + `fly_brain.gd`: la mosca. Red LIF de 80 neuronas: antenas → PN → cuerpos fungiformes → MBON → neuronas motoras, más fibra gigante de escape. Aprende con dopamina al comer y con castigo cerca de peligro. Cuando muere renace y conserva lo aprendido.

## Conectar el conectoma real (FlyWire)
`FlyBrain` usa listas de sinapsis salientes (event-driven), que es la estructura adecuada para escalar.
Para usar ~140.000 neuronas:
1. Exporta de FlyWire (Codex) las conexiones `pre_id, post_id, peso` y remapea los IDs a 0..N-1.
2. Identifica neuronas sensoriales (olfativas, visuales looming) y descendentes (giro, avance) y mapea `x[...]` de `fly.gd` a ellas.
3. Sustituye `_init()` para cargar las sinapsis y hazlo variable en tamaño (hoy `N=80` es constante).
4. GDScript no llega a esa escala en tiempo real: porta `step()` a C# o a una GDExtension (Rust/C++) y ejecútalo en un hilo.


## Personajes de Blender (.glb)
El lobo alquimista, el búho y el ogro/troll usan modelos reconstruidos en Blender a partir de la hoja de personajes
(`assets/models/char_wolf.glb`, `char_owl.glb`, `char_troll.glb`; fuentes en `personajes_blender/`).
- Se cargan en `MobModel._glb()` con el shader PS1 `pattern 7` (color de vértice; lo muy claro emite luz).
- Traen esqueleto y animaciones `idle`, `walk` y `attack`; `Mob._animate()` las reproduce según la velocidad y el ataque.
- Si falta el .glb, `MobModel` usa los modelos de primitivas de siempre.
- `tools/studio.tscn` (copiar a la raíz del proyecto) muestra los tres en un escenario de prueba.


## Cerebro real (conectoma FlyWire, 138.639 neuronas)
La mosca puede usar el cerebro real a través de un servidor Python (carpeta `cerebro_real/`, ver su `LEEME.md`).
- **B** alterna entre el cerebro local (80 neuronas, con aprendizaje) y el real; `--real-brain` arranca con el real.
- Código: `remote_brain.gd` (cliente TCP que hereda de FlyBrain; si no hay servidor, usa el local), y los cambios en `fly.gd` y `main.gd`.
- En modo real no hay aprendizaje (el conectoma tiene pesos fijos).

## Estética PS1 dark fantasy (post-proceso)
- `post_ps1.gdshader`: paleta reducida con dithering Bayer, viñeta, grano y azules fríos pasados a gris verdoso. Se añade en `main.gd::_post()` (capa 0, debajo del HUD). Ajusta `levels`, `vignette`, `grain` en el shader.
- `main.gd::_env()`: ambiente gris verdoso, niebla sucia (`fog_density`), saturación 0.62 y contraste 1.12.
- `sky.gdshader`: cielo ceniza con luna pálida (antes azul eléctrico).

## Envejecido, antorchas y personajes
- `tools/gen_textures.py`: las texturas de piedra, roca, suelo, madera y pizarra pasan por `age()` (desaturado, churretes de suciedad, manchas de humedad) y se guardan a 128 px (píxel más grueso). Regenerar: `python tools/gen_textures.py`.
- Antorchas y hogueras: parpadeo con varias frecuencias, chispazos, rango y color que respiran (`main.gd::_process`).
- Mobs (`mob_model.gd::_age`) y mosca (`fly.gd`): colores apagados y sucios; los modelos .glb se aclaran con `tint` 2.7.

## Mobs nuevos (estilo dark fantasy)
- Monstruos (facción 3): **esqueleto** (espada oxidada), **necrófago** (encorvado, garras), **espectro** (capa flotante, ojos fríos, lanza "sombra"), además del trasgo y el ogro.
- Culto (facción 2): **médico de la peste** (máscara de pico, farol con luz propia), además de cabra, búho y lobo.
- Se eligen al azar en `MobModel.pick_variant`; nombres/vida/hechizo por variante en `mob.gd` (`VNAMES`, `VLINES`, `_build`). Población: 20 monstruos y 10 cultistas en `main.gd::_population`.
- Los existentes (aldeano, caballero, trasgo, cabra) se retocaron: telas gastadas, acero oxidado, capas raídas, verdes apagados, sin dorados emisivos.
- Para probar uno aislado: `MobModel.force_variant = "skeleton"` antes de `spawn_mob`.

## Momentos del día, cámara libre y mapas
- **Hora del día** (`daynight.gd`): **T** salta con transición suave a Mañana → Día → Tarde → Noche; **Y** activa el paso automático del tiempo (1 h de juego cada 20 s); **R** enciende/apaga la lluvia (por defecto llueve de noche y al anochecer). Cambian cielo (sol, luna, estrellas, nubes), luz, niebla, saturación y brillo de antorchas.
- **Cámara libre** (tecla **C** hasta "Cámara libre"): **WASD** mover, **E/Q** subir/bajar, arrastrar con botón izquierdo para mirar, **Shift** ×4, **Ctrl** ×0.25, **rueda** cambia la velocidad. No choca con el terreno.
- **Minimapa** (esquina superior derecha, centrado en lo que sigue la cámara) y **mapa completo** (**M**; clic = la cámara libre viaja a ese punto). Puntos **rojos** = mobs vivos, amarillo = mosca, flecha blanca = cámara, cuadrado gris = castillo, marrón = aldeas, círculo dorado = faro. Código en `map_view.gd`.

## Animación de personajes
Los mobs con modelo de Blender mezclan idle/walk con fundido de 0,25 s, reproducen `attack` y `hit` (al recibir daño) y `death`:
al morir caen y se quedan en el suelo ~3,5 s antes de desaparecer y reaparecer (10 s en total).
