# Drogas: qué pasa si la mosca las consume

Opción para ver, en el juego, cómo cambia el comportamiento de la mosca cuando el **cerebro real** (conectoma FlyWire) recibe una droga, y cómo vuelve todo a la normalidad al quitarla.

> **Es una simulación cualitativa**, no farmacología real. No hay dosis en mg, ni metabolismo, ni receptores concretos. Cada droga se modela como un cambio en la fuerza de las sinapsis según su neurotransmisor (y, en algunas, un ruido de fondo). Sirve para ver *tendencias* (más hiperactiva, más torpe, más quieta), no para predecir efectos reales.

## Nombres en pantalla

En el juego algunas opciones se muestran por su nombre (alcohol, cafeína, nicotina, sedante) y el resto por categoría (el panel se llama «Compuestos» y la barra inferior «Química (P)»). Equivalencias con los nombres internos del servidor y de este documento:

| En pantalla | Nombre interno |
|---|---|
| Alcohol | `alcohol` |
| Cafeína | `cafeina` |
| Estimulante medio | `cocaina` |
| Estimulante fuerte | `anfetamina` |
| Nicotina | `nicotina` |
| Sedante | `sedante` |
| Serotoninérgico | `lsd` |
| Anestésico | `anestesico` |

## Cómo se usa

1. Arranca el servidor del cerebro (`brain_server/`) y el juego como siempre.
2. Pulsa **P** (o el botón *Drogas (P)*) para abrir el panel: una ventana en el centro de la pantalla (Esc o un clic fuera la cierra).
3. Elige la droga, la **cantidad** (escala de 5 pasos: 20 %–100 %) y la **duración** (30 s, 60 s, 2 min o *hasta quitarla*).
4. **Aplicar**: el panel se cierra, el efecto sube en ~6 s, se mantiene durante la duración y baja solo en ~20 s.
5. **Quitar droga** (el panel también se cierra): el efecto baja en ~3 s y la mosca vuelve a su actividad normal.

El HUD (arriba a la izquierda) muestra `Droga: <nombre> · efecto N % · subiendo / activa (quedan N s) / saliendo`.

## Qué hace cada droga

El efecto se calcula en el servidor sobre el conectoma real: cada sinapsis se multiplica por `1 + nivel × (factor − 1)` según el neurotransmisor de la neurona **presináptica** (anotación `top_nt` de FlyWire). Además hay un ruido Poisson de fondo (Hz por neurona, a dosis 1).

| Droga | Factores (a dosis 100 %) | Ruido de fondo | Idea |
|---|---|---|---|
| Alcohol | GABA ×1,8 · acetilcolina ×0,8 · glutamato ×0,85 | 0,12 Hz | más inhibición, menos excitación |
| Cafeína | acetilcolina ×1,08 · GABA ×0,92 · dopamina ×1,2 | 0,20 Hz | más excitación |
| Cocaína | dopamina ×2,5 · octopamina ×2,5 · serotonina ×1,6 | 0,45 Hz | modulación dopaminérgica alta |
| Anfetamina | dopamina ×3 · octopamina ×3 | 0,80 Hz | la anterior, más fuerte |
| Nicotina | acetilcolina ×1,15 | 0,25 Hz | excitación colinérgica |
| Sedante | GABA ×2,2 | — | mucha inhibición |
| LSD | serotonina ×3 · glutamato ×1,1 | 0,20 Hz | serotonina alta + ruido |
| Anestésico | GABA ×2,8 · acetilcolina ×0,6 | — | inhibición fuerte, excitación baja |

Los valores salen de una calibración con el cerebro real (`calib_drogas.py`), no de la literatura: se ajustaron hasta que cada droga produjera un cambio claro y distinto sin romper el giro del todo.

### Lo que se midió (cerebro real, estímulo constante, dosis 50 % / 100 %)

Sin droga: con olor a la derecha gira a la derecha (+0,99) con avance 0,41; ante una amenaza a la derecha gira a la izquierda (−0,50), avance 0,76 y reflejo de huida (gf) 0,58. En reposo el cerebro está en silencio (avance 0).

| Droga | Avance en reposo | Giro hacia olor (dcha.) | Giro ante amenaza (dcha.) | Reflejo de huida (gf) |
|---|---|---|---|---|
| Alcohol | 0,23 / 0,09 | +0,67 / +0,63 | −0,40 / −0,19 | 0,42 / 0,20 |
| Cafeína | 0,61 / 0,91 | +0,66 / +0,43 | −0,55 / −0,61 | 0,59 / 0,63 |
| Cocaína | 0,87 / 1,00 | +0,50 / +0,99 | −0,52 / −0,43 | 0,44 / 0,30 |
| Anfetamina | 0,85 / 1,00 | +0,32 / +1,00 | −0,48 / −0,39 | 0,46 / 0,21 |
| Nicotina | 0,51 / 0,96 | +0,82 / −0,17 | −0,55 / −0,61 | 0,66 / 0,67 |
| Sedante | 0 / 0 | +0,66 / +0,66 | −0,39 / −0,26 | 0,41 / 0,25 |
| LSD | 0,59 / 0,75 | +1,00 / +0,18 | −0,52 / −0,54 | 0,48 / 0,36 |
| Anestésico | 0 / 0 | +0,33 / +0,14 | −0,11 / +0,08 | 0,36 / 0,04 |

Lectura rápida: **alcohol** = torpe (orientación y huida peores, poco avance); **cafeína, cocaína, anfetamina, nicotina** = hiperactividad (a dosis alta la nicotina y el LSD desorientan el giro: casi no giran hacia el olor); **sedante y anestésico** = menos reactividad y huida más lenta. Las familias estimulantes se parecen entre sí porque en este modelo comparten el mismo mecanismo de excitación.

