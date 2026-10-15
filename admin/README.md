# Panel interno BioPulse

Interfaz web local para el propietario, solo conteos operativos. La comprobación real de acceso está en `supabase/functions/admin-ops/index.ts`: valida JWT con Auth y compara el UUID exacto con el secreto servidor `ADMIN_USER_ID`. Sin este secreto, responde 503 a todos. La función llama a un RPC disponible únicamente para `service_role`. Nunca hay clave secreta en el navegador.

Para usarlo: ejecuta `npm install` y `npm run dev` en esta carpeta y abre la dirección local que muestra Vite. El código usa por defecto la URL y la clave **publishable pública** que ya están en `BioPulse/project.yml`. Se pueden sustituir con `.env.local` si cambia el proyecto. `ADMIN_USER_ID` está configurado como secreto de la Edge Function remota con el UUID confirmado por el propietario; nunca se incluye en el frontend. Inicia sesión con esa misma cuenta. No uses la clave `service_role` en archivos `VITE_*`.

El panel no muestra datos biométricos, Diario, correos, IDs ni información clínica. Los contadores son globales y agregados. El código está preparado para alojarse en HTTPS posteriormente; por ahora no se publica un sitio web ni se habilita un dominio externo.
La sesión web se conserva solo en memoria: al recargar la página se debe iniciar sesión de nuevo.
