# Rendimiento

Objetivo: que el juego sea fluido en equipos modestos con el renderer de compatibilidad. Las medidas de abajo se tomaron **sin GPU** (renderizado por software con xvfb + llvmpipe y ejecuciones *headless*), salvo las capturas del usuario con su contador de FPS. Con renderizado por software solo se puede medir coste relativo, no FPS absolutos.

## De 2 a 165 FPS

Con el cerebro real el juego iba a unos 2 FPS (captura del usuario) y pasó a unos 165 FPS (captura del usuario) con un conjunto de optimizaciones; las principales:

- **Mobs con LOD:** los mobs lejos de la cámara «piensan» con menos frecuencia (y en el mismo paso mueven más distancia para compensar). Los escaneos del entorno van desfasados (`0.25 + randf() × 0.1` s) para que no coincidan en un mismo tick, y la comprobación de agua por delante se hace cada 4 ticks.
- **Mallas unidas:** cada personaje es una sola malla con esqueleto (una llamada de dibujo), en vez de decenas de piezas.
- **Animación:** las animaciones se congelan a más de 60 m de la cámara.
- **Cerebro real fuera del hilo del juego:** el servidor es un proceso aparte; Godot solo envía y lee mensajes cada 50 ms sin bloquear.
- **Agua más simple:** menos manchas en el shader (un solo color con manchas leves), también por estética.
- **Minimapa:** `clip_contents = true`, para que los marcadores no se dibujen fuera del mapa (corrección visual).

## El cuello de botella de la física (octubre)

Se informaron caídas puntuales a ~1 FPS. No se reprodujeron en el entorno de pruebas, pero la medición de la física mostró que **los ~66 mobs consumían ~9 ms por tick de física** (el presupuesto es 16,7 ms a 60 Hz), casi todo en `move_and_slide`. Cuando un tick pasa de presupuesto, Godot ejecuta varios ticks por frame, cada frame cuesta más y los FPS se desploman («espiral de la muerte»).

Medidas tomadas:

1. **LOD de física por tramos** (`mob.gd`, distancia a la cámara):
   - < 25 m: cada tick, con `move_and_slide`.
   - 25–40 m: 1 de cada 3 ticks, con `move_and_slide`.
   - > 40 m: 1 de cada 6 ticks y **sin motor de física**: el mob se coloca directamente sobre el terreno (`height_at`).
2. **Rayos anti-muros para los mobs lejanos:** al saltarse la física, los mobs lejanos atravesaban muros. Ahora, antes de cada paso, lanzan 3 rayos (a 0,3, 1,0 y 1,9 m de altura) y, si encuentran algo sólido vertical, no avanzan y eligen otro rumbo.
3. **Tope de ticks por frame:** `Engine.max_physics_steps_per_frame` bajó de 16 a 5, de modo que si algo se pone pesado el juego se ralentiza un poco en vez de colapsar.

Resultado (en el entorno de pruebas, con el cerebro real conectado): coste mediano de la física por tick de ~9 ms a ~5 ms, y el 1 % peor de ~26 ms a ~13 ms.

## Otras medidas de rendimiento

- **Lag al chocar contra paredes:** el rebote pasó de un cambio brusco de rumbo a un giro suave repartido en varios ticks (`bump_turn`).
- **Sondas de la mosca:** olor y bigotes usan unos pocos rayos por tick (3 de bigotes; el de olor se refresca cada 8 ticks); el coste medido es despreciable frente a los mobs.
- **Paso de física lento en máquinas débiles:** con el tope de 5 ticks el reloj del juego puede ir más lento que el real en momentos de carga.

## Cómo medir

`game/tests/ptime.gd` mide el coste de física por tick (percentiles) con el cerebro real; `game/tests/fps_sweep.gd` recorre 36 puntos del mapa en primera y tercera persona y mide el tiempo por frame (útil para encontrar zonas lentas con renderizado por software); `--print-fps`/el HUD (`show_fps`) muestran los FPS en vivo. Ver [PRUEBAS.md](PRUEBAS.md).

## Si sigues viendo caídas a ~1 FPS

Probablemente sea la GPU y no la física (relleno de pantalla: lluvia, agua, post-proceso). Prueba a desactivar la lluvia (**R**), cambiar la hora (**T**) o reducir la ventana, y anota en qué situación ocurre.
