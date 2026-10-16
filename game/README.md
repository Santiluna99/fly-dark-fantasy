# El juego

Esta carpeta es **el juego en sí**: el mundo, sus habitantes, la mosca y todo lo que se ve en pantalla. Está hecho con [Godot](https://godotengine.org/), un programa gratuito para crear videojuegos.

![Captura del juego](../docs/img/captura_juego.png)

## Cómo abrirlo

1. Instala **Godot 4.7**.
2. Abre Godot, pulsa **Importar** y elige esta carpeta (`game`).
3. Pulsa **F5** para jugar.

La primera vez tarda un poco más, porque Godot prepara los archivos.

Recuerda encender antes **el cerebro de la mosca** (carpeta [`brain_server`](../brain_server)). Si no lo haces, el juego funciona, pero la mosca se queda quieta y arriba pone **«SIN SERVIDOR»**.

## Qué vas a ver

- **Un mundo entero** con montañas, bosques, pantanos, ríos con cascadas, aldeas y castillos. Hay ciclo de día y noche, lluvia, estrellas y luna.
- **Habitantes con vida propia**, repartidos en cuatro grupos:
  - **Aldeanos**, que pasean, charlan y comercian entre ellos.
  - **Caballeros**, que luchan contra la secta y los monstruos; algunos curan a sus compañeros.
  - **La secta**: magos búho, lobos alquimistas, hombres cabra y médicos de la peste, que lanzan hechizos de fuego y sombra.
  - **Monstruos**: duendes, esqueletos, necrófagos, espectros y un gran monstruo verde. Atacan a todo el mundo.

  Cuando alguien muere, reaparece en su casa al rato.
- **La mosca**, que vuela buscando fruta, huye de los peligros y aprende a no chocarse con las paredes. Si pasa demasiado tiempo sin comer, muere y vuelve a nacer en otro sitio, pero recuerda lo que aprendió.
- **Un aspecto de juego antiguo**, como los de la primera PlayStation: imagen pixelada, colores limitados y formas que tiemblan un poco.

## Controles

| Tecla | Qué hace |
|---|---|
| **C** | Cambia la cámara: con los ojos del personaje, desde detrás o libre |
| **N** / **F** | Seguir al siguiente personaje / volver a la mosca |
| **V** | Acelerar el tiempo (×1, ×3, ×8) |
| **T** / **Y** | Cambiar la hora del día / que el día pase solo |
| **R** | Lluvia sí o no |
| **M** | Mapa (haz clic en un punto para viajar allí) |
| **F11** | Pantalla completa |

## Qué hay aquí

| Archivo o carpeta | Qué es |
|---|---|
| `main.gd` | El mundo: el terreno, los edificios, la cámara, el tiempo y la pantalla |
| `fly.gd` | La mosca: su cuerpo, lo que siente y cómo se mueve |
| `remote_brain.gd` | El «teléfono» con el que la mosca habla con su cerebro |
| `mob.gd` | El comportamiento de los habitantes: pasear, pelear, huir, hablar |
| `mob_model.gd` | Cómo se construye el cuerpo de cada habitante |
| `daynight.gd` | El día, la noche y la lluvia |
| `map_view.gd` | El mapa |
| `neuro_view.gd` | El panel que muestra la actividad del cerebro de la mosca |
| Archivos `.gdshader` | Los efectos visuales: el aspecto de PlayStation y el cielo |
| `assets/` | Texturas y modelos 3D de los personajes |
| `tests/` | Pruebas automáticas que comprueban que todo funciona bien |
| `tools/` | Herramientas para crear texturas y grabar vídeos del juego |

Si quieres saber cómo funciona todo por dentro, mira la carpeta [`docs`](../docs).
