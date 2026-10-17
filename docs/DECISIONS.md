# BioPulse 2.0 — registro de decisiones

## D-001 — Separar el proyecto nuevo del repositorio anterior

- **Estado:** CONFIRMED
- **Decisión:** desarrollar 2.0 desde cero en `BIOPULSE 2.0`; conservar el proyecto anterior solo para análisis y extracción de conocimiento.
- **Motivo:** evitar arrastrar dependencias, decisiones de producto y supuestos no auditados.

## D-002 — Plataforma principal

- **Estado:** CONFIRMED
- **Decisión:** iOS nativo.
- **Tecnologías candidatas:** Swift, SwiftUI, HealthKit, almacenamiento local, Python y Core ML cuando corresponda.
- **Pendiente:** versión mínima de iOS y arquitectura concreta.

## D-003 — Privacidad y almacenamiento

- **Estado:** CONFIRMED
- **Decisión:** priorizar privacidad y almacenamiento local.
- **Pendiente:** esquema de persistencia, cifrado adicional, copias de seguridad y sincronización opcional.

## D-004 — Auditoría del código heredado

- **Estado:** CONFIRMED
- **Decisión:** clasificar antes de reutilizar: `REUSE`, `MODIFY`, `REBUILD`, `REMOVE` o `INVESTIGATE`.
- **Resultado inicial:** ver tabla en `docs/ARCHITECTURE.md`.

## D-005 — Honestidad de las métricas

- **Estado:** CONFIRMED
- **Decisión:** no presentar predicciones como mediciones reales; etiquetar datos sintéticos, simulados e inferidos; no diagnosticar.

## D-006 — Machine learning

- **Estado:** PROPOSED
- **Decisión provisional:** ningún modelo entra en producción hasta tener dataset identificable, validación reproducible, baseline, control de leakage y métricas verificables.
- **Pendiente:** outcomes, datasets permitidos, evaluación por sujeto/tiempo y criterio de inclusión.

## D-007 — Calendario

- **Estado:** PROPOSED
- **Decisión:** usar cuatro semanas como plan inicial: auditoría/arquitectura, HealthKit/CSV, dashboard/ML y validación.
- **Riesgo:** el calendario puede cambiar tras la creación del proyecto iOS y la auditoría completa.

## D-008 — Estado de la auditoría local

- **Estado:** CONFIRMED
- **Decisión:** considerar el checkout antiguo como referencia no limpia porque contiene cambios sin confirmar y archivos no rastreados.
- **Pendiente:** comparar con remoto y reproducir resultados desde una revisión identificada.

## D-009 — Reconstruir el dominio, no portar la implementación web

- **Estado:** CONFIRMED
- **Decisión:** BioPulse 2.0 rescatará conceptos de producto, fórmulas candidatas, flujos de datos y decisiones de UX del proyecto antiguo, pero reconstruirá la implementación en capas nativas y testeables.
- **Motivo:** el proyecto anterior mezcla UI, estado, parsing, persistencia y analítica en una aplicación web.
- **Referencia:** `docs/LEGACY_AUDIT.md` y `docs/DOMAIN_MODEL.md`.

## D-010 — Provenance y calidad como parte del dominio

- **Estado:** PROPOSED
- **Decisión:** toda medición y métrica derivada deberá conservar fuente, unidad, cobertura, calidad, estado (`observed`, `derived`, `estimated`, `simulated` o `predicted`) y versión del cálculo.
- **Motivo:** el proyecto anterior utiliza defaults y proxies de sueño; 2.0 debe evitar que una estimación parezca una medición.

## D-011 — Primer vertical slice

- **Estado:** PROPOSED
- **Decisión:** la primera versión funcional será `CSV/demo → normalización → modelo canónico → pipeline → dashboard`, antes de coach remoto, backend o ML de producción.
- **Motivo:** valida el núcleo del producto con datos reproducibles y reduce riesgo de arquitectura.

## D-012 — Usuario inicial

- **Estado:** CONFIRMED
- **Decisión:** BioPulse está dirigido a cualquier persona interesada en su salud o rendimiento, no únicamente a atletas ni a usuarios avanzados de biohacking.
- **Implicación:** el producto debe explicar las métricas en lenguaje claro y no presuponer conocimientos fisiológicos.

## D-013 — Significado de BioScore

- **Estado:** CONFIRMED
- **Decisión:** `BioScore` representa principalmente bienestar general.
- **Implicación:** la capacidad de entrenamiento del día será una vista o indicador separado, no la definición principal del score.

## D-014 — Apple Watch/HealthKit como fuente prioritaria