## Escala de cantidad

En el panel la cantidad se elige con una escala de 5 pasos: 1 Mínima (20 %), 2 Baja (40 %), 3 Media (60 %), 4 Alta (80 %), 5 Máxima (100 %). Si se vuelve a pulsar *Aplicar* con otra cantidad mientras hay una droga, el efecto sube o baja suavemente hasta el nuevo nivel.

Dosis-respuesta medida en el juego, en tiempo real, con el cerebro real (`game/tests/dosetest.gd`; 22 s por nivel tras 7 s de subida; velocidad media de la mosca; 3 semillas):

| Nivel | 0 % | 20 % | 60 % | 100 % |
|---|---|---|---|---|
| Sedante | 1,27 m/s | 1,13 m/s | 0,76 m/s | 0,45 m/s |
| Alcohol | 1,20 m/s | 1,14 m/s | 1,12 m/s | 0,68 m/s |

El **sedante** baja de forma clara y ordenada con la cantidad en las tres semillas. El **alcohol** baja de media, pero es más irregular: en una semilla a 60 % la mosca iba más rápida y girando mucho (conducta errática), y las otras dos bajan de forma ordenada (1,16 → 1,02 → 0,76 → 0,64 y 1,22 → 1,01 → 0,80 → 0,65 m/s). Para enseñar una escala de cantidad, el sedante es la mejor opción.

## Que no quede ninguna secuela

- **Pesos**: el servidor guarda una copia de los pesos originales al arrancar. Al quitar la droga se restauran desde esa copia (se comprueba `np.array_equal(pesos, originales) == True` en `verif_drogas.py`) y el ruido de fondo vuelve a 0.
- **Actividad residual**: tras una droga excitante el conectoma puede *auto-mantener* actividad aunque ya tenga los pesos originales (se vio en pruebas: avance 0,5–0,6 sin ningún estímulo). Por eso, al terminar la droga el servidor además **vacía el estado neuronal** (voltajes, conductancias y spikes en tránsito). Con eso, 1 s después de quitar la droga el avance en reposo es 0 otra vez.
- **Aprendizaje**: mientras hay droga la mosca **no aprende** de los choques (el miedo a las paredes no cambia), así que no queda ninguna huella.
- **Muerte**: si la mosca muere, renace sin droga.
- Prueba en el juego, en tiempo real (`game/tests/drugtest.gd`): velocidad media antes / con la droga / justo tras quitarla / 25 s después.

| Droga (dosis 80 %) | Antes | Con droga | Después |
|---|---|---|---|
| Anfetamina | 1,32 m/s | 1,56 m/s | 1,30 m/s |
| Sedante | 1,16 m/s | 0,52 m/s | 1,16 m/s |
| Alcohol | 1,36 m/s | 0,81 m/s | 1,22 m/s |

## Una parte no sale solo del conectoma

En reposo (sin olor ni amenaza) el cerebro está en silencio y el cuerpo avanza a la velocidad mínima. Por eso el *frenado* de las drogas sedantes no aparece solo de las sinapsis: el cuerpo de la mosca multiplica su velocidad por `1 − nivel × freno` mientras dura la droga (alcohol 0,3 · sedante 0,6 · anestésico 0,92; ver `Drugs.LIST` en `game/drugs.gd`). El giro, el olfato, la huida y la hiperactividad sí los decide el conectoma. En el reposo, la hiperactividad de los estimulantes viene del ruido de fondo, que es lo que enciende las neuronas descendentes.

## Archivos

- `brain_server/fly_server.py`: tabla `DRUGS`, `set_drug()` (aplica/retira) y el campo opcional `drug` del protocolo.
- `game/drugs.gd`: curva del efecto en el tiempo (sube, mantiene, baja) y lista de drogas.
- `game/drug_panel.gd`: el panel (tecla P).
- `game/remote_brain.gd`: envía la droga al servidor solo cuando cambia.
- `game/fly.gd`: aplica la droga, el freno motor y congela el aprendizaje.
- `brain_server/calib_drogas.py`, `brain_server/verif_drogas.py`, `game/tests/drugtest.gd`: calibración y verificaciones.

## Protocolo

En el mensaje que el juego manda al servidor (ver `CEREBRO.md`) hay un campo opcional:

```json
{"orn":[0.1,0.4], "loom":[0,0], "hunger":0.2, "drug":{"name":"alcohol","level":0.5}}
{"orn":[0,0], "loom":[0,0], "hunger":0.2, "drug":null}
```

`level` va de 0 a 1 (dosis × curva de efecto); `null` (o nivel 0) retira la droga.

## Añadir otra droga

Añade una entrada a `DRUGS` en `fly_server.py` (`"nombre": ({"gaba": 1.5, ...}, ruido_hz)`) y otra a `Drugs.LIST` en `game/drugs.gd`. Las claves de neurotransmisor son `ach`, `glu`, `gaba`, `da`, `ser`, `oct`. Calibra con `python calib_drogas.py nombre`.

## Límites

- Es una simulación cualitativa; el efecto de una droga real depende de receptores, dosis y metabolismo que aquí no existen.
- Los lectores de giro y avance se entrenaron con el cerebro sano; con una droga fuerte pueden leer mal la actividad y dar giros que no corresponden a una conducta real (por ejemplo, el giro invertido de la nicotina o el LSD a dosis alta).
- Medido sobre un solo cerebro simulado y estímulos constantes; en el juego el entorno añade variabilidad.
