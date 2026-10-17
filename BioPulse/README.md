# BioPulse 2.0 para iOS

Este directorio contiene la interfaz SwiftUI, una primera lectura real de Apple Salud, el paquete de dominio y una especificación de proyecto para XcodeGen. La app ya se abrió en el simulador del usuario; los cambios posteriores todavía requieren una nueva compilación en la Mac.

## Archivos iniciales

- `Sources/App`: cinco secciones navegables (`Hoy`, `Tendencias`, `Diario`, `Sueño`, `Perfil`), pantalla de acceso, Coach, detalle y procedencia de señales, estados vacíos y lectura local de Apple Salud.
- `Resources/Assets.xcassets/ForestNight.imageset`: fondo nocturno del inicio; recurso decorativo, sin datos de salud.
- `project.yml`: especificación reproducible del proyecto iOS 17 para XcodeGen.
- `Sources/HealthKit/HealthMetric.swift`: catálogo tipado de métricas y estados de capacidad.
- `Sources/HealthKit/HealthKitCapabilityCatalog.swift`: mapea métricas a tipos HealthKit y evita confundir permiso denegado con ausencia de datos.
- `Package.swift` y `Sources/BioPulseDomain`: paquete Foundation-only con contratos de métricas diarias, calidad, procedencia y baseline personal robusto.
- `Tests/BioPulseDomainTests`: pruebas Swift Testing; los valores incluidos están marcados explícitamente como datos simulados de prueba.
- `Sources/BioPulseDomain/CSVImporter.swift`: importador local de CSV para los contratos tidy y wide, con reporte de columnas no mapeadas, advertencias y filas rechazadas.
- `Sources/BioPulseDomain/MetricTrend.swift`: tendencias deterministas contra el baseline personal, con cobertura y razones explícitas cuando no hay datos suficientes.
- `Sources/BioPulseDomain/LocalPersistence.swift`: contrato local de persistencia e implementación temporal en memoria, con conflictos y revisiones para snapshots diarios.
- `Sources/BioPulseDomain/ContextJournal.swift`: dominio y repositorios del Diario; valida entradas, conserva procedencia y revisiones, y persiste JSON local de forma atómica con protección completa en iOS.
- `Sources/App/JournalController.swift` y `JournalView.swift`: pestaña Diario con carga, creación, edición, eliminación, estados de espera/error y actualización manual.
- `Sources/App/AuthSessionStore.swift` y `AuthView.swift`: sesión obligatoria de Supabase Auth, correo/contraseña, Apple, Google, confirmación de correo con reenvío, recuperación con campos accesibles y manejo de callback.

## Estado funcional

- **Autenticación:** no se monta la app hasta que Supabase restaura o emite una sesión. Incluye correo/contraseña, Google, confirmación de registro, recuperación y cierre de sesión. El botón y la capacidad de Sign in with Apple están temporalmente desactivados para permitir firma en un Personal Team; para reactivarlos, habilitar `appleSignInEnabled` en `AuthView.swift` y añadir `com.apple.developer.applesignin: [Default]` a `project.yml`, además de configurar el proveedor en Supabase y firmar con un equipo compatible.
- **Pantalla de acceso:** fondos de bosque, superficies iluminadas y campos de contraseña que permiten mostrar u ocultar el contenido. Tras registrarte puedes reenviar el enlace de confirmación cada 60 segundos y volver al acceso. La pantalla no afirma que tu cuenta esté confirmada antes de recibir la sesión.
- **Aislamiento local implementado para el Diario:** el archivo nuevo usa una carpeta por UUID de usuario. El archivo antiguo sin ámbito no se carga ni se borra automáticamente.
- La URL y clave publishable del proyecto Supabase están configuradas en el `Info.plist` generado desde `project.yml`; nunca debe añadirse una clave `service_role` a la app.
- Apple Salud: solicita acceso de lectura solo para las señales utilizadas por la interfaz; muestra muestras recibidas o ausencia explícita. El permiso de lectura no puede confirmarse directamente mediante HealthKit.
- Hoy: destaca BioScore exploratorio para el último día completo cuando hay historial suficiente, más sueño, HRV, pasos y contexto del Diario. Fórmula y límites en `docs/SCORE_ALGORITHMS.md`.
- Tendencias: muestra mediciones e historial y una señal de cambio personal que exige persistencia en varias métricas; no expresa probabilidad de enfermedad.
- Sueño: suma intervalos dormidos sin duplicar superposiciones y calcula un Sleep Score exploratorio de duración y constancia si hay al menos siete noches previas. La meta personal se guarda por cuenta en este iPhone.
- Perfil: permite actualizar mediciones, abrir Ajustes y revisar localmente un CSV tidy/wide. Esta revisión no persiste el archivo ni incorpora sus registros al dashboard.
- Diario: guarda hábitos, síntomas y eventos exclusivamente en el dispositivo. Las entradas admiten crear, editar, eliminar y recargar; las revisiones impiden sobrescrituras silenciosas dentro del repositorio local. Aún falta validarlo en un iPhone con Xcode.