- **Estado:** CONFIRMED
- **Decisión:** los datos reales de Apple Watch a través de HealthKit son la fuente principal del producto. CSV será una fuente complementaria para importar históricos o dispositivos externos.
- **Implicación:** la implementación debe detectar disponibilidad por tipo, modelo, región, permisos, cobertura y calidad.

## D-015 — No completar datos fisiológicos ausentes

- **Estado:** CONFIRMED
- **Decisión:** BioPulse no inventará ni rellenará silenciosamente datos biométricos que el Apple Watch/HealthKit no haya proporcionado.
- **Implicación:** los scores deben degradarse, declararse incompletos o no mostrarse cuando falten entradas esenciales.

## D-016 — Catálogo de HealthKit

- **Estado:** PROPOSED
- **Decisión:** implementar un catálogo amplio de tipos relevantes de HealthKit, empezando por corazón, respiración, sueño, actividad, workouts y temperatura; ampliar después a ECG, AFib, movilidad, caídas, rutas, ruido y señales de contexto.
- **Motivo:** la disponibilidad varía por hardware, región, sistema y permisos; consultar el catálogo no garantiza que exista una muestra para el usuario.
- **Referencia:** `docs/HEALTHKIT_CATALOG.md`.

## D-017 — Dispositivo de validación y compatibilidad

- **Estado:** CONFIRMED
- **Decisión:** el primer dispositivo de prueba será un Apple Watch Ultra con la versión actual de iOS disponible para el usuario, pero BioPulse debe ser compatible con modelos de Apple Watch en general.
- **Implementación:** usar detección de capacidades, disponibilidad de tipos HealthKit, estado de solicitud de autorización y muestras reales; no acoplar la app a la marca Ultra. Para lecturas, no presentar una ausencia de datos como confirmación de permiso denegado.
- **Implicación:** cada métrica y función debe tener estados de soporte, autorización, cobertura y calidad, con degradación parcial cuando corresponda.

## D-018 — Compatibilidad guiada por capacidades

- **Estado:** CONFIRMED
- **Decisión:** BioPulse evaluará cada tipo HealthKit mediante estados de soporte, autorización, cobertura y validez. La disponibilidad de un Apple Watch Ultra no se utilizará como condición para mostrar funcionalidades en otros modelos.
- **Referencia:** `docs/HEALTHKIT_COMPATIBILITY_MATRIX.md`.

## D-019 — Fixtures sin datos biométricos inventados

- **Estado:** CONFIRMED
- **Decisión:** los primeros fixtures del repositorio son plantillas de contrato sin valores fisiológicos personales ni sintéticos. Los fixtures con valores solo se añadirán cuando estén desidentificados, etiquetados y sirvan a una prueba concreta.
- **Referencia:** `fixtures/README.md`.

## D-020 — Versión mínima de iOS

- **Estado:** CONFIRMED
- **Decisión:** BioPulse 2.0 tendrá iOS 17 como versión mínima de despliegue.
- **Implicación:** las funciones de HealthKit se implementarán con comprobaciones de disponibilidad cuando el tipo o la capacidad dependan de hardware, watchOS o región.

## D-021 — Paquete de dominio independiente de Apple

- **Estado:** CONFIRMED
- **Decisión:** mantener los contratos de métricas diarias y el cálculo de baseline personal en `BioPulseDomain`, un paquete Swift que solo depende de Foundation.
- **Motivo:** permite probar el modelo y los cálculos en Windows cuando exista una toolchain Swift, y reutilizarlos sin duplicación desde la futura app Xcode.
- **Reglas:** una métrica ausente se representa por ausencia; cada métrica almacenada exige unidad, procedencia, calidad, cobertura y número de muestras. Las fixtures de prueba no califican para un baseline por defecto; el cálculo solo puede incluirlas con un parámetro explícito de prueba.

## D-022 — Importación CSV por contratos explícitos

- **Estado:** CONFIRMED
- **Decisión:** el primer importador CSV acepta únicamente los formatos `tidy` y `wide` documentados. Cada fila válida se normaliza a `DailyMetric`; cada fila o valor inválido queda reportado en `rejectedRows`.
- **Motivo:** evita adivinar columnas, fechas, unidades o valores fisiológicos provenientes de archivos externos.
- **Límites:** aún no interpreta las exportaciones completas de sueño ni otros datos categóricos de Apple Health; se añadirá un adaptador tras inspeccionar un archivo real y desidentificado.

## D-023 — Tendencias personales antes de scores globales

