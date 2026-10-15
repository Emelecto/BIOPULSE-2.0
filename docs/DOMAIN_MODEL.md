# BioPulse 2.0 — modelo de dominio

## 1. Objetivo

Definir el contrato común que permitirá que HealthKit, CSV, datos demo y futuras fuentes alimenten el mismo sistema analítico sin que la interfaz dependa de una fuente concreta.

Este documento describe una propuesta de dominio. No representa todavía código Swift ni una decisión final de persistencia.

## 2. Principios del dominio

- **Fuente antes que score:** conservar el dato observado y su procedencia antes de calcular cualquier índice.
- **Calidad explícita:** ausencia, estimación, baja cobertura y conflicto de fuentes deben poder representarse.
- **Tiempo correcto:** cada medición debe conservar su instante o intervalo; las agregaciones diarias deben indicar cómo se obtuvieron.
- **Provenance:** toda métrica derivada debe poder rastrearse a sus entradas, fórmula y versión.
- **Separación semántica:** bienestar, riesgo, carga y sueño no son el mismo concepto.
- **No diagnóstico:** el dominio no debe usar términos que impliquen diagnóstico médico.

## 3. Entidades principales

### 3.1 `UserProfile`

Contexto opcional proporcionado por el usuario.

| Campo | Tipo conceptual | Estado |
|---|---|---|
| `id` | identificador local | PROPOSED |
| `age` | años, opcional | PROPOSED |
| `sex` | opcional y controlado por privacidad | UNKNOWN |
| `height` / `weight` | valor + unidad, opcional | PROPOSED |
| `fitnessContext` | texto o enum | PROPOSED |
| `goals` | lista de objetivos | PROPOSED |
| `createdAt` / `updatedAt` | fecha | PROPOSED |

El perfil no debe inventar ni completar métricas fisiológicas. Solo contextualiza cálculos que indiquen explícitamente que usan ese contexto.

### 3.2 `DataSource`

Describe de dónde proviene un registro.

```text
DataSource
├─ healthKit
├─ csvImport
├─ demoFixture
└─ futureProvider
```

Debe incluir identificador de fuente, proveedor, versión del importador, fecha de importación y consentimiento aplicable.

### 3.3 `RawMeasurement`

Unidad mínima observada o importada antes de agregación.

| Campo | Descripción |
|---|---|
| `id` | identificador local estable |
| `metric` | tipo canónico de métrica |
| `value` | valor numérico o categoría controlada |
| `unit` | unidad explícita |
| `startDate` / `endDate` | intervalo de observación |
| `source` | `DataSource` |
| `externalIdentifier` | identificador del proveedor, si existe |
| `quality` | estado y advertencias |
| `importedAt` | fecha de incorporación local |

Para HealthKit, `source` debe conservar el `HKSource`/dispositivo cuando esté disponible, además del tipo HealthKit y el intervalo temporal.

### 3.4 `DailyMetric`

Agregación de una métrica para un día local definido por timezone.

```text
DailyMetric<T>
├─ date
├─ metric
├─ value
├─ unit
├─ aggregation
├─ sampleCount
├─ coverage
├─ sourceRefs
├─ quality
└─ provenance
```

`aggregation` puede ser `mean`, `sum`, `min`, `max`, `median`, `duration`, `latest` o `notApplicable`. No se debe usar media para una métrica que requiera suma sin declararlo.

### 3.5 `DailySnapshot`

Vista diaria canónica usada por la analítica. Agrupa métricas disponibles, pero no sustituye los registros crudos.

Campos iniciales propuestos:

- fecha y zona horaria;
- HRV;
- RHR;
- frecuencia cardiaca;
- duración del sueño;
- eficiencia del sueño;
- despertares;
- recuperación observada, si la fuente la ofrece;
- frecuencia respiratoria;
- desviación de temperatura de piel, si existe;
- pasos;
- energía activa;
- duración de ejercicio;
- strain o carga, si la fuente lo ofrece;
- referencias a mediciones y calidad.

Un campo ausente debe permanecer ausente. Los defaults solo pueden existir en fixtures de prueba o como parámetros de una estimación identificada.

### 3.6 `Baseline`

Representa el rango personal de referencia de una métrica.

| Campo | Descripción |
|---|---|
| `metric` | métrica de referencia |
| `window` | número de días o periodo |
| `method` | media, mediana, robusto, etc. |
| `center` | centro calculado |
| `dispersion` | desviación, MAD u otra |
| `minimumSamples` | mínimo necesario |
| `eligibleSamples` | muestras utilizadas |
| `computedAt` | fecha de cálculo |
| `version` | versión de la fórmula |

