type Dependencies = {
  configured: boolean;
  authenticatedUser: (bearer: string) => Promise<{ id: string } | null>;
  deleteUser: (id: string) => Promise<boolean>;
};

const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

async function limitedBody(request: Request): Promise<string | null> {
  const limit = 256;
  if (Number(request.headers.get("Content-Length") ?? 0) > limit) return null;
  let bytes = 0;
  const decoder = new TextDecoder();
  let value = "";
  for await (const chunk of request.body ?? []) {
    bytes += chunk.byteLength;
    if (bytes > limit) return null;
    value += decoder.decode(chunk, { stream: true });
  }
  return value + decoder.decode();
}

export function createAccountDeleteHandler(dependencies: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return json(200, { ok: true });
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
    if (!dependencies.configured) return json(503, { error: "not_configured" });
    const bearer = request.headers.get("Authorization");
    if (!bearer?.startsWith("Bearer ") || !bearer.slice(7).trim()) return json(401, { error: "unauthorized" });
    let user: { id: string } | null;
    try { user = await dependencies.authenticatedUser(bearer); }
    catch { return json(503, { error: "authentication_unavailable" }); }
    if (!user) return json(401, { error: "unauthorized" });

    let content: string | null;
    try { content = await limitedBody(request); }
    catch { return json(400, { error: "invalid_request" }); }
    if (content === null) return json(413, { error: "payload_too_large" });
    let confirmation: unknown;
    try {
      const parsed = JSON.parse(content);
      confirmation = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed.confirmation : null;
    } catch { return json(400, { error: "invalid_request" }); }
    if (confirmation !== "ELIMINAR") return json(400, { error: "confirmation_required" });

    // The target comes exclusively from the verified identity, never the body.
    try {
      if (!await dependencies.deleteUser(user.id)) return json(503, { error: "deletion_failed" });
    } catch { return json(503, { error: "deletion_failed" }); }
    return json(200, { deleted: true });
  };
}
