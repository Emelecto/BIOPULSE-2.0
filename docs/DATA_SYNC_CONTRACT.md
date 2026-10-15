# Contrato de nube BioPulse 2.0

Estado: **CONFIRMED** para esquema, permisos y pruebas locales; **PROPOSED** para la integración iOS aún no implementada.

La sesión de cuenta es obligatoria para entrar en la app, pero **no** equivale a permiso para subir información. `sync_consents` registra eventos independientes para `profile`, `settings`, `journal` y `derived_metrics`; el más reciente por categoría decide si se permiten escrituras. `Coach` utiliza otro consentimiento y no activa sincronización. El backend acepta lecturas propias aunque una categoría esté revocada para permitir exportación/borrado. Revocar detiene nuevas subidas; **no elimina automáticamente filas remotas previas**. La eliminación debe ser una acción separada y visible. El Diario y los agregados permiten `DELETE` al propietario aun tras revocar; perfil y ajustes conservan sus filas mínimas de bootstrap y requieren un flujo de borrado de cuenta para su eliminación completa.

## Datos autorizables

| Categoría | Tabla | Contenido permitido | Nunca incluir |
| --- | --- | --- | --- |
| Perfil | `profiles` | nombre visible opcional | metadata de proveedores, contraseña |
| Ajustes | `user_settings` | zona horaria, sistema de unidades | tokens, claves |
| Diario | `journal_entries` | hábito/síntoma/evento escrito por el usuario, fecha, zona horaria y revisión | archivos externos sin permiso |
| Biometría agregada | `daily_metric_summaries` | un resumen por usuario, día local, métrica y fuente, con valor/unidad/calidad/cobertura/revisión | muestras HealthKit originales, timestamps de cada muestra, identificador de dispositivo |

Métricas admitidas: frecuencia cardiaca y reposo (`bpm`), HRV SDNN (`ms`), respiración (`breaths/min`), saturación (`fraction`), sueño y ejercicio (`min`), pasos (`count`), energía activa (`kcal`), VO₂ máx. (`mL/kg/min`) y desviación de temperatura (`degC`). `source_kind` solo admite `healthkit_aggregate` o `csv_aggregate`. `formula_version` permite rastrear cambios de cálculo. `sample_count` y `coverage_fraction` describen calidad sin exponer muestras. Se rechazan valores no finitos, unidades incongruentes, cantidades físicamente negativas y saturación fuera de la fracción 0–1; estos límites amplios no son umbrales clínicos.

## Flujo de cliente pendiente

1. Mostrar cuatro interruptores apagados al inicio, con explicación individual. Registrar `granted` solo después de acción afirmativa; nunca inferir consentimiento de login ni Coach.
2. Calcular resúmenes diarios **en el dispositivo** y separar datos por `auth.users.id`. No mandar muestras originales, rutas de archivos ni metadatos de dispositivo.
3. Subir mediante SDK Supabase con JWT de usuario y clave publishable. Jamás incluir `service_role` en la app. Las políticas RLS bloquean escrituras sin consentimiento vigente y entre cuentas.
4. Para Diario, usar UUID estable del registro local y `revision` optimista; si hay conflicto, detener la subida y pedir resolución visible. No sustituir contenido de forma silenciosa. Para métricas, usar clave natural `(user_id,local_date,metric_kind,source_kind)` y versión de fórmula; evitar `upsert` indiscriminado.
5. En revocación, detener la cola de esa categoría y descartar trabajos pendientes. Ofrecer borrado remoto separado; no borrar datos locales por revocar sincronización.

No hay transporte iOS implementado aún. Las pruebas SQL comprueban RLS, consentimiento, aislamiento, validación de agregados y revocación. La compilación y verificación en iPhone quedan para el siguiente ciclo con Mac.
