# El cerebro de la mosca

El cerebro de la mosca es el **conectoma real de *Drosophila*** (FlyWire), simulado en un servidor Python (`brain_server/`) al que se conecta el juego (`remote_brain.gd`). **El servidor es imprescindible**. `fly_brain.gd` solo conserva la interfaz común (`rate[]` de 80 grupos, `step`, `reset`, colores del panel) que usan la mosca y el panel de actividad.

## 1. El panel de actividad y los 80 grupos

El panel de la esquina (80 cuadraditos; brillo = tasa de disparo) usa los colores de `FlyBrain.group_color`. Cada cuadradito es el **promedio de un grupo de neuronas del conectoma** (no una neurona suelta); el servidor agrupa las 138.639 neuronas en 80 grupos con este orden:

| Índices | Color | Grupo | Función |
|---|---|---|---|
| 0–1 | azul | ORN | olfato de cada antena |
| 2–3 | azul | looming | detectores de amenaza izquierdo y derecho |
| 4 | azul | hambre | |
| 5–12 | celeste | PN | neuronas de proyección (procesan el olor) |
| 13–72 | violeta | células de Kenyon | cuerpos fungiformes (memoria asociativa en la mosca real) |
| 73–74 | amarillo | MBON | neuronas de salida: acercarse / evitar |
| 75–76 | verde | DN giro | izquierda / derecha |
| 77 | verde | DN avance | |
| 78–79 | rojo | fibra gigante | escape ante amenaza muy cercana |

## 2. El servidor del conectoma (`remote_brain.gd` + `brain_server/`)

El **conectoma de FlyWire** (138.639 neuronas, ~15 millones de sinapsis, versión 783) simulado con el modelo LIF de Shiu et al. (2023), compilado con numba, en un servidor Python que escucha en `127.0.0.1:9009`. Instrucciones de puesta en marcha en [`SERVIDOR_CEREBRO.md`](SERVIDOR_CEREBRO.md).

### Protocolo (JSON por líneas sobre TCP)

Godot → servidor (cada 50 ms):

```json
{"orn": [izq, der], "loom": [izq, der], "hunger": 0.0, "reset": false}
```

Servidor → Godot:

```json
{"turn": -1..1, "fwd": 0..1, "gf": 0..1, "kc": 0..1, "raw": {...}, "view": [80 valores], "t_ms": 12345.0}
```

`turn > 0` = girar a la derecha. `view` es la actividad del conectoma **agrupada en 80 grupos** (promedio de la tasa de disparo de cada grupo) para alimentar el panel neuronal, que con el cerebro real no muestra neuronas sueltas sino promedios. Si el servidor no responde (`live = false`), la mosca **se queda quieta**, sin hambre ni edad, y `RemoteBrain` reintenta conectar cada 3 s; el HUD muestra `SIN SERVIDOR` o `esperando al servidor…`.

### Cómo se traduce el conectoma en movimiento

- **Entradas:** el olor estimula todas las neuronas olfativas de cada antena (hasta 100 Hz); la amenaza estimula las neuronas de *looming* LPLC2 de cada ojo (hasta 150 Hz); el hambre aumenta la respuesta al olor.
- **Giro:** lo calcula un **lector** (`calibrate.py`, `calibrate_olfato.py`): un vector de pesos sobre las 1.299 neuronas descendentes, entrenado con ensayos del propio conectoma (estímulo mayor a la izquierda frente a derecha) y validado con ensayos no usados. Visión: 100 % de acierto; olfato: 94 % (correlación 0,90 con las condiciones del juego). **No es un circuito motor conocido**: es un decodificador entrenado.
- **Avance:** actividad total de las neuronas descendentes. **Escape:** fibra gigante (DNp01).
- **Realce de contraste entre antenas** (`CONTRAST` = 12): la diferencia real entre antenas es de un par de %, y el cerebro no lateraliza con diferencias tan pequeñas.
- **Velocidad:** ~0,7× el tiempo real en un solo núcleo; los reflejos son algo más lentos que los de una mosca.

## 3. Dolor y aprendizaje (`fly.gd`)

Como el conectoma no cambia sus pesos, el aprendizaje de la mosca vive **en las entradas del cerebro** (antes de enviarlas al servidor).

**Dolor.** Un choque lateral contra algo vertical (`|normal.y| < 0.7`: muro, tronco, roca) provoca:

- dolor = 1 (decae en ~0,8 s) que activa el detector de amenaza del lado golpeado, y por tanto huida/giro hacia el lado contrario;
- una **memoria del lugar** (hasta 14 puntos, 10 s) que cuenta como amenaza delante de la mosca mientras está a < 6 m;
- un rebote suave (giro de hasta 0,9 rad a ~3 rad/s) y un impulso hacia arriba;
- si el choque es de frente, el lado del rebote se elige al azar (para no sesgar el giro).

**Pared pegada.** Si el contacto continuo supera 0,5 s, la mosca retrocede ~0,9 s a 5 m/s, sube y gira hacia la dirección de la normal de la pared.

**Bigotes y miedo aprendido** (condicionamiento clásico). Tres rayos de 9 m (centro y ±0,6 rad) miden cuán cerca está una pared. La mosca nace *ingenua* (`wall_fear = 0`: no reacciona a lo que ve). Cada golpe sube el miedo (`+0,12 + 0,2 × cercanía de la pared a la vista`, tope 1,5), y con miedo la cercanía de una pared se convierte en amenaza del lado correspondiente. El rayo central se reparte hacia el lado más cerrado, de modo que la mosca gira hacia el abierto. El miedo se guarda en `user://mosca_aprendizaje.json` (sobrevive a la muerte y a cerrar el juego; para volver a una mosca ingenua, borra el archivo). Aprende con ~10-20 golpes.

**Olor y muros.** El olor no atraviesa muros: cada ~8 ticks se lanza un rayo mosca → fruta (hasta 45 m); si hay algo sólido en medio, esa fruta llega con el 15 % de fuerza.

## 4. Simetría izquierda/derecha

El conectoma real no es perfectamente simétrico. Con frutas cerca, la mosca acababa dando vueltas casi siempre a la izquierda (85-87 % del giro). Sin estímulos o solo con mobs no había sesgo; el sesgo aparecía con el olor y no con un desvío fijo del decodificador, así que no se encontró un origen concreto. Solución en `remote_brain.gd`: cada 6-12 s se **espeja** el cerebro (se intercambian las entradas izquierda/derecha de olor y amenaza y se invierte el giro que sale). El comportamiento sigue siendo correcto (va hacia el olor, huye de la amenaza), pero cualquier sesgo propio cambia de signo y se compensa. Además se corrigieron dos sesgos propios del código: el giro en el borde del mapa (siempre a la izquierda) y el rebote en choques de frente. Resultado en pruebas con el cerebro real: ~53 % izquierda / 47 % derecha (45-59 % según la semilla).

## Límites

- El conectoma real no aprende; el miedo a las paredes no es plasticidad del conectoma.
- El giro lo da un decodificador entrenado, no un circuito motor identificado.
- A más de ~20 m de una fruta la señal entre antenas es débil y la mosca avanza casi en línea recta con deriva aleatoria.
