# Paneles internos BioPulse — Admin y Developer

Interfaz web interna local con dos espacios de solo lectura:

- **Admin:** cuentas, actividad de Coach y eventos de consentimiento en conteos globales. No muestra métricas biométricas, entradas de Diario, correos ni identidades.
- **Developer:** diagnóstico en vivo de la sesión y el endpoint privado, mapa de arquitectura y estado documentado del ML. El Isolation Forest personal se identifica como experimental; el ML supervisado como investigación. No ofrece controles de producción, secretos ni datos de usuarios.

Ambos paneles comparten el inicio de sesión privado del propietario. La comprobación real de acceso está en `supabase/functions/admin-ops/index.ts`: valida JWT con Auth y compara el UUID exacto con el secreto servidor `ADMIN_USER_ID`. Sin este secreto, responde 503 a todos. La función llama a un RPC disponible únicamente para `service_role`. Nunca hay clave secreta en el navegador.

Para usarlo: ejecuta `npm install` y `npm run dev` en esta carpeta y abre la dirección local que muestra Vite. El código usa por defecto la URL y la clave **publishable pública** que ya están en `BioPulse/project.yml`. Se pueden sustituir con `.env.local` si cambia el proyecto. `ADMIN_USER_ID` está configurado como secreto de la Edge Function remota con el UUID confirmado por el propietario; nunca se incluye en el frontend. Inicia sesión con esa misma cuenta. No uses la clave `service_role` en archivos `VITE_*`.

El panel no muestra datos biométricos, Diario, correos, IDs ni información clínica. Los contadores son globales y agregados. El diagnóstico de Developer solo declara el endpoint conectado tras una respuesta autenticada correcta. El estado de otros componentes se presenta como inventario documentado y no como comprobación automática. El código está preparado para alojarse en HTTPS posteriormente; por ahora no se publica un sitio web ni se habilita un dominio externo.
La sesión web se conserva solo en memoria: al recargar la página se debe iniciar sesión de nuevo.