- **Estado:** CONFIRMED
- **Decisión:** calcular inicialmente tendencias deterministas por métrica contra un baseline personal robusto de mediana/MAD, antes de definir BioScore.
- **Reglas:** una tendencia usa solo observaciones anteriores al día evaluado; requiere cobertura y número de muestras mínimos; informa una razón explícita si faltan datos. Las fixtures simuladas solo pueden participar al habilitarlas explícitamente en pruebas. Las tendencias describen variación respecto al historial personal, no salud, diagnóstico, causalidad ni pronóstico.
- **Motivo:** entrega análisis explicable y verificable sin adelantar una fórmula de bienestar global aún no validada.

## D-024 — Contrato local de persistencia con control de revisión

- **Estado:** CONFIRMED
- **Decisión:** definir `BioPulseLocalStore` y una implementación en memoria para snapshots diarios, baselines y tendencias antes de elegir el motor físico de almacenamiento.
- **Reglas:** insertar un snapshot en un día ya ocupado produce un conflicto; reemplazarlo exige su identificador y revisión esperada. Esto evita sobrescribir silenciosamente datos de otra importación o fuente.
- **Pendiente:** implementar el adaptador físico local en macOS y decidir retención, borrado, migraciones y posible sincronización.

## D-025 — Dirección de la interfaz iOS

- **Estado:** CONFIRMED
- **Decisión:** usar el lenguaje visual oscuro y sereno del mockup aprobado, con un bosque nocturno decorativo en Hoy, acentos turquesa y cinco secciones: Hoy, Tendencias, Diario, Sueño y Perfil.
- **Referencia:** `docs/UI_DESIGN.md`.
- **Pendiente:** validar render, contraste y accesibilidad en Xcode y iPhone.

## D-026 — Ring BioScore honesto

- **Estado:** CONFIRMED
- **Decisión:** el ring del BioScore será visible desde Hoy y abrirá una explicación. Mientras la fórmula de bienestar general y sus entradas no estén validadas, mostrará un guion y un contorno neutro sin progreso numérico.
- **Motivo:** evita mostrar una puntuación o porcentaje inventado como si fuera el bienestar del usuario.

## D-027 — Primer puente de presentación con Apple Salud

- **Estado:** PROPOSED
- **Decisión provisional:** consultar directamente en el dispositivo las señales que la interfaz utiliza y mostrar el valor solo cuando HealthKit devuelva una muestra o suma. La vista de CSV será una revisión local sin persistencia.
- **Límite:** el código iOS y la configuración XcodeGen están escritos pero aún no compilados ni probados en Mac. Las tendencias históricas, el score numérico y la persistencia CSV quedan pendientes.

## D-028 — Alcance funcional obligatorio

- **Estado:** CONFIRMED
- **Decisión:** el producto objetivo debe incluir diario contextual, glosario y explicaciones de métricas, visualizaciones con contexto, BioScore, Sleep Score, registro y asociaciones de hábitos, respiración guiada, perfil y objetivos, mapa de energía, vista técnica, tendencias y previsiones descriptivas, resumen semanal y centro de privacidad/permisos.
- **Implicación:** estas funciones pueden dividirse por fases, pero no se consideran descartadas del producto.
- **Regla:** la ausencia de datos suficientes debe producir un estado honesto y explicable, no un valor inventado.

## D-029 — Coach BioPulse como pilar estratégico

- **Estado:** CONFIRMED
- **Decisión:** BioPulse tendrá un Coach basado en IA como capacidad estratégica. La conexión con un proveedor remoto como Groq se planificará después del núcleo local.
- **Arquitectura prevista:** proveedor de IA intercambiable, consentimiento explícito, minimización de datos, límites de uso, lenguaje no diagnóstico y fallback local.
- **Motivo de la secuenciación:** primero debemos estabilizar el modelo canónico, el diario, la calidad de datos y las explicaciones para que el Coach reciba contexto trazable.

## D-030 — Vista técnica obligatoria

- **Estado:** CONFIRMED
- **Decisión:** la vista técnica forma parte del producto y del alcance del concurso de ciencia de datos.
- **Regla:** solo mostrará datasets, variables, versiones, baselines, métodos de evaluación, métricas reproducibles y limitaciones identificables. Los valores hardcodeados de la interfaz anterior no se reutilizarán como evidencia.

## D-031 — Cuentas y sincronización cloud por fases

