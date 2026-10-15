# BioPulse 2.0 para iOS

Este directorio contiene la interfaz SwiftUI, una primera lectura real de Apple Salud, el paquete de dominio y una especificación de proyecto para XcodeGen. La app ya se abrió en el simulador del usuario; los cambios posteriores todavía requieren una nueva compilación en la Mac.

## Archivos iniciales

- `Sources/App`: cuatro secciones navegables (`Hoy`, `Tendencias`, `Sueño`, `Perfil`), detalle de señales, ring BioScore sin cifra no validada, estados vacíos y lectura local de Apple Salud.
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
- `Sources/App/AuthSessionStore.swift` y `AuthView.swift`: sesión obligatoria de Supabase Auth, correo/contraseña, Apple, Google, recuperación de contraseña y manejo de callback.

## Estado funcional

- **Autenticación implementada en código, no validada en Mac:** no se monta la app hasta que Supabase restaura o emite una sesión. Incluye correo/contraseña, Apple, Google, confirmación de registro, recuperación y cierre de sesión. Apple/Google requieren configuración de proveedores y credenciales en Supabase; Apple también requiere firma/capacidad en Apple Developer.
- **Aislamiento local implementado para el Diario:** el archivo nuevo usa una carpeta por UUID de usuario. El archivo antiguo sin ámbito no se carga ni se borra automáticamente.
- La URL y clave publishable del proyecto Supabase están configuradas en el `Info.plist` generado desde `project.yml`; nunca debe añadirse una clave `service_role` a la app.
- Apple Salud: solicita acceso de lectura solo para las señales utilizadas por la interfaz; muestra muestras recibidas o ausencia explícita. El permiso de lectura no puede confirmarse directamente mediante HealthKit.
- Hoy: presenta HRV, sueño y pasos observados, con detalle y procedencia. El BioScore permanece sin número porque aún no existe una fórmula validada.
- Tendencias: muestra las mediciones actuales; el historial y la referencia personal todavía no están conectados a esta vista.
- Sueño: suma las etapas dormidas registradas durante la noche y evita intervalos superpuestos.
- Perfil: permite actualizar mediciones, abrir Ajustes y revisar localmente un CSV tidy/wide. Esta revisión no persiste el archivo ni incorpora sus registros al dashboard.
- Diario: guarda hábitos, síntomas y eventos exclusivamente en el dispositivo. Las entradas admiten crear, editar, eliminar y recargar; las revisiones impiden sobrescrituras silenciosas dentro del repositorio local. Aún falta validarlo en un iPhone con Xcode.

## Actualizar la copia de macOS

1. Descargar la versión actualizada del repositorio o actualizar la copia local.
2. Desde la carpeta `BioPulse` que contiene `project.yml`, ejecutar `xcodegen generate` y abrir `BioPulse.xcodeproj` generado. Regenerar el proyecto restablece cambios hechos solamente en la interfaz de Xcode; la configuración necesaria ya está en `project.yml`.
3. Seleccionar un simulador de iPhone y ejecutar la app con ⌘R. Comprobar que el título y los campos de acceso no se recortan a los lados.

## Confirmación de correo en Supabase remoto

El callback de la app es `biopulse://auth-callback`. Está registrado en `Info.plist` y el cliente lo envía explícitamente al registrar una cuenta y al recuperar la contraseña. `supabase/config.toml` configura el proyecto **local**; no cambia automáticamente el proyecto alojado.

En el panel del proyecto `ielprdmmuocajtbimvdx`, abrir **Authentication → URL Configuration**:

1. Configurar **Site URL** como `biopulse://auth-callback`.
2. Añadir `biopulse://auth-callback` a **Redirect URLs** y guardar. Usar la URL exacta, sin comodines.
3. En **Authentication → Email Templates → Confirm signup** comprobar que el enlace usa `{{ .ConfirmationURL }}`. Si se ha creado una plantilla personalizada que usa `{{ .SiteURL }}`, adaptarla para respetar `{{ .RedirectTo }}` según la [documentación de Supabase](https://supabase.com/docs/guides/auth/redirect-urls#email-templates-when-using-redirectto). Revisar también la plantilla de recuperación si fue personalizada.

Pedir un **correo nuevo** tras guardar la configuración: un mensaje enviado antes conserva su enlace anterior. Abrirlo en el mismo iPhone donde esté instalada BioPulse; una instalación en el simulador no puede abrirse desde Safari de otro teléfono. Si el enlace anterior confirmó la cuenta antes de llegar a localhost, intentar primero iniciar sesión con esa cuenta.

Apple y Google requieren además la configuración de sus proveedores en Supabase y, para Apple, firma y capacidad en Apple Developer. Probar registro, callback, recuperación, cierre y cambio entre dos cuentas en iOS 17+; después verificar Dynamic Type, VoiceOver y lecturas reales de Apple Salud.

## Verificación actual

En Windows no es posible compilar esta interfaz para iOS ni capturar el simulador. La compilación y apertura anteriores fueron reportadas por el usuario; los cambios actuales de diseño y configuración aún deben comprobarse en la Mac.
