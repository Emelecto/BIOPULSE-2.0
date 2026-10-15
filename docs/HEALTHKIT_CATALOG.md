# Catálogo de datos Apple Watch / HealthKit

## Estado y alcance

- **CONFIRMED:** Apple Watch comparte datos con HealthKit y las apps pueden leerlos con autorización del usuario.
- **CONFIRMED:** HealthKit organiza datos como cantidades, categorías, correlaciones, series, workouts, rutas y registros clínicos.
- **CONFIRMED:** Apple exige permisos específicos por tipo y el usuario puede limitar el histórico autorizado.
- **PROPOSED:** BioPulse leerá todos los tipos relevantes para salud, recuperación y rendimiento que estén disponibles en el dispositivo del usuario, sin asumir que todos estarán presentes.
- **CONFIRMED:** iOS 17 es la versión mínima de despliegue de BioPulse 2.0.
- **UNKNOWN:** versión mínima de watchOS, modelos exactos de los usuarios objetivo y países de distribución.

Contexto de validación aportado por el usuario:

- **CONFIRMED:** la prueba inicial se realizará con un Apple Watch Ultra y la versión actual de iOS del usuario.
- **CONFIRMED:** la aplicación debe ser compatible con la familia de Apple Watch, no solo con el modelo Ultra.
- **PROPOSED:** la matriz de compatibilidad se basará en capacidades detectadas y tipos HealthKit disponibles, no en checks rígidos de modelo.

Fuentes oficiales consultadas:

- [HealthKit — Data types](https://developer.apple.com/documentation/healthkit/data-types)
- [HKQuantityTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier)
- [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)
- [HKHealthStore](https://developer.apple.com/documentation/healthkit/hkhealthstore)
- [Apple Watch — Track your vitals](https://support.apple.com/guide/watch/vitals-apd15aa7ed96/watchos)
- [Apple Watch — health features](https://support.apple.com/guide/watch/get-started-with-health-features-apd7941a2f19/watchos)

## Regla principal

BioPulse no debe construir un valor sustituto cuando una métrica real no existe. La app debe mostrar:

- `available`: existe una muestra autorizada y válida;
- `partial`: existe cobertura incompleta;
- `missing`: el tipo no está disponible o no fue autorizado;
- `estimated`: se calculó un proxy explícito, solo si el usuario acepta verlo;
- `unsupported`: el dispositivo o región no ofrece el tipo;
- `restricted`: HealthKit está restringido;
- `invalid`: la muestra no puede utilizarse.

Para el MVP, `estimated` no se utilizará para aparentar una medición real. Si falta sueño, HRV u otra variable importante, el score debe degradarse o no mostrarse.

## Datos biométricos y fisiológicos

| Área | Datos HealthKit relevantes | Uso posible en BioPulse | Disponibilidad |
|---|---|---|---|
| Corazón | Heart Rate | tendencia, rango personal, carga de workout | depende de muestras y uso |
| Corazón | Resting Heart Rate | baseline y bienestar | depende de muestras suficientes |
| Corazón | HRV SDNN | variabilidad y tendencia | modelo/reloj/uso; no asumir RMSSD |
| Corazón | Walking Heart Rate Average | contexto de movilidad | depende de actividad y muestras |
| Corazón | Heart Rate Recovery 1 min | recuperación post-ejercicio | depende de workouts compatibles |
| Corazón | ECG | registro/correlación de ECG | modelos compatibles, región y permisos |
| Corazón | AFib burden | contexto cardiaco, no diagnóstico | modelos/región/condiciones/permisos |
| Corazón | irregular/high/low heart rate events | eventos registrados por Apple | disponibilidad y región |
| Respiración | Respiratory Rate | tendencia nocturna y recuperación | requiere datos de sueño/uso |
| Oxigenación | Oxygen Saturation | contexto de tendencia | modelo, región y restricciones; puede no estar disponible |
| Temperatura | Apple Sleeping Wrist Temperature | desviación nocturna y tendencia | modelos compatibles, sueño configurado y noches suficientes |
| Sueño | in bed, awake, asleep unspecified, core, deep, REM | duración, regularidad, arquitectura de sueño | requiere registros de sueño; las etapas pueden faltar |
| Sueño | sleeping breathing disturbances classification | señal de perturbaciones respiratorias | disponibilidad por sistema/modelo y HealthKit |
| Movilidad | walking steadiness, walking speed, six-minute walk distance | tendencia funcional | depende de dispositivo, caminatas y muestras |
| Caídas | number of times fallen / fall events | contexto de seguridad y tendencia | no es una medición continua de riesgo |

Apple documenta que el sueño puede incluir muestras de estar en cama, despierto, sueño no especificado, Core, Deep y REM. Las muestras de vigilia registradas por Apple Watch pueden no cubrir el inicio o el final de una sesión de sueño; por tanto, el cálculo de despertares y porcentajes debe tolerar cobertura incompleta.

## Actividad, ejercicio y rendimiento

| Área | Datos relevantes | Uso posible |
|---|---|---|
| Actividad diaria | steps, walking/running distance, flights climbed | carga y contexto diario |
| Energía | active energy, basal energy | volumen y balance de actividad |
| Anillos/tiempo | exercise time, move time, stand time, stand hours | consistencia y comportamiento |
| Aeróbico | VO2 max, low cardio fitness event | tendencia de capacidad aeróbica |
| Carrera | running speed, power, ground contact time y otras métricas disponibles | análisis de rendimiento |
| Ciclismo | cycling speed, power y distancia | análisis de sesión |
| Natación | distancia, velocidad y strokes cuando existan | análisis de sesión |
| Workout | tipo, inicio, fin, duración, distancia, energía, eventos y estadísticas | carga y contexto por sesión |
| Ruta | workout route / localizaciones | mapa, distancia y contexto; requiere permisos de ubicación |
| Esfuerzo | workout effort score / physical effort cuando el sistema lo ofrezca | carga reportada por Apple |
| Entorno | time in daylight, environmental audio exposure, headphone audio exposure | contexto de recuperación y hábitos |
| Otros | UV exposure, underwater depth, water temperature donde aplique | almacenar solo si es útil y disponible |

Los workouts funcionan como contenedores de una actividad y pueden tener estadísticas asociadas por tipo de cantidad. BioPulse debe leer el workout y sus estadísticas, evitando sumar dos veces muestras diarias y muestras incluidas dentro del workout.

## Datos de contexto que pueden existir en HealthKit

No todos provienen del Apple Watch ni deben confundirse con biometría del reloj:

- altura, masa corporal, IMC, masa magra y porcentaje de grasa;
- presión arterial y glucosa procedentes de dispositivos o entradas externas;
- nutrición, cafeína y alcohol;
- mindfulness y estado de ánimo;
- medicamentos y síntomas;
- ciclo menstrual y salud reproductiva;
- registros clínicos.

Estos datos pueden mejorar el contexto de bienestar, pero son opt-in, sensibles y deben formar módulos separados. No serán requisitos del primer cálculo de `BioScore`.

## Disponibilidad y limitaciones que debe manejar la app

1. Verificar `HKHealthStore.isHealthDataAvailable()` antes de consultar.
2. Solicitar permisos de lectura por grupos y explicar por qué se necesita cada grupo.
3. No interpretar “sin datos” como “permiso denegado”: para lecturas, HealthKit protege esta distinción y la app no puede conocer de forma fiable si el usuario denegó un tipo concreto o si simplemente no hay muestras legibles.
4. Detectar histórico limitado y reportar cobertura real.
5. Manejar cambios de permiso realizados desde Salud o Ajustes.
6. Registrar modelo de dispositivo, sistema y fuente cuando HealthKit lo proporcione.
7. No asumir que un tipo presente en HealthKit fue generado por Apple Watch; conservar origen del sample.
8. Considerar duplicados y prioridades de fuentes al leer HealthKit.
9. Usar zona horaria y fechas de los samples; no agrupar todo por UTC sin decisión explícita.
10. Habilitar background delivery solo después de definir el coste, frecuencia y necesidad del MVP.

## Características dependientes de hardware o región

- Oxígeno en sangre puede no estar disponible en determinados modelos/regiones.
- ECG requiere hardware compatible y no está disponible en Apple Watch SE; también depende de región.
- Temperatura de muñeca durante el sueño requiere modelos compatibles, configuración de sueño y suficientes noches.
- Sueño y etapas requieren que el usuario duerma con el reloj y tenga configurado el seguimiento.
- Respiración, HRV y recuperación dependen de muestras y del contexto de uso.
- Funciones de apnea, AFib, hipertensión y otras notificaciones son señales del sistema con disponibilidad y restricciones propias; BioPulse no debe convertirlas en diagnósticos.

El Ultra será nuestro dispositivo de validación de cobertura amplia, no el contrato mínimo de compatibilidad. Para cada métrica se debe registrar una capacidad como `supported`, `authorizationRequestNeeded`, `readAccessIndeterminate`, `noSamples` o `restricted`, y la interfaz debe seguir funcionando cuando una capacidad no exista.

## Política de implementación

### Primera implementación HealthKit

Registrar un catálogo tipado y consultar primero:

- heart rate;
- resting heart rate;
- heart rate variability SDNN;
- respiratory rate;
- oxygen saturation, si está disponible;
- sleeping wrist temperature, si está disponible;
- sleep analysis y etapas;
- step count;
- walking/running distance;
- active energy;
- exercise time;
- flights climbed;
- workouts y estadísticas asociadas;
- VO2 max, si está disponible;
- heart rate recovery, si está disponible.

### Compatibilidad por capacidades

La integración debe consultar y construir el catálogo dinámicamente:

1. Verificar disponibilidad general de HealthKit.
2. Construir los tipos de lectura soportados por el SDK y la versión mínima elegida.
3. Solicitar permisos de forma progresiva y explicada.
4. Consultar muestras reales y registrar su fuente/dispositivo.
5. Marcar cada tipo según soporte, autorización, cobertura y validez.
6. Ocultar o degradar solo la función dependiente, no romper toda la aplicación.

No se debe escribir una rama de producto del tipo “si Ultra entonces mostrar todo”. El comportamiento debe surgir de los datos y capacidades efectivamente disponibles.

### Segunda expansión

Añadir ECG/AFib, rutas, métricas avanzadas de carrera/ciclismo/natación, movilidad, caídas, ruido, luz y señales respiratorias de sueño después de comprobar permisos, revisión de privacidad y utilidad para el producto.

### Prohibiciones

- No crear HRV, sueño, temperatura, recuperación o strain artificiales para completar tarjetas.
- No afirmar que todos los Apple Watch entregan los mismos datos.
- No llamar “medición Apple Watch” a un score calculado por BioPulse.
- No convertir un evento o señal de HealthKit en diagnóstico.