El baseline nunca debe usar datos futuros respecto al día que se está evaluando cuando el objetivo sea predicción.

### 3.7 `DerivedMetric`

Resultado calculado a partir de observaciones y/o baselines.

Ejemplos:

- `hrvDeviation`;
- `rhrDeviation`;
- `sleepScore`;
- `recoveryScore`;
- `readinessScore`;
- `riskScore`;
- `bioScore`;
- `energyProfile`;
- `trend`.

Debe incluir fórmula o algoritmo, inputs, versión, estado `observed | derived | estimated | predicted`, y una explicación apta para la interfaz.

### 3.8 `SignalFlag`

Señal explicable producida por una regla o detector.

```text
SignalFlag
├─ code
├─ severity
├─ status
├─ evidenceRefs
├─ ruleVersion
├─ explanation
└─ medicalDisclaimerRequired
```

Los nombres deben describir señales observadas, no afirmar diagnósticos. Ejemplo aceptable: `acute_fatigue_pattern`; ejemplo no aceptable como diagnóstico: `infection_confirmed`.

### 3.9 `ScoreResult`

Contrato común para BioScore, Sleep Score, Readiness y Risk Score.

```text
ScoreResult
├─ score: 0...100
├─ label
├─ direction: higherIsBetter | lowerIsBetter
├─ components
├─ confidenceOrCoverage
├─ status
├─ calculatedAt
└─ provenance
```

Un score no debe mostrarse sin explicar al menos su nombre, dirección, cobertura de datos y principales componentes.

### 3.10 `PredictionResult`

Entidad separada de `ScoreResult`.

Debe incluir:

- outcome y horizonte temporal;
- valor predicho y unidad;
- modelo y versión;
- dataset y versión;
- features utilizadas;
- baseline comparado;
- métricas de evaluación;
- incertidumbre o calibración;
- limitaciones;
- estado `experimental` o `productionValidated`.

No se debe crear esta entidad para una simple proyección lineal sin etiquetarla como tendencia o forecast explicativo.

## 4. Catálogo inicial de métricas

| Métrica | Unidad | Tipo de entrada | Agregación inicial | Estado |
|---|---|---|---|---|
| HRV | ms | observada | mean/median según fuente | PROPOSED |
| RHR | bpm | observada | mean o proveedor | PROPOSED |
| Heart rate | bpm | observada | series / median para resumen | PROPOSED |
| Sleep duration | h | observada o estimada | duration/sum | PROPOSED |
| Sleep efficiency | % | observada o estimada | proveedor/mean | PROPOSED |
| Recovery | % o score proveedor | observada o derivada | proveedor/latest | PROPOSED |
| Respiratory rate | respiraciones/min | observada | mean | PROPOSED |
| Skin temperature deviation | unidad del proveedor | observada | mean/latest | PROPOSED |
| Steps | count | observada | sum | PROPOSED |
| Active energy | kcal | observada | sum | PROPOSED |
| Exercise duration | min | observada | sum | PROPOSED |
| Wake-ups | count | observada o estimada | sum | PROPOSED |
| Strain/load | score del proveedor | observada o derivada | latest/mean | PROPOSED |

`Recovery` y `Strain` no son tipos biométricos universales de Apple Watch. Si no existe una muestra HealthKit equivalente, BioPulse debe mantenerlos ausentes o calcular un indicador propio con otro nombre y provenance explícita.

Las unidades y transformaciones definitivas deben verificarse por fuente. No asumir que dos proveedores usan la misma definición de HRV, recovery o strain.

## 5. Capas de analítica

```text
RawMeasurement
    ↓ normalización y validación
DailyMetric / DailySnapshot
    ↓ baseline personal
DerivedMetric
    ↓ reglas y modelos validados
SignalFlag / ScoreResult / PredictionResult
    ↓ explicación
Dashboard, tendencias y recomendaciones
```

### Capa 1 — Observación

Datos directamente medidos o exportados, con fuente y unidad.

### Capa 2 — Normalización

Conversión de fechas, unidades, nombres y formatos. No debe crear datos fisiológicos sin marcarlo.

### Capa 3 — Derivación determinista

Scores y tendencias transparentes, con fórmulas versionadas.

#### Tendencias personales iniciales

