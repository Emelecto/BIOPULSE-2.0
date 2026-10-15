# Matriz de compatibilidad HealthKit

## Propósito

BioPulse debe funcionar con cualquier Apple Watch compatible con la versión mínima de la app. La disponibilidad se resuelve por capacidad real, permisos, fuente y cobertura de muestras; nunca por una condición exclusiva de modelo.

## Estados de capacidad

| Estado | Significado en la interfaz |
|---|---|
| `supported` | El tipo puede consultarse en el entorno actual. |
| `authorizationRequestNeeded` | El sistema indica que se debe solicitar o actualizar la autorización. |
| `readAccessIndeterminate` | HealthKit no permite saber si el usuario negó la lectura o si no existen datos legibles. |
| `noSamples` | Tras una consulta autorizada y con cobertura conocida, no existen muestras utilizables en el periodo. |
| `partial` | Hay datos, pero no cumplen la cobertura definida para esa función. |
| `restricted` | HealthKit está restringido por el sistema o entorno. |
| `unsupported` | El tipo o la función no están disponibles para este hardware, región o sistema. |
| `invalid` | Existen muestras, pero no superan validación de unidad, fecha o fuente. |

No se debe interpretar una consulta vacía como rechazo de permiso; HealthKit protege esa distinción para los tipos de lectura.

## Capas de soporte

| Nivel | Datos / funciones | Política de producto |
|---|---|---|
| Core | HR, RHR, HRV SDNN, sueño, pasos, distancia, energía activa, ejercicio, workouts | Se solicitan de forma progresiva; el dashboard funciona con un subconjunto suficiente. |
| Enhanced | respiración, temperatura de muñeca, SpO₂, VO₂ max, recuperación cardiaca, pisos, sueño por etapas | Mejoran explicación y tendencias; nunca son requisito silencioso. |
| Advanced | ECG, AFib burden, eventos de ritmo, perturbaciones respiratorias al dormir, rutas, métricas de carrera/ciclismo/natación, movilidad, caídas, ruido, luz solar | Módulos opt-in; no definen el BioScore inicial. |
| Contextual | masa corporal, ciclo, estado de ánimo, nutrición, medicación, registros clínicos | Separados del MVP; requieren propósito, privacidad y consentimiento específicos. |

## Matriz de métricas core

| Métrica canónica | HealthKit / muestra | Uso inicial | Requisito de cobertura | Si falta |
|---|---|---|---|---|
| `heartRate` | Heart Rate | tendencia y contexto de workouts | una o más muestras válidas | ocultar tendencia o mostrar cobertura limitada |
| `restingHeartRate` | Resting Heart Rate | baseline de bienestar | mínimo de días definido por pipeline | no calcular componente dependiente |
| `heartRateVariabilitySDNN` | HRV SDNN | baseline y cambio personal | mínimo de días definido por pipeline | no calcular componente dependiente |
| `sleepAnalysis` | Sleep Analysis + etapas | duración, regularidad y arquitectura | una sesión válida | mostrar “sin datos de sueño”, no estimar |
| `stepCount` | Step Count | actividad diaria | día parcial o completo | mostrar cobertura parcial |
| `walkingRunningDistance` | Distance Walking + Running | actividad diaria | día parcial o completo | ocultar componente |
| `activeEnergyBurned` | Active Energy Burned | volumen de actividad | día parcial o completo | ocultar componente |
| `appleExerciseTime` | Apple Exercise Time | consistencia | día parcial o completo | ocultar componente |
| `workout` | HKWorkout + estadísticas | carga por sesión | workout válido | no mostrar análisis de workout |

## Matriz enhanced y advanced

| Métrica canónica | HealthKit / muestra | Nivel | Condición adicional | Tratamiento |
|---|---|---|---|---|
| `respiratoryRate` | Respiratory Rate | Enhanced | muestras válidas; típicamente asociadas a descanso/sueño | tendencia, nunca diagnóstico |
| `wristTemperature` | Apple Sleeping Wrist Temperature | Enhanced | hardware, sueño configurado y noches suficientes | usar desviación/tendencia, no temperatura corporal |
| `oxygenSaturation` | Oxygen Saturation | Enhanced | hardware, región y permisos | contexto, no diagnóstico |
| `vo2Max` | VO2 Max | Enhanced | muestras ofrecidas por HealthKit | tendencia de capacidad aeróbica |
| `heartRateRecoveryOneMinute` | Heart Rate Recovery One Minute | Enhanced | workouts/muestras compatibles | recuperación post-ejercicio |
| `flightsClimbed` | Flights Climbed | Enhanced | hardware y muestra disponible | actividad contextual |
| `electrocardiogram` | ECG samples | Advanced | hardware/región/permiso | visor de registros, no interpretación médica |
| `afibBurden` | Atrial Fibrillation Burden | Advanced | disponibilidad del sistema | mostrar exactamente como señal de Apple, sin reinterpretar |
| `sleepBreathingDisturbances` | Apple Sleeping Breathing Disturbances | Advanced | hardware/sistema/permiso | estado contextual, no diagnóstico |
| `workoutRoute` | Workout Route | Advanced | ruta guardada y permiso | mapa local opcional |
| `runningMetrics` | running speed/power/ground contact/etc. | Advanced | deporte y muestra disponibles | detalles específicos del deporte |
| `mobility` | walking steadiness, speed, six-minute walk | Advanced | muestras disponibles | tendencia funcional |
| `fallEvents` | number of times fallen | Advanced | evento registrado | historial, no predicción |
| `timeInDaylight` / `audioExposure` | HealthKit quantities | Advanced | muestras disponibles | contexto de hábitos |

## Flujo de detección

```text
HealthKit disponible
  ↓
Tipos compilados por SDK + catálogo BioPulse
  ↓
Solicitud de permisos explicada por grupos
  ↓
Consulta de muestras y fuente
  ↓
Estado por métrica: support + authorization + coverage + validity
  ↓
Módulos y scores se adaptan a las métricas realmente presentes
```

## Criterios de aceptación para la futura implementación

- La aplicación no muestra una métrica como disponible sin muestra válida y autorizada.
- Una métrica ausente no produce un valor por defecto fisiológico.
- La ausencia de una métrica enhanced o advanced no bloquea el dashboard core.
- Cada tarjeta indica al menos fuente, periodo de cobertura y estado de calidad cuando sea relevante.
- El test con Apple Watch Ultra cubre las capacidades presentes, pero no se convierte en requisito para otros Apple Watch.
- Se prueban explícitamente `supported`, `authorizationRequestNeeded`, `readAccessIndeterminate`, `noSamples`, `partial`, `restricted`, `unsupported` e `invalid`.

## Pendiente

- Decidir versión mínima de iOS y watchOS antes de compilar el catálogo Swift.
- Confirmar países objetivo para funciones dependientes de región.
- Definir mínimo de días y cobertura por cada componente de BioScore.
