> Documentación técnica de la carpeta [`brain_server/`](../brain_server). Para una explicación sencilla, ver [`brain_server/README.md`](../brain_server/README.md).

# Cerebro real de la mosca para Nocturnia (conectoma FlyWire)

Servidor Python que simula el conectoma completo (138.639 neuronas, 15 millones de sinapsis; FlyWire v783) y se conecta al juego
por TCP local (puerto 9009). Godot le manda lo que siente la mosca y recibe giro, avance y actividad.

## Puesta en marcha
1. `pip install -r requirements.txt` (Python 3.10+; usa numba, así que la primera ejecución tarda unos segundos más)
2. `sh descargar_datos.sh` (o `descargar_datos.bat` en Windows): baja ~370 MB de GitHub a la carpeta `datos/` (una sola vez)
3. `sh iniciar.sh` (o `iniciar.bat`). Verás `Cerebro listo: 138639 neuronas...`
4. Abre el proyecto Godot (`game/`) y pulsa F5. Es el **único cerebro** de la mosca: el HUD muestra "Cerebro: REAL, 138.639 neuronas".
   Si el servidor no está, la mosca espera quieta (HUD: "SIN SERVIDOR") y el juego reintenta conectar cada 3 s. La primera respuesta puede tardar unos segundos.

## Qué hace cada parte
- `fly_sim.py` — simulador LIF (parámetros de Shiu et al. 2023) con estado persistente y bucle compilado (numba); paso de 0,5 ms.
  Corre a ~0,7 veces el tiempo real en un solo núcleo.
- `fly_server.py` — hilo del cerebro continuo + servidor. Estímulos: olor en todas las neuronas olfativas de cada antena (hasta 100 Hz),
  amenaza en las neuronas de looming LPLC2 de cada ojo (hasta 150 Hz), hambre aumenta la respuesta al olor.
  Salidas: giro, avance, fibra gigante (escape), actividad de células de Kenyon y 80 grupos para el panel neuronal.
- `calibrate.py` — aprende los **lectores de giro**: un vector de pesos sobre las 1.299 neuronas descendentes, entrenado con ensayos
  del propio conectoma (estímulo mayor a la izquierda vs derecha) y validado con ensayos no usados:
  visión 100 % de acierto, olfato 94 %. Guarda `decoders.npz`. Vuelve a ejecutarlo si cambias parámetros del modelo.
- `fly_circuits.py`, `fly_fixes.py` — los experimentos de olfato/visión de antes (el perfil olfativo de `fly_fixes` se aplica al arrancar).
- `test_client.py` — prueba el servidor sin Godot (estímulo a izq/der, amenaza, etc.).

## Decisiones y límites (importante)
- **El giro lo da un lector que entrené yo**, no un circuito motor conocido: el signo de las neuronas descendentes individuales
  era ambiguo y ruidoso. Para la huida se gira en sentido contrario a la amenaza; para el olfato, hacia el lado de más olor.
- **No hay aprendizaje**: el conectoma tiene pesos fijos; en modo real no funcionan la recompensa ni el castigo.
- **El avance** sale de la actividad total de las neuronas descendentes (no de una neurona concreta).
- **El olor lleva realce de contraste entre antenas** (`CONTRAST` en `remote_brain.gd`): la diferencia real entre antenas es de
  un par de %, y el cerebro no lateraliza con diferencias tan pequeñas.
- **Rendimiento del seguimiento de olor**: en mis pruebas la mosca se acerca a una fruta hasta 2-3 m pero no siempre la captura
  (radio de comer 1,5 m): gira con retraso (~0,3-0,5 s) y con ruido. Ajustables: `TURN_RATE`, `CONTRAST`, la ganancia de
  avance en `remote_brain.gd`, y `ALPHA` / `RATE_ORN` en `fly_server.py`.
- La huida de amenazas sí está validada: amenaza a un lado → fibra gigante activa y giro hacia el lado contrario.
- El cerebro corre a ~0,7× el tiempo real: los reflejos son algo más lentos que los de una mosca.

## Corrección: la mosca daba vueltas en el sitio
**Causa.** El lector olfativo se había calibrado solo con un contraste enorme (50 frente a 15 Hz) y un nivel simétrico. Con olor simétrico a otras intensidades devolvía giros de ±0,3 a ±0,8 (sesgo que dependía de la intensidad) y apenas distinguía izquierda de derecha con diferencias pequeñas. Como el giro máximo era alto (~3,5 rad/s) y el sesgo duraba segundos, la mosca trazaba círculos de ~1 m.
**Arreglo.**
- `calibrate_olfato.py`: reentrena solo el lector olfativo con las condiciones del juego (5 intensidades × 12 asimetrías de −80 % a +80 %, incluidas las simétricas con objetivo 0), regresión ridge sobre las neuronas descendentes. Validación con ensayos no usados: correlación 0,90; simétrico = 0,01 (sd 0,10); signo correcto en el 90 % incluso con 10 % de diferencia entre antenas. Para repetirlo: `python calibrate_olfato.py 6` (≈3 min).
- Servidor: suavizado más largo (`ALPHA` 0,06) y `OLF_STEER` 1,8.
- Godot (`remote_brain.gd`): giro máximo ~1,5 rad/s (`TURN_RATE` 0,14), zona muerta de 0,1, `CONTRAST` 12 y frenado cerca de la fruta. `fly.gd`: antenas separadas 1,6 m.
**Resultado (3 semillas, 53–77 s):** sin vueltas sobre el sitio (giro total 18–20 rad en 77 s, antes 83 rad en 59 s) y 2, 2 y 3 frutas comidas (antes 0).
**Límites que siguen.** A más de ~20 m de la fruta la señal entre antenas es débil y la mosca avanza casi en línea recta con deriva aleatoria; con mobs cerca el giro de huida domina. Sigue sin haber aprendizaje en modo real.

## Nota sobre el cliente (Godot)
El **espejo izquierda/derecha** que compensa el sesgo de giro del conectoma se hace en el cliente (`game/remote_brain.gd`), no aquí: el servidor recibe las entradas ya intercambiadas y su giro se invierte al llegar. Ver [`docs/CEREBRO.md`](CEREBRO.md). Para probar con varias instancias a la vez usa un puerto distinto por servidor: `python fly_server.py --port 9021`.
