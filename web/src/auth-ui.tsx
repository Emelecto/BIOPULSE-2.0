import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { Activity, ArrowLeft, ArrowRight, Check, CheckCircle2, Eye, EyeOff, FileUp, KeyRound, LockKeyhole, Mail, RefreshCw, ShieldCheck, Trash2, Watch, X } from "lucide-react";
import { supabase } from "./data";
import { authErrorMessage, authRedirect, passwordValidation } from "./auth-copy";
import { exportSyncedData } from "./account-export";
import "./auth-ui.css";

function AuthBrand() {
  return <span className="auth-brand"><span className="auth-brand-mark" aria-hidden="true">B</span><span>BioPulse</span></span>;
}

function AuthFrame({ eyebrow, title, description, children }: { eyebrow: string; title: string; description: string; children: ReactNode }) {
  return <div className="auth-v2">
    <a className="auth-v2-back" href="/"><ArrowLeft size={17} /> Volver al sitio</a>
    <div className="auth-v2-layout">
      <div className="auth-v2-story"><AuthBrand /><div><span className="auth-v2-eyebrow">TU ESPACIO PERSONAL</span><h1>Más claridad para<br /><em>escuchar tu cuerpo.</em></h1><p>Tus señales, tu contexto y tus decisiones. BioPulse te acompaña desde el primer dato.</p></div><span className="auth-v2-story-foot"><ShieldCheck size={16} /> Tus datos de salud se conectan solo con tu permiso.</span></div>
      <main className="auth-v2-content"><div className="auth-v2-panel"><span className="auth-v2-kicker">{eyebrow}</span><h2>{title}</h2><p className="auth-v2-description">{description}</p>{children}</div><p className="auth-v2-under">BioPulse · Bienestar, en contexto.</p></main>
    </div>
  </div>;
}

function PasswordField({ value, onChange, label = "Contraseña", autoComplete, minLength = 8 }: { value: string; onChange: (value: string) => void; label?: string; autoComplete: string; minLength?: number }) {
  const [visible, setVisible] = useState(false);
  return <label className="auth-v2-field">{label}<span className="auth-v2-input-wrap"><input type={visible ? "text" : "password"} value={value} onChange={(event) => onChange(event.target.value)} autoComplete={autoComplete} minLength={minLength} required /><button type="button" aria-label={visible ? `Ocultar ${label.toLowerCase()}` : `Mostrar ${label.toLowerCase()}`} onClick={() => setVisible(!visible)}>{visible ? <EyeOff size={18} /> : <Eye size={18} />}</button></span></label>;
}

function Feedback({ error, notice }: { error?: string; notice?: string }) {
  return <>{error && <p role="alert" className="auth-v2-feedback is-error">{error}</p>}{notice && <p role="status" className="auth-v2-feedback">{notice}</p>}</>;
}

