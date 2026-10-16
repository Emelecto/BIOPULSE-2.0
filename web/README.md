# BioPulse web + Health Auto Export

**CONFIRMED:** implementación local; build, normalizador, 80 pruebas pgTAP y flujo HTTP local del puente pasan. La migración `20261015000400` figura aplicada en Supabase remoto y la función `health-bridge` figura activa; la petición remota sin sesión recibe `401`. El código está en GitHub. **UNKNOWN:** recepción de un export real desde iPhone, login OAuth, QA con una cuenta real y despliegue Vercel. El sitio todavía no tiene URL pública confirmada.

## Ejecutar localmente

```powershell
cd "C:\Users\ecard\OneDrive\Escritorio\BIOPULSE 2.0\web"
Copy-Item .env.example .env.local
# Edita .env.local con la URL y la clave PUBLICABLE (nunca service_role).
npm ci
npm run dev
```

Abrir `http://127.0.0.1:4173/` (landing) y `/app` (cuenta obligatoria). `npm run build` genera `dist/`; `npm test` prueba la normalización. La web usa Supabase Auth, tablas con RLS, la Edge Function existente del Coach y la nueva `health-bridge`. El sitio nuevo de despliegue está en `web/`; `landing/` y `BioPulse/Preview/` quedan como referencias anteriores y no son el producto web funcional.

Para pruebas web contra la pila Supabase local puede usarse `VITE_SUPABASE_URL=http://127.0.0.1:54321` y su clave pública local. En ese modo el asistente no crea enlaces para iPhone: `localhost` no es accesible desde el teléfono y el destino final requiere HTTPS público.

## Estado de publicación y pasos pendientes

1. La migración `supabase/migrations/20261015000400_health_bridge.sql` ya está aplicada en el proyecto remoto vinculado. En local se aplicó sin reset y `supabase test db` pasó 80 pruebas. No ejecutar `supabase db reset` para este flujo.
2. `health-bridge` ya está desplegada con verificación JWT del gateway deshabilitada. **La función verifica manualmente** JWT en acciones de cuenta y el token aleatorio revocable en POST de Health Auto Export. Mantener `SUPABASE_URL`, clave pública y clave secreta solo en secretos del servidor. No exponer la secreta a Vite/Vercel.
3. En Supabase Auth → URL Configuration, añadir URLs exactas de redirección para `https://TU-DOMINIO/app` y `http://127.0.0.1:4173/app` al probar en local. No reemplazar sin análisis el callback iOS existente. Habilitar Google OAuth solo si el proveedor está configurado.
4. En Vercel, crear proyecto con **Root Directory `web`**, Build Command `npm run build`, Output Directory `dist`. Configurar `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`. El `vercel.json` reescribe `/app` para recargas y callbacks. Usar HTTPS y dominio definitivo antes de distribuir enlaces de correo.
5. Probar alta y verificación de correo en web, login, recuperación de contraseña, RLS, Coach y revocación con una cuenta de prueba. La integración HTTP local automatizada está en `supabase/tests/health_bridge_http.mjs`; requiere `supabase functions serve health-bridge --no-verify-jwt` en otra terminal y crea/borra una cuenta sintética local. Luego validar el flujo de Health Auto Export en el iPhone del propietario antes de invitar a otros usuarios.

No publicar sin revisar aviso de privacidad, contacto de soporte y políticas legales para datos de salud. La landing no captura correos y no anuncia iOS como descarga disponible.

## Flujo del usuario en iPhone

1. Instalar Health Auto Export desde su fuente oficial, activar la capacidad REST requerida por esa app y conceder los permisos de Apple Salud de los tipos que quiera compartir.
2. Abrir BioPulse web e iniciar sesión. En **Perfil → Conecta tus señales**, marcar por separado «Resúmenes diarios» y, opcionalmente, «Energía por hora». Crear enlace seguro.
3. Tocar el enlace diario en Safari del iPhone. Health Auto Export debe mostrar una automatización REST JSON con agregación diaria y sueño agregado. Guardar y ejecutar una vez manualmente. Si autorizó intradía, tocar también el segundo enlace y revisar agrupación por hora.
4. Regresar a BioPulse y pulsar «Actualizar estado». Solo un POST aceptado actualiza la fecha de último envío. Si falta una métrica, comprobar permisos, unidades (`kcal`, `ms`, `bpm`), registros reales y logs de Health Auto Export. La ejecución en segundo plano no garantiza tiempo real.
5. Para detener: «Revocar conexión» en BioPulse y desactivar automatizaciones en Health Auto Export. «Eliminar datos importados» detiene primero la conexión y borra los resúmenes recibidos por este puente. Rotar enlace invalida el anterior inmediatamente.

El enlace incluye un token de escritura de duración indefinida hasta revocación; no compartirlo, capturarlo ni enviarlo por chat. Se guarda solo su hash SHA-256 en el servidor. El navegador solo conserva el token en memoria de la pantalla de configuración. Dos automatizaciones usan un token y flujos separados. El servidor rechaza tipos no permitidos, unidades incompatibles, segmentos originales de sueño, valores no agregados y duplicados dentro de la carga. Reenvíos idénticos no crean duplicados ni actualizan revisiones de métricas sin cambios. La carga original no se almacena.

**Limitaciones:** la web no accede directamente a HealthKit; el puente es de terceros y requiere acciones del usuario. No implementamos carga CSV/XML. Una automatización de sueño agregado entrega duraciones por fase, **no la secuencia temporal exacta**. BioScore/Sleep Score y color clínico siguen pendientes de un algoritmo validado; la UI muestra «—» en vez de inventar resultados. Diario web se guarda en la nube solo tras consentimiento propio; el Diario local de iOS todavía no se sincroniza automáticamente.

## Fuentes de integración

- [Health Auto Export: sincronización REST](https://help.healthyapps.dev/en/health-auto-export/automations/rest-api/)
- [Health Auto Export: formato JSON de métricas y sueño](https://help.healthyapps.dev/en/health-auto-export/export-format/health-metrics/)
- [Health Auto Export: deep links de automatización](https://help.healthyapps.dev/en/health-auto-export/automations/deep-link/)

**PROPOSED:** observar una carga real del iPhone y adaptar el normalizador si la versión instalada cambia nombres o fechas; ampliar métricas únicamente tras pruebas y consentimiento explícito.
