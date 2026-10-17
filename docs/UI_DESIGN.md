# BioPulse 2.0 — diseño y estado de interfaz

## Implementación actual

La app SwiftUI usa una interfaz oscura y atmosférica, con fondo nocturno, superficies elevadas y acentos de color por tipo de señal. Las exploraciones visuales bajo `design-explorations/` documentan la evolución del diseño; el código actual y su futura revisión en Xcode determinan lo que realmente está implementado.

**CONFIRMED en el código fuente:**

- Cinco áreas principales: Hoy, Tendencias, Diario, Sueño y Perfil.
- Lecturas de Apple Salud con estados para datos presentes o ausentes y enlaces a su explicación/procedencia.
- BioScore y Sleep Score `personal-v1`, deterministas y exploratorios; requieren cobertura suficiente y no tienen validación clínica.
- Tendencias personales, anotaciones, timeline, check-in subjetivo y experimentos personales exploratorios.
- Diario editable, centro de aprendizaje, resumen compartible, vista técnica, objetivos flexibles, respiración guiada, mapa de energía y preferencias de recordatorios locales.
- Cuenta obligatoria; el inicio de sesión no concede consentimiento para sincronizar datos.
- Coach conversacional en español con consentimiento específico y límites informativos/no diagnósticos. La respuesta real del proveedor y la experiencia en dispositivo siguen pendientes de QA.

**UNKNOWN:** compilación actual con Xcode, apariencia en dispositivos reales, permisos HealthKit efectivos, VoiceOver, Dynamic Type y notificaciones. La presencia de una vista en el código no confirma por sí sola su funcionamiento en iOS.

## Reglas visuales y de información

1. Las cifras fisiológicas proceden de muestras observadas; si no hay muestras o cobertura suficiente, se explica la ausencia y no se inventa un valor.
2. Los datos observados, autoinformes, cálculos, inferencias y predicciones deben distinguirse. No se presenta un score exploratorio como diagnóstico ni como medida clínica validada.
3. Cada métrica debe conservar fuente, periodo y contexto relevantes. La coincidencia entre una anotación y un cambio no implica causalidad.
4. Texto legible en superficies oscuras, áreas táctiles amplias, adaptación a Dynamic Type y nombres accesibles para controles.
5. Los ejemplos de las exploraciones visuales son ilustrativos; no constituyen datos reales ni resultados de BioPulse.
6. Recordatorios opt-in y fáciles de desactivar. Las exportaciones requieren selección visible y revisión del contenido antes de compartir.

## Validación pendiente en Mac/Xcode

- Generar el proyecto desde `BioPulse/project.yml`, compilar y ejecutar en simulador o iPhone.
- Revisar solicitudes y consultas de HealthKit con datos reales autorizados, historial, cobertura y días sin datos.
- Revisar Dynamic Type, VoiceOver, contraste, navegación y áreas táctiles.
- Revisar persistencia y aislamiento al cerrar sesión/cambiar de cuenta, importación CSV, exportación, permisos y notificaciones.
- Probar Coach con respuesta real del proveedor, consentimiento, revocación, errores y fallback.
- Corregir hallazgos; entonces actualizar el estado de cada función de «implementado en código» a «verificado» cuando corresponda.

## Funciones explícitamente futuras

- App complementaria para watchOS, widgets y complicaciones para Apple Watch.
- Transporte de sincronización cloud desde la app iOS.
- Predicciones clínicas o scores con validación clínica.
