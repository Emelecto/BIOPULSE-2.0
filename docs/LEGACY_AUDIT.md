# Auditoría funcional del proyecto anterior

## 1. Propósito y alcance

Esta auditoría sirve para rescatar conocimiento del repositorio antiguo sin trasladar automáticamente su implementación web a BioPulse 2.0.

- **Repositorio auditado:** `BIOPULSE PROYECTO CIENCIA DE DATOS`.
- **Repositorio público relacionado:** `https://github.com/Emelecto/Bio-Pulse`.
- **Estado de la auditoría:** funcional y estructural a nivel de código local; no equivale a una auditoría clínica ni a una validación científica independiente.
- **Estado del nuevo proyecto:** no se implementaron funcionalidades como resultado de esta auditoría.

## 2. Resumen ejecutivo

El proyecto anterior ya contiene un MVP web con cinco áreas de producto, un pipeline de datos, importación CSV, datos demo, registro de hábitos, recomendaciones, coach contextual, exportación de datos y experimentos ML. El principal valor que debemos rescatar es el modelo mental del producto y la experiencia de uso.

La reconstrucción 2.0 debe conservar el dominio y cambiar la base técnica:

```text
Fuentes → adaptadores → modelo canónico → analítica → explicaciones → interfaz
```

El proyecto anterior mezcla esas capas en hooks, componentes y funciones web. En 2.0 deben separarse para que cada cálculo pueda probarse sin depender de SwiftUI ni de una fuente concreta.

## 3. Flujo de producto confirmado

### 3.1 Entrada y selección de fuente

El shell de la app permite usar:

- datos demo generados de forma reproducible;
- CSV personalizado;
- conexiones preparadas para Fitbit y Whoop;
- referencias a Apple, Garmin y otros exports mediante el importador genérico.

La conexión web de Fitbit/Whoop no es una integración completa de producto: requiere OAuth y backend seguro. El propio código reconoce que no se deben guardar secretos en el frontend.

### 3.2 Normalización

`useBiopulseData.js` implementa:

- normalización de nombres de columnas;
- tolerancia a acentos, mayúsculas, espacios y guiones;
- detección de CSV `wide` y `tidy`;
- identificación de fecha, tipo y valor;
- agregación diaria por media o suma;
- detección de métricas por sinónimos;
- diagnóstico de columnas encontradas y no mapeadas;
- mapeo manual para campos principales.

La normalización interna termina en filas diarias con campos como HRV, RHR, recuperación, sueño, respiración, temperatura, pasos, despertares y strain.

### 3.3 Tratamiento de datos faltantes

El sistema anterior aplica defaults para varios campos. Si el export no contiene sueño, crea un proxy basado en timing de frecuencia cardiaca o, como fallback, en HRV/RHR y luz solar. El resultado se marca con `sleepEstimated=true`, pero esto no elimina el riesgo de que el usuario lo interprete como sueño medido.

Decisión para 2.0: conservar la capacidad de mostrar un cálculo alternativo, pero hacer que la calidad y el origen sean parte visible del modelo, no solo una bandera interna.

### 3.4 Pipeline analítico

`computePipeline` realiza, entre otras, estas operaciones:

1. Orden temporal.
2. Baseline global de HRV y RHR.
3. Desviaciones respecto al baseline.
4. Sleep Score derivado.
5. Stress y fatigue scores.
6. Z-scores sobre ventanas de siete días.
7. Entropía aproximada sobre ventanas de catorce días.
8. Flags de fatiga aguda y posible proceso infeccioso.
9. Risk Score compuesto.
10. BioScore compuesto.
11. Etiquetas de nivel y mensajes explicativos.

Además existen cálculos separados para mapa de energía, forecast lineal, readiness, zona de esfuerzo, correlaciones y streaks.

### 3.5 Experiencia de usuario

La estructura del producto anterior contiene:

- **Inicio:** BioScore, Risk Score, plan de hoy, métricas y tendencias.
- **Live:** frecuencia cardiaca y métricas de estado; parte de la experiencia está simulada.
- **Datos:** registro de hábitos, readiness y zona de esfuerzo.
- **Sueño:** Sleep Score, tendencia y detalle de componentes.
- **Técnico:** mapa de energía, forecast y resultados de modelos.
- **Ajustes:** fuente, rango histórico, umbral, tema, privacidad y exportaciones.
- **Coach:** respuesta contextual, fallback local y guía de respiración.

La navegación y la presentación pueden rediseñarse en SwiftUI; el orden conceptual es un activo reutilizable.

## 4. Inventario de activos y decisión de migración

