# Supabase para BioPulse 2.0

Este directorio contiene la configuración local, migraciones SQL, funciones Edge y pruebas pgTAP del backend. Las migraciones de cuentas y del Coach están aplicadas en el proyecto remoto; la configuración Auth del Dashboard/SMTP/OAuth aún requiere verificación independiente.

## Modelo inicial

- `auth.users`: identidad y credenciales administradas por Supabase Auth; BioPulse no almacena contraseñas.
- `public.profiles`: nombre visible mínimo por cuenta.
- `public.user_settings`: zona horaria y sistema de unidades.
- `public.sync_consents`: historial append-only de consentimiento por categoría sincronizada.
- `public.journal_entries`: diario contextual por cuenta, con revisión optimista para edición.
- `public.coach_consents`: historial inmutable de autorización específica para enviar contexto del Coach a Groq.
- `public.coach_memories`: resumen no visible con TTL de siete días, accesible solo desde backend.
- `public.coach_usage`: cuota diaria atómica por cuenta; servicio/función únicamente.

Un trigger privado posterior al alta en `auth.users` crea una fila vacía en `profiles` y una fila `user_settings` con zona `UTC` y unidades métricas. No copia metadata OAuth ni concede consentimiento de sincronización. Las migraciones están aplicadas en local y remoto; la suite pgTAP valida RLS, bootstrap, consentimiento y cuota del Coach (39 pruebas).

Todas las tablas expuestas tienen RLS y permisos explícitos para `authenticated`; el rol `anon` no recibe acceso. Las políticas comparan el propietario con `auth.uid()`. Para escribir perfil, ajustes o Diario, la última decisión de consentimiento para esa categoría debe ser `granted`. Revocar consentimiento bloquea nuevas escrituras, pero conserva lectura y borrado de los registros propios. Las muestras originales de HealthKit no forman parte de este esquema. El usuario debe tener sesión autenticada para abrir y usar BioPulse; no existe modo invitado. La autenticación obligatoria no activa la sincronización.

## Reproducir localmente

Requisitos: Supabase CLI y Docker Desktop.

```powershell
supabase start
supabase db reset
supabase test db
```

`db reset` reconstruye únicamente la base local a partir de las migraciones y es destructivo para los datos de desarrollo locales. No usar `--linked` en este flujo.

## Reglas para credenciales

- La app iOS solo podrá incluir URL del proyecto y clave publishable/anon.
- Nunca incluir `service_role`, contraseña de base de datos ni secretos de proveedores OAuth en la app.
- Eliminar una cuenta se hará desde una operación de servidor protegida que elimine el usuario de Auth y deje que las claves foráneas en cascada borren sus datos de BioPulse.
- Antes de producción: configurar correo SMTP propio, confirmación de correo, URLs de redirección exactas, límites de autenticación, copias de seguridad y un entorno separado.

## Flujo de autenticación de la app

La aplicación exige una sesión antes de mostrar las pestañas. El registro por correo puede requerir confirmación antes de emitir sesión; el callback es `biopulse://auth-callback`. La app también incluye Apple (nonce) y Google, pero ambos proveedores deben habilitarse y configurarse en el proyecto remoto antes de que esos botones funcionen. La sincronización de datos no se activa por iniciar sesión.

## Coach IA (código en preparación para habilitar)

`functions/coach/index.ts` expone acciones autenticadas `grant_consent`, `revoke_consent`, `clear_memory` y `send`. Verifica el JWT contra Auth, obtiene la identidad del servidor (nunca acepta `user_id` del cuerpo), requiere el consentimiento vigente `coach-context-v1`, limita cada petición, aplica una cuota diaria atómica y usa Groq solo desde Edge Function. No guarda prompts, respuestas ni historial completo en la base de datos. El cliente envía únicamente mensajes de la conversación abierta y contexto agregado permitido (`metrics`, `trends`, `journal`); el esquema rechaza objetos/campos de muestras HealthKit sin procesar. Un resumen breve puede guardarse por cuenta y expira a los siete días; Cron lo elimina cada hora (máximo aproximado: 1 hora después del vencimiento). Revocar consentimiento también borra la memoria.

Valores configurables en secretos/variables de Edge Functions, sin guardar claves en el repositorio:

- `GROQ_API_KEY`: secreto requerido del proveedor.
- `GROQ_MODEL`: ID de un modelo activo compatible con Chat Completions y JSON mode.
- `COACH_DAILY_LIMIT`: peticiones máximas por cuenta/día UTC (por defecto 20, rango permitido 1–100).

La pantalla SwiftUI y el cliente autenticado están conectados en código. La función está validada localmente para arranque y rechazo de llamadas sin sesión, pero aún no está desplegada. La clave/modelo de Groq no están configurados y no se ha probado una respuesta real del proveedor ni compilado la app en Mac. La protección de emergencia por palabras clave es una medida auxiliar, no un sistema clínico exhaustivo.
