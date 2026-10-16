// Local-only integration test. Creates and removes a synthetic Auth user.
import { spawnSync } from "node:child_process";
import { randomBytes, randomUUID } from "node:crypto";
import assert from "node:assert/strict";

const status = spawnSync("supabase", ["status", "-o", "json"], { encoding: "utf8" });
if (status.status !== 0) throw new Error("Start local Supabase before this test.");
const config = JSON.parse(status.stdout);
const base = config.API_URL;
if (base !== "http://127.0.0.1:54321") throw new Error("This test runs only against local Supabase.");
const adminKey = config.SERVICE_ROLE_KEY;
const anonKey = config.ANON_KEY;
if (!adminKey || !anonKey) throw new Error("Local keys unavailable.");
const email = `bridge-${randomUUID()}@biopulse.test`;
const password = randomBytes(24).toString("hex");
let userId;

async function request(path, { key = anonKey, token = key, body, method = "POST" } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: { apikey: key, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const payload = await response.json().catch(() => ({}));
  return { status: response.status, payload };
}
try {
  const created = await request("/auth/v1/admin/users", { key: adminKey, body: { email, password, email_confirm: true } });
  assert.equal(created.status, 200, `Local user creation: ${JSON.stringify(created.payload)}`);
  userId = created.payload.id;
  const login = await request("/auth/v1/token?grant_type=password", { body: { email, password } });
  assert.equal(login.status, 200, "Local login failed");
  const jwt = login.payload.access_token;
  const manage = (body) => request("/functions/v1/health-bridge", { token: jwt, body });
  assert.equal((await manage({ action: "status" })).payload.dailyConsent, false);
  assert.equal((await manage({ action: "consent", category: "derived_metrics", decision: "granted" })).status, 200);
  const started = await manage({ action: "start" });
  assert.equal(started.status, 200);
  assert.match(started.payload.token, /^bp_[a-f0-9]{64}$/);
  const bridgeToken = started.payload.token;
  const send = (stream, body) => request(`/functions/v1/health-bridge?stream=${stream}`, { token: bridgeToken, body });
  const daily = { data: { metrics: [
    { name: "step_count", units: "count", data: [{ date: "2026-10-15 00:00:00 -0500", qty: 8124 }] },
    { name: "sleep_analysis", units: "hr", data: [{ date: "2026-10-15", totalSleep: 7.5, core: 3.5, deep: 1.5, rem: 2.5 }] },
  ] } };
  assert.equal((await send("daily", daily)).status, 200, "Daily aggregate rejected");
  const rows = await request(`/rest/v1/daily_metric_summaries?select=metric_kind,revision,value&user_id=eq.${userId}&source_kind=eq.health_auto_export_aggregate`, { token: jwt, method: "GET" });
  assert.equal(rows.status, 200);
  assert.equal(rows.payload.length, 2);
  assert.equal((await send("daily", daily)).status, 200);
  const again = await request(`/rest/v1/daily_metric_summaries?select=metric_kind,revision&user_id=eq.${userId}&source_kind=eq.health_auto_export_aggregate`, { token: jwt, method: "GET" });
  assert.ok(again.payload.every((row) => row.revision === 1), "Identical resend changed revisions");
  const hourly = { data: { metrics: [{ name: "active_energy", units: "kcal", data: [{ date: "2026-10-15 08:00:00 -0500", qty: 42 }] }] } };
  assert.equal((await send("intraday", hourly)).status, 403, "Hourly accepted without separate consent");
  assert.equal((await manage({ action: "consent", category: "intraday_metrics", decision: "granted" })).status, 200);
  assert.equal((await send("intraday", hourly)).status, 200);
  const rawSleep = { data: { metrics: [{ name: "sleep_analysis", units: "hr", data: [{ date: "2026-10-15", startDate: "2026-10-14 22:00:00 -0500", totalSleep: 7 }] }] } };
  assert.equal((await send("daily", rawSleep)).status, 400, "Raw sleep segment accepted");
  assert.equal((await manage({ action: "revoke" })).status, 200);
  assert.equal((await send("daily", daily)).status, 401, "Revoked token still works");
  assert.equal((await manage({ action: "delete_data" })).status, 200);
  const remaining = await request(`/rest/v1/daily_metric_summaries?select=id&user_id=eq.${userId}&source_kind=eq.health_auto_export_aggregate`, { token: jwt, method: "GET" });
  assert.equal(remaining.payload.length, 0);
  console.log("Health bridge local HTTP: auth, consent, aggregate, idempotence, revoke and deletion passed.");
} finally {
  if (userId) await request(`/auth/v1/admin/users/${userId}`, { key: adminKey, method: "DELETE" });
}