- **Estado:** CONFIRMED
- **Decisión:** toda persona debe iniciar sesión para abrir y usar BioPulse; no habrá modo invitado. El acceso requiere una sesión autenticada vigente.
- **Decisión de datos separada:** iniciar sesión no autoriza por sí solo la sincronización. La sincronización cloud se habilita con consentimiento por categoría.
- **Pendiente:** integrar y validar autenticación iOS, recuperación y borrado, configurar proveedores y completar el aviso de privacidad.
- **Regla:** HealthKit sigue siendo una fuente controlada por la persona; sus datos originales permanecen en el dispositivo por defecto.

## D-032 — Métodos de autenticación objetivo

- **Estado:** CONFIRMED
- **Decisión:** el registro e inicio de sesión admitirán Iniciar sesión con Apple, correo/contraseña y Google.
- **Backend propuesto:** Supabase Auth; falta crear/configurar el proyecto y validar proveedores.
- **Secuenciación:** preparar ahora esquema, migraciones y pruebas RLS. La integración Swift, deep links y pruebas de dispositivo requieren Xcode en macOS.

## D-033 — Límite de sincronización cloud

- **Estado:** CONFIRMED
- **Decisión:** los datos biométricos originales de HealthKit permanecerán locales por defecto. Perfil, diario, configuraciones y métricas derivadas podrán sincronizarse solo mediante consentimiento explícito y revocable.
- **Pendiente:** cifrado, retención, borrado, recuperación, resolución de conflictos y granularidad del consentimiento.

## D-034 — Alcance y seguridad del Coach IA

- **Estado:** CONFIRMED
- **Decisión:** el Coach podrá analizar métricas, tendencias y diario contextual únicamente con autorización explícita. Su alcance se limitará a BioPulse, educación sobre métricas y contexto personal relacionado.
- **Controles previstos:** proveedor intercambiable, contexto mínimo, allowlist de capacidades, separación de instrucciones y datos, herramientas cerradas, validación de entrada/salida, rate limiting, pruebas de prompt injection/jailbreak y fallback local.
- **Límite:** estos controles reducen riesgo, pero no permiten prometer inmunidad total a jailbreaks. El Coach no diagnosticará ni sustituirá atención médica.

## D-035 — Scores visibles desde el MVP

- **Estado:** CONFIRMED
- **Decisión:** BioScore y Sleep Score tendrán un lugar visible desde el MVP.
- **Regla:** hasta disponer de fórmulas, entradas y datos reales validados, mostrarán estado pendiente y explicación, no una puntuación demo presentada como personal.

## D-036 — Funciones pospuestas

- **Estado:** CONFIRMED
- **Decisión:** Risk Score, modo Live e integraciones directas con Fitbit, Whoop, Garmin y Oura quedan para una fase futura.
- **Implicación:** no condicionarán la arquitectura ni el alcance del primer MVP.

## D-037 — Diario como sección principal

- **Estado:** CONFIRMED
- **Decisión:** el Diario tendrá una pestaña propia entre Tendencias y Sueño. No quedará escondido dentro de Perfil porque aporta contexto transversal a métricas, asociaciones, resumen semanal y Coach.
- **Implementación actual:** la pestaña permite cargar, crear, editar y eliminar hábitos, síntomas y eventos. Las entradas se validan en el dominio, se guardan en un JSON local con escritura atómica y protección completa en iOS, y usan revisiones para evitar sobrescrituras silenciosas.
- **Límite:** la persistencia no se ha compilado ni validado todavía en un dispositivo iOS. El Diario no infiere asociaciones ni causalidad; por ahora solo conserva el contexto registrado por la persona.

## D-038 — Navegación inicial de funciones obligatorias

- **Estado:** PROPOSED
- **Decisión provisional:** Hoy aloja BioScore, mapa de energía y respiración; Tendencias conduce a resumen semanal y vista técnica; Sueño aloja Sleep Score; Perfil agrupa cuenta, sincronización, privacidad y permisos; el Coach usa un acceso flotante global.
- **Pendiente:** validar jerarquía, tamaños táctiles y Dynamic Type en iPhone con Xcode.

## D-039 — Autenticación obligatoria y datos aislados por cuenta

- **Estado:** CONFIRMED
- **Decisión:** la app solo puede utilizarse con una sesión de cuenta autenticada. No habrá modo invitado. La identidad requerida no activa automáticamente la sincronización cloud.
- **Datos locales:** separar almacenamiento y cachés por el identificador estable de cuenta; al cerrar sesión, una cuenta no debe ver datos locales de otra.
- **Seguridad de base de datos:** cada fila privada pertenece a `auth.users.id`; RLS exige `auth.uid() = user_id` (o `id` para `profiles`). El rol `anon` no recibe permisos en las tablas privadas.
- **Referencia:** migraciones y prueba RLS en `supabase/`.

