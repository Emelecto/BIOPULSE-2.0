# Fixtures de contrato

Estos archivos no contienen datos biométricos reales ni mediciones sintéticas. Son plantillas de contrato para desarrollar y probar adaptadores de HealthKit y CSV sin almacenar salud personal en el repositorio.

## Uso previsto

- Validar encabezados y mapeos de CSV.
- Validar estados de capacidad HealthKit.
- Validar que valores ausentes permanezcan ausentes.
- Crear, más adelante, pruebas unitarias con datos desidentificados y consentimiento explícito.

## Prohibiciones

- No sustituir `null` por valores fisiológicos por defecto.
- No considerar estos archivos evidencia de una medición.
- No añadir exportaciones personales de Salud/Apple Watch al repositorio.

## Archivos

| Archivo | Uso |
|---|---|
| `contracts/healthkit-capability-template.json` | Estados de disponibilidad que debe resolver el adaptador HealthKit. |
| `contracts/daily-snapshot-template.json` | Forma canónica de un resumen diario sin observaciones inventadas. |
| `csv/apple-health-tidy-header.csv` | Encabezado de export típico de HealthKit. |
| `csv/wearable-wide-header.csv` | Encabezado canónico de importación diaria amplia. |

Cuando exista una implementación, los fixtures de valores deberán ser claramente desidentificados, etiquetados como `simulated` y limitarse a métricas que Apple Watch/HealthKit realmente pueda producir.
