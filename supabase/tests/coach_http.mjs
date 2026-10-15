// Local-only HTTP smoke test. Run while `supabase functions serve coach --no-verify-jwt` is active.
import assert from 'node:assert/strict';
import { execSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const lines = execSync('supabase status -o env', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
const env = Object.fromEntries(lines.split(/\r?\n/).filter((line) => /^[A-Z_]+=/.test(line)).map((line) => {
  const separator = line.indexOf('=');
  return [line.slice(0, separator), line.slice(separator + 1).replace(/^"|"$/g, '')];
}));
const { API_URL, FUNCTIONS_URL, ANON_KEY, SERVICE_ROLE_KEY } = env;
if (!API_URL || !FUNCTIONS_URL || !ANON_KEY || !SERVICE_ROLE_KEY) throw new Error('Local Supabase credentials unavailable');

const email = `coach-smoke-${randomUUID()}@example.test`;
const password = `${randomUUID()}!Ab9`;
let userID;

const adminHeaders = { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' };
async function send(action, token, extra = {}) {
  const result = await fetch(`${FUNCTIONS_URL}/coach`, {
    method: 'POST',
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, ...extra }),
  });
  return [result.status, await result.json()];
}

try {
  const create = await fetch(`${API_URL}/auth/v1/admin/users`, {
    method: 'POST', headers: adminHeaders,
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!create.ok) throw new Error(`Local test account creation failed (${create.status})`);
  userID = (await create.json()).id;

  const signIn = await fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST', headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!signIn.ok) throw new Error(`Local test sign-in failed (${signIn.status})`);
  const token = (await signIn.json()).access_token;

  let [status, body] = await send('consent_status', token);
  assert.equal(status, 200);
  assert.equal(body.consented, false);
  [status, body] = await send('send', token, { messages: [{ role: 'user', content: 'Hola' }] });
  assert.equal(status, 403);
  [status] = await send('grant_consent', token);
  assert.equal(status, 200);
  [status, body] = await send('send', token, { messages: [{ role: 'user', content: 'Tengo dolor en el pecho' }] });
  assert.equal(status, 200);
  assert.match(body.answer, /atención urgente/);
  assert.equal(body.memoryUpdated, false);
  [status] = await send('clear_memory', token);
  assert.equal(status, 200);
  [status] = await send('revoke_consent', token);
  assert.equal(status, 200);
  [status, body] = await send('send', token, { messages: [{ role: 'user', content: 'Hola' }] });
  assert.equal(status, 403);
  console.log('Coach local HTTP: consent, urgent path, memory clear and revocation PASS');
} finally {
  if (userID) {
    const remove = await fetch(`${API_URL}/auth/v1/admin/users/${userID}`, { method: 'DELETE', headers: adminHeaders });
    if (!remove.ok) console.error(`Local test account cleanup failed (${remove.status})`);
  }
}
