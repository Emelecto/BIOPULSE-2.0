# Índices personales BioPulse — `personal-v1`

## Actualización iOS `personal-v2` — 20-10-2026

La app iOS incorpora autorreportes de duración por fecha al despertar. Para los scores toma una sola fuente por noche: Apple Salud por defecto, o el autorreporte si no hay medición o el usuario lo prioriza explícitamente. La procedencia manual se muestra cuando afecta tanto a la noche evaluada como a la referencia previa. Los CSV permanecen separados de los autorreportes de la cuenta. Descanso percibido, calidad, despertares y factores se guardan como contexto local y no puntúan. La versión admite una duración explícita de cero horas y cuenta fechas únicas, manteniendo las fórmulas y ventanas indicadas abajo. La web conserva `personal-v1`. Contrato y criterios: [Sueño manual](MANUAL_SLEEP.md).

**CONFIRMED:** implementación de fórmulas deterministas en `web/src/scoring.ts` y `BioPulse/Sources/BioPulseDomain/WellnessScores.swift`. Son hipótesis de producto, sin validación clínica. No se entrena ni publica un modelo predictivo con datos de BioPulse en esta fase.

## Contrato y reglas de entrada

- Cálculo local en navegador o iPhone. La base almacena agregados observados; no se guardan scores derivados ni se envían a un modelo. La web filtra `quality=observed`, valor finito y unidad canónica. iOS toma agregados de Apple Salud en memoria. Los valores nulos, cero y datos estimados no se usan para completar huecos.
- BioScore y señal de cambio usan **ayer**, el último día calendario completo. Sleep Score usa la última noche registrada. Todas las ventanas previas excluyen el día evaluado, evitando que una lectura altere su propia referencia.
- El índice lleva fecha, versión, componentes y motivo de ausencia. La ausencia de datos deja el anillo neutro. Un score de 0 no significa enfermedad; 100 no certifica salud. Las etapas de sueño agregadas se visualizan pero no puntúan.
- La meta inicial de sueño es **480 minutos** y puede cambiarse entre 360 y 600 minutos en pasos de 30. Web la guarda en `localStorage` por ID de cuenta; iOS en `UserDefaults` por ID de cuenta. Son preferencias locales, no sincronizadas entre dispositivos.

## Fórmulas provisionales

Todas las funciones `clamp` limitan a `[0,100]`. Los parámetros numéricos se eligieron para iniciar pruebas de producto; no son umbrales fisiológicos validados.

### Sleep Score

Requiere duración de la noche evaluada y **7 noches previas en los 14 días anteriores**. `target` es la meta personal; `median14` es la mediana de duraciones previas.

```
duración = clamp(100 - max(0, |minutos - target| - 30) × 100 / 240)
constancia = clamp(100 - max(0, |minutos - median14| - 30) × 100 / 150)
Sleep Score = round(0.65 × duración + 0.35 × constancia)
```

No mide arquitectura del sueño, horarios de acostarse o descanso percibido. Desde `personal-v2` iOS recoge un check-in subjetivo estructurado como contexto; no cambia la fórmula ni se incorpora automáticamente al ML.

### BioScore

Requiere Sleep Score del mismo día, HRV SDNN, frecuencia cardiaca en reposo y energía activa del día completo. Para cada métrica fisiológica exige **14 días previos en los 28 anteriores**. La referencia es mediana y MAD, con un piso de dispersión para evitar dividir por cero. La dirección del índice de recuperación es específica para esta hipótesis y compara solo al usuario consigo mismo.

```
escala_HRV = max(1.4826 × MAD_HRV, 0.1 × mediana_HRV, 5 ms)
escala_FC  = max(1.4826 × MAD_FC,  0.1 × mediana_FC,  3 bpm)
HRV       = clamp(75 + 15 × (HRV - mediana_HRV) / escala_HRV)
FC        = clamp(75 - 15 × (FC - mediana_FC) / escala_FC)
recuperación = (HRV + FC) / 2
actividad = clamp(100 - 60 × |log2((energía + 50) / (mediana_energía + 50))|)
BioScore = round(0.40 × Sleep Score + 0.35 × recuperación + 0.25 × actividad)
```

La actividad mide cercanía a la rutina personal; más kcal no siempre mejor. El índice no identifica causas. Pasos y energía activa no se suman por separado para reducir doble conteo.

### Señal de cambio personal (Risk Score exploratorio)

Usa sueño, HRV y FC en reposo. Requiere **dos días completos consecutivos**, y para cada uno 14 días previos por señal en una ventana de 28 días. Para cada señal se calcula una desviación absoluta respecto a su mediana personal, dividida por `max(1.4826×MAD, 10 % de mediana, piso)`; los pisos son 45 min, 5 ms y 3 bpm. Solo se considera persistente si al menos **dos de tres señales** superan 1.5 desviaciones cada uno de los dos días. Entonces `round(clamp(máxima desviación actual × 20))`; en caso contrario, 0 con texto que aclara que ello no descarta un problema de salud.

Este número mide magnitud de desviación, **no probabilidad de enfermedad**. No emite alertas médicas automáticas. En una versión futura se pueden evaluar tasas de falsas alertas antes de notificar.

## Modelos de ML y función prevista

La app incluye un **Isolation Forest personal no supervisado** para identificar combinaciones de HRV, frecuencia cardiaca en reposo y energía activa que se aíslan de los 90 días anteriores. Exige al menos 30 días completos previos y una observación completa para el día evaluado. Entrena e infiere localmente en el dispositivo; no requiere sueño ni sube mediciones. Su índice 0–100 indica aislamiento estadístico relativo, no probabilidad, predicción de recuperación ni riesgo de enfermedad. No hay etiquetas para evaluar falsos positivos o beneficio clínico; permanece exploratorio.

El script `ml/train_research.py` conserva dos familias de **investigación supervisada** con etiquetas posteriores e independientes: resultados futuros de sueño/recuperación/rendimiento y eventos clínicos documentados. Compara un predictor trivial, regresión lineal regularizada o logística, y gradient boosting con separación por persona y corte temporal. Ningún modelo supervisado está integrado en la app. El benchmark disponible de readiness no superó al predictor trivial, por lo que no se activa. Para recuperación hará falta un resultado subjetivo estructurado con consentimiento; para enfermedad, resultados clínicos fiables, revisión clínica, validación externa y calibración. El Diario libre y los scores calculados de las mismas entradas no sirven como verdad clínica.

## Criterios pendientes de validación

**UNKNOWN:** concordancia web/iOS en un mismo conjunto real del usuario, impacto de zonas horarias/viajes, cobertura real de Health Auto Export, utilidad de los pesos, interpretación por usuarios, consistencia con autoevaluaciones, tasas de falsas señales y rendimiento de ML en datos externos. No promocionar estos índices como resultados clínicos ni utilizar el color para afirmar salud o enfermedad.
