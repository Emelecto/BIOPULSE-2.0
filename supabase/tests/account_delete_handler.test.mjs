import { test } from "node:test";
import assert from "node:assert/strict";
import { createAccountDeleteHandler } from "../functions/account-delete/handler.ts";

function fixture(overrides = {}) {
  const deleted = [];
  const authenticated = [];
  const handler = createAccountDeleteHandler({
    configured: true,
    authenticatedUser: async (bearer) => { authenticated.push(bearer); return { id: "verified-owner" }; },
    deleteUser: async (id) => { deleted.push(id); return true; },
    ...overrides,
  });
  return { handler, deleted, authenticated };
}
function request(body = { confirmation: "ELIMINAR" }, options = {}) {
  return new Request("https://biopulse.test/account-delete", {
    method: "POST",
    headers: { Authorization: "Bearer test-session", "Content-Type": "application/json" },
    body: JSON.stringify(body),
    ...options,
  });
}

test("preflight and unsupported methods never delete", async () => {
  const { handler, deleted } = fixture();
  const preflight = await handler(new Request("https://biopulse.test", { method: "OPTIONS" }));
  assert.equal(preflight.status, 200);
  assert.equal(preflight.headers.get("Cache-Control"), "no-store");
  assert.equal((await handler(new Request("https://biopulse.test"))).status, 405);
  assert.deepEqual(deleted, []);
});
test("missing configuration and invalid sessions fail closed", async () => {
  for (const overrides of [{ configured: false }, { authenticatedUser: async () => null }]) {
    const { handler, deleted } = fixture(overrides);
    assert.ok([401, 503].includes((await handler(request())).status));
    assert.deepEqual(deleted, []);
  }
  const { handler, deleted, authenticated } = fixture();
  assert.equal((await handler(request({}, { headers: {} }))).status, 401);
  assert.equal((await handler(request({}, { headers: { Authorization: "Bearer " } }))).status, 401);
  assert.deepEqual(authenticated, []);
  assert.deepEqual(deleted, []);
});
test("confirmation is explicit and malformed inputs cannot delete", async () => {
  const { handler, deleted } = fixture();
  for (const body of [null, [], {}, { confirmation: "eliminar" }, { confirmation: true }]) {
    assert.equal((await handler(request(body))).status, 400);
  }
  assert.equal((await handler(request({}, { body: "{" }))).status, 400);
  assert.deepEqual(deleted, []);
});
test("body size is limited even without Content-Length", async () => {
  const { handler, deleted } = fixture();
  assert.equal((await handler(request({ confirmation: "ELIMINAR", extra: "x".repeat(300) }))).status, 413);
  assert.deepEqual(deleted, []);
});
test("forged account ID never changes the verified deletion target", async () => {
  const { handler, deleted, authenticated } = fixture();
  const response = await handler(request({ confirmation: "ELIMINAR", user_id: "someone-else" }));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { deleted: true });
  assert.deepEqual(authenticated, ["Bearer test-session"]);
  assert.deepEqual(deleted, ["verified-owner"]);
});
test("service failures do not claim successful deletion or expose internals", async () => {
  for (const deleteUser of [async () => false, async () => { throw new Error("private-server-detail"); }]) {
    const { handler } = fixture({ deleteUser });
    const response = await handler(request());
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: "deletion_failed" });
  }
});
