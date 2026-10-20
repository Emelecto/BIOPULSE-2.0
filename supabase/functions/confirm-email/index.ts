// The hosted Supabase domain rewrites HTML responses to text/plain.
// Branded web auth pages are served by Vercel; this route remains the iOS fallback.
const message = `BIOPULSE

Abriste el enlace de verificación.

Vuelve a la app BioPulse e inicia sesión con tu correo y contraseña.
Si tu cuenta todavía aparece sin confirmar, solicita un enlace nuevo desde la app.

También puedes entrar a BioPulse web:
https://biopulse-20.vercel.app/app

Conectar datos de salud siempre será una decisión tuya.`;

Deno.serve((request) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Método no permitido", { status: 405, headers: { Allow: "GET, HEAD" } });
  }
  return new Response(request.method === "HEAD" ? null : message, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
    },
  });
});