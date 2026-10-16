# El cerebro de la mosca

Esta carpeta contiene **el cerebro de la mosca del juego**. Es un programa aparte que tiene que estar encendido mientras juegas: sin él, la mosca se queda quieta.

## ¿Qué es?

Es una copia digital del cerebro completo de una mosca de la fruta real, con unas **140.000 neuronas**. El mapa lo hizo un equipo de científicos (el proyecto [FlyWire](https://flywire.ai/)), que fue anotando una a una las neuronas y sus conexiones.

Este programa pone ese mapa en marcha: las neuronas se activan y se pasan señales entre ellas, como en un cerebro vivo.

## ¿Cómo habla con el juego?

Funciona como una conversación que se repite muchas veces por segundo:

1. **El juego le cuenta lo que siente la mosca:** cuánto huele la fruta por cada antena, si algo se le acerca por la izquierda o por la derecha y cuánta hambre tiene.
2. **El cerebro reacciona.** Esas señales activan las neuronas del olfato y de la vista, y la actividad se extiende por el resto del cerebro.
3. **El cerebro contesta qué hacer:** girar a un lado o al otro, avanzar o huir de golpe.

El juego también muestra en pantalla un panel con la actividad de las neuronas, para ver cómo «piensa» la mosca.

## Cómo encenderlo

Necesitas tener instalados **[Python](https://www.python.org/)** (versión 3.10 o más nueva) y **[Git](https://git-scm.com/)**.

**La primera vez,** abre una terminal en esta carpeta e instala lo que hace falta:

```bash
pip install -r requirements.txt
```

**Cada vez que quieras jugar:**

- En **Windows**, haz doble clic en `iniciar.bat`.
- En **Mac o Linux**, ejecuta `sh iniciar.sh`.

La primera vez descarga los datos del cerebro (unos 370 MB), así que tarda un poco. Cuando aparezca **«Cerebro listo»**, abre el juego. Deja esta ventana abierta mientras juegas.

## Qué hay aquí

| Archivo | Para qué sirve |
|---|---|
| `iniciar.bat` / `iniciar.sh` | Enciende el cerebro (y descarga los datos si faltan) |
| `descargar_datos.bat` / `.sh` | Solo descarga los datos del cerebro |
| `fly_server.py` | El programa que conversa con el juego |
| `fly_sim.py` | El motor que simula las neuronas |
| `decoders.npz` | Lo que traduce la actividad del cerebro en «gira a la izquierda» o «gira a la derecha» |
| `calibrate.py`, `calibrate_olfato.py` | Las herramientas con las que se creó ese traductor |
| `test_client.py` | Prueba el cerebro sin abrir el juego |

## Bueno saber

- **El cerebro no aprende.** Es un mapa fijo de conexiones. El miedo a las paredes que aprende la mosca se añade por fuera, en lo que siente.
- **Va un poco más lento que uno real**, al 70 % de velocidad más o menos.
- **Usa un núcleo entero del procesador**, así que el ordenador puede notar el esfuerzo.
- **La forma de girar no viene de un circuito conocido del cerebro.** Se entrenó un traductor con el propio cerebro: se le mostró olor o peligro a un lado y se aprendió qué neuronas se activan en cada caso.

Si quieres los detalles técnicos (parámetros, pruebas y correcciones), están en [`docs/SERVIDOR_CEREBRO.md`](../docs/SERVIDOR_CEREBRO.md) y [`docs/CEREBRO.md`](../docs/CEREBRO.md).
