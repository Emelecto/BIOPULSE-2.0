# BioPulse 2.0 para iOS

Este directorio contiene la interfaz SwiftUI, una primera lectura real de Apple Salud, el paquete de dominio y un proyecto de Xcode listo para abrir. `BioPulse.xcodeproj` está incluido en el repositorio; no necesitas Homebrew ni XcodeGen para abrir esta versión.

## Archivos iniciales

- `Sources/App`: cinco secciones navegables (`Hoy`, `Tendencias`, `Diario`, `Sueño`, `Perfil`), pantalla de acceso, Coach, detalle y procedencia de señales, estados vacíos y lectura local de Apple Salud.
- `Resources/Assets.xcassets/ForestNight.imageset`: fondo nocturno del inicio; recurso decorativo, sin datos de salud.
- `project.yml`: especificación reproducible del proyecto iOS 17 para XcodeGen.
- `BioPulse.xcodeproj`: proyecto generado y versionado para abrir directamente en Xcode.
- `Info.plist`: configuración de la app que Xcode necesita al compilar; debe permanecer junto a `BioPulse.xcodeproj`.
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

## Abrir en la Mac

1. Descargar la versión más reciente de la rama `main` o actualizar la copia local; un ZIP descargado antes de la inclusión de `BioPulse.xcodeproj` no lo tendrá.
2. Descomprimir el ZIP y abrir `BioPulse/BioPulse.xcodeproj` con Xcode. No hace falta ejecutar comandos.
3. Para probar en tu iPhone: conectar y desbloquear el dispositivo, seleccionarlo como destino, abrir el target **BioPulse → Signing & Capabilities**, elegir tu **Team** y pulsar **Run** (⌘R). Si Xcode indica que el identificador del paquete ya está ocupado para tu equipo, cambiarlo allí antes de repetir Run.
4. Si prefieres el simulador, seleccionar uno de iPhone y pulsar ⌘R. Revisar navegación y que el texto de acceso no se recorte.

Solo hace falta regenerar el proyecto con XcodeGen si cambias `project.yml` o agregas archivos que requieran modificar la estructura del proyecto. En ese caso, vuelve a versionar el `.xcodeproj` generado.

## Confirmación de correo en Supabase remoto

El registro por correo vuelve a una URL pública de BioPulse en `https://ielprdmmuocajtbimvdx.supabase.co/functions/v1/confirm-email`. Muestra un mensaje sencillo en el navegador del celular: Supabase Edge Functions entrega HTML como texto plano, por lo que no se usa una página HTML. Así se puede confirmar desde un celular personal y luego iniciar sesión en el simulador, sin configurar el correo allí. Google y la recuperación de contraseña siguen usando `biopulse://auth-callback` para regresar a la app. El esquema está registrado en el `Info.plist` generado. `supabase/config.toml` configura el proyecto **local**; no cambia automáticamente el proyecto alojado.

El proyecto remoto `ielprdmmuocajtbimvdx` ya tiene la **Site URL** configurada con esa URL HTTPS. En **Authentication → URL Configuration** están permitidas exactamente esa URL y `biopulse://auth-callback`; se comprobó que las demás propiedades remotas no cambiaron. Si una plantilla de **Authentication → Email Templates → Confirm signup** se personalizó y todavía manda a otra URL, comprobar que utiliza `{{ .ConfirmationURL }}` o respeta `{{ .RedirectTo }}` según la [documentación de Supabase](https://supabase.com/docs/guides/auth/redirect-urls#email-templates-when-using-redirectto).

Pedir un **correo nuevo** desde la nueva versión de la app: un mensaje enviado antes conserva su enlace anterior. Abrirlo en el celular personal; debe mostrar el mensaje «Ya abriste el enlace de verificación». Después, volver al simulador e iniciar sesión con el mismo correo y contraseña. Si el enlace anterior confirmó la cuenta antes de llegar a localhost, intentar primero iniciar sesión con esa cuenta.

Apple y Google requieren además la configuración de sus proveedores en Supabase y, para Apple, firma y capacidad en Apple Developer. Probar registro, callback, recuperación, cierre y cambio entre dos cuentas en iOS 17+; después verificar Dynamic Type, VoiceOver y lecturas reales de Apple Salud.

## Verificación actual

**CONFIRMED:** [GitHub Actions en macOS, Xcode 26.6](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39053219208) generó el proyecto, compiló para simulador y para dispositivo iOS sin firma, y pasó las 26 pruebas Swift del dominio. El artefacto generado coincide byte por byte con el `.xcodeproj` versionado. **UNKNOWN:** firma con tu Apple Team, instalación y ejecución en tu iPhone, permisos reales de HealthKit, navegación visual, accesibilidad y flujos de cuenta/Coach en dispositivo. La compilación para dispositivo en CI no firma ni instala la app.

**Corrección del 17-10-2026:** la primera copia versionada omitía `Info.plist`; al abrirla directamente, Xcode mostraba «Build input file cannot be found». El archivo generado ya está versionado. El [run 39056797219](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39056797219) compiló primero el proyecto de un checkout limpio, sin regenerarlo, y después confirmó que XcodeGen reproduce los archivos versionados; también pasaron 26 pruebas y el build iOS sin firma. Una copia descargada antes de esta corrección debe actualizarse.

**Ajuste de pantalla del 17-10-2026:** el video del iPhone mostró el contenido de la app dentro de un área más corta, con franjas negras arriba y abajo. `UILaunchScreen` no estaba declarado. Se añadió la clave en `project.yml` y `Info.plist`; el [run 39064452025](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39064452025) compiló el proyecto versionado para simulador antes de regenerar, comprobó que los archivos se mantienen sincronizados, pasó 26 pruebas y compiló para iPhone sin firma. **Pendiente:** volver a instalar en el iPhone y confirmar visualmente que ocupa el área esperada; CI no sustituye esa comprobación física.
