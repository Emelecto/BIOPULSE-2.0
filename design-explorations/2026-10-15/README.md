# BioPulse — exploración de temas para iOS

Estado: **propuestas visuales**, sin implementación en SwiftUI. Las diez imágenes usan los mismos valores **simulados** para comparar composición y jerarquía; no representan mediciones de una persona ni resultados clínicos. `BioScore` permanece pendiente y sin cifra.

## Base común de los prompts

Una pantalla nativa de **Hoy** en un iPhone, con área segura, cinco pestañas (`Hoy`, `Tendencias`, `Diario`, `Sueño`, `Perfil`) y texto en español. Contenido comparativo: `Sueño · 7 h 20 min`, `HRV · 48 ms`, `Actividad · 8.420 pasos`, `Diario · Registrar contexto`, `BioScore pendiente` y acceso a `Coach`. Cada imagen lleva la etiqueta visible `CONCEPTO · DATOS SIMULADOS` fuera del teléfono. Sin diagnósticos, scores inventados ni gráficas de datos ficticios.

Los prompts de dirección partieron de diez composiciones generadas con `taste-skill`. Se adaptaron a iOS mediante `imagegen-frontend-mobile` y se revisaron con `ui-ux-pro-max` para legibilidad, área segura, jerarquía y estados pendientes. Se usó la herramienta integrada de generación de imágenes.

| # | Imagen | Dirección del prompt | Paleta y distribución |
| --- | --- | --- | --- |
| 01 | [Bosque habitable](images/01-bosque-habitable.png) | `place-carries-it` | Fotografía de bosque como espacio principal; gris estudio y verde profundo; señales en superficie plana. |
| 02 | [Informe vivo](images/02-informe-vivo.png) | `editorial-report` | Gris frío y vino tinto; masthead tipográfico y lectura como informe. |
| 03 | [Contornos del pulso](images/03-contornos-del-pulso.png) | `one-motif` | Blanco, verde botánico y rosa tenue; un contorno orgánico decorativo estructura la cabecera. |
| 04 | [Capítulos de color](images/04-capitulos-de-color.png) | `colour-chapters` | Blanco, menta, naranja y carbón; cada señal ocupa un plano cromático. |
| 05 | [Instrumento sereno](images/05-instrumento-sereno.png) | `quiet-instrument` | Grafito y naranja; cifras abiertas en una secuencia vertical precisa. |
| 06 | [Catálogo de señales](images/06-catalogo-de-senales.png) | `specimen-catalogue` | Blanco, azul marino y un detalle mandarina; señales como fichas de consulta. |
| 07 | [Horizonte dividido](images/07-horizonte-dividido.png) | `split-stage` | Cabecera partida entre texto y paisaje nocturno; carbón, concreto y salvia. |
| 08 | [Frase como interfaz](images/08-frase-como-interfaz.png) | `sentence-as-layout` | Carmín, carbón y rosa claro; frase y franja panorámica dominan la entrada. |
| 09 | [Guía de campo](images/09-guia-de-campo.png) | `borrowed-category` | Carbón, verde azulado, azul mineral y ocre; señales como capítulos de una guía exterior. |
| 10 | [Notas de terreno](images/10-notas-de-terreno.png) | `uneven-photographs` | Papel gris, tinta casi negra y latón; fotografías a escalas desiguales alrededor del Diario. |

## Revisión visual aplicada

- 01: `BioScore pendiente` pasó de botón destacado a estado secundario; se añadió acceso a Coach.
- 04 y 07: se añadió acceso visible a Coach.
- 05: se aumentó el contraste del estado pendiente.
- 08: se redujo la cabecera tipográfica y se dio más espacio a las métricas y al Diario.

Estas son imágenes conceptuales. La legibilidad real con Dynamic Type, VoiceOver, contrastes medidos y tamaño táctil se validará al implementar el tema elegido en SwiftUI.
