# BioPulse 2.0 — instrucciones permanentes para agentes

## Propósito

BioPulse 2.0 es un proyecto nuevo de una aplicación iOS nativa para salud, recuperación y rendimiento físico. El directorio `BIOPULSE PROYECTO CIENCIA DE DATOS` es únicamente un repositorio de referencia del producto anterior; no debe modificarse durante el desarrollo de 2.0.

## Estado de conocimiento

Usar estas etiquetas en la documentación y en las decisiones:

- **CONFIRMED:** comprobado en el repositorio, en una prueba reproducible o confirmado explícitamente por el usuario.
- **PROPOSED:** propuesta de diseño pendiente de validación o implementación.
- **UNKNOWN:** no verificado o sin evidencia suficiente.

No convertir una propuesta o un resultado heredado en un hecho sin una prueba que lo respalde.

## Reglas operativas

1. Antes de implementar, leer este archivo y consultar solo la documentación relevante.
2. Inspeccionar los archivos afectados antes de editarlos.
3. Definir criterios de aceptación antes de cada cambio funcional.
4. Mantener la privacidad como requisito: preferir procesamiento y almacenamiento local.
5. No inventar datos fisiológicos, mediciones, resultados de modelos ni validaciones.
6. Etiquetar claramente datos sintéticos, simulados, inferidos, observados y predichos.
7. Nunca presentar una predicción como medición real ni como diagnóstico médico.
8. Para ML, exigir dataset identificable, variables definidas, pipeline reproducible, separación de entrenamiento/evaluación, control de leakage, baseline y métricas verificables.
9. No introducir dependencias o infraestructura sin justificar su necesidad.
10. No realizar operaciones destructivas. No modificar el repositorio antiguo.
11. No publicar, desplegar, subir cambios ni crear PRs sin autorización explícita.
12. Después de implementar, ejecutar pruebas pertinentes, revisar el diff, informar cambios y limitaciones, y actualizar `docs/DECISIONS.md` cuando corresponda.

## Ámbitos de escritura

- Proyecto nuevo: `C:\Users\ecard\OneDrive\Escritorio\BIOPULSE 2.0`.
- Referencia de auditoría, solo lectura: `C:\Users\ecard\OneDrive\Escritorio\BIOPULSE PROYECTO CIENCIA DE DATOS`.

## Convenciones iniciales

- Plataforma objetivo: iOS nativo.
- Candidatos tecnológicos: Swift, SwiftUI, HealthKit, almacenamiento local, Python para investigación y Core ML cuando aporte valor.
- La arquitectura definitiva sigue pendiente hasta completar la auditoría y crear una primera base iOS.
- El calendario de cuatro semanas es provisional y no sustituye criterios de calidad o validación.

## Flujo mínimo de trabajo

Antes: leer contexto → inspeccionar → definir aceptación → documentar riesgos.

Después: probar → revisar cambios → informar resultado y limitaciones → actualizar decisiones.
