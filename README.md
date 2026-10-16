# Nocturnia

**Un pequeño mundo de fantasía oscura donde una mosca vive con el cerebro de una mosca de verdad.**

![Captura del juego](docs/img/captura_juego.png)

## ¿Qué es esto?

Nocturnia es un mundo en 3D con aspecto de videojuego antiguo, como los de la primera PlayStation. Tiene aldeas, castillos, bosques, pantanos, lluvia y un ciclo de día y noche. En él viven aldeanos, caballeros, una secta y monstruos. Cada uno va a lo suyo: pasean, conversan, comercian y se pelean.

La protagonista es una **mosca de la fruta**. Nadie la controla: ni el jugador ni unas reglas escritas a mano. La mueve una copia digital del **cerebro real de una mosca**.

## ¿Cómo que «un cerebro real»?

Unos científicos (el proyecto **FlyWire**) cartografiaron el cerebro completo de una mosca de la fruta. Son unas **140.000 neuronas** y millones de conexiones entre ellas, y está publicado para que cualquiera lo use.

Este proyecto pone ese mapa a funcionar en el ordenador, como si el cerebro estuviera vivo, y lo conecta con la mosca del juego:

1. **La mosca siente.** Huele la fruta con sus dos antenas y ve si algo se le acerca peligrosamente. También tiene hambre.
2. **El cerebro decide.** Lo que siente se convierte en señales que entran en las neuronas del cerebro simulado.
3. **La mosca se mueve.** Lo que responde el cerebro se traduce en girar a un lado o al otro, avanzar o huir.

Así la mosca busca fruta, esquiva a los monstruos, se choca, aprende a tenerle miedo a las paredes, y a veces se muere de hambre (y renace).

## Cómo probarlo

Hacen falta dos programas abiertos a la vez: **el cerebro** y **el juego**.

### 1. Lo que necesitas instalar (una sola vez)

- **[Godot 4.7](https://godotengine.org/)**, el programa con el que está hecho el juego. Es gratis.
- **[Python 3.10 o más nuevo](https://www.python.org/)**, para el cerebro.
- **[Git](https://git-scm.com/)**, para descargar los datos del cerebro.

### 2. Encender el cerebro

Abre una terminal dentro de la carpeta `brain_server` y escribe:

```bash
pip install -r requirements.txt
```

Después, en Windows, haz doble clic en **`iniciar.bat`** (en Mac o Linux: `sh iniciar.sh`).

La primera vez descarga unos 370 MB de datos del cerebro, así que tarda un rato. Cuando veas **«Cerebro listo»**, deja esa ventana abierta.

### 3. Abrir el juego

Abre Godot, elige **Importar**, selecciona la carpeta `game` y pulsa **F5** para jugar.

Si el cerebro no está encendido, la mosca se queda quieta esperando y arriba pone **«SIN SERVIDOR»**. En cuanto lo enciendas, se pone en marcha sola.

## Controles

| Tecla | Qué hace |
|---|---|
| **C** | Cambia la cámara: ver con los ojos del personaje, verlo desde detrás, o cámara libre |
| **N** | Seguir al siguiente personaje |
| **F** | Volver a seguir a la mosca |
| **V** | Acelerar el tiempo (×1, ×3, ×8) |
| **T** | Saltar a otra hora del día |
| **Y** | Hacer que el día pase solo (o pararlo) |
| **R** | Encender o apagar la lluvia |
| **M** | Abrir el mapa (haz clic en un punto para viajar allí) |
| **F11** | Pantalla completa |
| **Arrastrar el ratón** | Mirar alrededor |

En la cámara libre: **W A S D** para moverte, **Q** y **E** para bajar y subir, **Shift** para ir más rápido y la rueda del ratón para cambiar la velocidad.

## Qué hay en cada carpeta

| Carpeta | Qué es |
|---|---|
| [`game/`](game) | El juego en sí: el mundo, los personajes, la mosca y los efectos visuales |
| [`brain_server/`](brain_server) | El cerebro de la mosca. Es un programa aparte que el juego necesita para que la mosca se mueva |
| [`blender/`](blender) | Las recetas con las que se crearon los personajes en 3D y sus animaciones |
| [`docs/`](docs) | Explicaciones más a fondo, para quien quiera saber cómo funciona todo por dentro |

Cada carpeta tiene su propio README con más detalle.

## Cosas a tener en cuenta

- **Sin el cerebro encendido, la mosca no hace nada.** Es lo que la mueve.
- **El cerebro de la mosca no aprende.** Es un mapa fijo. Lo que sí aprende (el miedo a las paredes) se añadió por fuera, en lo que la mosca siente.
- **El cerebro va un poco más lento que uno real** (al 70 % de velocidad, más o menos), así que sus reflejos son algo lentos.
- Necesita un ordenador con algo de potencia: el cerebro usa un núcleo del procesador entero.

## Créditos

- **Cerebro de la mosca:** [FlyWire](https://flywire.ai/), versión 783. Modelo de simulación basado en Shiu y colaboradores (2023). Los datos no están en este repositorio: se descargan al encender el cerebro por primera vez.
- **Motor del juego:** [Godot Engine](https://godotengine.org/), licencia MIT.
- **Texturas, modelos y personajes:** generados con código para este proyecto.
- **Licencia del código:** todavía sin elegir.