## D-040 — Cliente de autenticación iOS

- **Estado:** CONFIRMED
- **Decisión:** la app usa Supabase Auth mediante el SDK Swift fijado a la versión 2.49.0; incorpora correo/contraseña, Apple con nonce, Google OAuth, confirmación, recuperación y cierre de sesión. La puerta de navegación espera a que se resuelva la sesión.
- **Seguridad:** solo URL y clave publishable en la app; nunca `service_role`. Iniciar sesión no concede consentimiento de sincronización.
- **Datos locales:** el Diario escribe bajo `Application Support/BioPulse/Accounts/<user_id>/`; el archivo anterior sin cuenta no se importa automáticamente. La identidad de usuario fuerza recrear el controlador.
- **Pendiente:** compilar/probar en Mac y configurar/validar SMTP, redirects y proveedores OAuth en Supabase y Apple Developer.

## D-041 — Bootstrap de datos mínimos al crear cuenta

- **Estado:** CONFIRMED
- **Decisión:** un trigger `SECURITY DEFINER` en esquema privado crea perfil vacío y preferencias por defecto al insertarse una identidad en `auth.users`.
- **Límites:** no copia metadata del proveedor, datos de salud ni consentimiento. La función fija `search_path`, limita privilegios y evita duplicados.
- **Verificación:** migración `20261014000200` aplicada local y remotamente; suite pgTAP local 28/28.

## D-042 — Coach IA con Groq, consentimiento y memoria efímera

- **Estado:** CONFIRMED
- **Proveedor y acceso:** Groq se invoca desde una Supabase Edge Function autenticada; la clave nunca forma parte de la app. La elección final del modelo es configurable y se hará con pruebas de calidad/coste.
- **Contexto:** el usuario autoriza una vez, antes del primer envío, el uso de métricas derivadas, tendencias y contexto del Diario. No se envían muestras originales de HealthKit. El consentimiento del Coach es independiente del consentimiento de sincronización y revocable.
- **Conversación y memoria:** la UI conserva solo la conversación activa en memoria local; el backend no persiste el transcript. Una memoria resumida y no visible puede permanecer hasta siete días desde su actualización, se elimina por acción del usuario/revocación y se purga por cron aproximadamente dentro de una hora del vencimiento.
- **Seguridad funcional:** español, tono neutral sencillo, temas de bienestar relacionados con la app; sin diagnósticos ni tratamiento médico. Respuestas sobre síntomas graves redirigen a atención profesional/urgente. La memoria y el contexto son datos no confiables; no se habilitan herramientas de modelo.
- **Límites:** endpoint valida sesión, cuerpo y esquema de contexto; cuota diaria atómica inicial de 20 solicitudes por cuenta, configurable entre 1 y 100.
- **Verificado:** migración `20261014000300` aplicada local y remotamente; suite pgTAP local 39/39; Edge Function inicia localmente y responde 401 sin JWT.
- **Implementado en código:** autorización única, conversación efímera, revocación/borrado de memoria y cliente iOS para la Edge Function; todavía sin compilación en Mac.
- **Verificado:** la función vuelve a arrancar localmente después de los cambios y rechaza una llamada sin sesión (401).
- **Actualización 15-10-2026:** la función está desplegada; `GROQ_API_KEY` y `GROQ_MODEL` figuran configurados como secretos remotos (sus valores no se exponen). Pasaron 10 pruebas unitarias de política y una prueba HTTP local autenticada de consentimiento, respuesta urgente, borrado de memoria y revocación sin invocar Groq. Sigue pendiente validar una respuesta real de Groq y el flujo completo en iPhone.

## D-043 — Profundidad visual y movimiento accesible

