# BioPulse 2.0 para iOS

Este directorio contiene la interfaz SwiftUI, una primera lectura real de Apple Salud, el paquete de dominio y una especificación de proyecto para XcodeGen. El código iOS aún no se ha compilado ni ejecutado: esa comprobación requiere una Mac con Xcode.

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
- La URL y clave publishable del proyecto Supabase están configuradas en `project.yml`; nunca debe añadirse una clave `service_role` a la app.
- Apple Salud: solicita acceso de lectura solo para las señales utilizadas por la interfaz; muestra muestras recibidas o ausencia explícita. El permiso de lectura no puede confirmarse directamente mediante HealthKit.
- Hoy: presenta HRV, sueño y pasos observados, con detalle y procedencia. El BioScore permanece sin número porque aún no existe una fórmula validada.
- Tendencias: muestra las mediciones actuales; el historial y la referencia personal todavía no están conectados a esta vista.
- Sueño: suma las etapas dormidas registradas durante la noche y evita intervalos superpuestos.
- Perfil: permite actualizar mediciones, abrir Ajustes y revisar localmente un CSV tidy/wide. Esta revisión no persiste el archivo ni incorpora sus registros al dashboard.
- Diario: guarda hábitos, síntomas y eventos exclusivamente en el dispositivo. Las entradas admiten crear, editar, eliminar y recargar; las revisiones impiden sobrescrituras silenciosas dentro del repositorio local. Aún falta validarlo en un iPhone con Xcode.

## Siguiente paso en macOS

1. Instalar Xcode y XcodeGen; ejecutar `xcodegen generate` desde este directorio.
2. Abrir `BioPulse.xcodeproj`, resolver el paquete `supabase-swift`, seleccionar un equipo de firma y confirmar las capacidades HealthKit y Sign in with Apple.
3. Configurar y probar en Supabase la confirmación por correo/SMTP, las URLs de retorno, Apple y Google (sus claves no se guardan en este repositorio).
4. Compilar en iOS 17+, probar inicio/registro/callback/recuperación/cierre y cambio entre dos cuentas; verificar permisos, Dynamic Type y VoiceOver.
5. Validar lecturas reales con el Apple Watch Ultra de prueba y con al menos un modelo distinto cuando esté disponible.

## Verificación actual

En Windows, `swift test` sigue bloqueado por la configuración de SDK C/C++ descrita anteriormente. En este entorno `swiftc` tampoco llegó a iniciar la comprobación sintáctica. No se afirma compilación ni funcionamiento en dispositivo hasta verificarlos en Mac.
