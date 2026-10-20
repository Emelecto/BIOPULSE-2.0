// Local-only integration test. Uses two synthetic accounts and never contacts production.
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
const password = randomBytes(24).toString("hex");
const accounts = [];

async function request(path, { key = anonKey, token = key, body, method = "POST" } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: { apikey: key, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, payload: await response.json().catch(() => ({})) };
}

async function createAccount() {
  const email = `delete-${randomUUID()}@biopulse.test`;
  const created = await request("/auth/v1/admin/users", {
    key: adminKey,
    body: { email, password, email_confirm: true },
  });
  assert.equal(created.status, 200, `Local user creation failed: ${JSON.stringify(created.payload)}`);
  accounts.push(created.payload.id);
  const login = await request("/auth/v1/token?grant_type=password", { body: { email, password } });
  assert.equal(login.status, 200);
  return { id: created.payload.id, jwt: login.payload.access_token };
}

const ownedTables = [
  ["profiles", "id"], ["user_settings", "user_id"], ["sync_consents", "user_id"],
  ["journal_entries", "user_id"], ["coach_consents", "user_id"], ["coach_memories", "user_id"],
  ["coach_usage", "user_id"], ["daily_metric_summaries", "user_id"],
  ["health_bridge_connections", "user_id"], ["intraday_metric_summaries", "user_id"],
  ["sleep_stage_summaries", "user_id"],
];

async function seedAccount(userId) {
  const now = new Date().toISOString();
  const rows = [
    ["sync_consents", { data_category: "journal", decision: "granted", policy_version: "synthetic-test-v1" }],
    ["journal_entries", { category: "event", title: "Synthetic test only", notes: "No real health information", occurred_at: now, timezone_identifier: "UTC" }],
    ["coach_consents", { decision: "granted", policy_version: "synthetic-test-v1" }],
    ["coach_memories", { summary: "Synthetic test only", expires_at: new Date(Date.now() + 86_400_000).toISOString() }],
    ["coach_usage", { window_start: now, request_count: 1 }],
    ["daily_metric_summaries", { local_date: "2026-10-19", timezone_identifier: "UTC", metric_kind: "steps", value: 10, unit: "count", aggregation: "sum", sample_count: 1, quality: "observed", source_kind: "csv_aggregate", formula_version: "synthetic-test-v1" }],
    ["health_bridge_connections", { token_hash: randomBytes(32).toString("hex") }],
    ["intraday_metric_summaries", { bucket_start: "2026-10-19T12:00:00Z", local_date: "2026-10-19", timezone_identifier: "UTC", metric_kind: "steps", value: 10, unit: "count", aggregation: "sum" }],
    ["sleep_stage_summaries", { local_date: "2026-10-19", stage: "core", minutes: 60 }],
  ];
  for (const [table, row] of rows) {
    const result = await request(`/rest/v1/${table}`, { key: adminKey, body: { user_id: userId, ...row } });
    assert.equal(result.status, 201, `Cannot seed ${table}: ${JSON.stringify(result.payload)}`);
  }
}

try {
  const owner = await createAccount();
  const other = await createAccount();
  await seedAccount(owner.id);
  await seedAccount(other.id);
  const invoke = (token, body) => request("/functions/v1/account-delete", { token, body });

  assert.equal((await invoke(anonKey, { confirmation: "ELIMINAR" })).status, 401);
  assert.equal((await invoke(owner.jwt, { confirmation: "eliminar" })).status, 400);
  assert.equal((await request(`/auth/v1/admin/users/${owner.id}`, { key: adminKey, method: "GET" })).status, 200);

  // A forged client-supplied ID must never select the account to delete.
  const deleted = await invoke(owner.jwt, { confirmation: "ELIMINAR", user_id: other.id });
  assert.equal(deleted.status, 200, JSON.stringify(deleted.payload));
  assert.equal(deleted.payload.deleted, true);
  assert.equal((await request(`/auth/v1/admin/users/${owner.id}`, { key: adminKey, method: "GET" })).status, 404);
  assert.equal((await request(`/auth/v1/admin/users/${other.id}`, { key: adminKey, method: "GET" })).status, 200);

  for (const [table, ownerField] of ownedTables) {
    const ownerRows = await request(`/rest/v1/${table}?select=${ownerField}&${ownerField}=eq.${owner.id}`, { key: adminKey, method: "GET" });
    assert.equal(ownerRows.status, 200);
    assert.equal(ownerRows.payload.length, 0, `${table} did not cascade after Auth deletion`);
    const otherRows = await request(`/rest/v1/${table}?select=${ownerField}&${ownerField}=eq.${other.id}`, { key: adminKey, method: "GET" });
    assert.equal(otherRows.status, 200);
    assert.ok(otherRows.payload.length > 0, `Other account's ${table} was removed`);
  }
  assert.equal((await invoke(owner.jwt, { confirmation: "ELIMINAR" })).status, 401);
  console.log("Account deletion local HTTP: authorization, confirmation, ownership and cascade passed.");
} finally {
  for (const id of accounts) {
    await request(`/auth/v1/admin/users/${id}`, { key: adminKey, method: "DELETE" });
  }
}
