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

## Avance backend / investigación del 15-10-2026

- **CONFIRMED:** esquema y RLS de agregados diarios, migración aplicada local y remotamente; cuatro consentimientos de sincronización independientes. El transporte iOS sigue pendiente.
- **CONFIRMED:** panel Admin/Dev local y endpoint remoto desplegado; solo conteos operativos, sin datos de salud. `ADMIN_USER_ID` quedó configurado como secreto remoto. Falta verificar el inicio de sesión real del propietario en el navegador.
- **CONFIRMED:** auditoría de 100.000 filas/286 sujetos del CSV heredado; sin etiqueta clínica independiente ni licencia verificada. Plantilla reproducible de dos familias ML y pruebas, sin modelo validado ni activado.
- **CONFIRMED:** 67 pruebas pgTAP, 10 pruebas unitarias de política Coach, 3 pruebas de contrato ML y una prueba HTTP local autenticada del Coach pasan. La función Coach está desplegada; faltan pruebas con respuesta real de Groq y en dispositivo.
- Ver [contrato cloud](DATA_SYNC_CONTRACT.md) e [investigación ML](ML_RESEARCH.md) para límites exactos. Las notas anteriores de este roadmap representan hitos históricos, no estado más reciente.

## Hitos de salida

1. Proyecto iOS compilable.
2. Ingesta local verificable desde HealthKit o CSV.
3. Métricas trazables a fuente y fórmula.
4. Validación automatizada del dominio.
5. Decisión explícita sobre ML: incluir, posponer o retirar.

## Pospuesto, no descartado

Sincronización multi-dispositivo, Coach IA remoto, publicación en App Store e integraciones OAuth externas.

El consejo clínico y las predicciones clínicas sí permanecen fuera del producto.

## Implementación de expansión de producto — 2026-10-15

- **Landing:** las ocho mejoras están implementadas en fuente y se revisaron en navegador de escritorio y móvil. El sitio no está publicado; captura de beta apagada. Antes de lanzamiento faltan destino/consentimiento/bajas, contacto, políticas revisadas y enlace de App Store.
- **iOS:** comparación personal, gráfica de 28 días con marcas de anotación, timeline, check-in subjetivo, experimentos, cobertura insuficiente, aprendizaje, exportación revisable, enfoque flexible, progreso no punitivo y preferencias/recordatorios locales están implementados en fuente.
- **Verificación iOS pendiente:** no hay Xcode/macOS en el entorno de trabajo. El parser de Swift reconoce los archivos, pero falta compilación, tests con el SDK de Apple, revisión en iPhone/VoiceOver/HealthKit/notificaciones y confirmar APIs de Charts/HealthKit en la versión efectiva del proyecto.
- **Apple Watch:** widgets y complicaciones siguen intencionalmente para después y no se anuncian como disponibles.

El desglose, límites funcionales y criterios de verificación están en el [backlog de producto](PRODUCT_BACKLOG.md). La investigación ML y sus puertas de evidencia no cambian; ninguna predicción médica se ha activado.