export function AuthPage() {
  const [mode, setMode] = useState<"login" | "signup" | "recovery">(() => new URLSearchParams(window.location.search).get("mode") === "signup" ? "signup" : "login");
  const [sent, setSent] = useState<"signup" | "recovery" | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [needsConfirmation, setNeedsConfirmation] = useState(false);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!supabase || busy) return;
    setError(""); setNotice(""); setNeedsConfirmation(false);
    if (mode === "signup") {
      const issue = passwordValidation(password, confirmation);
      if (issue) { setError(issue); return; }
    }
    setBusy(true);
    try {
      if (mode === "login") {
        const { error: issue } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
        if (issue) { setError(authErrorMessage(issue, "login")); setNeedsConfirmation(issue.code === "email_not_confirmed"); }
      } else if (mode === "signup") {
        const { error: issue, data } = await supabase.auth.signUp({ email: email.trim(), password, options: { emailRedirectTo: authRedirect("confirm") } });
        if (issue) setError(authErrorMessage(issue, "signup"));
        else if (!data.session) { setPassword(""); setConfirmation(""); setSent("signup"); }
      } else {
        const { error: issue } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: authRedirect("reset") });
        if (issue) setError(authErrorMessage(issue, "recovery"));
        else setSent("recovery");
      }
    } catch { setError("No pudimos conectar ahora. Comprueba tu conexión e inténtalo de nuevo."); }
    finally { setBusy(false); }
  }
  async function resend() {
    if (!supabase || busy) return;
    setBusy(true); setError(""); setNotice("");
    try {
      const result = sent === "signup"
        ? await supabase.auth.resend({ type: "signup", email: email.trim(), options: { emailRedirectTo: authRedirect("confirm") } })
        : await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: authRedirect("reset") });
      if (result.error) setError(authErrorMessage(result.error, "resend"));
      else setNotice("Solicitud recibida. Si corresponde, llegará un nuevo enlace a ese correo.");
    } catch { setError("No pudimos enviar el correo ahora. Inténtalo más tarde."); }
    finally { setBusy(false); }
  }
  function switchMode(next: typeof mode) { setMode(next); setSent(null); setError(""); setNotice(""); setNeedsConfirmation(false); setPassword(""); setConfirmation(""); }
  if (sent) return <AuthFrame eyebrow="REVISA TU CORREO" title={sent === "signup" ? "Un paso para empezar." : "Te ayudamos a volver."} description={sent === "signup" ? "Si este correo puede registrarse, recibirás un enlace para confirmar tu cuenta." : "Si existe una cuenta con ese correo, recibirás un enlace para cambiar la contraseña."}>
    <div className="auth-v2-mail"><Mail size={28} /><strong>{email.trim()}</strong><span>Busca un mensaje de BioPulse. Revisa también spam o promociones.</span></div>
    <Feedback error={error} notice={notice} />
    <button className="auth-v2-primary" type="button" disabled={busy} onClick={resend}><RefreshCw size={17} /> {busy ? "Enviando…" : "Enviar otro enlace"}</button>
    <button className="auth-v2-text" type="button" onClick={() => switchMode("login")}>Volver a iniciar sesión</button>
  </AuthFrame>;
  return <AuthFrame eyebrow="ACCESO BIOPULSE" title={mode === "login" ? "Qué bueno verte." : mode === "signup" ? "Este espacio es tuyo." : "Recupera tu acceso."} description={mode === "login" ? "Entra para continuar leyendo tus señales con contexto." : mode === "signup" ? "Crea tu cuenta. Tú eliges después si conectas datos de salud." : "Escribe tu correo y te enviaremos un enlace si tiene una cuenta."}>
    {mode !== "recovery" && <div className="auth-v2-switch" role="group" aria-label="Acceso"><button type="button" aria-pressed={mode === "login"} onClick={() => switchMode("login")}>Iniciar sesión</button><button type="button" aria-pressed={mode === "signup"} onClick={() => switchMode("signup")}>Crear cuenta</button></div>}
    <form onSubmit={submit} className="auth-v2-form">
      <label className="auth-v2-field">Correo electrónico<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" required /></label>
      {mode !== "recovery" && <PasswordField value={password} onChange={setPassword} autoComplete={mode === "signup" ? "new-password" : "current-password"} minLength={mode === "signup" ? 8 : 1} />}
      {mode === "signup" && <><PasswordField label="Confirmar contraseña" value={confirmation} onChange={setConfirmation} autoComplete="new-password" /><small className="auth-v2-hint">Usa al menos 8 caracteres y una contraseña única.</small></>}
      {mode === "login" && <button className="auth-v2-text is-end" type="button" onClick={() => switchMode("recovery")}>Olvidé mi contraseña</button>}
      <Feedback error={error} notice={notice} />
      {needsConfirmation && <button className="auth-v2-text" type="button" onClick={() => { setSent("signup"); setError(""); }}>Solicitar otro correo de confirmación</button>}
      <button className="auth-v2-primary" type="submit" disabled={busy || !supabase}>{busy ? "Un momento…" : mode === "login" ? "Entrar a BioPulse" : mode === "signup" ? "Crear cuenta" : "Enviar enlace"}<ArrowRight size={17} /></button>
    </form>
    {mode === "login" && <button className="auth-v2-secondary" type="button" disabled={!supabase || busy} onClick={async () => { setError(""); try { const result = await supabase?.auth.signInWithOAuth({ provider: "google", options: { redirectTo: `${location.origin}/app` } }); if (result?.error) setError(authErrorMessage(result.error, "login")); } catch { setError("No pudimos iniciar con Google ahora. Inténtalo más tarde."); } }}>Continuar con Google</button>}
    {mode === "recovery" && <button className="auth-v2-text" type="button" onClick={() => switchMode("login")}>Volver a iniciar sesión</button>}
    {!supabase && <Feedback error="BioPulse todavía no tiene configurado el acceso en este entorno." />}
    <p className="auth-v2-privacy"><ShieldCheck size={17} /> Entrar no activa la sincronización de datos de salud.</p>
  </AuthFrame>;
}

