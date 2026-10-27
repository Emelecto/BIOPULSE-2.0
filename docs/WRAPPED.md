# BioPulse Wrapped mensual

## Alcance y aceptación

- Entrada desde Hoy y Tendencias en iOS y web autenticada; siete escenas con navegación directa y deslizamiento horizontal.
- Mes seleccionable entre los meses del historial disponible. El mes actual se identifica como parcial. Apple Salud y el puente web consultan hasta 90 días; un CSV puede incluir más historial. No se promete un archivo mensual ilimitado.
- Sueño, pasos, energía activa, HRV y frecuencia en reposo: media, mínimo, máximo, días registrados, tramos de siete días y comparación con el mes anterior. Totales solo para métricas acumulables.
- Gráfica que conserva días ausentes, selector diario y procedencia. La comparación muestra cobertura de ambos meses; no añade muestras ni calcula un score nuevo.
- Diario sobre el calendario. iOS incorpora entradas, anotaciones y check-ins locales. Web usa el Diario autorizado que ya carga la cuenta. Con CSV se excluye el contexto personal de la cuenta en ambas plataformas.
- Tarjeta de imagen con selección explícita de métricas y vista previa. No contiene notas del Diario. iOS usa ImageRenderer y la hoja de compartir del sistema; web crea un PNG local. Generar no publica ni envía la imagen.
- Réplica pública de la landing con datos simulados identificados, dos meses, cambios de sueño y entradas de la sesión. Puede abrirse en pantalla completa. No consulta servicios de salud ni IA.
- Número del BioScore estable; movimiento en sus filamentos. Bucles pausados fuera de pantalla, al ocultar la app/documento y con movimiento reducido.
- Microanimaciones para pulsación, entrada de escenas, gráficos, selección, expansiones y confirmaciones. iOS conserva los controles de selección y transiciones nativos.
- Wrapped operable con botones, teclado y navegación accesible; capítulos no visibles quedan fuera del foco en web. El teléfono conserva su etiqueta de simulación.

## Arquitectura

`MonthlyWrapped.swift` contiene el resumen puro de dominio. Los destinos SwiftUI viven con las demás vistas de producto en `ProductViews.swift`, ya incluido por el proyecto Xcode y por XcodeGen. El adaptador usa las observaciones diarias y el sueño resuelto existente: Apple Salud o registro manual por noche, sin mezclar un CSV con registros personales.

La web comparte `wrapped-data.ts` y `WrappedStory` entre la cuenta y la demostración pública; los datos de demostración se crean únicamente en `LandingPhone`. No hay dependencias adicionales ni migraciones de base de datos. Se pagina el historial diario y el Diario para evitar el truncamiento anterior de la respuesta.

## Comprobaciones

- CONFIRMED local: compilación de producción y 29 pruebas web, incluidas ocho de Wrapped y carga paginada (fechas inválidas, meses bisiestos, unidades, revisiones, días ausentes, contexto horario y simulación).
- CONFIRMED local: análisis sintáctico de los archivos Swift modificados y nuevos.
- UNKNOWN hasta CI: compilación con SDK de Apple y pruebas de dominio Swift. Swift en Windows no pudo resolver el SDK C requerido (`stdlib.h`), por lo que no se presenta como una prueba ejecutada.
- UNKNOWN hasta revisión en dispositivo: aspecto y fluidez nativos, hoja de compartir, VoiceOver, Dynamic Type y respuesta táctil en iPhone.
- La revisión del componente web mediante la demo no sustituye un recorrido autenticado con una cuenta y datos remotos reales.

## Recorrido manual

1. Abrir Wrapped desde Hoy y Tendencias. Recorrer las siete escenas, por gesto y botones.
2. Cambiar mes, señal y día; expandir detalles y comparación. Confirmar que los huecos permanecen vacíos.
3. Abrir un día con Diario y otro sin notas. En CSV, confirmar que no aparece Diario personal.
4. Elegir métricas, revisar la tarjeta y crear la imagen. Confirmar que no contiene notas y que la demo lleva su etiqueta.
5. Cerrar y volver; cambiar de cuenta/fuente. Confirmar aislamiento de datos.
6. Activar movimiento reducido, cambiar de pestaña y mandar la app a segundo plano. Revisar que las cifras siguen legibles y los bucles se pausan.
