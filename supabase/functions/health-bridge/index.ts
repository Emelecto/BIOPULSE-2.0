import { createClient } from "npm:@supabase/supabase-js@2";
import { normalizeExport, type Stream } from "./normalize.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-retry-count, traceparent, tracestate, baggage",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Cache-Control": "no-store",
};
const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
const url = Deno.env.get("SUPABASE_URL");
const publicKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY");
const secretKey = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const admin = url && secretKey
  ? createClient(url, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  : null;

async function limitedText(req: Request, limit: number): Promise<string> {
  if (Number(req.headers.get("Content-Length") ?? 0) > limit) {
    throw new Error("payload_too_large");
  }
  const decoder = new TextDecoder();
  let body = "";
  let bytes = 0;
  for await (const chunk of req.body ?? []) {
    bytes += chunk.byteLength;
    if (bytes > limit) throw new Error("payload_too_large");
    body += decoder.decode(chunk, { stream: true });
  }
  return body + decoder.decode();
}

async function sha256(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)].map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}
async function activeConsent(
  userId: string,
  category: string,
): Promise<boolean> {
  const { data, error } = await admin!.from("sync_consents").select("decision")
    .eq("user_id", userId).eq("data_category", category).order("id", {
      ascending: false,
    }).limit(1).maybeSingle();
  if (error) throw error;
  return data?.decision === "granted";
}
async function stopBridge(userId: string): Promise<boolean> {
  const stop = await admin!.from("health_bridge_connections").update({
    revoked_at: new Date().toISOString(),
  }).eq("user_id", userId);
  if (stop.error) return false;
  const consent = await admin!.from("sync_consents").insert([
    {
      user_id: userId,
      data_category: "derived_metrics",
      decision: "revoked",
      policy_version: "hae-aggregate-v1",
    },
    {
      user_id: userId,
      data_category: "intraday_metrics",
      decision: "revoked",
      policy_version: "hae-aggregate-v1",
    },
  ]);
  return !consent.error;
}
async function ingest(req: Request, stream: Stream): Promise<Response> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/, "");
  if (!token || !/^bp_[a-f0-9]{64}$/.test(token)) {
    return json(401, { error: "invalid_bridge_token" });
  }
  const { data: connection, error } = await admin!.from(
    "health_bridge_connections",
  ).select("user_id,revoked_at").eq("token_hash", await sha256(token))
    .maybeSingle();
  if (error) return json(503, { error: "bridge_unavailable" });
  if (!connection || connection.revoked_at) {
    return json(401, { error: "bridge_revoked" });
  }
  if (!await activeConsent(connection.user_id, "derived_metrics")) {
    return json(403, { error: "daily_consent_required" });
  }
  if (
    stream === "intraday" &&
    !await activeConsent(connection.user_id, "intraday_metrics")
  ) return json(403, { error: "intraday_consent_required" });
  let raw: string;
  try {
    raw = await limitedText(req, 256_000);
  } catch {
    return json(413, { error: "payload_too_large" });
  }
  let normalized;
  try {
    normalized = normalizeExport(JSON.parse(raw), stream);
  } catch (issue) {
    return json(400, {
      error: issue instanceof Error ? issue.message : "invalid_export",
    });
  }
  const owner = connection.user_id;
  for (
    const [table, rows, conflict] of [
      [
        "daily_metric_summaries",
        normalized.daily,
        "user_id,local_date,metric_kind,source_kind",
      ],
      [
        "intraday_metric_summaries",
        normalized.hourly,
        "user_id,bucket_start,metric_kind,source_kind",
      ],
      [
        "sleep_stage_summaries",
        normalized.sleep,
        "user_id,local_date,stage,source_kind",
      ],
    ] as const
  ) {
    if (!rows.length) continue;
    const dates = rows.map((row) => row.local_date).sort();
    const { data: existing, error: readError } = await admin!.from(table)
      .select("*").eq("user_id", owner).eq(
        "source_kind",
        "health_auto_export_aggregate",
      ).gte("local_date", dates[0]).lte("local_date", dates.at(-1)!);
    if (readError) return json(503, { error: "write_failed" });
    const keyFields = table === "daily_metric_summaries"
      ? ["local_date", "metric_kind"]
      : table === "intraday_metric_summaries"
      ? ["bucket_start", "metric_kind"]
      : ["local_date", "stage"];
    const keyOf = (row: Record<string, unknown>) =>
      keyFields.map((field) => row[field]).join(":");
    const prior = new Map((existing ?? []).map((row) => [keyOf(row), row]));
    const changed = rows.filter((row) => {
      const old = prior.get(keyOf(row as unknown as Record<string, unknown>));
      return !old ||
        Object.entries(row).some(([field, value]) => old[field] !== value);
    });
    if (!changed.length) continue;
    if (table === "daily_metric_summaries") {
      // Its trigger makes id/created_at immutable; generic upsert would replace generated id.
      for (const row of changed) {
        const old = prior.get(keyOf(row as unknown as Record<string, unknown>));
        const request = old
          ? admin!.from(table).update(row).eq("id", old.id).eq("user_id", owner)
          : admin!.from(table).insert({ ...row, user_id: owner });
        const { error: writeError } = await request;
        if (writeError) return json(503, { error: "write_failed" });
      }
    } else {
      const { error: writeError } = await admin!.from(table).upsert(
        changed.map((row) => ({ ...row, user_id: owner })),
        { onConflict: conflict },
      );
      if (writeError) return json(503, { error: "write_failed" });
    }
  }
  const now = new Date().toISOString();
  await admin!.from("health_bridge_connections").update({
    last_sync_at: now,
    [stream === "daily" ? "last_daily_sync_at" : "last_intraday_sync_at"]: now,
    last_error: null,
  }).eq("user_id", owner);
  return json(200, {
    ok: true,
    accepted: normalized.daily.length + normalized.hourly.length +
      normalized.sleep.length,
  });
}

