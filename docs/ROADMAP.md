# BioPulse 2.0 — roadmap provisional

## Estado

El siguiente calendario es **PROPOSED** y depende de la auditoría, la disponibilidad de un entorno iOS y la validación científica. No es una promesa de entrega.

## Fase 1 — base verificable y lenguaje de producto

- Completar auditoría del proyecto anterior.
- Inicializar proyecto iOS funcional.
- Definir arquitectura, esquema de datos, permisos y criterios de aceptación.
- Crear pruebas del dominio con fixtures etiquetados.
- Convertir la preview visual en una especificación SwiftUI reutilizable.
- Diseñar contratos para diario contextual, glosario, calidad de datos y visualizaciones.

## Fase 2 — fuentes, diario y persistencia local

- Estado parcial: el Diario contextual ya cuenta con dominio, CRUD y persistencia local JSON; falta compilarlo y validarlo en iOS.
- Integrar autorización y lectura mínima de HealthKit.
- Implementar importación CSV, mapeo, validación y mensajes de error.
- Implementar persistencia local y manejo de ausencia de datos.
- Implementar perfil, objetivos, contexto personal y diario contextual.
- Añadir centro local de privacidad y permisos.

## Fase 3 — producto y analítica explicable

- Construir dashboard, métricas y tendencias.
- Implementar únicamente cálculos aprobados y documentados.
- Ejecutar experimentos ML reproducibles fuera de la app; decidir si algún modelo merece conversión a Core ML.
- Implementar explicaciones, glosario, visualizaciones con contexto y resumen semanal.
- Diseñar BioScore y Sleep Score con estados de datos insuficientes.
- Incorporar mapa de energía, respiración guiada y previsiones descriptivas si cumplen sus criterios.
- Crear la vista técnica con resultados versionados, fuentes y limitaciones.

## Fase 4 — validación y estabilización

- Pruebas de integración, regresión y rendimiento.
- Revisión de privacidad, accesibilidad y lenguaje no diagnóstico.
- Correcciones, estabilización y documentación de limitaciones.

## Fase backend actual — cuenta obligatoria y base de datos

- **Requisito confirmado:** no hay modo invitado; una sesión autenticada es necesaria para entrar a la app.
- Preparar esquema, migraciones y pruebas de aislamiento RLS en `supabase/`.
- Configurar Apple, correo/contraseña y Google; completar deep links, verificación, recuperación y cierre de sesión.
- Aislar persistencia y cachés locales por cuenta, y limpiar el estado visible al salir.
- Diseñar sincronización cloud opt-in por categoría, con control sobre qué se sube y cómo se elimina.
- Mantener HealthKit original en el dispositivo por defecto.
- Integrar el SDK Swift y probar cambios de sesión cuando haya acceso a Mac/Xcode.

## Coach IA — base en implementación

- **Hecho:** migración de consentimiento, memoria TTL y cuota diaria aplicada local y remotamente; Edge Function de Groq y pantalla SwiftUI implementadas en código.
- **Hecho:** la función arranca localmente y rechaza peticiones sin sesión; la suite pgTAP cubre 39 invariantes.
- Configurar el secreto y modelo de Groq, probar con sesión autenticada en local y desplegar la función.
- Completar la evaluación breve de respuestas de salud y el fallback local antes de habilitar el Coach.
- Compilar y probar en Mac/Xcode, incluida autorización, memoria, revocación, errores y Dynamic Type.

## Hitos de salida

1. Proyecto iOS compilable.
2. Ingesta local verificable desde HealthKit o CSV.
3. Métricas trazables a fuente y fórmula.
4. Validación automatizada del dominio.
5. Decisión explícita sobre ML: incluir, posponer o retirar.

## Pospuesto, no descartado

Sincronización multi-dispositivo, Coach IA remoto, publicación en App Store e integraciones OAuth externas.

El consejo clínico y las predicciones clínicas sí permanecen fuera del producto.