## Actualizar la copia de macOS

1. Descargar la versión actualizada del repositorio o actualizar la copia local.
2. Desde la carpeta `BioPulse` que contiene `project.yml`, ejecutar `xcodegen generate` y abrir `BioPulse.xcodeproj` generado. Regenerar el proyecto restablece cambios hechos solamente en la interfaz de Xcode; la configuración necesaria ya está en `project.yml`.
3. Seleccionar un simulador de iPhone y ejecutar la app con ⌘R. Comprobar que el título y los campos de acceso no se recortan a los lados.

## Confirmación de correo en Supabase remoto

El registro por correo vuelve a una URL pública de BioPulse en `https://ielprdmmuocajtbimvdx.supabase.co/functions/v1/confirm-email`. Muestra un mensaje sencillo en el navegador del celular: Supabase Edge Functions entrega HTML como texto plano, por lo que no se usa una página HTML. Así se puede confirmar desde un celular personal y luego iniciar sesión en el simulador, sin configurar el correo allí. Google y la recuperación de contraseña siguen usando `biopulse://auth-callback` para regresar a la app. El esquema está registrado en el `Info.plist` generado. `supabase/config.toml` configura el proyecto **local**; no cambia automáticamente el proyecto alojado.

El proyecto remoto `ielprdmmuocajtbimvdx` ya tiene la **Site URL** configurada con esa URL HTTPS. En **Authentication → URL Configuration** están permitidas exactamente esa URL y `biopulse://auth-callback`; se comprobó que las demás propiedades remotas no cambiaron. Si una plantilla de **Authentication → Email Templates → Confirm signup** se personalizó y todavía manda a otra URL, comprobar que utiliza `{{ .ConfirmationURL }}` o respeta `{{ .RedirectTo }}` según la [documentación de Supabase](https://supabase.com/docs/guides/auth/redirect-urls#email-templates-when-using-redirectto).

Pedir un **correo nuevo** desde la nueva versión de la app: un mensaje enviado antes conserva su enlace anterior. Abrirlo en el celular personal; debe mostrar el mensaje «Ya abriste el enlace de verificación». Después, volver al simulador e iniciar sesión con el mismo correo y contraseña. Si el enlace anterior confirmó la cuenta antes de llegar a localhost, intentar primero iniciar sesión con esa cuenta.

Apple y Google requieren además la configuración de sus proveedores en Supabase y, para Apple, firma y capacidad en Apple Developer. Probar registro, callback, recuperación, cierre y cambio entre dos cuentas en iOS 17+; después verificar Dynamic Type, VoiceOver y lecturas reales de Apple Salud.

## Verificación actual

En Windows no es posible compilar esta interfaz para iOS ni capturar el simulador. La compilación y apertura anteriores fueron reportadas por el usuario; los cambios actuales de diseño y configuración aún deben comprobarse en la Mac.