async function manage(req: Request): Promise<Response> {
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json(401, { error: "unauthorized" });
  }
  const userClient = createClient(url!, publicKey!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (!user || authError) return json(401, { error: "unauthorized" });
  let body: Record<string, unknown>;
  try {
    body = JSON.parse(await limitedText(req, 4_096));
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error();
    }
  } catch {
    return json(400, { error: "invalid_request" });
  }
  const action = body.action;
  if (action === "status") {
    const { data } = await admin!.from("health_bridge_connections").select(
      "created_at,revoked_at,last_sync_at,last_daily_sync_at,last_intraday_sync_at",
    ).eq("user_id", user.id).maybeSingle();
    return json(200, {
      connected: !!data && !data.revoked_at,
      lastSyncAt: data?.last_sync_at ?? null,
      lastDailySyncAt: data?.last_daily_sync_at ?? null,
      lastIntradaySyncAt: data?.last_intraday_sync_at ?? null,
      dailyConsent: await activeConsent(user.id, "derived_metrics"),
      intradayConsent: await activeConsent(user.id, "intraday_metrics"),
    });
  }
  if (action === "consent") {
    if (
      (body.category !== "derived_metrics" &&
        body.category !== "intraday_metrics") ||
      (body.decision !== "granted" && body.decision !== "revoked")
    ) return json(400, { error: "invalid_consent" });
    const { error } = await userClient.from("sync_consents").insert({
      user_id: user.id,
      data_category: body.category,
      decision: body.decision,
      policy_version: "hae-aggregate-v1",
    });
    if (error) return json(503, { error: "consent_update_failed" });
    if (body.category === "derived_metrics" && body.decision === "revoked") {
      await admin!.from("health_bridge_connections").update({
        revoked_at: new Date().toISOString(),
      }).eq("user_id", user.id);
    }
    return json(200, { ok: true });
  }
  if (action === "start") {
    if (!await activeConsent(user.id, "derived_metrics")) {
      return json(403, { error: "daily_consent_required" });
    }
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    const token = `bp_${
      [...bytes].map((n) => n.toString(16).padStart(2, "0")).join("")
    }`;
    const { error } = await admin!.from("health_bridge_connections").upsert({
      user_id: user.id,
      token_hash: await sha256(token),
      created_at: new Date().toISOString(),
      revoked_at: null,
      last_sync_at: null,
      last_daily_sync_at: null,
      last_intraday_sync_at: null,
    });
    if (error) return json(503, { error: "connection_failed" });
    return json(200, { token });
  }
  if (action === "revoke") {
    return await stopBridge(user.id)
      ? json(200, { ok: true })
      : json(503, { error: "revoke_failed" });
  }
  if (action === "delete_data") {
    // Deleting while a live automation can upload again would be misleading.
    if (!await stopBridge(user.id)) {
      return json(503, { error: "revoke_failed" });
    }
    const daily = await admin!.from("daily_metric_summaries").delete().eq(
      "user_id",
      user.id,
    ).eq("source_kind", "health_auto_export_aggregate");
    const hourly = await admin!.from("intraday_metric_summaries").delete().eq(
      "user_id",
      user.id,
    );
    const sleep = await admin!.from("sleep_stage_summaries").delete().eq(
      "user_id",
      user.id,
    );
    return daily.error || hourly.error || sleep.error
      ? json(503, { error: "delete_failed" })
      : json(200, { ok: true });
  }
  return json(400, { error: "unknown_action" });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!admin || !url || !publicKey) {
    return json(503, { error: "service_unavailable" });
  }
  try {
    const stream = new URL(req.url).searchParams.get("stream");
    if (stream === "daily" || stream === "intraday") {
      return await ingest(req, stream);
    }
    return await manage(req);
  } catch {
    return json(503, { error: "service_unavailable" });
  }
});
