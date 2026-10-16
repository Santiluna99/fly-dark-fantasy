# Personajes Nocturnia (Lobo Hechicero, Mago Búho, Troll de Colina)

Reconstruidos con Blender (bpy) a partir de la hoja de personajes: silueta frontal/lateral -> malla, y color proyectado desde las vistas.

- modelos/*.blend  -> abrir en Blender (malla con color por vértice "Col", esqueleto "Rig", animaciones idle/walk/attack en pistas NLA)
- modelos/*.glb    -> para Godot 4 (arrastrar a res://). Los colores van como COLOR_0 (ya en espacio lineal).
- scripts/         -> para regenerar. Rutas absolutas dentro de los scripts (/home/claude/blender/...): cámbialas a tu carpeta.
    * wolf_ref.py, owl_ref.py, troll_ref.py  (uno por personaje), charlib.py y fit.py (comunes)
    * Requiere: Blender 4.x/5.x con Python o `pip install bpy numpy scipy pillow scikit-image`
- comparaciones/   -> hoja vs modelo (frente, lado, espalda)
- referencia/      -> recortes de la hoja usados

Notas: el búho no tiene vista lateral pura en la hoja, así que su profundidad se estima por proporción.
Las manos del lobo, el libro y las garras del búho son piezas simples añadidas a mano.
Dentro de Godot, si se ven oscuros, sube el parámetro `tint` del shader PS1 (x1.5).

## Mobs orgánicos hechos en Blender (sin hoja de referencia)
- `scripts/mobgen.py`: librería (cuerpo con modificador Skin + Subsurf, accesorios esculpidos, colores de vértice sucios, armadura con pesos automáticos, animaciones idle/walk/attack, exportación .glb).
- `scripts/mob_*.py`: skeleton, ghoul, wraith, plague, human (0-2), knight, goblin (0-1), goat. Ejecutar: `python mob_knight.py` (ajusta la ruta OUT en mobgen.py).
- `modelos/mob_*.glb|.blend`: resultados; ya están en `nocturnia/assets/models/`.

## Animaciones ampliadas
Todos los personajes tienen ahora codos, rodillas y pies (huesos `fore_*`, `shin_*`, `foot_*`) además de brazos/piernas.
Animaciones: `idle` (respira, mira a los lados, desplaza el peso), `walk` (flexión de rodilla y codo, giro de torso, rebote de cadera),
`attack` (armar, golpear, recuperar), `hit` (retroceso) y `death` (tambalea, cae de espaldas; no se repite).
- `scripts/mobgen.py`: `std_bones`/`std_anims` nuevos. Los accesorios (espadas, botas, escudos) se reasignan solos al hueso del segmento.
- `scripts/reanimate.py <blend> <salida>`: añade esos huesos a lobo/búho/troll y repesa las mallas (las mangas del lobo siguen al brazo).
- `scripts/posepreview.py`: render rápido de poses para revisar.