export function ResetPasswordPage({ done }: { done: () => void }) {
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  async function submit(event: FormEvent) {
    event.preventDefault();
    const issue = passwordValidation(password, confirmation);
    if (issue) { setError(issue); return; }
    if (!supabase) return;
    setBusy(true); setError("");
    try {
      const result = await supabase.auth.updateUser({ password });
      if (result.error) setError(authErrorMessage(result.error, "update"));
      else { setPassword(""); setConfirmation(""); setSaved(true); }
    } catch { setError("No pudimos guardar la contraseña ahora. Inténtalo de nuevo."); }
    finally { setBusy(false); }
  }
  return <AuthFrame eyebrow={saved ? "ACCESO RESTABLECIDO" : "NUEVA CONTRASEÑA"} title={saved ? "Ya puedes continuar." : "Volvamos a empezar."} description={saved ? "Tu contraseña se actualizó correctamente." : "Elige una contraseña nueva para proteger tu cuenta."}>
    {saved ? <><div className="auth-v2-complete"><CheckCircle2 size={28} /> Contraseña actualizada</div><button className="auth-v2-primary" type="button" onClick={done}>Entrar a BioPulse <ArrowRight size={17} /></button></> : <form className="auth-v2-form" onSubmit={submit}><PasswordField label="Nueva contraseña" value={password} onChange={setPassword} autoComplete="new-password" /><PasswordField label="Confirmar nueva contraseña" value={confirmation} onChange={setConfirmation} autoComplete="new-password" /><small className="auth-v2-hint">Usa al menos 8 caracteres y una contraseña única.</small><Feedback error={error} /><button className="auth-v2-primary" type="submit" disabled={busy}>{busy ? "Guardando…" : "Guardar nueva contraseña"}<ArrowRight size={17} /></button></form>}
  </AuthFrame>;
}

export function AuthCallbackPage({ kind, confirmed }: { kind: "confirm" | "reset" | "email-change"; confirmed: boolean }) {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const urlError = new URLSearchParams(location.search).get("error") || new URLSearchParams(location.hash.slice(1)).get("error");
  const success = confirmed && !urlError;
  async function resend(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !email.trim()) return;
    setBusy(true); setError(""); setNotice("");
    try {
      const result = kind === "reset"
        ? await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: authRedirect("reset") })
        : await supabase.auth.resend({ type: kind === "email-change" ? "email_change" : "signup", email: email.trim(), options: { emailRedirectTo: authRedirect(kind === "email-change" ? "email-change" : "confirm") } });
      if (result.error) setError(authErrorMessage(result.error, "resend"));
      else setNotice("Solicitud recibida. Si corresponde, recibirás un enlace nuevo.");
    } catch { setError("No pudimos enviar el correo ahora. Inténtalo más tarde."); }
    finally { setBusy(false); }
  }
  return <AuthFrame eyebrow={success ? "ACCESO DISPONIBLE" : "ENLACE NO DISPONIBLE"} title={success ? "Tu espacio está listo." : "Necesitamos un enlace nuevo."} description={success ? "Tienes una sesión activa en BioPulse. Puedes continuar y revisar el estado de tu cuenta en Perfil." : "Este enlace puede haber caducado o ya se usó. Solicita uno nuevo para continuar."}>
    {success ? <><div className="auth-v2-complete"><CheckCircle2 size={28} /> Sesión activa</div><a className="auth-v2-primary" href="/app">Continuar a BioPulse <ArrowRight size={17} /></a></> : <form className="auth-v2-form" onSubmit={resend}><label className="auth-v2-field">Correo electrónico<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" required /></label><Feedback error={error} notice={notice} /><button className="auth-v2-primary" type="submit" disabled={busy || !supabase}>{busy ? "Enviando…" : "Solicitar otro enlace"}<ArrowRight size={17} /></button><a className="auth-v2-text" href="/app">Volver al acceso</a></form>}
  </AuthFrame>;
}

