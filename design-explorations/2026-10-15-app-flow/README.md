# BioPulse · propuesta visual de las cinco pestañas

## Estado

- **CONFIRMED:** la dirección de «Hoy» y el ajuste del grid solicitados por el usuario. En `01-hoy.png` todas las tarjetas tienen el mismo ancho; Esfuerzo ocupa únicamente la columna izquierda y conserva más altura que las demás.
- **PROPOSED:** `02-tendencias.png`, `03-diario.png`, `04-sueno.png` y `05-perfil.png` son mockups para revisión. No equivalen a pantallas implementadas ni aprobadas todavía.
- **UNKNOWN:** fórmula y validación de BioScore/Sleep Score/sub-scores, calidad de las series y compatibilidad visual real en tamaños iPhone, Dynamic Type y VoiceOver.

## Imágenes y dirección / prompts finales

1. **Hoy — `01-hoy.png`:** conservar el anillo orgánico BioScore como foco; dos columnas de igual ancho y gutter regular. Esfuerzo alto a la izquierda; HRV y FC apilados a la derecha; Sueño y Pasos en la fila inferior. Los bordes derechos de Esfuerzo/Sueño y los izquierdos de HRV/FC/Pasos están alineados. Recuadros carbón, blanco en los controles, color únicamente en la puntuación propia de cada métrica. Es la corrección final del mockup previamente elegido.
2. **Tendencias — `02-tendencias.png`:** periodos 7/30/90 días, gráfico semanal BioScore con puntos de color según el score, módulo «¿Qué cambió?» comparativo sin causalidad y anotación contextual. No repetir el anillo del home.
3. **Diario — `03-diario.png`:** check-in subjetivo con opciones neutras, botón principal blanco y una línea de tiempo de anotaciones. Sin convertir el estado emocional en medición biométrica.
4. **Sueño — `04-sueno.png`:** Sleep Score ilustrativo como foco secundario, duración registrada, cronología nocturna con categorías de fases en tonos neutros y acceso a explicación. Se retiró una afirmación de calidad no validada.
5. **Perfil — `05-perfil.png`:** identidad ilustrativa, permisos Apple Salud para revisar, sincronización por categoría, autorización del Coach y preferencias. No se presenta ningún permiso o conexión como concedido. Coach flotante separado de Exportar/Cerrar sesión.

## Sistema común

Mockups iOS independientes, no un collage: mismo marco, tipografía, cinco pestañas y botón flotante Coach IA. Fondo y acciones en carbón/blanco/plata. Colores rojo → amarillo → verde solo para scores normalizados y sus visualizaciones; jamás como único indicador. Las categorías no puntuadas (por ejemplo fases del sueño o entradas del Diario) permanecen neutras. Los números, barras, fechas, anotaciones y correo mostrados son **datos simulados de diseño**, no mediciones reales, resultados de ML ni diagnósticos. Ver la escala cromática propuesta en `../2026-10-15-final/README.md`.

## Pendiente antes de implementar

Validar cada score y su dirección favorable antes de mostrarlo; usar estado neutral cuando falten datos. Reproducir las tarjetas en SwiftUI con layout adaptable, áreas táctiles ≥44 pt, contraste, VoiceOver, Dynamic Type y Reducir movimiento. En móviles pequeños, contenido desplazable sin que Coach ni tab bar oculten acciones. Los PNG son referencias estáticas; no hay animación ni pantalla iOS compilada en esta entrega.
