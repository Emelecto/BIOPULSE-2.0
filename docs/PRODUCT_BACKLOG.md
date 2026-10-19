# BioPulse — backlog de expansión del producto

## Estado

Actualización 2026-10-15: las ideas de landing y las experiencias iOS/locales descritas abajo se incorporaron al código fuente. La landing pasó una revisión de interacción en navegador; iOS aún requiere compilación y pruebas en Xcode/Mac. Esto no implica que se haya publicado la web o que la app esté lista para lanzamiento. Widgets/complicaciones de Apple Watch siguen siendo trabajo futuro.

La app debe distinguir datos observados, autoinformes del usuario, cálculos, inferencias y predicciones. Ninguna idea de este backlog autoriza diagnósticos, tratamientos, causalidad automática ni datos biométricos ficticios presentados como reales.

## A. Landing y presencia pública

Estado: **implementado en fuente; no publicado**. La beta continúa desactivada y el lanzamiento público tiene requisitos pendientes.

1. **Entrada memorable:** bosque nocturno, señales visuales y propuesta clara, con estado de preparación visible.
2. **Recorrido interactivo señal → contexto → reflexión:** sueño, actividad y Diario; explicación conceptual sin scores ni muestras ficticias.
3. **Situaciones ilustrativas:** escenarios marcados como ejemplos, nunca testimonios.
4. **Privacidad visual:** permisos, datos locales, límites cloud en iOS y separación entre login y consentimiento.
5. **Ahora / después:** base actual, trabajo en desarrollo e ideas futuras de ML separadas.
6. **FAQ y criterios científicos:** Apple Health/Watch, cuenta, datos, beta y límites médicos; referencias no presentadas como validación de BioPulse.
7. **Movimiento accesible:** historia interactiva, navegación móvil, teclado y `prefers-reduced-motion`.
8. **Beta preparada pero desactivada:** no recopila correos. Contacto, políticas revisadas y App Store aún son requisitos de lanzamiento.

## B. Experiencia dentro de la app

Estado: **implementado en fuente para iOS, compilación y QA en Xcode pendientes**, excepto #9.

1. **“¿Qué cambió?” — MVP implementado:** siete días completos frente a hasta 21 días de referencia; requiere 4/7 y 7/21 observaciones; sin atribución causal ni valoración buena/mala.
2. **Línea de tiempo del día — MVP implementado:** registros del Diario, check-ins y anotaciones locales junto a señales HealthKit con procedencia; acumulados no reciben hora falsa.
3. **Experimentos personales guiados — MVP implementado:** pregunta, hábito, duración y reflexión manual; exploratorio, no ensayo clínico ni causalidad.
4. **Anotaciones en tendencias — MVP implementado:** fechas anotadas se marcan sobre una gráfica diaria de HealthKit y se listan con texto. La coincidencia temporal no implica causa.
5. **Check-in subjetivo opcional — MVP implementado:** energía autoinformada y nota, separadas de Apple Salud.
6. **Datos insuficientes — MVP implementado en vistas añadidas:** explica cobertura mínima, permisos y ausencia de relleno; no fuerza un score.
7. **Centro de aprendizaje — MVP implementado:** definiciones, fuente, cobertura y límites mediante detalle contextual.
8. **Resumen compartible — MVP implementado:** selección de categorías, vista previa y hoja de compartir local; no es historia clínica certificada ni envío automático.
9. **Widgets y complicaciones Apple Watch — FUTURO / NO IMPLEMENTADO:** se difiere hasta validar iPhone y diseñar controles de privacidad para superficies visibles.

## C. Personalización y motivación

Estado: **implementado en fuente para iOS; compilación y QA en Xcode pendientes**.

- **Objetivos flexibles:** escoger enfoque de sueño, actividad, Diario o aprendizaje; sin puntuación única.
- **Rituales configurables:** resumen semanal local, día/hora de recordatorio semanal, recordatorio diario opt-in y horario silencioso. Los avisos son locales y sin datos de salud.
- **Progreso saludable:** cuenta días únicos con contexto registrado en el mes, sin rachas ni penalización por descanso o datos ausentes.
- **Niveles de lectura:** sencilla o técnica; las explicaciones de procedencia y límites siguen accesibles.

## D. Dependencias y puertas de calidad

- “¿Qué cambió?” requiere una referencia personal reproducible, historial suficiente y métricas con fuente, unidad y cobertura. No mostrar conclusiones si esos requisitos no se cumplen.
- Línea de tiempo, anotaciones y check-in deben preservar la procedencia: HealthKit/CSV, dato derivado o autoinforme.
- Los experimentos personales no deben recomendar suspender tratamientos, diagnosticar ni declarar causalidad a partir de una sola persona.
- Exportaciones y widgets requieren revisión de privacidad, selección explícita de contenido y controles para ocultar o eliminar información.
- Los recordatorios deben ser opt-in, configurables y fáciles de desactivar.
- La sincronización sigue siendo por categoría y consentimiento separado; login no equivale a autorización cloud.
- Los modelos supervisados y cualquier predicción de riesgo permanecen en investigación según [investigación ML](ML_RESEARCH.md). iOS incluye un Isolation Forest personal experimental que solo mide atipicidad estadística; no se anuncia como validado ni clínico.

## E. Verificación pendiente y siguiente secuencia

Antes de anunciar las funciones iOS como disponibles, compilar y revisar en Mac/Xcode:

1. Compilar app y ejecutar las pruebas de dominio; verificar consultas históricas y cobertura en un dispositivo con HealthKit.
2. Revisar accesibilidad, Dynamic Type, VoiceOver, permisos de notificaciones, persistencia local, exportación y borrado/cambio de cuenta.
3. Revisar la gráfica y el resumen compartido con datos reales del propietario, sin publicar información sensible.
4. Mantener Apple Watch como etapa posterior. Landing sigue sin publicar y beta sin captura.

Las puertas de publicación de la landing siguen siendo destino de beta, consentimiento y bajas, contacto de soporte, políticas revisadas y disponibilidad/enlace real de App Store.
