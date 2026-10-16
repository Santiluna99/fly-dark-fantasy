# Pruebas

No hay GPU en el entorno de desarrollo, así que las pruebas son **automáticas, sin pantalla** (`--headless`) o con renderizado por software (`xvfb` + `--rendering-driver opengl3`, ~3-5 FPS, válido para capturas pero no para FPS reales). Los scripts están en `game/tests/`; cada uno es una escena que instancia `main.tscn` y mide algo.

## Reglas de método

- **Con el cerebro real.** Desde que se decidió, las pruebas de comportamiento de la mosca se hacen con el servidor del conectoma conectado y **a tiempo real** (sin `--fixed-fps` ni `Engine.time_scale`): el cerebro avanza con el reloj de pared, así que acelerar el juego lo dejaría con pocos pasos por segundo simulado y falsearía el resultado.
- **Servidores aparte por prueba.** Cada ejecución en paralelo usa su propio puerto (`python fly_server.py --port 9021`) porque el servidor consume un núcleo.
- **Varias semillas** (`seed(n)` por argumento), mismo mapa y comparación antes/después con el mismo conjunto de semillas. Son muestras pequeñas (2-5 semillas): dan orden de magnitud, no intervalos de confianza.
- **Línea base.** Para comparar se copia el proyecto a otra carpeta y se revierte (o desactiva) solo el cambio estudiado.
- **Ejecución a través de `grep`.** Un fallo de compilación en GDScript inunda la salida; se filtra con `grep -E "RESULTADO|SCRIPT ERROR"`.

## Cómo ejecutar

```bash
godot --headless --path game --import                                     # una vez
godot --headless --path game res://tests/soak5.tscn                       # estabilidad general
godot --headless --path game res://tests/hstat.tscn                       # estadísticas del terreno
# con el cerebro real (en otra terminal: cd brain_server && python fly_server.py --port 9011)
godot --headless --path game res://tests/stickreal.tscn -- <semilla> <aprende 0|1> 9011
godot --headless --path game res://tests/wallreal.tscn  -- <semilla> 9011
godot --headless --path game res://tests/ptime.tscn     -- <semilla> 9011 base
```

| Script | Qué mide |
|---|---|
| `soak5` | Estabilidad: simulación larga, muertes, mobs vivos y con animación; falla si hay errores |
| `stickreal` | Vuelo libre 180 s con el cerebro real: % de tiempo en contacto con paredes, episodios, racha más larga |
| `wallreal` | Una fruta detrás de una pared: contacto con la pared y frutas comidas |
| `ptime` | Coste de física por tick (p50, p99, máx) |
| `fps_sweep` | Tiempo por frame en 36 puntos × 2 cámaras (para detectar zonas lentas) |
| `hstat` | Altura máxima, % de agua, % de terreno alto y empinado |
| `crosswall` | ¿Atraviesan muros los mobs lejanos? |
| `drown3` | Ahogamientos de mobs en 240 s simulados |

## Resultados principales

**Choques de la mosca contra paredes** (vuelo libre, `contacto` = % de ticks tocando una superficie vertical):

| Cambio | Antes | Después |
|---|---|---|
| Rebote suave + dolor + retroceso si queda pegada (cerebro local, 5 semillas × 300 s; histórico) | 7–28 %, racha hasta 4,7 s | 3,5–7 %, racha ≤ 0,2 s |
| Aprendizaje por bigotes (cerebro local, 3 semillas × 300 s; histórico) | ~6 % constante | 1,4–3,4 % |
| Aprendizaje (cerebro **real**, 3 semillas × 180 s, inicio ingenuo) | 7,9 / 14,2 / 26,0 % | 0,0 / 8,3 / 0,6 % |
| Relieve suave (cerebro real, aprendiendo) | 0,5 / 7,4 % | 0,1 / 5,0 % |
| Olor ocluido por muros (cerebro real, fruta tras una pared, 90 s) | 15–25 % de contacto, 30–43 episodios | 4–8 %, 8–18 episodios |

**Simetría de giro** (cerebro real, % del giro hacia la izquierda): 85–87 % solo con frutas → 59, 45, 51 y 57 % con el espejo (4 semillas, con frutas y mobs; media ≈ 53 %).

**Física:** coste mediano por tick 9 → 5 ms; peor 1 % 26 → 13 ms (ver [RENDIMIENTO.md](RENDIMIENTO.md)).

**Terreno:** altura máxima 33 → 14 m; terreno > 6 m del 21 % al 9,5 % del mapa.

**Mobs lejanos y muros** (`crosswall`): sin comprobación de rayos 7 de 7 mobs atravesaban el muro; con los rayos pasaron 3 de 6 y con física completa 2 de 6 (parte de los cruces es legítima: aperturas y esquinas).

## Hipótesis descartadas y resultados negativos

- **Anticipar el terreno** (la mosca mira la altura 3 y 7 m por delante para subir antes): empeoró (0 frutas en 180 s frente a 3), se descartó.
- **Solo dolor sin retroceso:** peor que sin dolor en 2 de 5 semillas (una quedó 70 s pegada); se añadió el retroceso por contacto sostenido.
- **Medir mobs «dentro de sólidos»:** la sonda daba falsos positivos incluso con física completa (9–14 %), así que no sirve como prueba de atravesar muros; se usó la prueba directa de `crosswall`.
- **Caídas a ~1 FPS:** no se pudieron reproducir sin GPU; se encontró y se corrigió el cuello de botella de la física, pero no se puede asegurar que sea la única causa.

## Vídeos

`game/tools/grabar_recorrido.gd` graba recorridos con Godot *movie maker*: `godot --path game --write-movie salida.avi --fixed-fps 30 res://tools/grabar_recorrido.tscn -- 1800 [--guiar]` (1800 fotogramas = 60 s; `--guiar` lleva a la mosca de mob en mob; hay que tener el servidor del cerebro en marcha). Se hicieron dos recorridos (uno con el cerebro local, hoy eliminado, y otro con el real) alternando primera y tercera persona. Los vídeos no están en el repositorio por su tamaño (súbelos como *release*).
