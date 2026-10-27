# BioPulse 2.0 — diseño y estado de interfaz

## Implementación actual

La app SwiftUI usa una interfaz oscura y atmosférica, con fondo nocturno, superficies elevadas y acentos de color por tipo de señal. Las exploraciones visuales bajo `design-explorations/` documentan la evolución del diseño; la revisión visual en un dispositivo determinará su apariencia real.

**CONFIRMED en el código fuente:**

- Cinco áreas principales: Hoy, Tendencias, Diario, Sueño y Perfil.
- Lecturas de Apple Salud con estados para datos presentes o ausentes y enlaces a su explicación/procedencia.
- BioScore y Sleep Score `personal-v1`, deterministas y exploratorios; requieren cobertura suficiente y no tienen validación clínica.
- Tendencias personales, anotaciones, timeline, check-in subjetivo y experimentos personales exploratorios.
- Diario editable, centro de aprendizaje, resumen compartible, vista técnica, objetivos flexibles, respiración guiada, mapa de energía y preferencias de recordatorios locales.
- Cuenta obligatoria; el inicio de sesión no concede consentimiento para sincronizar datos.
- Coach conversacional en español con consentimiento específico y límites informativos/no diagnósticos. La respuesta real del proveedor y la experiencia en dispositivo siguen pendientes de QA.

**CONFIRMED:** [CI en macOS con Xcode 26.6](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39053219208) compiló el target iOS para simulador y dispositivo sin firma y pasó 26 pruebas Swift del dominio. El video aportado por el usuario el 2026-10-26 muestra las cinco pestañas de iOS y sus desplazamientos, y sirve como referencia visual anterior al ajuste de densidad. **UNKNOWN:** validación del nuevo diseño compacto en iPhone, permisos HealthKit efectivos, VoiceOver, Dynamic Type y notificaciones. La compilación no confirma por sí sola el comportamiento visual o funcional de cada pantalla.

## Densidad compacta — 2026-10-26

- **CONFIRMED en fuente:** cabecera con marca de 20 pt, título `.title2`, fecha/subtítulo `.caption` y espaciado de 12 pt entre grupos. Tarjetas con 12 pt de margen interior; botones principales y secundarios conservan un mínimo de 44 pt.
- **CONFIRMED en fuente:** anillo base de 176 pt, métricas de al menos 110 pt y energía de al menos 232 pt. Las dimensiones relevantes usan `ScaledMetric`; las tarjetas pueden crecer y las filas se apilan con texto grande.
- **CONFIRMED en fuente:** Hoy presenta las métricas antes de calibración y registro de sueño. Tendencias muestra la gráfica antes del panel ML. Las explicaciones siguen disponibles en desplegables; no se alteran cálculos, permisos ni persistencia.
- **CONFIRMED en web:** el teléfono de la landing reproduce este orden y lenguaje visual, con cinco pestañas, gráficas filtrables, detalles y formularios de demostración. Las cifras y respuestas se identifican como simuladas. Los cambios existen solo en memoria y se pierden al recargar; no se conecta con HealthKit, la cuenta o el Coach real.
- **Aceptación pendiente en iPhone:** comprobar primera vista en un dispositivo de 390 × 844 pt y otro pequeño, texto estándar y tamaños de accesibilidad, cabeceras legibles, tarjetas sin recortes y controles operables. La réplica web no acredita por sí sola la apariencia nativa.

## Reglas visuales y de información

1. Las cifras fisiológicas proceden de muestras observadas; si no hay muestras o cobertura suficiente, se explica la ausencia y no se inventa un valor.
2. Los datos observados, autoinformes, cálculos, inferencias y predicciones deben distinguirse. No se presenta un score exploratorio como diagnóstico ni como medida clínica validada.
3. Cada métrica debe conservar fuente, periodo y contexto relevantes. La coincidencia entre una anotación y un cambio no implica causalidad.
4. Texto legible en superficies oscuras, áreas táctiles amplias, adaptación a Dynamic Type y nombres accesibles para controles.
5. Los ejemplos de las exploraciones visuales son ilustrativos; no constituyen datos reales ni resultados de BioPulse.
6. Recordatorios opt-in y fáciles de desactivar. Las exportaciones requieren selección visible y revisión del contenido antes de compartir.

## Validación pendiente en dispositivo

- Abrir `BioPulse/BioPulse.xcodeproj`, configurar firma y ejecutar en iPhone; repetir flujos críticos en simulador si conviene.
- Revisar solicitudes y consultas de HealthKit con datos reales autorizados, historial, cobertura y días sin datos.
- Revisar Dynamic Type, VoiceOver, contraste, navegación y áreas táctiles.
- Revisar persistencia y aislamiento al cerrar sesión/cambiar de cuenta, importación CSV, exportación, permisos y notificaciones.
- Probar Coach con respuesta real del proveedor, consentimiento, revocación, errores y fallback.
- Corregir hallazgos; entonces actualizar el estado de cada función de «implementado en código» a «verificado» cuando corresponda.

## Movimiento y Wrapped mensual — 2026-10-26

- Anillo orgánico con luz y deformación suave, número estable, pausa por visibilidad/ciclo de vida y movimiento reducido.
- Respuesta de pulsación compartida, entradas cortas y cambios animados de selección, gráficas y Diario.
- Wrapped usa una presentación inmersiva oscura, acentos por señal, tipografía editorial, siete escenas y navegación horizontal. Cada señal conserva su gráfica diaria y procedencia; los detalles, comparación y tarjeta de imagen son interactivos.
- CONFIRMED: [CI macOS/Xcode](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/40435652597) compiló para simulador y dispositivo sin firma y pasó 42 pruebas de dominio. Se revisó la demo web en escritorio y móvil. UNKNOWN: interacción y apariencia de esta entrega en iPhone real.
- Misma estructura narrativa en SwiftUI, app web y teléfono público. Este último muestra datos simulados y ofrece ampliación a pantalla completa. Ver alcance y aceptación en `WRAPPED.md`.

## Funciones explícitamente futuras

- App complementaria para watchOS, widgets y complicaciones para Apple Watch.
- Transporte de sincronización cloud desde la app iOS.
- Predicciones clínicas o scores con validación clínica.