- **Estado:** CONFIRMED
- **Decisión:** ampliar el sistema nocturno de bosque y menta con superficies opacas iluminadas, sombras suaves y componentes con relieve; reservar el material translúcido para el acceso contextual del Coach. Lavanda diferencia Sueño; las líneas topográficas son decoración y nunca codifican una medición.
- **Jerarquía:** Hoy destaca sueño, HRV, movimiento y contexto del Diario. BioScore y Sleep Score conservan su explicación visible, pero pasan a segundo plano mientras no tengan cálculo validado. Ninguna gráfica, anillo o cifra decorativa se presenta como dato fisiológico.
- **Movimiento:** las transiciones breves acompañan foco, pulsación, aparición y cambio de valor. El fondo permanece quieto. Reducir movimiento elimina el desplazamiento y ralentiza la sesión respiratoria. Los gestos de navegación y las hojas siguen el comportamiento nativo.
- **Accesibilidad:** Dynamic Type reorganiza las señales en pantallas estrechas o texto grande; VoiceOver recibe anuncios de estado; controles interactivos mantienen al menos 44 puntos de área táctil; Reducir transparencia usa fondos sólidos.
- **Autenticación:** campos compartidos con foco de teclado, mostrar/ocultar contraseña, confirmación dedicada y reenvío de registro con enfriamiento visual de 60 segundos. La recuperación de contraseña reutiliza los mismos campos accesibles.
- **Diario:** el formulario permanece abierto si la escritura local falla o entra en conflicto. El aviso, anuncio VoiceOver y háptica de éxito solo aparecen tras confirmar la persistencia y cerrar la hoja.
- **Pendiente de verificación:** compilar con Xcode y revisar render, foco y VoiceOver en Mac; los cambios actuales se inspeccionaron mediante análisis sintáctico Swift, pero aún no se han renderizado en iOS.

## D-044 — Sincronización por categoría y agregados diarios

- **Estado:** CONFIRMED para backend; PROPOSED para integración iOS.
- **Decisión:** identidad obligatoria no implica subida. Perfil, ajustes, Diario y métricas derivadas tienen consentimiento independiente. El backend acepta solo agregados diarios con unidad, calidad y procedencia; nunca muestras HealthKit originales. Revocar bloquea nuevas escrituras y deja borrado remoto como acción separada.
- **Verificación:** migraciones `20261015000100` y `20261015000300` aplicadas local y remotamente; suite pgTAP local 67/67.

## D-045 — ML de dos familias con resultados bloqueados

- **Estado:** CONFIRMED para auditoría y código de investigación; UNKNOWN para validez predictiva.
- **Decisión:** separar eventos de riesgo/anomalía/enfermedad de resultados futuros de sueño, recuperación y rendimiento. No publicar modelos ni scores clínicos sin etiqueta independiente, licencia, consentimiento, corte temporal, sujetos no vistos y validación externa.
- **Verificación:** CSV heredado auditado sin modificación (100.000 filas, 286 sujetos, sin etiqueta clínica); 3 pruebas de contrato ML pasan. Los AUC heredados no son evidencia clínica.

## D-046 — Operaciones privadas sin datos de salud

- **Estado:** CONFIRMED para código, despliegue y configuración del UUID; sesión real del propietario pendiente de prueba.
- **Decisión:** panel web local, autenticación de cuenta y allowlist exacta de UUID en secreto de servidor. Solo seis contadores globales; ninguna fila sanitaria ni identidad se devuelve al navegador. Sin `ADMIN_USER_ID`, denegar a todos.
- **Verificación:** migración `20261015000200` aplicada local y remotamente, endpoint desplegado, `ADMIN_USER_ID` configurado en secretos, 67/67 pruebas pgTAP y respuesta 401 sin JWT en remoto. La UI compila; no se ha probado sesión real del propietario.

## D-047 — Expansión de producto: landing, contexto personal y personalización

- **Estado:** CONFIRMED para implementación de MVP local; Xcode/QA de iOS pendiente. Apple Watch continúa FUTURE.
- **Decisión:** convertir en producto las ocho ideas de landing y las vistas locales de comparación descriptiva, gráfica con anotaciones, timeline, check-in subjetivo, experimentación personal, estados sin datos, educación contextual, resúmenes semanal/compartible y preferencias flexibles.
- **Privacidad:** check-ins, anotaciones, experimentos y preferencias se guardan por usuario en archivo local con protección de archivo iOS; no se sincronizan por login. La exportación requiere selección explícita y previsualización. Notificaciones son opt-in y contienen texto genérico, sin valores de salud.
- **Evidencia y límites:** comparaciones solo usan muestras agregadas disponibles, excluyen días vacíos y exigen cobertura mínima; anotaciones se marcan en el tiempo, sin causalidad. El progreso no usa rachas ni sanciona descanso. Landing no captura correos ni afirma que el ML/Watch estén disponibles.
- **Verificación:** JavaScript y referencias HTML revisados; controles interactivos y navegación probados en navegador móvil/escritorio. Swift pasó análisis sintáctico local, pero no hubo SDK de Apple/Xcode para compilar o ejecutar la app ni sus pruebas. Esta limitación debe resolverse antes de llamar la expansión iOS lista para usuarios.

## D-048 — Home futuro con color semántico por score

