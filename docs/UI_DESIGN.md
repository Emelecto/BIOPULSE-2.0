# BioPulse 2.0 — sistema visual inicial

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
