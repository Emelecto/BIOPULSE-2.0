const message = `BIOPULSE

Ya abriste el enlace de verificación.

Vuelve a BioPulse en el simulador e inicia sesión
con tu correo y contraseña. No necesitas abrir
tu correo dentro del simulador.

Si la app todavía indica que tu cuenta no está
confirmada, solicita un enlace nuevo e inténtalo
otra vez.`;

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