export function WelcomePanel({ onClose, onProfile }: { onClose: () => void; onProfile: () => void }) {
  const panel = useRef<HTMLElement>(null);
  const close = useRef(onClose);
  close.current = onClose;
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    panel.current?.querySelector<HTMLButtonElement>("button")?.focus();
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") { close.current(); return; }
      if (event.key !== "Tab" || !panel.current) return;
      const buttons = [...panel.current.querySelectorAll<HTMLButtonElement>("button:not(:disabled)")];
      if (!buttons.length) return;
      if (event.shiftKey && document.activeElement === buttons[0]) { buttons[buttons.length - 1].focus(); event.preventDefault(); }
      else if (!event.shiftKey && document.activeElement === buttons[buttons.length - 1]) { buttons[0].focus(); event.preventDefault(); }
    }
    window.addEventListener("keydown", onKey);
    return () => { window.removeEventListener("keydown", onKey); previous?.focus(); };
  }, []);
  return <div className="welcome-scrim" role="presentation"><section ref={panel} className="welcome-panel" role="dialog" aria-modal="true" aria-labelledby="welcome-title"><button className="welcome-close" onClick={onClose} aria-label="Cerrar bienvenida"><X size={20} /></button><AuthBrand /><span className="auth-v2-kicker">BIENVENIDO A BIOPULSE</span><h2 id="welcome-title">Empecemos por lo que ya sabes de ti.</h2><p>BioPulse reúne señales observadas y el contexto que eliges añadir. Puedes explorar sin conectar Apple Salud.</p><div className="welcome-steps"><div><span><Activity size={20} /></span><strong>Lee tus señales</strong><small>Los scores solo aparecen cuando hay historial suficiente.</small></div><div><span><FileUp size={20} /></span><strong>Prueba un CSV</strong><small>Se revisa en este navegador y no se envía al servidor.</small></div><div><span><Watch size={20} /></span><strong>Conecta si quieres</strong><small>El puente desde iPhone requiere permisos y consentimientos por separado.</small></div></div><div className="welcome-actions"><button className="auth-v2-primary" onClick={onProfile}>Ir a mis datos <ArrowRight size={17} /></button><button className="auth-v2-secondary" onClick={onClose}>Explorar primero</button></div></section></div>;
}

const consentLabels: Record<string, string> = { profile: "Perfil", settings: "Preferencias", journal: "Diario", derived_metrics: "Resúmenes diarios", intraday_metrics: "Energía por hora" };
type Consent = { data_category: string; decision: string; recorded_at: string };

