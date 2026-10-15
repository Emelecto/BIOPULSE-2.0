import { createClient } from "npm:@supabase/supabase-js@2";

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
    },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return reply(200, { ok: true });
  if (request.method !== "GET") return reply(405, { error: "method_not_allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
  const secretKey = Deno.env.get("SUPABASE_SECRET_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const adminUserID = Deno.env.get("ADMIN_USER_ID");
  const bearer = request.headers.get("Authorization");
  // Fail closed until the exact owner UUID is configured server-side.
  if (!url || !publicKey || !secretKey || !adminUserID ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(adminUserID)) {
    return reply(503, { error: "admin_not_configured" });
  }
  if (!bearer?.startsWith("Bearer ")) return reply(401, { error: "unauthorized" });

  const userClient = createClient(url, publicKey, {
    global: { headers: { Authorization: bearer } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return reply(401, { error: "unauthorized" });
  if (user.id.toLowerCase() !== adminUserID.toLowerCase()) return reply(403, { error: "forbidden" });

  const serverClient = createClient(url, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await serverClient.rpc("admin_operational_metrics");
  if (error || !data) return reply(503, { error: "metrics_unavailable" });
  return reply(200, { metrics: data });
});