- **Actualización 15-10-2026:** el usuario confirmó el último ajuste del grid: todas las tarjetas tienen igual ancho en dos columnas; Esfuerzo solo es más alta. El mockup definitivo de «Hoy» está en `design-explorations/2026-10-15-app-flow/01-hoy.png`. Las otras cuatro pestañas son propuestas visuales en esa misma carpeta, no implementaciones aprobadas.
- **Estado:** CONFIRMED para dirección visual; PROPOSED para implementación y mapa cromático exacto; UNKNOWN para validez de sub-scores.
- **Decisión:** usar el mosaico asimétrico seleccionado por el usuario, con BioScore en anillo orgánico como foco. Fondo, navegación y Coach IA quedan neutros blancos/plata sobre carbón. Cada visualización biométrica toma color de su propio score favorable normalizado: rojo cerca de 0, amarillo en 50 y verde BioPulse en 100, con matices graduales incluso ante cambios de ~2 puntos.
- **Seguridad de interpretación:** puntuación y estado textual acompañan al color. La ausencia de datos permanece neutral. HRV, FC, sueño, actividad y esfuerzo no heredan color directamente de valores brutos ni se califican clínicamente sin una transformación individual validada. Las cifras y curvas del mockup final son simuladas.
- **Referencia:** `design-explorations/2026-10-15-final/README.md` y `design-explorations/2026-10-15-final/biopulse-home-semantic-colors.png`. No se han modificado vistas SwiftUI ni validado el render en iOS.

## D-049 — Implementación visual de las cinco pestañas

- **Estado:** CONFIRMED para código y fuentes de datos; UNKNOWN para compilación/render iOS.
- **Decisión:** aplicar la dirección del mockup a Hoy, Tendencias, Diario, Sueño y Perfil ahora. La tarjeta alta del home es energía activa registrada por hora, no «esfuerzo» inferido. La FC principal es frecuencia en reposo. HRV muestra la media de las muestras del día. Los datos faltantes muestran guiones o estados vacíos.
- **Scores:** BioScore, Sleep Score y subscores no se calculan ni muestran como cifras hasta construir y validar sus algoritmos. El interpolador cromático continuo queda preparado, pero ningún valor bruto recibe un juicio rojo/verde.
- **Visual:** carbón y blanco para fondo, navegación y Coach IA; anillo decorativo orgánico con Reduce Motion; tarjetas de igual ancho en dos columnas y la de energía activa doble de alta. Gráficas solo con agregados o intervalos observados. El check-in del Diario se identifica como dato subjetivo.
- **Verificación:** los archivos Swift afectados pasan `swiftc -frontend -parse` en Windows. `swift test` no puede cargar el manifiesto por una instalación incompleta del SDK C de Swift para Windows (`stdlib.h` ausente); no equivale a error demostrado del código iOS. Compilación en Xcode y QA en iPhone pendientes.

## D-050 — Web de cuenta obligatoria y puente Health Auto Export

- **Estado:** CONFIRMED para implementación local, compilación, pruebas, migración remota `20261015000400` y despliegue remoto de `health-bridge` (`verify_jwt = false`); UNKNOWN para login de propietario, despliegue Vercel y POST real desde iPhone.
- **Decisión:** una sola web Vite/React sirve landing y `/app`; el producto exige sesión Supabase y reproduce la dirección visual de las cinco pestañas iOS y el Coach. Web y Swift comparten fuentes de datos cuando están sincronizadas, pero no componentes ni ejecución de código Swift; los cambios visuales futuros requieren implementarse en ambas plataformas.
- **Privacidad:** consentimiento separado para agregados diarios y energía por hora. Health Auto Export envía JSON a una función con token revocable; la base guarda hash del token y solo agregados canónicos. No hay importación CSV/XML web ni muestras HealthKit originales. El Diario web tiene consentimiento independiente.
- **Límites:** sueño agregado no permite reconstruir intervalos exactos; BioScore y Sleep Score permanecen vacíos hasta validación. El estado de sincronización muestra fecha real, no promete actualización continua. La landing no anuncia descarga iOS disponible.
- **Verificación:** `npm run build`, `npm test`, `npm audit` sin vulnerabilidades y `deno check` pasaron en la fase de implementación; en la sesión de publicación no estaba disponible el ejecutable `deno`, pero se repitieron build, tests y las 80 pruebas pgTAP. Landing y acceso obligatorio revisados en navegador, escritorio y 375 px. La prueba HTTP local completó autenticación, consentimientos, importación sintética, idempotencia, bloqueo de datos sin permiso, revocación y borrado. La migración remota figura aplicada, la función figura activa y una petición remota sin sesión devuelve `401 {"error":"unauthorized"}`. POST real de iPhone pendiente.
- **Actualización 2026-10-17:** `https://biopulse-20.vercel.app/` responde HTTP 200 y muestra la web 2.0. El usuario informó que el login y un envío real desde iPhone funcionan; la verificación independiente de ese flujo sigue pendiente. El commit `10d2474` se desplegó mediante la integración GitHub–Vercel; el sitio público sirve `personal-v1`.

