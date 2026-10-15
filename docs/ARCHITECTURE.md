# BioPulse 2.0 — arquitectura

## Estado

- **CONFIRMED:** la aplicación nueva será iOS nativa.
- **PROPOSED:** SwiftUI para interfaz y Swift para lógica de dominio.
- **PROPOSED:** HealthKit como fuente de datos del dispositivo y una capa separada de importación CSV.
- **CONFIRMED:** una sesión autenticada es requisito para abrir y usar la app; no habrá modo invitado.
- **CONFIRMED:** datos locales y cachés quedan aislados por cuenta en el dispositivo.
- **CONFIRMED:** la sincronización cloud será opt-in por categoría, aunque iniciar sesión sea obligatorio.
- **PROPOSED:** Python aislado para investigación y entrenamiento; Core ML solo para modelos que superen la validación requerida.
- **CONFIRMED:** iOS 17 es la versión mínima de despliegue.
- **PROPOSED:** persistencia local detrás de un contrato de repositorio; el motor físico se decidirá en macOS tras crear el proyecto Xcode.
- **CONFIRMED:** la sincronización cloud será opt-in y no subirá los datos biométricos originales de HealthKit por defecto.
- **CONFIRMED:** la autenticación futura incluirá Apple, correo/contraseña y Google.
- **PROPOSED:** el Coach IA usará una capa de proveedor intercambiable; Groq es un candidato, no una dependencia actual.

## Principios

1. Separar adquisición, normalización, dominio fisiológico, analítica, persistencia y presentación.
2. Mantener los cálculos deterministas y testeables fuera de las vistas.
3. Minimizar datos y permisos: pedir solo lo necesario y explicar el uso.
4. Diseñar la fuente de datos como una abstracción para HealthKit, CSV y fixtures de pruebas.
5. Evitar que la UI o un proveedor externo definan la verdad del dominio.

## Arquitectura propuesta

```text
SwiftUI
  ↓
ViewModels / casos de uso
  ↓
`BioPulseDomain` (paquete Swift sin frameworks Apple): métricas, calidad, procedencia, snapshots y baselines
  ↓
Dominio analítico: tendencias, reglas y contratos de ML
  ↓
Repositorios
  ├─ HealthKit
  ├─ Importador CSV
  └─ Persistencia local
```

Los experimentos Python deben vivir fuera del runtime de la app y producir artefactos versionables, con metadatos de dataset, features, versión de código y métricas. Una conversión a Core ML requiere validación adicional de equivalencia entre inferencia de investigación y producción.

## Límites de datos y servicios futuros

```text
Sesión autenticada ── requisito para entrar a la app
          │
          ├─ datos locales ──────────────── aislados por user_id
          ├─ perfil / diario / ajustes ──── nube solo con consentimiento
          ├─ métricas derivadas ─────────── nube solo con consentimiento
          └─ HealthKit original ─────────── permanece en el dispositivo
```

**Backend propuesto:** Supabase Auth + PostgreSQL, con migraciones versionadas,
políticas RLS en cada tabla expuesta y acceso desde iOS bajo la sesión
autenticada. `service_role` y secretos de proveedores solo existirán en
entornos de servidor. El esquema inicial está en `../supabase/`.

**Implementado en código, pendiente de validación en Mac:** la app bloquea el
acceso hasta restaurar o establecer una sesión Supabase Auth; ofrece correo y
contraseña, Apple, Google y recuperación de contraseña. El Diario local se
guarda en una ruta por `user_id`; el cambio de cuenta recrea su controlador.
La URL y clave publishable están en la configuración generada de la app; no se
incluyen claves privilegiadas. El flujo requiere configurar los proveedores,
redirecciones y correo en Supabase y probar la compilación/distribución iOS.

Las migraciones de datos, bootstrap de cuenta y privacidad/cuotas del Coach se
aplicaron en local y en el proyecto enlazado. La suite pgTAP local pasó 39/39.
La función del Coach arranca localmente y rechaza una llamada sin sesión (401),
pero no está desplegada ni conectada a la app. La
configuración Auth remota (confirmación de correo, SMTP y proveedores OAuth)
todavía debe verificarse por separado.

