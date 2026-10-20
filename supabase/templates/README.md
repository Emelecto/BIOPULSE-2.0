# Correos de autenticación BioPulse

Los seis HTML de esta carpeta son las fuentes de los mensajes de BioPulse. `supabase/config.toml` los usa en Supabase local. En el proyecto alojado, las plantillas **no se actualizan automáticamente desde Git**: copiar asunto y HTML en **Authentication → Email Templates** del Dashboard. Activar por separado las notificaciones de seguridad de cambio de contraseña y correo si están disponibles en el plan y en la configuración del proyecto.

| Mensaje | Asunto |
|---|---|
| Confirmation | Confirma tu cuenta en BioPulse |
| Recovery | Recupera tu acceso a BioPulse |
| Email Change | Confirma tu nuevo correo en BioPulse |
| Invite User | Te invitaron a BioPulse |
| Password Changed Notification | Tu contraseña de BioPulse cambió |
| Email Changed Notification | El correo de tu cuenta BioPulse cambió |

Las plantillas de acción usan `{{ .ConfirmationURL }}`, el enlace de Supabase que verifica el token antes de redirigir. No sustituirlo por un enlace directo a la web. El aviso de seguridad no lleva token.

## Qué necesitamos para activar el envío alojado

- Un dominio que controle el equipo (o un subdominio dedicado para correo) y una dirección remitente, por ejemplo `hola@<dominio-del-equipo>`. La dirección exacta se decide cuando tengan el dominio.
- Una cuenta en un proveedor de correo transaccional con SMTP. Ese proveedor entregará el servidor, puerto, usuario y contraseña SMTP; estos datos se introducen **solo en el Dashboard de Supabase**, nunca en Git ni por chat.
- Acceso a la configuración DNS del dominio para añadir los registros de autenticación que pida el proveedor (normalmente SPF y DKIM) y verificar el remitente.
- Acceso de administrador al proyecto Supabase alojado para configurar SMTP, las seis plantillas y las URL de redirección. Después se deben probar los enlaces y la entrega con una cuenta de prueba.

Antes de invitar a usuarios reales:

1. En **Authentication → URL Configuration**, conservar `biopulse://auth-callback` y la función `confirm-email` de iOS; añadir las rutas web exactas `https://biopulse-20.vercel.app/app`, `/app/confirm`, `/app/reset` y `/app/email-change`. Repetir con el dominio definitivo si cambia.
2. Configurar un proveedor SMTP propio y el remitente de BioPulse en **Authentication → SMTP Settings**. El servidor predeterminado de Supabase solo sirve para pruebas limitadas y puede rechazar direcciones externas al equipo.
3. Copiar los asuntos y HTML al Dashboard; habilitar notificaciones de seguridad si se desea. Probar registro, reenvío, recuperación, cambio de correo y contraseña con una cuenta de prueba y revisar móvil/escritorio y carpeta spam.
4. Desactivar seguimiento o reescritura de enlaces en el proveedor de correo si interfiere con los enlaces de Supabase.

La URL de sitio de la configuración local apunta todavía a la función `confirm-email` para preservar el callback iOS existente. La web envía su `emailRedirectTo` específico a cada ruta. No cambiar la URL general sin volver a probar el flujo iOS.