- **CONFIRMED:** `TrendCalculator` compara una medición diaria con su baseline personal de mediana/MAD y devuelve un resultado disponible o una razón explícita de indisponibilidad.
- **CONFIRMED:** el baseline usado por una tendencia solo considera snapshots con fecha anterior al día evaluado y la misma zona horaria; no incluye el día actual ni datos futuros.
- **CONFIRMED:** el resultado indica cambio absoluto, desviación normalizada cuando la MAD es mayor que cero, cobertura, multiplicador del rango de referencia y dirección respecto de la referencia personal.
- **CONFIRMED:** la dirección solo expresa posición frente al rango personal (`above`, `below` o `within`). No afirma que el cambio sea positivo, negativo, médico o causal.
- **PROPOSED:** la interfaz traducirá estas tendencias a lenguaje sencillo por métrica, tras validar las reglas de presentación y contexto.

### Capa 4 — Inferencia

Proxies o estimaciones, siempre con `estimated`, método y cobertura.

### Capa 5 — Predicción

Modelos ML con dataset, baseline, métricas y evaluación formal.

## 6. Contratos de calidad

Cada métrica debe poder responder:

1. ¿Qué mide?
2. ¿En qué unidad?
3. ¿De qué fuente viene?
4. ¿Cuántas muestras la respaldan?
5. ¿Está completa o estimada?
6. ¿Qué fórmula la transformó?
7. ¿Qué versión del pipeline la produjo?

Estados mínimos propuestos:

```text
available
partial
missing
estimated
simulated
invalid
conflicting
```

## 7. Contrato de importación CSV

El importador debe producir:

```text
ImportResult
├─ records
├─ detectedFormat
├─ mappedColumns
├─ unmappedColumns
├─ warnings
├─ rejectedRows
├─ coverageSummary
└─ sourceMetadata
```

Reglas iniciales:

- rechazar o aislar filas sin fecha válida;
- no convertir HRV/RHR faltantes en valores predeterminados;
- conservar columnas no mapeadas para diagnóstico;
- informar timezone y ambigüedad de fechas;
- distinguir “no existe en el archivo” de “valor inválido”;
- no marcar sueño como medido cuando fue inferido.

### Implementación inicial del importador

- **CONFIRMED:** `BioPulseDomain` admite dos contratos: `tidy` (`type, sourceName, unit, startDate, endDate, value`) y `wide` (`date` más columnas canónicas).
- **CONFIRMED:** para `wide`, el día solo acepta `YYYY-MM-DD`; para `tidy`, la fecha exige ISO 8601 con zona horaria. Las fechas ambiguas se rechazan.
- **CONFIRMED:** valores vacíos no se convierten en cero ni se registran; la métrica queda ausente. Los valores no numéricos, no finitos o con unidad incompatible se registran como rechazados.
- **CONFIRMED:** las columnas sin mapeo canónico se conservan en el resultado como no mapeadas; no se descartan silenciosamente.
- **PROPOSED:** añadir adaptadores específicos para exportaciones completas de Apple Health, incluidos los intervalos de sueño y tipos categóricos, tras verificar su formato real.
- **UNKNOWN:** esquema exacto de la exportación CSV que se importará primero desde el dispositivo del usuario.

## 8. Contrato de fuentes futuras

Todas las fuentes deben implementar conceptualmente:

```text
HealthDataSource
├─ requestAuthorization()
├─ fetchMeasurements(range)
├─ mapToCanonicalRecords()
└─ sourceMetadata()
```

HealthKit y CSV son las primeras implementaciones. Fitbit, Whoop y otras fuentes quedan como adaptadores posteriores, no como dependencias del dominio.

## 9. Preguntas abiertas del dominio

- BioScore representa bienestar general; siguen pendientes sus componentes, pesos, umbrales y condiciones mínimas de cobertura.
- ¿Risk Score será un detector de anomalías personales o un riesgo fisiológico más amplio?
- ¿Cuál será el mínimo de días para mostrar scores?
- ¿Cuál timezone define el día del usuario?
- ¿Se almacenarán datos crudos indefinidamente o con retención configurable?
- ¿Qué métricas deben ser obligatorias para el MVP?
- ¿Se quiere conservar el registro de hábitos en la primera versión?
- ¿Qué versión mínima de watchOS y qué modelos de Apple Watch debemos soportar más allá de la política de capacidades?

## 10. Próximo paso técnico

Crear fixtures JSON/CSV pequeños y versionados que cubran:

1. día completo con datos observados;
2. día con HRV/RHR pero sin sueño;
3. CSV tidy de Apple Health;
4. CSV wide de wearable;
5. valores inválidos y fechas ambiguas;
6. datos demo claramente marcados.

Estos fixtures serán la base de las pruebas antes de implementar HealthKit o la interfaz final.