## D-051 — Índices personales exploratorios `personal-v1`

- **Estado:** CONFIRMED para implementación web/iOS y pruebas web; UNKNOWN para utilidad y validación clínica. El usuario confirmó que el puente real desde iPhone funciona; la paridad con datos reales entre plataformas sigue sin probarse.
- **Decisión:** Sleep Score (duración y constancia), BioScore (sueño, recuperación, actividad) y señal de cambio personal. Solo datos observados e historial previo suficiente. El cálculo ocurre en el cliente; no se persiste una cifra derivada. La referencia y las salidas están versionadas y explicadas en `docs/SCORE_ALGORITHMS.md`.
- **ML:** el entrenamiento de investigación compara predictor trivial, regresión regularizada/logística y boosting con separación por usuario/tiempo. Sin etiquetas independientes no se entrena ni despliega un modelo real. La señal de cambio no expresa riesgo de enfermedad.
- **Verificación:** `npm run build`, `npm test` (10 pruebas), 4 pruebas del contrato ML y análisis sintáctico Swift pasaron en Windows. `swift test` sigue bloqueado por `stdlib.h` ausente en el SDK Swift para Windows; compilar y probar en Xcode antes de publicar la versión iOS.

## D-052 — PMData como benchmark externo de investigación

- **Estado:** CONFIRMED para descarga de subconjunto del archivo oficial, adaptación temporal y evaluación; UNKNOWN para permiso comercial inequívoco y generalización a Apple Watch.
- **Decisión:** no activar un modelo entrenado. Sobre 1.268 pares día→readiness del día siguiente de 16 personas, el holdout fijo incluyó 482 filas de 12 personas antes del 2020-01-15 y 199 filas de cuatro personas no vistas desde esa fecha. MAE: predictor mediano 1,4824; regresión lineal 1,7064; boosting 2,0065. La persistencia de readiness anterior dio MAE 1,4824. Los candidatos no mejoraron las referencias.
- **Fuente:** [PMData de Simula](https://datasets.simula.no/pmdata/), Fitbit Versa 2 y autorreporte PMSys. La página actual indica CC BY 4.0, mientras el [artículo original](https://web-backend.simula.no/sites/default/files/publications/files/3339825.3394926.pdf) indica CC BY-NC 4.0; resolver antes de cualquier reutilización comercial. No hay participantes Apple Watch ni etiqueta de enfermedad.
- **Límites:** un solo holdout pequeño; cuatro de las siete features del contrato no estaban disponibles; ninguna prueba de eficacia clínica ni de utilidad para usuarios iOS. Detalles y comandos en `ml/ACTIVATION_REVIEW_2026-10-17.md`.

## D-053 — Proyecto Xcode versionado y compilación en CI macOS

- **Estado:** CONFIRMED para generación del proyecto, compilación iOS sin firma y pruebas Swift; UNKNOWN para firma, instalación y funcionamiento en el iPhone del usuario.
- **Decisión:** versionar `BioPulse/BioPulse.xcodeproj` junto con `project.yml` para que una descarga del repositorio pueda abrirse directamente en Xcode sin Homebrew ni XcodeGen local. El workflow manual `.github/workflows/ios-project.yml` regenera el proyecto en macOS y verifica build de simulador, `swift test` y build de dispositivo sin firma.
- **Verificación:** [run 39053219208](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39053219208) con Xcode 26.6: ambos builds correctos y 26 pruebas Swift aprobadas. El proyecto generado coincide byte por byte con el versionado.
- **Siguiente puerta:** elegir Apple Team en Xcode y probar instalación, HealthKit, cuenta, render y flujos críticos en iPhone. Un build de dispositivo sin firma no cubre esa puerta.
- **Corrección 2026-10-17:** el primer `.xcodeproj` versionado referenciaba `BioPulse/Info.plist`, pero XcodeGen lo creaba solo en CI y el archivo faltaba en la descarga. Se versionó el `Info.plist` generado. El [run 39056797219](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39056797219) compiló el proyecto desde un checkout limpio antes de ejecutar XcodeGen, comprobó que la generación no altera los archivos versionados, pasó 26 pruebas y compiló para dispositivo sin firma. La puerta de firma/instalación física sigue UNKNOWN.
