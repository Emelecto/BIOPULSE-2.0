# BioPulse 2.0 — sistema visual inicial

## Implementación visual iOS actual (16 de octubre de 2026)

- **CONFIRMED:** la dirección del home se trasladó a SwiftUI: fondo grafito casi plano, acentos de interfaz blancos, BioScore central en un anillo orgánico decorativo, y un grid de tarjetas de igual ancho. Energía activa ocupa la altura de dos tarjetas; HRV, FC en reposo, sueño y pasos muestran lecturas de Apple Salud o un estado vacío.
- **CONFIRMED:** Tendencias usa agregados diarios observados con selección de 7/30/90 días y barras solo en días con registros. Sueño usa intervalos de etapas realmente recibidos. Diario ofrece check-in subjetivo y conserva el registro editable. Perfil conserva permisos, importación CSV y cierre de sesión.
- **CONFIRMED:** `ScoreColor` interpola de rojo a amarillo y verde para scores futuros. No se aplica a lecturas crudas ni presenta un estado médico. BioScore, Sleep Score y subscores permanecen sin cifra hasta implementar y validar sus algoritmos.
- **UNKNOWN:** compilación y apariencia final en Xcode/iPhone. En Windows solo se verificó la sintaxis de los archivos Swift; la compilación iOS, Dynamic Type y VoiceOver requieren el Mac.
- Las decisiones de la sección histórica «Dirección aprobada» que hablan de bosque, menta global y BioScore secundario quedan sustituidas por la dirección anterior. Se conservan abajo como historial, no como especificación vigente.

## Dirección visual más reciente para «Hoy» (15 de octubre de 2026)

- **CONFIRMED:** ajuste final del home: grid de dos columnas de igual ancho. Esfuerzo conserva la altura de las tarjetas HRV+FC apiladas, pero tiene exactamente el mismo ancho que Sueño; HRV y FC tienen el mismo ancho que Pasos. Referencia más reciente: `../design-explorations/2026-10-15-app-flow/01-hoy.png`.
- **PROPOSED:** mockups de Tendencias, Diario, Sueño y Perfil, coherentes con el home, en `../design-explorations/2026-10-15-app-flow/`. Pendientes de revisión del usuario y de implementación.
- **CONFIRMED:** el usuario seleccionó el mosaico asimétrico con BioScore orgánico como dirección del home. Referencia final: `../design-explorations/2026-10-15-final/biopulse-home-semantic-colors.png`; reglas y límites: `../design-explorations/2026-10-15-final/README.md`.
- **CONFIRMED:** el color verde deja de ser un acento global. Fondo, luces ambientales, navegación y botón del Coach IA son neutros blancos/plata sobre carbón oscuro. Cada métrica con score validado usa un matiz propio entre rojo (0), amarillo (50) y verde BioPulse (100), con variación gradual cada ~2 puntos.
- **CONFIRMED:** la puntuación, el texto de estado y la explicación acompañan siempre al color. Un score ausente no adopta un color de alarma.
- **PROPOSED:** las anclas cromáticas y la interpolación del README citado son referencia para implementación, no una fórmula científica. El mockup usa datos simulados y no autoriza mostrar BioScore ni sub-scores reales antes de validarlos.
- Esta dirección sustituye, para el home futuro, la regla de menta como acento general y lavanda fija para sueño descrita en la sección histórica siguiente. La UI actualmente implementada puede seguir usando esa paleta hasta que se programe y verifique la nueva dirección.

## Dirección aprobada

- **CONFIRMED:** equilibrio entre serenidad y rendimiento, con claridad cotidiana y profundidad técnica opcional.
- **CONFIRMED:** interfaz iOS oscura, premium, atmosférica y funcional. El bosque nocturno aprobado aporta el fondo; superficies opacas con iluminación, relieve y sombras ordenan las medidas y los controles.
- **CONFIRMED:** el BioScore debe verse al entrar. Representa bienestar general.
- **CONFIRMED:** el BioScore solo mostrará un número cuando haya fórmula y datos suficientes validados. Mientras tanto, una fila secundaria explica que está pendiente; no se reserva protagonismo con un anillo vacío.
- **CONFIRMED:** menta indica acción y datos disponibles; lavanda distingue el sueño. Contornos orgánicos inspirados en el bosque son decoración, se excluyen de VoiceOver y nunca codifican biometría.
- **CONFIRMED:** materiales translúcidos se limitan al acceso contextual del Coach. Las superficies de lectura y entrada se mantienen opacas para conservar legibilidad.

## Estructura

- `Hoy`: estado de la fuente, fecha, sueño, HRV, actividad y acceso al Diario, respiración guiada y mapa de energía. BioScore aparece como explicación secundaria hasta que su fórmula se valide. Cada señal abre una explicación con procedencia y fecha.
- `Tendencias`: acceso a mediciones. Su referencia histórica queda expresamente pendiente de conexión a la interfaz.
- `Diario`: registro contextual de hábitos, síntomas y eventos. Las asociaciones futuras deben mostrarse como exploratorias, no causales.
- `Sueño`: Sleep Score visible en estado pendiente, lectura de duración de la última noche y alcance del cálculo.
- `Perfil`: Apple Salud, revisión CSV, acceso de cuenta obligatorio, sincronización consentida, privacidad y permisos.

El Coach usa un botón contextual dentro del área segura inferior en las cinco
pestañas, separado de la barra de navegación y del área desplazable. Abre una
hoja nativa de conversación. Antes del
primer envío aparece una autorización única que detalla los datos agregados,
el contexto del Diario, el proveedor externo y la memoria efímera; la conversación
actual se borra al cerrar la hoja.

## Reglas de interfaz

1. Una cifra procede de muestras reales de Apple Salud o queda ausente. El tiempo dormido se calcula de intervalos registrados y se etiqueta como tal. La imagen del bosque es decorativa.
2. Las pantallas de detalle explican fuente, momento y significado sin derivar conclusiones médicas.
3. Los controles de autorización no afirman que HealthKit revele el permiso de lectura; solo se muestra la solicitud y la recepción de muestras.
4. Los módulos mantienen texto legible sobre superficies oscuras, áreas táctiles amplias y desplazamiento vertical para Dynamic Type.
5. No dibujar curvas, anillos de progreso o scores con datos inventados. Una futura gráfica solo puede usar series observadas y periodos identificados.
6. El bosque y sus contornos son decoración estática. Las entradas breves usan desplazamiento y opacidad suaves; las cifras cambian con transición numérica; las hojas conservan el movimiento nativo al abrir y cerrar.
7. Pulsaciones reciben feedback inmediato y el guardado del Diario confirma solo después de persistir, con háptica y anuncio accesible. No se bloquea la interacción durante una animación.
8. Reducir movimiento reemplaza transiciones y fases animadas por estados estáticos/crossfades. Tamaños de lectura grandes reorganizan las métricas en vertical; los campos de contraseña permiten mostrar u ocultar el texto.
9. La confirmación de correo muestra el destinatario, permite regresar al acceso y reenviar el enlace con una espera de 60 segundos; no informa que la cuenta está verificada hasta que la sesión lo confirma.

## Pendiente de validación en Mac

- Render real en tamaños de iPhone, Dynamic Type, VoiceOver y contraste sobre el bosque.
- Firma, permisos HealthKit y compatibilidad de fuentes por dispositivo.
- Fórmula y umbrales de BioScore, tendencias históricas, persistencia CSV y local.