export function AccountCenter({ email, userId, onDataControls }: { email: string; userId: string; onDataControls: () => void }) {
  const [consents, setConsents] = useState<Consent[]>([]);
  const [coachConsent, setCoachConsent] = useState<string | null>(null);
  const [emailDraft, setEmailDraft] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [consentError, setConsentError] = useState("");
  const [deleteConfirmation, setDeleteConfirmation] = useState("");
  const [deleteError, setDeleteError] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState("");
  const [exportNotice, setExportNotice] = useState("");
  async function refreshConsents() {
    if (!supabase) return;
    const [sync, coach] = await Promise.all([
      supabase.from("sync_consents").select("data_category,decision,recorded_at").eq("user_id", userId).order("id", { ascending: false }).limit(500),
      supabase.from("coach_consents").select("decision").eq("user_id", userId).order("id", { ascending: false }).limit(1),
    ]);
    if (sync.error || coach.error) { setConsentError("No pudimos consultar los consentimientos ahora."); return; }
    const latest = new Map<string, Consent>();
    for (const row of sync.data ?? []) if (!latest.has(row.data_category)) latest.set(row.data_category, row as Consent);
    setConsents([...latest.values()]);
    setCoachConsent(coach.data?.[0]?.decision ?? null);
    setConsentError("");
  }
  useEffect(() => { void refreshConsents(); }, [userId]);
  async function changeEmail(event: FormEvent) {
    event.preventDefault();
    if (!supabase || busy || !emailDraft.trim()) return;
    setBusy(true); setError(""); setNotice("");
    try {
      const result = await supabase.auth.updateUser({ email: emailDraft.trim() }, { emailRedirectTo: authRedirect("email-change") });
      if (result.error) setError(authErrorMessage(result.error, "update"));
      else { setNotice("Solicitamos el cambio. Revisa los mensajes enviados para confirmarlo; tu correo actual sigue activo hasta completar el proceso."); setEmailDraft(""); }
    } catch { setError("No pudimos solicitar el cambio ahora."); }
    finally { setBusy(false); }
  }
  async function changePassword(event: FormEvent) {
    event.preventDefault();
    const issue = passwordValidation(password, confirmation);
    if (issue) { setError(issue); return; }
    if (!supabase || busy) return;
    setBusy(true); setError(""); setNotice("");
    try {
      const result = await supabase.auth.updateUser({ password });
      if (result.error) setError(authErrorMessage(result.error, "update"));
      else { setNotice("Contraseña actualizada. Si no reconoces este cambio, recupera tu acceso desde la pantalla de inicio."); setPassword(""); setConfirmation(""); }
    } catch { setError("No pudimos cambiar la contraseña ahora."); }
    finally { setBusy(false); }
  }
  async function deleteAccount(event: FormEvent) {
    event.preventDefault();
    if (!supabase || deleting || exporting || deleteConfirmation !== "ELIMINAR") return;
    setDeleting(true); setDeleteError("");
    let remoteDeleted = false;
    try {
      const result = await supabase.functions.invoke("account-delete", { body: { confirmation: "ELIMINAR" } });
      if (result.error || result.data?.deleted !== true) {
        setDeleteError("No pudimos confirmar la eliminación. Comprueba tu cuenta antes de intentarlo otra vez.");
        return;
      }
      remoteDeleted = true;
      await supabase.auth.signOut({ scope: "local" });
      const local = await supabase.auth.getSession();
      if (local.data.session) {
        setDeleteError("La cuenta se eliminó, pero no pudimos limpiar la sesión de este navegador. Cierra esta pestaña y borra los datos del sitio.");
        return;
      }
      window.location.assign("/app");
    } catch {
      setDeleteError(remoteDeleted
        ? "Tu cuenta se eliminó. Cierra esta pestaña para terminar de salir de BioPulse."
        : "No pudimos confirmar la eliminación. Vuelve a abrir BioPulse antes de intentar otra acción.");
    } finally { setDeleting(false); }
  }
  async function downloadData() {
    if (!supabase || exporting || deleting) return;
    setExporting(true); setExportError(""); setExportNotice("");
    try {
      const payload = await exportSyncedData(supabase, userId);
      const url = URL.createObjectURL(new Blob([JSON.stringify(payload, null, 2)], { type: "application/json;charset=utf-8" }));
      const link = document.createElement("a");
      link.href = url;
      link.download = `biopulse-datos-${new Date().toISOString().slice(0, 10)}.json`;
      document.body.appendChild(link);
      link.click(); link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
      setExportNotice("Tu copia está lista para descargar. Guárdala en un lugar privado.");
    } catch (issue) {
      setExportError(issue instanceof Error ? issue.message : "No pudimos completar la descarga.");
    } finally { setExporting(false); }
  }
  return <section className="account-center" aria-labelledby="account-center-title"><div className="section-title"><h2 id="account-center-title">Cuenta y privacidad</h2><p>Todo bajo tu control</p></div><div className="account-center-grid"><div className="account-center-card"><span className="auth-v2-kicker"><KeyRound size={15} /> SEGURIDAD</span><h3>Tu acceso</h3><p>Correo actual: <strong>{email}</strong></p><details><summary>Cambiar correo <ArrowRight size={16} /></summary><form onSubmit={changeEmail}><label className="auth-v2-field">Nuevo correo<input type="email" value={emailDraft} onChange={(event) => setEmailDraft(event.target.value)} autoComplete="email" required /></label><button className="auth-v2-secondary" disabled={busy}>Solicitar cambio</button></form></details><details><summary>Cambiar contraseña <ArrowRight size={16} /></summary><form onSubmit={changePassword}><PasswordField label="Nueva contraseña" value={password} onChange={setPassword} autoComplete="new-password" /><PasswordField label="Confirmar contraseña" value={confirmation} onChange={setConfirmation} autoComplete="new-password" /><button className="auth-v2-secondary" disabled={busy}>Guardar contraseña</button></form></details><Feedback error={error} notice={notice} /></div><div className="account-center-card"><span className="auth-v2-kicker"><ShieldCheck size={15} /> PRIVACIDAD</span><h3>Tus consentimientos</h3><p>Entrar a BioPulse no concede permisos de salud.</p><ul className="account-consent-list">{Object.entries(consentLabels).map(([key, label]) => { const item = consents.find((entry) => entry.data_category === key); return <li key={key}><span>{label}</span><strong className={item?.decision === "granted" ? "is-granted" : ""}>{item?.decision === "granted" ? "Permitido" : item?.decision === "revoked" ? "Revocado" : "Sin activar"}</strong></li>; })}<li><span>Coach IA</span><strong className={coachConsent === "granted" ? "is-granted" : ""}>{coachConsent === "granted" ? "Permitido" : coachConsent === "revoked" ? "Revocado" : "Sin activar"}</strong></li></ul>{consentError && <Feedback error={consentError} />}<button className="auth-v2-text" type="button" onClick={() => void refreshConsents()}><RefreshCw size={15} /> Actualizar estados</button></div></div><div className="account-center-actions"><button type="button" onClick={onDataControls}><LockKeyhole size={18} /> Gestionar y eliminar datos sincronizados <ArrowRight size={16} /></button><button type="button" onClick={() => void supabase?.auth.signOut()}><ArrowLeft size={18} /> Cerrar sesión</button></div><div className="account-export"><h3>Una copia para ti</h3><p>Descarga tu perfil, preferencias, Diario web, registros sincronizados y consentimientos. No incluye Apple Salud original, CSV local, datos guardados solo en iOS ni la memoria temporal del Coach.</p><button className="auth-v2-secondary" type="button" disabled={exporting || deleting} onClick={downloadData}>{exporting ? "Preparando tu copia…" : "Descargar datos sincronizados"}</button><Feedback error={exportError} notice={exportNotice} /></div><details className="account-delete"><summary><Trash2 size={17} /> Eliminar mi cuenta BioPulse</summary><p>Esta acción elimina tu acceso y los datos asociados a tu cuenta en BioPulse. No borra las mediciones originales de Apple Salud ni archivos CSV que conserves en tu dispositivo. No se puede deshacer.</p><form onSubmit={deleteAccount}><label className="auth-v2-field"><span>Escribe <strong>ELIMINAR</strong> para confirmar</span><input type="text" value={deleteConfirmation} onChange={(event) => setDeleteConfirmation(event.target.value)} autoComplete="off" spellCheck={false} aria-label="Escribe ELIMINAR para confirmar" /></label><button className="account-delete-button" type="submit" disabled={deleting || exporting || deleteConfirmation !== "ELIMINAR"}>{deleting ? "Eliminando…" : "Eliminar cuenta definitivamente"}</button></form><Feedback error={deleteError} /></details><p className="account-center-note"><Check size={15} /> El CSV local no se almacena en tu cuenta ni en el servidor.</p></section>;
}
