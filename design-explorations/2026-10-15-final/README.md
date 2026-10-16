# BioPulse · dirección visual seleccionada para «Hoy»

## Estado

- **CONFIRMED (dirección visual):** el usuario eligió el mosaico asimétrico del mockup 3 de `../2026-10-15-v6/03-mosaico-asimetrico.png` y pidió esta versión final con color semántico por puntuación.
- **PROPOSED (implementación):** `biopulse-home-semantic-colors.png` es una referencia visual estática, no una pantalla ya implementada. El anillo orgánico todavía no está animado.
- **UNKNOWN:** fórmulas, calibración, dirección favorable de cada métrica, umbrales clínicos o validación de los scores. Ningún valor de la imagen es una medición real o un resultado verificado de ML.

## Prompts / dirección final

Edición del mockup 3: conservar anillo BioScore, tarjeta alta de esfuerzo a la izquierda, HRV y FC apiladas a la derecha, Sueño y Pasos abajo, Coach IA flotante y cinco pestañas. Eliminar acentos verdes globales del fondo, la navegación y el botón del Coach; usar blanco, plata y carbón neutrales. Reservar el color para el anillo y las visualizaciones de cada métrica, con brillos localizados y recuadros oscuros legibles. Mostrar puntuaciones variadas y separar siempre puntuación normalizada de unidad observada. Edición final: diferenciar el 82 del 100 y corregir la puntuación HRV a `12/100`.

## Regla cromática deseada

El color de cada visualización se obtiene de **su propia puntuación normalizada favorable de 0 a 100**, no del valor bruto (ms, bpm, horas o pasos). Esta es una intención de diseño, no una fórmula biométrica. Una propuesta de anclas perceptuales para interpolar suavemente, evitando saltos de color, es:

| Score | Color de referencia | Lectura visual |
| ---: | --- | --- |
| 0 | `#E84F58` | rojo fuerte |
| 25 | `#E77A3F` | naranja |
| 50 | `#E5C64A` | amarillo |
| 70 | `#B9CB59` | amarillo verdoso |
| 82 | `#A9D968` | lima suave |
| 90 | `#4CCB72` | verde claro |
| 100 | `#18C760` | verde BioPulse |

Interpolar entre anclas según la puntuación real; un cambio de ~2 puntos debe poder producir un matiz perceptiblemente diferente sin provocar parpadeo ni cambios bruscos. La intensidad del resplandor debe permanecer contenida. Color **nunca** será el único indicador: acompañar con número, etiqueta y explicación accesible. Si no existe un score validado o faltan datos, mostrar estado neutral gris/blanco con explicación, nunca rojo por ausencia.

Los ejemplos de la imagen son deliberadamente distintos: BioScore 82, esfuerzo 50, HRV 12, FC 70, sueño 90 y pasos 100. **Todos son datos simulados de diseño.** Antes de usar etiquetas como «bajo» o «favorable» en producción, definir la semántica específica por métrica y validar el cálculo; por ejemplo, un valor alto de esfuerzo o una frecuencia cardiaca baja no son automáticamente «saludables» o «malos». La función de color solo puede aplicarse a una puntuación cuya dirección favorable esté justificada.

## Elementos neutrales

Fondo, luces ambientales, contornos globales, navegación y botón flotante del Coach IA: blanco/plata/carbón. Ninguno cambia de color con los scores. Contraste, Dynamic Type, VoiceOver, reducción de movimiento y tamaños pequeños quedan pendientes de validar en una implementación SwiftUI real.
