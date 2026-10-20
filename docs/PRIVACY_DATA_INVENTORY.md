# Inventario de datos para revisión de privacidad

Documento técnico, **no es una política de privacidad aprobada**. Estado 19-10-2026. La versión pública debe describir el despliegue real, no solo el código.

| Flujo | Datos | Destino comprobado en fuente | Control del usuario / límite |
| --- | --- | --- | --- |
| Cuenta | Correo, identidad de proveedor y sesión | Supabase Auth | Registro obligatorio; recuperación y cierre de sesión. Borrado completo implementado en fuente, pendiente de desplegar y probar. |
| Apple Salud en iOS | Lecturas autorizadas y muestras necesarias para cálculos | Memoria del iPhone; no hay transporte nativo iOS a Supabase | Permiso por tipo en iOS; datos originales no se suben por la app. |
| CSV iOS | Archivo elegido y agregados diarios calculados | Memoria de la app durante la sesión | Se puede quitar en Perfil. BioPulse no modifica Apple Salud ni conserva el CSV al cerrar. |
| Diario y contexto iOS | Entradas, check-ins, anotaciones, experimentos y preferencias | Directorio local separado por UUID de cuenta, con protección de archivo | El usuario edita/borra entradas. El borrado de cuenta intenta eliminar todo el directorio local de esa cuenta. |
| CSV web | Archivo elegido y agregados calculados | Web Worker y memoria del navegador | Se descarta al quitarlo, recargar o cerrar sesión; no se envía a Supabase. |
| Web y Health Auto Export | Agregados diarios, horarios y de etapas de sueño autorizados | Supabase, mediante la función `health-bridge`; el payload original se valida en memoria | Consentimientos separados, enlace revocable y eliminación de agregados. La automatización de la app de terceros se gestiona también en esa app. |
| Diario web | Entradas escritas por el usuario | Supabase, tras consentimiento de `journal` | Edición y borrado por el titular; RLS. |
| Coach IA | Mensajes y contexto derivado seleccionado; hasta 20 entradas recientes del Diario según la interfaz iOS | Función BioPulse → proveedor Groq, solo tras consentimiento específico | Memoria resumida de hasta siete días en Supabase y revocación; no se envían muestras originales de HealthKit. La política de retención del proveedor externo debe verificarse antes de publicar. |
| Landing | Navegación pública | Vercel | No existe formulario beta activo. Cookies, logs e infraestructura efectiva del alojamiento requieren revisión. |

## Datos faltantes antes de redactar la versión pública

1. Nombre y datos de contacto de la persona o entidad responsable; correo de soporte funcional y países donde se ofrecerá BioPulse.
2. Dominio definitivo, proveedor SMTP y ubicación/configuración del proyecto Supabase y del sitio Vercel.
3. Retención y eliminación real de registros operativos, copias de seguridad, correos y datos procesados por Groq y Health Auto Export. El código de BioPulse no controla todas estas retenciones.
4. Base y texto de consentimiento para cada finalidad; proceso para solicitudes de acceso, rectificación, portabilidad y eliminación según las jurisdicciones de lanzamiento.
5. Revisión de los textos públicos y del formulario de privacidad de App Store con los flujos finalmente activados. No afirmar que “todos los datos quedan en el dispositivo” si se ofrece la web sincronizada o el Coach.
