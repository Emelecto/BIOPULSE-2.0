import { createClient } from '@supabase/supabase-js';
import './style.css';

// These are public app credentials, also embedded in BioPulse/project.yml.
// Authorization is enforced only by the Edge Function using ADMIN_USER_ID.
const url = import.meta.env.VITE_SUPABASE_URL || 'https://ielprdmmuocajtbimvdx.supabase.co';
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_vBpKxn5X27C-gRvD1iiwpg_5BZ57_2E';
const configured = /^https:\/\//.test(url ?? '') && key && !key.startsWith('YOUR_');
const client = configured ? createClient(url, key, {
  auth: { autoRefreshToken: true, persistSession: false, detectSessionInUrl: false },
}) : null;

const $ = (selector) => document.querySelector(selector);
const login = $('#login-panel');
const dashboard = $('#dashboard');
const status = $('#status');
const grid = $('#metric-grid');

function setStatus(message, error = false) {
  status.textContent = message;
  status.classList.toggle('error', error);
}

function showLogin() {
  login.hidden = false;
  dashboard.hidden = true;
  grid.replaceChildren();
}

function showDashboard() {
  login.hidden = true;
  dashboard.hidden = false;
}

function card(label, value, note, index) {
  const article = document.createElement('article');
  article.className = 'metric-card';
  article.style.setProperty('--index', index);
  const number = Number(value);
  const display = Number.isFinite(number) ? new Intl.NumberFormat('es-CO').format(number) : '—';
  article.innerHTML = `<span class="metric-label"></span><strong></strong><span class="metric-note"></span>`;
  article.querySelector('.metric-label').textContent = label;
  article.querySelector('strong').textContent = display;
  article.querySelector('.metric-note').textContent = note;
  return article;
}

async function loadMetrics() {
  if (!client) return;
  setStatus('Actualizando indicadores…');
  $('#refresh').disabled = true;
  try {
    const { data: { session }, error: sessionError } = await client.auth.getSession();
    if (sessionError || !session) { showLogin(); setStatus('Inicia sesión para continuar.', true); return; }
    const response = await fetch(`${url}/functions/v1/admin-ops`, {
      headers: { Authorization: `Bearer ${session.access_token}`, apikey: key },
      cache: 'no-store',
    });
    const payload = await response.json();
    if (response.status === 401) { showLogin(); setStatus('La sesión venció. Entra de nuevo.', true); return; }
    if (response.status === 403) { showLogin(); await client.auth.signOut(); setStatus('Esta cuenta no tiene acceso al panel interno.', true); return; }
    if (payload.error === 'admin_not_configured') throw new Error('El acceso de administrador aún no está activado en el servidor.');
    if (!response.ok || !payload.metrics) throw new Error('No se pudieron consultar los indicadores. Inténtalo de nuevo.');
    const m = payload.metrics;
    const items = [
      ['Cuentas creadas', m.accounts, 'Total registrado'],
      ['Cuentas nuevas', m.newAccounts7d, 'Últimos 7 días'],
      ['Solicitudes al Coach', m.coachRequestsToday, 'Hoy · UTC'],
      ['Usuarios activos en Coach', m.coachUsersToday, 'Hoy · UTC'],
      ['Eventos de consentimiento', m.syncConsentEvents7d, 'Sincronización · 7 días'],
      ['Eventos de consentimiento', m.coachConsentEvents7d, 'Coach IA · 7 días'],
    ];
    grid.replaceChildren(...items.map((item, index) => card(...item, index)));
    const timestamp = new Date(m.generatedAt);
    $('#updated-at').textContent = Number.isNaN(timestamp.getTime()) ? '' : `Actualizado ${timestamp.toLocaleString('es-CO')}`;
    showDashboard();
    setStatus('Indicadores actualizados.');
  } catch (error) {
    setStatus(error instanceof Error ? error.message : 'No se pudo conectar.', true);
  } finally {
    $('#refresh').disabled = false;
  }
}

$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!client) return;
  const button = $('#login-form button');
  button.disabled = true;
  setStatus('Comprobando acceso…');
  const { error } = await client.auth.signInWithPassword({
    email: $('#email').value.trim(), password: $('#password').value,
  });
  $('#password').value = '';
  button.disabled = false;
  if (error) { setStatus('No se pudo iniciar sesión. Revisa tus credenciales.', true); return; }
  await loadMetrics();
});

$('#refresh').addEventListener('click', loadMetrics);
$('#logout').addEventListener('click', async () => {
  await client?.auth.signOut();
  showLogin();
  setStatus('Sesión cerrada.');
});

if (!client) {
  $('#login-form button').disabled = true;
  setStatus('Configura VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY para usar el panel.', true);
} else {
  client.auth.getSession().then(({ data }) => {
    if (data.session) loadMetrics();
    else setStatus('Panel privado listo para iniciar sesión.');
  });
}