El backend del Coach no recibe acceso directo a HealthKit: acepta contexto
agregado permitido y excluye muestras originales. La función exige autorización
específica, no almacena el transcript, guarda una memoria de siete días y aplica
una cuota atómica. La interfaz iOS deberá mostrar la autorización antes del
primer envío. Ningún filtro o prompt garantiza riesgo cero; hace falta evaluar
casos de prompt injection, errores clínicos y síntomas graves antes de publicar.

## Paquete de dominio inicial

- **CONFIRMED:** `BioPulse/Package.swift` define `BioPulseDomain`, un paquete Swift que solo depende de Foundation.
- **CONFIRMED:** el paquete modela métricas diarias, unidades canónicas, procedencia, calidad, día local y baseline robusto mediana/MAD.
- **CONFIRMED:** una métrica no incluida en `DailySnapshot` permanece ausente; no se reemplaza por un valor por defecto.
- **CONFIRMED:** `BioPulseLocalStore` define operaciones locales para snapshots, baselines y tendencias, con control optimista de revisiones al reemplazar snapshots.
- **CONFIRMED:** `BioPulse/project.yml` declara el paquete como dependencia local del proyecto iOS que se generará con XcodeGen en Mac.
- **PROPOSED:** la capa SwiftUI actual consulta HealthKit para las señales visibles; la arquitectura definitiva de repositorio y persistencia aún requiere integración y pruebas en Mac.
- **UNKNOWN:** motor físico definitivo (SwiftData, SQLite u otro), retención de registros crudos y estrategia de sincronización.

## Auditoría del proyecto anterior

Auditoría local en `BIOPULSE PROYECTO CIENCIA DE DATOS`, estado no limpio:

| Elemento | Estado | Decisión inicial | Evidencia / motivo |
|---|---|---|---|
| `biopulse-vite/src/lib/bioUtils.js` | CONFIRMED | MODIFY | Contiene PRNG sintético, scores, z-scores, ApEn, reglas de riesgo, proyección y correlaciones; útil como referencia, no como código Swift listo para producción. |
| `biopulse-vite/src/hooks/useBiopulseData.js` | CONFIRMED | INVESTIGATE | Centraliza fuentes demo/CSV/wearable, periodo y persistencia web; requiere revisar completo el contrato y separarlo de React/localStorage. |
| `biopulse-vite/src/components/Technical.jsx` | CONFIRMED | REBUILD | Presenta visualizaciones y constantes de ROC/CV/confusión/importancias; la procedencia de esos valores debe verificarse antes de reutilizar resultados. |
| Componentes de visualización | CONFIRMED | MODIFY | Hay anillos, mapa de energía, forecast y gráficos; los conceptos pueden inspirar SwiftUI, pero no se copia el shell web. |
| Lógica de procesamiento | CONFIRMED | REBUILD/MODIFY | Hay pipeline de scores y flags, pero deben redefinirse contratos, unidades, ventanas y manejo de datos reales. |
| Algoritmos fisiológicos | CONFIRMED | INVESTIGATE | Existen ApEn, z-scores y reglas de fatiga/infección; requieren revisión científica, pruebas y lenguaje no diagnóstico. |
| Scripts ML | CONFIRMED | REBUILD | Existen `files/train_real_models.py`, `files/06_rigor_tecnico.py` y `biopulse-vite/scripts/train_predict.py`; no se ha establecido aún un pipeline 2.0 reproducible ni leakage auditado. |
| Datasets | CONFIRMED | INVESTIGATE | Hay `whoop_fitness_dataset_100k.csv`, `converted-health-data.csv`, carpetas Fitabase y datasets sintéticos; licencia, procedencia, esquema y uso permitido siguen pendientes. |
| Backend heredado (Vercel/Web) | CONFIRMED | REMOVE | No se porta a la app nativa. |
| Supabase Auth/PostgreSQL | CONFIRMED como dirección | REBUILD | Nuevo backend para login obligatorio y datos sincronizados con consentimiento; se está preparando un esquema específico de 2.0. |

## Estado del repositorio

- **CONFIRMED:** `BIOPULSE 2.0` estaba vacío durante la auditoría y no tenía Git inicializado.
- **CONFIRMED:** el repositorio antiguo contiene cambios sin confirmar y archivos no rastreados; sus resultados no deben tratarse como una release reproducible.
- **UNKNOWN:** contenido remoto actual de GitHub, historial completo y diferencias entre el checkout local y la URL pública.