| Activo | Estado auditado | Decisión 2.0 | Acción recomendada |
|---|---|---|---|
| `bioUtils.js` | Pipeline amplio de cálculos y reglas | MODIFY / REBUILD | Convertir funciones en especificaciones, luego implementarlas en un módulo de dominio testeable. |
| `useBiopulseData.js` | Normalización, CSV, estado y persistencia mezclados | REBUILD | Separar adaptadores, parser, repositorio y casos de uso. |
| `Technical.jsx` | Visualiza métricas, pero contiene constantes ML | REBUILD | Rescatar estructura; conectar solo resultados versionados y reproducibles. |
| `Dashboard.jsx` / `Inicio.jsx` | Experiencia principal ya definida | MODIFY | Mantener jerarquía de información; rehacer en SwiftUI. |
| `DataSourceModal.jsx` | Buen flujo de selección y diagnóstico CSV | MODIFY | Convertir a flujo nativo con seguridad y calidad de datos visible. |
| Componentes de anillos y gráficos | Lenguaje visual coherente | MODIFY | Rehacer visualizaciones nativas; conservar semántica, no código. |
| `useLogs.js` / `logPresets.js` | Registro de hábitos y efectos exploratorios | INVESTIGATE | Definir eventos, privacidad y metodología antes de mostrar correlaciones causales. |
| Coach local | Bancos de mensajes y reglas | MODIFY | Mantener fallback local; posponer LLM remoto hasta resolver privacidad y producto. |
| Coach Groq/Vercel | Streaming, rate-limit y filtros | REMOVE inicialmente | No incluir en el MVP local-first; evaluar como módulo posterior. |
| Exportación JSON | Dataset para investigación | MODIFY | Diseñar exportación versionada, con provenance y consentimiento. |
| Informe CSV médico | Resumen legible | INVESTIGATE | Mantener como idea; revisar lenguaje, contexto y responsabilidad de uso. |
| `train_real_models.py` | Entrenamiento de clasificadores | INVESTIGATE / REBUILD | Reproducir desde una revisión identificada y auditar etiquetas/leakage. |
| `train_predict.py` | Regresor a tres días con R² de train | REMOVE de producción | No usar como evidencia; rehacer evaluación temporal y baseline. |
| `training_results.json` | Resultados numéricos guardados | INVESTIGATE | No mostrar como evidencia hasta rastrear ejecución, datos y commit. |
| Backend heredado Vercel/Supabase/auth | Infraestructura web | REMOVE | No portar su implementación. BioPulse 2.0 tendrá un backend nuevo con Supabase Auth/PostgreSQL para login obligatorio y sincronización consentida; ver `../supabase/`. |
| Datasets Whoop/Fitabase/HealthKit | Material de investigación e importación | INVESTIGATE | Catalogar esquema, licencia, sujetos, fechas, calidad y uso permitido. |

## 5. Riesgos y hallazgos críticos

### 5.1 Defaults que pueden parecer mediciones

El parser rellena datos ausentes con valores por defecto para permitir que el dashboard funcione. En 2.0 un valor ausente no debe convertirse silenciosamente en una medición aparente. Debe existir un estado de disponibilidad y calidad.

### 5.2 Sueño inferido

El proxy de sueño es útil para experimentar, pero no equivale a una medición de sueño. Debe mostrarse como `estimated` y quedar excluido de comparaciones que pretendan validar sueño real.

### 5.3 Datos demo

La semilla fija y los eventos inyectados son buenos para pruebas visuales y regresión. No deben aparecer como datos fisiológicos reales ni entrar en entrenamiento de modelos.

### 5.4 Etiquetas derivadas de features

Los scripts generan etiquetas de recuperación, fatiga e infección con umbrales sobre variables que también aparecen como features. Esto puede explicar AUC extremadamente altos y constituye un riesgo de circularidad o leakage conceptual. No es evidencia de capacidad clínica.

### 5.5 Métricas ML embebidas

Los valores de ROC y CV que muestra `Technical.jsx` están codificados en la interfaz. Deben reemplazarse por artefactos con versión, dataset, configuración y métricas calculadas en una ejecución identificable.

### 5.6 Correlación de hábitos

Las comparaciones entre días con y sin hábitos son exploratorias y no prueban causalidad. En 2.0 deben exigir tamaños mínimos, mostrar incertidumbre y evitar lenguaje como “este hábito causó”.

## 6. Qué debe ser el MVP 2.0

### Debe incluir

- Datos demo claramente marcados.
- Importación CSV robusta.
- Modelo canónico de datos.
- Persistencia local.
- BioScore y recuperación con explicación.
- Sueño medido separado de sueño estimado.
- Tendencias con calidad y cobertura visibles.
- Dashboard principal sencillo.
- Pruebas del pipeline.

### Debe esperar

- Coach LLM remoto.
- Cuentas y sincronización cloud.
- Integraciones OAuth de terceros.
- Predicciones clínicas.
- Modelos ML de producción.
- “Gemelo digital” como promesa de producto.

## 7. Criterios de finalización de esta auditoría

- [x] Se identificó el flujo de entrada, normalización, analítica y presentación.
- [x] Se revisaron el núcleo de cálculo, el hook de datos, el dashboard, el área técnica, el importador y el sistema de coach.
- [x] Se inventariaron datasets y scripts ML principales.
- [x] Se clasificaron activos para rescate o reconstrucción.
- [x] Se documentaron riesgos que impiden reutilizar resultados ML sin revisión.
- [ ] Verificar licencias y restricciones de uso de cada dataset.
- [ ] Reproducir entrenamiento desde una revisión limpia y documentada.
- [ ] Confirmar con el usuario el usuario objetivo y el alcance exacto del MVP.
