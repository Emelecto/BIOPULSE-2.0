import React, { useCallback, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import type { Session } from "@supabase/supabase-js";
import "@fontsource/dm-sans/latin-400.css";
import "@fontsource/dm-sans/latin-500.css";
import "@fontsource/dm-sans/latin-600.css";
import "@fontsource/dm-sans/latin-700.css";
import "@fontsource/manrope/latin-600.css";
import "@fontsource/manrope/latin-700.css";
import "@fontsource/manrope/latin-800.css";
import {
  Activity,
  ArrowDownRight,
  ArrowRight,
  BookOpen,
  ChevronLeft,
  ChevronRight,
  Heart,
  HeartPulse,
  Home,
  LockKeyhole,
  LogOut,
  Menu,
  Moon,
  Plus,
  RefreshCw,
  Send,
  ShieldCheck,
  Sparkles,
  Trash2,
  TrendingUp,
  UserRound,
  Watch,
  X,
  Zap,
} from "lucide-react";
import {
  automationLink,
  bridge,
  configured,
  dateLabel,
  daysAgo,
  formatMetric,
  journalConsent,
  latest,
  loadJournal,
  loadMetrics,
  phoneBridgeReady,
  supabase,
  timeLabel,
  today,
  type BridgeStatus,
  type Daily,
  type Hourly,
  type Journal,
  type Sleep,
} from "./data";
import { bioScore, changeSignal, scoreColor, sleepScore, type ScoreResult } from "./scoring";
import "./style.css";

type Tab = "Hoy" | "Tendencias" | "Diario" | "Sueño" | "Perfil";
const tabs: {
  name: Tab;
  icon: React.ComponentType<{ size?: number; strokeWidth?: number }>;
}[] = [
  { name: "Hoy", icon: Home },
  { name: "Tendencias", icon: TrendingUp },
  { name: "Diario", icon: BookOpen },
  { name: "Sueño", icon: Moon },
  { name: "Perfil", icon: UserRound },
];
const metricNames: Record<string, string> = {
  hrv_sdnn: "HRV media",
  resting_heart_rate: "FC en reposo",
  sleep_duration: "Sueño",
  steps: "Pasos",
  active_energy: "Energía activa",
  heart_rate: "Frecuencia cardiaca",
};
const emptyMetrics = {
  daily: [] as Daily[],
  hourly: [] as Hourly[],
  sleep: [] as Sleep[],
};
function Brand({ light = false }: { light?: boolean }) {
  return (
    <span className={`brand ${light ? "brand-light" : ""}`}>
      <Activity size={27} strokeWidth={2.4} aria-hidden="true" /> BioPulse
    </span>
  );
}
function Btn({
  children,
  onClick,
  secondary = false,
  disabled = false,
  type = "button",
  className = "",
}: {
  children: React.ReactNode;
  onClick?: () => void;
  secondary?: boolean;
  disabled?: boolean;
  type?: "button" | "submit";
  className?: string;
}) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`action ${secondary ? "action-secondary" : ""} ${className}`}
    >
      {children}
    </button>
  );
}
function Card({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <section className={`card ${className}`}>{children}</section>;
}
function Empty({
  title,
  children,
}: {
  title: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="empty-state">
      <span className="empty-line" />
      <strong>{title}</strong>
      {children && <p>{children}</p>}
    </div>
  );
}
function Header({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <header className="page-heading">
      <div>
        <span className="eyebrow">BIOPULSE / {title.toUpperCase()}</span>
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>
      <span className="heading-mark" aria-hidden="true">
        <Activity size={25} />
      </span>
    </header>
  );
}

function Landing() {
  const [menu, setMenu] = useState(false);
  return (
    <div className="landing">
      <a className="skip" href="#contenido">
        Saltar al contenido
      </a>
      <header className="land-nav">
        <a href="/" aria-label="BioPulse, inicio">
          <Brand />
        </a>
        <button
          className="menu-button"
          type="button"
          onClick={() => setMenu(!menu)}
          aria-label="Abrir navegación"
          aria-expanded={menu}
        >
          <Menu />
        </button>
        <nav className={menu ? "nav-open" : ""} aria-label="Navegación">
          <a href="#metodo" onClick={() => setMenu(false)}>
            Cómo funciona
          </a>
          <a href="#privacidad" onClick={() => setMenu(false)}>
            Privacidad
          </a>
          <a href="#preguntas" onClick={() => setMenu(false)}>
            Preguntas
          </a>
          <a className="nav-open-app" href="/app">
            Abrir app web <ArrowRight size={16} />
          </a>
        </nav>
      </header>
      <main id="contenido">
        <section className="land-hero">
          <div className="land-glow" aria-hidden="true" />
          <div className="land-hero-copy">
            <p className="eyebrow">
              <span className="live-pip" /> BIENESTAR, EN CONTEXTO
            </p>
            <h1>
              Tu cuerpo da señales.
              <br />
              <em>Entiéndelas juntas.</em>
            </h1>
            <p className="land-lead">
              Sueño, actividad y lo que vives cada día. BioPulse reúne tus
              registros reales para ayudarte a observar patrones sin convertir
              una señal en un diagnóstico.
            </p>
            <div className="land-buttons">
              <a className="action" href="/app">
                Abrir app web <ArrowRight size={18} />
              </a>
              <a className="action action-secondary" href="#ios">
                iOS próximamente <ArrowDownRight size={18} />
              </a>
            </div>
            <span className="land-subnote">
              La web funciona con cuenta · iOS aún no está en App Store
            </span>
          </div>
          <div
            className="land-visual"
            aria-label="Vista conceptual de BioPulse sin valores ficticios"
          >
            <div className="preview-top">
              HOY <span>DATOS REALES · SIN CÁLCULOS INVENTADOS</span>
            </div>
            <div className="preview-ring">
              <div className="ring-orbit one" />
              <div className="ring-orbit two" />
              <div className="ring-core">
                <small>BIO SCORE</small>
                <b>—</b>
                <span>en desarrollo</span>
              </div>
            </div>
            <div className="preview-cards">
              <div>
                <Moon size={17} /> Sueño <strong>—</strong>
              </div>
              <div>
                <HeartPulse size={17} /> HRV <strong>—</strong>
              </div>
            </div>
            <p>La claridad también consiste en mostrar lo que falta.</p>
          </div>
          <div className="land-vertical">
            01 / 04 · OBSERVAR ANTES DE CONCLUIR
          </div>
        </section>
        <section className="land-section land-method" id="metodo">
          <div className="section-index">
            01 <span>/</span> LA IDEA
          </div>
          <div className="land-columns">
            <h2>
              Una señal sola
              <br />
              no cuenta <em>toda</em>
              <br />
              la historia.
            </h2>
            <div>
              <p className="land-intro">
                Sueño, movimiento y contexto se leen mejor juntos.
              </p>
              <p>
                Cuando hay registros, BioPulse muestra tendencias observadas, su
                procedencia y sus huecos. Puedes acompañarlas con entradas de
                diario para reflexionar, sin presentar asociaciones como causas.
              </p>
              <a href="/app" className="line-link">
                Explorar mi espacio <ArrowRight size={17} />
              </a>
            </div>
          </div>
          <div className="signal-rail">
            <span>
              <Moon size={18} /> Sueño
            </span>
            <i />
            <span>
              <Zap size={18} /> Actividad
            </span>
            <i />
            <span>
              <BookOpen size={18} /> Contexto
            </span>
            <i />
            <strong>Una lectura más completa</strong>
          </div>
        </section>
        <section className="land-section land-privacy" id="privacidad">
          <div className="section-index">
            02 <span>/</span> CONTROL
          </div>
          <h2>
            Tus datos.
            <br />
            <em>Tus decisiones.</em>
          </h2>
          <div className="privacy-grid">
            <div>
              <ShieldCheck />
              <h3>Cuenta obligatoria</h3>
              <p>
                Solo tú accedes a tu espacio. Crear una cuenta no sincroniza
                Salud ni el Diario automáticamente.
              </p>
            </div>
            <div>
              <Watch />
              <h3>Un puente opcional</h3>
              <p>
                Health Auto Export puede enviar resúmenes diarios y, si lo
                autorizas aparte, energía por hora. No enviamos muestras
                originales.
              </p>
            </div>
            <div>
              <LockKeyhole />
              <h3>Revocable</h3>
              <p>
                Puedes detener la conexión desde BioPulse y eliminar los
                resúmenes recibidos. Los índices personales requieren historial suficiente y muestran cómo se calcularon.
              </p>
            </div>
          </div>
        </section>
        <section className="land-section land-platform" id="ios">
          <div className="section-index">
            03 <span>/</span> DÓNDE USARLO
          </div>
          <div>
            <h2>
              Empieza en la web.
              <br />
              <em>Continúa en iOS.</em>
            </h2>
            <p>
              La app web es la forma más sencilla de probar el proyecto hoy. La
              instalación pública en iPhone llegará cuando exista distribución
              oficial; por ahora no hay enlace de App Store.
            </p>
            <a className="action" href="/app">
              Entrar a BioPulse <ArrowRight size={18} />
            </a>
          </div>
          <div className="platform-slate">
            <span>WEB APP</span>
            <strong>Disponible para probar</strong>
            <small>Con cuenta y conexión opcional de Health Auto Export</small>
            <span className="platform-divider" />
            <span>APP IOS</span>
            <strong>En desarrollo</strong>
            <small>No disponible para descarga pública</small>
          </div>
        </section>
        <section className="land-section land-faq" id="preguntas">
          <div className="section-index">
            04 <span>/</span> PREGUNTAS
          </div>
          <h2>
            Lo importante,
            <br />
            <em>sin letra pequeña.</em>
          </h2>
          <div className="faq-list">
            <details>
              <summary>¿Necesito un Apple Watch?</summary>
              <p>
                No siempre. Health Auto Export usa los datos que tengas en Apple
                Salud; la disponibilidad de cada señal depende de tus fuentes y
                permisos.
              </p>
            </details>
            <details>
              <summary>¿La web lee Apple Salud directamente?</summary>
              <p>
                No. Los navegadores no tienen acceso a HealthKit. En iPhone,
                Health Auto Export actúa como puente opcional y envía solo
                agregados autorizados.
              </p>
            </details>
            <details>
              <summary>¿BioScore está disponible?</summary>
              <p>
                Sí, como índice exploratorio cuando hay suficientes días observados.
                Puedes consultar los componentes y la fecha; todavía no tiene validación clínica.
              </p>
            </details>
            <details>
              <summary>¿Da diagnósticos o tratamientos?</summary>
              <p>
                No. BioPulse organiza información de bienestar; ante síntomas
                graves busca atención médica.
              </p>
            </details>
          </div>
        </section>
      </main>
      <footer className="land-footer">
        <Brand />
        <p>Bienestar, en contexto.</p>
        <a href="/app">
          Abrir app web <ArrowRight size={16} />
        </a>
        <small>
          BioPulse es un MVP de ciencia de datos. No sustituye atención médica.
          Antes de un lanzamiento público faltan políticas legales revisadas,
          soporte y distribución iOS.
        </small>
      </footer>
    </div>
  );
}

function Auth() {
  const [mode, setMode] = useState<"login" | "signup" | "recovery">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!supabase) return;
    setBusy(true);
    setError("");
    setNotice("");
    const result =
      mode === "login"
        ? await supabase.auth.signInWithPassword({ email, password })
        : mode === "signup"
          ? await supabase.auth.signUp({
              email,
              password,
              options: { emailRedirectTo: `${location.origin}/app` },
            })
          : await supabase.auth.resetPasswordForEmail(email, {
              redirectTo: `${location.origin}/app`,
            });
    setBusy(false);
    if (result.error) setError(result.error.message);
    else if (mode === "signup")
      setNotice(
        "Revisa tu correo para confirmar la cuenta. El enlace regresará a esta web.",
      );
    else if (mode === "recovery")
      setNotice("Te enviamos un enlace para restablecer tu contraseña.");
  }
  return (
    <div className="auth-page">
      <a href="/" className="auth-back">
        <ChevronLeft size={17} /> Volver al sitio
      </a>
      <div className="auth-grid">
        <div className="auth-story">
          <Brand />
          <span className="eyebrow">TU ESPACIO PERSONAL</span>
          <h1>
            Entender empieza
            <br />
            <em>por observar.</em>
          </h1>
          <p>
            Entra para ver tus señales reales, llevar tu Diario y conectar Apple
            Salud solo si tú lo decides.
          </p>
          <div className="auth-art">
            <Activity size={53} strokeWidth={1} />
          </div>
        </div>
        <Card className="auth-card">
          <p className="eyebrow">ACCESO SEGURO</p>
          <h2>
            {mode === "login"
              ? "Bienvenido de nuevo"
              : mode === "signup"
                ? "Crea tu cuenta"
                : "Recupera tu acceso"}
          </h2>
          <p>Tu cuenta es necesaria para usar BioPulse.</p>
          {!configured && (
            <div className="notice error">
              Falta configurar VITE_SUPABASE_URL y
              VITE_SUPABASE_PUBLISHABLE_KEY.
            </div>
          )}
          <div className="auth-switch">
            <button
              className={mode === "login" ? "selected" : ""}
              onClick={() => setMode("login")}
            >
              Iniciar sesión
            </button>
            <button
              className={mode === "signup" ? "selected" : ""}
              onClick={() => setMode("signup")}
            >
              Crear cuenta
            </button>
          </div>
          <form onSubmit={submit}>
            <label>
              Correo electrónico
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
                required
              />
            </label>
            {mode !== "recovery" && (
              <label>
                Contraseña
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete={
                    mode === "signup" ? "new-password" : "current-password"
                  }
                  minLength={6}
                  required
                />
              </label>
            )}
            {mode === "login" && (
              <button
                type="button"
                className="text-button forgot"
                onClick={() => setMode("recovery")}
              >
                Olvidé mi contraseña
              </button>
            )}
            {error && (
              <div role="alert" className="notice error">
                {error}
              </div>
            )}
            {notice && (
              <div role="status" className="notice">
                {notice}
              </div>
            )}
            <Btn type="submit" disabled={busy || !configured}>
              {busy
                ? "Un momento…"
                : mode === "login"
                  ? "Iniciar sesión"
                  : mode === "signup"
                    ? "Crear cuenta"
                    : "Enviar enlace"}
              <ArrowRight size={17} />
            </Btn>
          </form>
          {mode === "login" && (
            <button
              className="action action-secondary google-button"
              onClick={async () => {
                const result = await supabase?.auth.signInWithOAuth({
                  provider: "google",
                  options: { redirectTo: `${location.origin}/app` },
                });
                if (result?.error) setError(result.error.message);
              }}
              disabled={!configured}
            >
              Continuar con Google
            </button>
          )}
          {mode === "recovery" && (
            <button className="text-button" onClick={() => setMode("login")}>
              Volver al inicio de sesión
            </button>
          )}
          <p className="auth-foot">
            <ShieldCheck size={16} /> Iniciar sesión no activa ninguna
            sincronización.
          </p>
        </Card>
      </div>
    </div>
  );
}

function ResetPassword({ done }: { done: () => void }) {
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!supabase) return;
    setBusy(true);
    const result = await supabase.auth.updateUser({ password });
    setBusy(false);
    if (result.error) setError(result.error.message);
    else done();
  }
  return (
    <div className="auth-page">
      <div className="reset-wrap">
        <Card className="auth-card">
          <Brand light />
          <h2>Crea una contraseña nueva</h2>
          <p>El enlace de recuperación te trajo de vuelta a BioPulse.</p>
          <form onSubmit={submit}>
            <label>
              Nueva contraseña
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                minLength={8}
                autoComplete="new-password"
                required
              />
            </label>
            {error && (
              <p role="alert" className="notice error">
                {error}
              </p>
            )}
            <Btn type="submit" disabled={busy}>
              Guardar contraseña
            </Btn>
          </form>
        </Card>
      </div>
    </div>
  );
}

function BarChart({
  rows,
  tall = false,
  label,
}: {
  rows: { key: string; value: number }[];
  tall?: boolean;
  label: string;
}) {
  if (!rows.length)
    return (
      <Empty title="Sin registros suficientes">
        Aparecerán aquí cuando se reciban agregados reales.
      </Empty>
    );
  const max = Math.max(...rows.map((r) => r.value), 1);
  return (
    <div
      role="img"
      aria-label={`${label}: ${rows.map((r) => `${r.key} ${r.value.toFixed(1)}`).join(", ")}`}
      className={`bar-chart ${tall ? "bar-chart-tall" : ""}`}
    >
      <div className="bars">
        {rows.map((r) => (
          <div className="bar-slot" key={r.key}>
            <span
              className="bar"
              style={{ height: `${Math.max(3, (r.value / max) * 100)}%` }}
            />
            <small>{r.key}</small>
          </div>
        ))}
      </div>
    </div>
  );
}
function Ring({
  title,
  compact = false,
  score,
}: {
  title: string;
  compact?: boolean;
  score?: ScoreResult;
}) {
  const tint = scoreColor(score?.value ?? null);
  return (
    <div className={`score-ring ${compact ? "ring-compact" : ""}`} role="img" style={tint ? { color: tint } : undefined} aria-label={score?.value === null ? `${title}: ${score.reason}` : `${title}: ${score?.value ?? "sin datos"} de 100`}>
      <div className="ring-layer ring-a" />
      <div className="ring-layer ring-b" />
      <div className="ring-layer ring-c" />
      <div className="score-center">
        <span>{title}</span>
        <strong>{score?.value ?? "—"}</strong>
        <small>{score?.value === null ? "datos insuficientes" : score ? `Índice exploratorio · ${dateLabel(score.date)}` : "cálculo pendiente"}</small>
      </div>
    </div>
  );
}
function MetricCard({
  title,
  row,
  history,
  icon: Icon,
  note,
  onClick,
}: {
  title: string;
  row?: Daily;
  history: Daily[];
  icon: React.ComponentType<{ size?: number }>;
  note: string;
  onClick: () => void;
}) {
  return (
    <button type="button" className="card metric-card" onClick={onClick}>
      <span className="metric-head">
        {title}
        <Icon size={17} />
      </span>
      <strong>{formatMetric(row)}</strong>
      <div className="mini-bars" aria-hidden="true">
        {history.length ? (
          history
            .slice(-7)
            .reverse()
            .map((point) => (
              <i
                key={point.local_date}
                style={{
                  height: `${Math.max(15, (point.value / Math.max(...history.map((x) => x.value), 1)) * 100)}%`,
                }}
              />
            ))
        ) : (
          <span className="mini-empty" />
        )}
      </div>
      <small>{note}</small>
    </button>
  );
}

function Today({
  daily,
  hourly,
  onJournal,
  onMetric,
  onConnect,
  targetMinutes,
}: {
  daily: Daily[];
  hourly: Hourly[];
  onJournal: () => void;
  onMetric: (kind: string) => void;
  onConnect: () => void;
  targetMinutes: number;
}) {
  const date = today();
  const score = bioScore(daily, daysAgo(1), targetMinutes);
  const hourRows = hourly
    .filter((r) => r.local_date === date && r.metric_kind === "active_energy")
    .map((r) => ({
      key: new Date(r.bucket_start).toLocaleTimeString("es-CO", {
        hour: "2-digit",
        hour12: false,
      }),
      value: r.value,
    }));
  const history = (kind: string) =>
    daily.filter((r) => r.metric_kind === kind).slice(0, 7);
  return (
    <>
      <Header
        title="Hoy"
        subtitle={new Date().toLocaleDateString("es-CO", {
          weekday: "long",
          day: "numeric",
          month: "long",
        })}
      />
      <button
        className="hero-score"
        type="button"
        onClick={() => onMetric("bioscore")}
      >
        <Ring title="BIO SCORE" score={score} />
        <span>{score.value === null ? score.reason : `Índice personal · ${dateLabel(score.date)} · versión ${score.version}`}</span>
        <small>
          Ver componentes <ArrowRight size={13} />
        </small>
      </button>
      {daily.length === 0 && (
        <Card className="callout">
          <ShieldCheck size={22} />
          <div>
            <strong>Conecta tus señales</strong>
            <p>
              No hay resúmenes disponibles. Puedes configurar Health Auto Export
              desde tu Perfil.
            </p>
            <Btn secondary onClick={onConnect}>
              Configurar puente <ArrowRight size={15} />
            </Btn>
          </div>
        </Card>
      )}
      <div className="section-title">
        <h2>Señales de hoy</h2>
        <p>Datos observados, no puntuaciones</p>
      </div>
      <div className="metrics-grid">
        <button
          className="card energy-card"
          onClick={() => onMetric("active_energy")}
        >
          <span className="metric-head">
            Energía activa <Zap size={17} />
          </span>
          <strong>{formatMetric(latest(daily, "active_energy"))}</strong>
          <div className="energy-graph">
            <BarChart rows={hourRows} tall label="Energía activa por hora" />
          </div>
          <small>Registrada por hora · Apple Salud</small>
        </button>
        <div className="metric-stack">
          <MetricCard
            title="HRV media"
            row={latest(daily, "hrv_sdnn")}
            history={history("hrv_sdnn")}
            icon={Activity}
            note="Media de hoy"
            onClick={() => onMetric("hrv_sdnn")}
          />
          <MetricCard
            title="FC en reposo"
            row={latest(daily, "resting_heart_rate")}
            history={history("resting_heart_rate")}
            icon={Heart}
            note="Valor agregado"
            onClick={() => onMetric("resting_heart_rate")}
          />
        </div>
        <MetricCard
          title="Sueño"
          row={daily.find((r) => r.metric_kind === "sleep_duration")}
          history={history("sleep_duration")}
          icon={Moon}
          note="Última noche con datos"
          onClick={() => onMetric("sleep_duration")}
        />
        <MetricCard
          title="Pasos"
          row={latest(daily, "steps")}
          history={history("steps")}
          icon={Activity}
          note="Acumulado de hoy"
          onClick={() => onMetric("steps")}
        />
      </div>
      <div className="section-title">
        <h2>Dale contexto</h2>
        <p>Tus datos cuentan solo una parte</p>
      </div>
      <button className="card list-action" onClick={onJournal}>
        <BookOpen />
        <span>
          <strong>Añadir al Diario</strong>
          <small>Registra un hábito, síntoma o evento.</small>
        </span>
        <ArrowRight size={17} />
      </button>
      <p className="fine-print">
        BioPulse no ofrece diagnósticos médicos ni interpreta una lectura
        aislada como enfermedad.
      </p>
    </>
  );
}

function Trends({
  daily,
  onMetric,
}: {
  daily: Daily[];
  onMetric: (kind: string) => void;
}) {
  const [kind, setKind] = useState("hrv_sdnn");
  const [period, setPeriod] = useState(7);
  const signal = changeSignal(daily, daysAgo(1));
  const rows = daily
    .filter((r) => r.metric_kind === kind && r.local_date >= daysAgo(period))
    .sort((a, b) => a.local_date.localeCompare(b.local_date));
  const previous = daily.filter(
    (r) =>
      r.metric_kind === kind &&
      r.local_date < daysAgo(period) &&
      r.local_date >= daysAgo(period * 2),
  );
  const average = (points: Daily[]) =>
    points.length
      ? points.reduce((sum, r) => sum + r.value, 0) / points.length
      : null;
  return (
    <>
      <Header
        title="Tendencias"
        subtitle="Cambios observados en tus registros"
      />
      <Card className="signal-card">
        <span className="card-topline">SEÑAL DE CAMBIO PERSONAL</span>
        <strong>{signal.value === null ? "—" : signal.value === 0 ? "Sin cambio persistente" : `${signal.value}/100`}</strong>
        <p>{signal.reason}</p>
        <small>{dateLabel(signal.date)} · {signal.version} · magnitud de cambio, no probabilidad de enfermedad</small>
      </Card>
      <Card className="chart-card">
        <div className="card-topline">
          <span>UNA SEÑAL EN EL TIEMPO</span>
          <TrendingUp size={17} />
        </div>
        <h2>Tu historia, día a día</h2>
        <p>Solo se muestran días con datos; los huecos no se rellenan.</p>
        <div className="filter-row">
          <label>
            Señal
            <select value={kind} onChange={(e) => setKind(e.target.value)}>
              {[
                "hrv_sdnn",
                "resting_heart_rate",
                "sleep_duration",
                "active_energy",
                "steps",
              ].map((m) => (
                <option value={m} key={m}>
                  {metricNames[m]}
                </option>
              ))}
            </select>
          </label>
          <label>
            Periodo
            <select
              value={period}
              onChange={(e) => setPeriod(Number(e.target.value))}
            >
              <option value={7}>7 días</option>
              <option value={30}>30 días</option>
              <option value={90}>90 días</option>
            </select>
          </label>
        </div>
        <BarChart
          rows={rows.map((r) => ({
            key: dateLabel(r.local_date),
            value: r.value,
          }))}
          tall
          label={`Tendencia de ${metricNames[kind]}`}
        />
        <small>Agregados observados · Apple Salud vía Health Auto Export</small>
      </Card>
      <div className="section-title">
        <h2>¿Qué cambió?</h2>
        <p>Comparación descriptiva · no causal</p>
      </div>
      <Card className="compare-card">
        {average(rows) !== null && average(previous) !== null ? (
          <>
            <div>
              <span>PERIODO ACTUAL</span>
              <strong>
                {average(rows)!.toFixed(1)} {rows[0]?.unit}
              </strong>
            </div>
            <ArrowRight size={18} />
            <div>
              <span>PERIODO ANTERIOR</span>
              <strong>
                {average(previous)!.toFixed(1)} {previous[0]?.unit}
              </strong>
            </div>
            <p>
              Solo días con registros. Esta diferencia no demuestra una causa ni
              equivale a un score.
            </p>
          </>
        ) : (
          <Empty title="Aún no hay dos periodos comparables">
            Necesitamos registros en ambos periodos para mostrar una
            comparación.
          </Empty>
        )}
      </Card>
      <div className="section-title">
        <h2>Mediciones</h2>
        <p>Toca una señal para conocerla</p>
      </div>
      {Object.keys(metricNames)
        .filter((m) => m !== "heart_rate")
        .map((m) => (
          <button
            key={m}
            className="card metric-row"
            onClick={() => onMetric(m)}
          >
            <span>{metricNames[m]}</span>
            <strong>{formatMetric(latest(daily, m))}</strong>
            <ChevronRight size={18} />
          </button>
        ))}
      <p className="fine-print">
        Los agregados no sustituyen una evaluación clínica. La cobertura depende
        de Apple Salud y de la automatización.
      </p>
    </>
  );
}

function SleepPage({ daily, sleep, targetMinutes, onTargetChange }: { daily: Daily[]; sleep: Sleep[]; targetMinutes: number; onTargetChange: (value: number) => void }) {
  const row = daily.find((r) => r.metric_kind === "sleep_duration");
  const score = sleepScore(daily, row?.local_date ?? today(), targetMinutes);
  const stages = sleep.filter(
    (r) =>
      r.local_date === row?.local_date &&
      ["core", "deep", "rem"].includes(r.stage),
  );
  const total = stages.reduce((sum, r) => sum + r.minutes, 0);
  return (
    <>
      <Header title="Sueño" subtitle="Tu última noche registrada" />
      <Card className="sleep-hero">
        <Ring title="SLEEP SCORE" compact score={score} />
        <div>
          <span>TIEMPO DORMIDO</span>
          <strong>{formatMetric(row)}</strong>
          <small>
            {row ? dateLabel(row.local_date) : "Sin datos disponibles"}
          </small>
        </div>
        <p>{score.reason} {score.value === null ? "" : `Duración ${score.components.duration}/100 · constancia ${score.components.consistency}/100.`}</p>
      </Card>
      <Card className="sleep-target-card">
        <label htmlFor="sleep-target">Meta personal de sueño</label>
        <select id="sleep-target" value={targetMinutes} onChange={event => onTargetChange(Number(event.target.value))}>
          {[360,390,420,450,480,510,540,570,600].map(minutes => <option key={minutes} value={minutes}>{minutes / 60} horas</option>)}
        </select>
        <small>Se guarda en este navegador para tu cuenta. La fórmula usa duración y constancia, no etapas estimadas.</small>
      </Card>
      <div className="section-title">
        <h2>Etapas de la noche</h2>
        <p>Resumen por etapa · no intervalos individuales</p>
      </div>
      <Card className="stage-card">
        {stages.length && total > 0 ? (
          <>
            <div
              className="stage-stripe"
              aria-label={stages
                .map((s) => `${s.stage}: ${s.minutes} minutos`)
                .join(", ")}
            >
              {stages.map((s) => (
                <span
                  key={s.stage}
                  className={`stage-${s.stage}`}
                  style={{ width: `${(s.minutes / total) * 100}%` }}
                />
              ))}
            </div>
            {stages.map((s) => (
              <div className="stage-row" key={s.stage}>
                <span className={`stage-dot stage-${s.stage}`} />
                <span>
                  {s.stage === "core"
                    ? "Ligero"
                    : s.stage === "deep"
                      ? "Profundo"
                      : "REM"}
                </span>
                <strong>{Math.round(s.minutes)} min</strong>
              </div>
            ))}
            <p>
              Health Auto Export comparte totales por día. Una línea temporal
              exacta necesitaría segmentos originales, que esta conexión no
              envía.
            </p>
          </>
        ) : (
          <Empty title="Sin etapas agregadas">
            Si tu fuente registra fases de sueño y se comparte el resumen,
            aparecerán aquí.
          </Empty>
        )}
      </Card>
      <div className="section-title">
        <h2>Historial</h2>
        <p>Duración observada de noches anteriores</p>
      </div>
      <Card>
        <BarChart
          rows={daily
            .filter((r) => r.metric_kind === "sleep_duration")
            .slice(0, 7)
            .reverse()
            .map((r) => ({
              key: dateLabel(r.local_date),
              value: r.value / 60,
            }))}
          label="Horas de sueño registradas"
        />
      </Card>
    </>
  );
}

function JournalPage({
  userId,
  entries,
  onReload,
}: {
  userId: string;
  entries: Journal[];
  onReload: () => Promise<void>;
}) {
  const [allowed, setAllowed] = useState(false);
  const [selected, setSelected] = useState(today());
  const [category, setCategory] = useState<Journal["category"]>("habit");
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<string | null>(null);
  useEffect(() => {
    journalConsent(userId)
      .then(setAllowed)
      .catch(() => setAllowed(false));
  }, [userId]);
  const visible = entries.filter(
    (r) => new Intl.DateTimeFormat("sv-SE").format(new Date(r.occurred_at)) === selected,
  );
  const checkIn = visible.find((entry) => entry.title.startsWith("Check-in: "));
  async function saveCheckIn(label: string) {
    if (!supabase || busy) return;
    setBusy(true);
    setError("");
    const title = `Check-in: ${label}`;
    const result = checkIn
      ? await supabase.from("journal_entries").update({ title }).eq("user_id", userId).eq("id", checkIn.id)
      : await supabase.from("journal_entries").insert({
          user_id: userId,
          category: "event",
          title,
          notes: "",
          occurred_at: new Date(`${selected}T12:00:00`).toISOString(),
          timezone_identifier: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
        });
    setBusy(false);
    if (result.error) setError(result.error.message);
    else await onReload();
  }
  async function setConsent(decision: "granted" | "revoked") {
    if (!supabase) return;
    setBusy(true);
    setError("");
    const { error } = await supabase
      .from("sync_consents")
      .insert({
        user_id: userId,
        data_category: "journal",
        decision,
        policy_version: "web-journal-v1",
      });
    setBusy(false);
    if (error) setError(error.message);
    else setAllowed(decision === "granted");
  }
  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!supabase || !title.trim()) return;
    setBusy(true);
    setError("");
    const record = {
      user_id: userId,
      category,
      title: title.trim(),
      notes: notes.trim(),
      occurred_at: new Date(`${selected}T12:00:00`).toISOString(),
      timezone_identifier:
        Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
    };
    const result = editing
      ? await supabase
          .from("journal_entries")
          .update({ category, title: record.title, notes: record.notes })
          .eq("user_id", userId)
          .eq("id", editing)
      : await supabase.from("journal_entries").insert(record);
    setBusy(false);
    if (result.error) {
      setError(result.error.message);
      return;
    }
    setTitle("");
    setNotes("");
    setEditing(null);
    await onReload();
  }
  async function remove(id: string) {
    if (!supabase || !window.confirm("¿Eliminar esta entrada del Diario?"))
      return;
    const { error } = await supabase
      .from("journal_entries")
      .delete()
      .eq("user_id", userId)
      .eq("id", id);
    if (error) setError(error.message);
    else await onReload();
  }
  function shift(days: number) {
    const date = new Date(`${selected}T12:00:00`);
    date.setDate(date.getDate() + days);
    setSelected(new Intl.DateTimeFormat("sv-SE").format(date));
  }
  return (
    <>
      <Header title="Diario" subtitle="Tu contexto, en tus palabras" />
      <div className="day-switch">
        <button onClick={() => shift(-1)} aria-label="Día anterior">
          <ChevronLeft />
        </button>
        <span>
          {new Date(`${selected}T12:00:00`).toLocaleDateString("es-CO", {
            weekday: "long",
            day: "numeric",
            month: "long",
          })}
        </span>
        <button
          onClick={() => shift(1)}
          disabled={selected >= today()}
          aria-label="Día siguiente"
        >
          <ChevronRight />
        </button>
      </div>
      {!allowed ? (
        <Card className="consent-card">
          <LockKeyhole />
          <h2>Tu Diario es opcional</h2>
          <p>
            En la web, tus entradas se guardan en tu cuenta en Supabase.
            Autoriza esta categoría de forma separada si quieres usarlas aquí.
            Esto no activa la sincronización de Salud.
          </p>
          <Btn onClick={() => setConsent("granted")} disabled={busy}>
            Autorizar Diario <ArrowRight size={17} />
          </Btn>
        </Card>
      ) : (
        <>
          <Card className="checkin-card">
            <span className="card-topline">CONTEXTO SUBJETIVO <Heart size={17} /></span>
            <h2>¿Cómo te sientes?</h2>
            <p>Tu respuesta queda junto a tus datos, nunca como medición objetiva.</p>
            <div className="checkin-options">
              {["Baja energía", "En equilibrio", "Con energía"].map((label) => (
                <button
                  type="button"
                  key={label}
                  disabled={busy}
                  aria-pressed={checkIn?.title === `Check-in: ${label}`}
                  onClick={() => saveCheckIn(label)}
                >
                  {label}
                </button>
              ))}
            </div>
          </Card>
          <Card className="journal-editor">
            <span className="card-topline">
              ENTRADA PERSONAL <BookOpen size={17} />
            </span>
            <h2>{editing ? "Editar registro" : "Añadir contexto"}</h2>
            <p>Esta entrada es subjetiva; no se trata como una medición.</p>
            <form onSubmit={save}>
              <label>
                Tipo
                <select
                  value={category}
                  onChange={(e) =>
                    setCategory(e.target.value as Journal["category"])
                  }
                >
                  <option value="habit">Hábito</option>
                  <option value="symptom">Cómo me sentí</option>
                  <option value="event">Evento</option>
                </select>
              </label>
              <label>
                Título
                <input
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  maxLength={120}
                  required
                  placeholder="Ej. Entrenamiento, viaje o café tarde"
                />
              </label>
              <label>
                Nota opcional
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  maxLength={2000}
                  rows={3}
                  placeholder="¿Qué te gustaría recordar?"
                />
              </label>
              <Btn type="submit" disabled={busy || !title.trim()}>
                {busy
                  ? "Guardando…"
                  : editing
                    ? "Guardar cambios"
                    : "Añadir registro"}
                <Plus size={17} />
              </Btn>
              {editing && (
                <button
                  type="button"
                  className="text-button"
                  onClick={() => {
                    setEditing(null);
                    setTitle("");
                    setNotes("");
                  }}
                >
                  Cancelar edición
                </button>
              )}
            </form>
          </Card>
          <div className="section-title">
            <h2>Línea de tiempo</h2>
            <p>
              {visible.length
                ? `${visible.length} registros este día`
                : "Sin registros este día"}
            </p>
          </div>
          {visible.length ? (
            visible.map((entry) => (
              <Card className="journal-entry" key={entry.id}>
                <span className="entry-type">
                  {entry.category === "habit"
                    ? "HÁBITO"
                    : entry.category === "event"
                      ? "EVENTO"
                      : "CÓMO ME SENTÍ"}
                </span>
                <strong>{entry.title}</strong>
                {entry.notes && <p>{entry.notes}</p>}
                <div>
                  <button
                    onClick={() => {
                      setEditing(entry.id);
                      setTitle(entry.title);
                      setNotes(entry.notes);
                      setCategory(entry.category);
                    }}
                  >
                    Editar
                  </button>
                  <button onClick={() => remove(entry.id)}>Eliminar</button>
                </div>
              </Card>
            ))
          ) : (
            <Empty title="Todavía no hay registros">
              Añade una entrada cuando haya algo que quieras recordar.
            </Empty>
          )}
          <button
            className="text-button revoke-journal"
            onClick={() => setConsent("revoked")}
          >
            Revocar permiso para nuevas entradas
          </button>
        </>
      )}
      {error && (
        <p role="alert" className="notice error">
          {error}
        </p>
      )}
    </>
  );
}

function Profile({
  email,
  userId,
  status,
  refreshStatus,
  refreshMetrics,
}: {
  email: string;
  userId: string;
  status: BridgeStatus | null;
  refreshStatus: () => Promise<void>;
  refreshMetrics: () => Promise<void>;
}) {
  const [token, setToken] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [dailyOpt, setDailyOpt] = useState(false);
  const [hourlyOpt, setHourlyOpt] = useState(false);
  const dailyLink = token ? automationLink(token, "daily") : "";
  const hourlyLink = token ? automationLink(token, "intraday") : "";
  async function run(action: string, extra: Record<string, unknown> = {}) {
    setBusy(true);
    setError("");
    try {
      const result = await bridge(action, extra);
      await refreshStatus();
      return result;
    } catch (issue) {
      setError(
        issue instanceof Error ? issue.message : "No se pudo completar.",
      );
      return null;
    } finally {
      setBusy(false);
    }
  }
  async function setup() {
    if (!phoneBridgeReady) { setError("Para conectar el iPhone necesitas desplegar el endpoint público con HTTPS."); return; }
    if (!dailyOpt) {
      setError("Debes elegir si autorizas los resúmenes diarios.");
      return;
    }
    const first = await run("consent", {
      category: "derived_metrics",
      decision: "granted",
    });
    if (!first) return;
    if (hourlyOpt) {
      const second = await run("consent", {
        category: "intraday_metrics",
        decision: "granted",
      });
      if (!second) return;
    } else if (status?.intradayConsent)
      await run("consent", {
        category: "intraday_metrics",
        decision: "revoked",
      });
    const started = await run("start");
    if (started && typeof started.token === "string") {
      setToken(started.token);
      setInfo(
        "Abre los enlaces en tu iPhone. Revisa los permisos y guarda las automatizaciones en Health Auto Export.",
      );
    }
  }
  async function revoke() {
    if (
      !window.confirm(
        "¿Detener Health Auto Export? Las automatizaciones fallarán hasta que las desactives también en esa app.",
      )
    )
      return;
    const result = await run("revoke");
    if (result) {
      setToken("");
      setInfo(
        "Conexión revocada. Desactiva las automatizaciones en Health Auto Export.",
      );
    }
  }
  async function deleteData() {
    if (
      !window.confirm(
        "¿Detener la conexión y eliminar todos los resúmenes importados por Health Auto Export? Esta acción no se puede deshacer.",
      )
    )
      return;
    const result = await run("delete_data");
    if (result) {
      await refreshMetrics();
      setInfo("Resúmenes importados eliminados.");
    }
  }
  return (
    <>
      <Header title="Perfil" subtitle="Conexiones, cuenta y privacidad" />
      <Card className="profile-account">
        <div className="avatar">
          <UserRound />
        </div>
        <div>
          <span>CUENTA BIOPULSE</span>
          <strong>{email}</strong>
          <small>Acceso privado · {userId.slice(0, 8)}…</small>
        </div>
      </Card>
      <div className="section-title">
        <h2>Apple Salud en la web</h2>
        <p>Health Auto Export como puente opcional</p>
      </div>
      <Card className="bridge-card">
        <div className="bridge-title">
          <Watch />
          <div>
            <h2>
              {status?.connected ? "Puente configurado" : "Conecta tus señales"}
            </h2>
            <p>
              {status?.connected
                ? status.lastSyncAt ? `Último envío: ${timeLabel(status.lastSyncAt)}` : "Esperando el primer envío de Health Auto Export."
                : "Configura desde tu iPhone en unos pasos."}
            </p>
          </div>
          <span
            className={`state-pip ${status?.connected ? "connected" : ""}`}
          />
        </div>
        <div className="bridge-meta">
          <span>
            Diarios <strong>{timeLabel(status?.lastDailySyncAt)}</strong>
          </span>
          <span>
            Por hora <strong>{timeLabel(status?.lastIntradaySyncAt)}</strong>
          </span>
        </div>
        <p>
          Necesitas Health Auto Export con exportación REST, Apple Salud
          autorizada y conexión a internet. Las actualizaciones de iOS en
          segundo plano no son instantáneas; puedes ejecutar la automatización
          manualmente.
        </p>
      </Card>
      <Card className="wizard">
        <span className="card-topline">
          CONFIGURACIÓN <ShieldCheck size={18} />
        </span>
        <h2>Elige exactamente qué compartir</h2>
        <label className="check-row">
          <input
            type="checkbox"
            checked={dailyOpt}
            onChange={(e) => setDailyOpt(e.target.checked)}
          />
          <span>
            <strong>Resúmenes diarios</strong>
            <small>
              Sueño agregado, pasos, energía activa, HRV y FC en reposo. Sin
              muestras originales.
            </small>
          </span>
        </label>
        <label className="check-row">
          <input
            type="checkbox"
            checked={hourlyOpt}
            onChange={(e) => setHourlyOpt(e.target.checked)}
          />
          <span>
            <strong>Energía por hora</strong>
            <small>
              Consentimiento independiente para el gráfico intradía. No incluye
              muestras minuto a minuto.
            </small>
          </span>
        </label>
        <Btn onClick={setup} disabled={busy || !dailyOpt || !phoneBridgeReady}>
          {status?.connected
            ? "Renovar enlace de conexión"
            : "Crear enlace seguro"}
          <ArrowRight size={17} />
        </Btn>
        <small>
          Crear un enlace nuevo invalida inmediatamente la configuración
          anterior.
        </small>
        {!phoneBridgeReady && <p className="notice">La conexión con iPhone requiere la función desplegada en una URL pública HTTPS. En local puedes probar el resto de la web.</p>}
        {token && (
          <div className="links-panel">
            <p>
              <strong>Abre estos enlaces únicamente en tu iPhone.</strong> El
              token es secreto y se muestra solo ahora. No compartas ni captures
              esta pantalla.
            </p>
            <a className="action" href={dailyLink}>
              1. Configurar resúmenes diarios <ArrowRight size={17} />
            </a>
            {hourlyOpt && (
              <a className="action action-secondary" href={hourlyLink}>
                2. Configurar energía por hora <ArrowRight size={17} />
              </a>
            )}
            <ol>
              <li>
                Confirma el cambio a Health Auto Export y concede permisos de
                lectura de esas métricas.
              </li>
              <li>
                Revisa que el destino sea REST API, JSON, agrupación por
                día/hora y sueño agregado.
              </li>
              <li>Guarda cada automatización y ejecuta una prueba manual.</li>
              <li>
                Vuelve aquí y toca «Actualizar estado» para comprobar el primer
                envío.
              </li>
            </ol>
          </div>
        )}
      </Card>
      <div className="bridge-actions">
        <Btn
          secondary
          onClick={() => {
            refreshStatus();
            refreshMetrics();
          }}
          disabled={busy}
        >
          <RefreshCw size={17} /> Actualizar estado
        </Btn>
        {status?.connected && (
          <Btn secondary onClick={revoke} disabled={busy}>
            Revocar conexión
          </Btn>
        )}
        <button className="danger-link" onClick={deleteData} disabled={busy}>
          <Trash2 size={16} /> Eliminar datos importados
        </button>
      </div>
      {error && (
        <div role="alert" className="notice error">
          {error}
        </div>
      )}
      {info && (
        <div role="status" className="notice">
          {info}
        </div>
      )}
      <div className="section-title">
        <h2>Tu cuenta</h2>
        <p>Control de acceso</p>
      </div>
      <button
        className="card list-action"
        onClick={() => supabase?.auth.signOut()}
      >
        <LogOut />
        <span>
          <strong>Cerrar sesión</strong>
          <small>Vuelve a entrar cuando quieras.</small>
        </span>
        <ArrowRight size={17} />
      </button>
      <p className="fine-print">
        La app iOS todavía guarda datos HealthKit originales en el dispositivo.
        Este puente web solo recibe agregados autorizados. No ofrece
        diagnósticos ni tratamientos.
      </p>
    </>
  );
}

type Chat = { role: "user" | "assistant"; content: string };
function Coach({
  onClose,
  daily,
  journal,
}: {
  onClose: () => void;
  daily: Daily[];
  journal: Journal[];
}) {
  const [consented, setConsented] = useState(false);
  const [messages, setMessages] = useState<Chat[]>([]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    supabase?.functions
      .invoke("coach", { body: { action: "consent_status" } })
      .then(({ data }) => setConsented(!!data?.consented));
  }, []);
  async function consent(action: "grant_consent" | "revoke_consent") {
    if (!supabase) return;
    setBusy(true);
    const { error } = await supabase.functions.invoke("coach", {
      body: { action },
    });
    setBusy(false);
    if (error) setError(error.message);
    else {
      setConsented(action === "grant_consent");
      if (action === "revoke_consent") setMessages([]);
    }
  }
  async function send(event: React.FormEvent) {
    event.preventDefault();
    if (!supabase || !draft.trim()) return;
    const next = [
      ...messages,
      { role: "user" as const, content: draft.trim() },
    ].slice(-16);
    setMessages(next);
    setDraft("");
    setBusy(true);
    setError("");
    const context = {
      metrics: daily
        .slice(0, 40)
        .map((r) => ({
          name: r.metric_kind,
          value: r.value,
          unit: r.unit,
          observedAt: r.local_date,
          quality: r.quality,
          provenance: r.source_kind,
          period: "daily",
        })),
      journal: journal
        .slice(0, 10)
        .map((r) => ({
          category: r.category,
          title: r.title,
          notes: r.notes.slice(0, 1_000),
          occurredAt: r.occurred_at,
          timezone: r.timezone_identifier,
        })),
    };
    const { data, error } = await supabase.functions.invoke("coach", {
      body: { action: "send", messages: next, context },
    });
    setBusy(false);
    if (error || typeof data?.answer !== "string")
      setError("El Coach no pudo responder. Intenta de nuevo más tarde.");
    else setMessages([...next, { role: "assistant", content: data.answer }]);
  }
  return (
    <div
      className="coach-scrim"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <section
        className="coach-panel"
        role="dialog"
        aria-modal="true"
        aria-label="Coach IA"
      >
        <header>
          <div>
            <Sparkles size={19} />
            <span>
              <strong>Coach BioPulse</strong>
              <small>IA · contexto y bienestar</small>
            </span>
          </div>
          <button onClick={onClose} aria-label="Cerrar Coach">
            <X />
          </button>
        </header>
        {!consented ? (
          <div className="coach-consent">
            <ShieldCheck size={33} />
            <h2>Antes de conversar</h2>
            <p>
              Si autorizas, el Coach recibirá métricas agregadas y entradas
              recientes del Diario para responder. No recibe muestras originales
              de HealthKit. Recuerda que no diagnostica ni recomienda
              tratamientos.
            </p>
            <Btn onClick={() => consent("grant_consent")} disabled={busy}>
              Autorizar Coach
            </Btn>
          </div>
        ) : (
          <>
            <div className="chat-list" aria-live="polite">
              {messages.length ? (
                messages.map((m, i) => (
                  <div className={`bubble bubble-${m.role}`} key={i}>
                    {m.content}
                  </div>
                ))
              ) : (
                <div className="chat-empty">
                  <Sparkles size={29} />
                  <h2>¿Qué quieres entender hoy?</h2>
                  <p>
                    Podemos hablar de tus registros de sueño, actividad o de
                    cómo te has sentido. Esta conversación visible se borra al
                    cerrar; una memoria breve puede permanecer hasta una semana.
                  </p>
                </div>
              )}
            </div>
            <form className="chat-compose" onSubmit={send}>
              <label className="sr-only" htmlFor="chat-text">
                Pregunta al Coach
              </label>
              <input
                id="chat-text"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                maxLength={4000}
                placeholder="Escribe tu pregunta…"
              />
              <button
                type="submit"
                disabled={busy || !draft.trim()}
                aria-label="Enviar"
              >
                <Send size={19} />
              </button>
            </form>
            <button
              className="coach-revoke"
              onClick={() => consent("revoke_consent")}
            >
              Revocar acceso del Coach
            </button>
          </>
        )}
        {error && (
          <p role="alert" className="notice error">
            {error}
          </p>
        )}
      </section>
    </div>
  );
}

function AppShell({ session }: { session: Session }) {
  const [tab, setTab] = useState<Tab>("Hoy");
  const [metrics, setMetrics] = useState(emptyMetrics);
  const [entries, setEntries] = useState<Journal[]>([]);
  const [status, setStatus] = useState<BridgeStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [coach, setCoach] = useState(false);
  const [detail, setDetail] = useState<string | null>(null);
  const userId = session.user.id;
  const [targetMinutes, setTargetMinutes] = useState(() => {
    const stored = Number(localStorage.getItem(`biopulse.sleepTarget.${session.user.id}`));
    return Number.isInteger(stored) && stored >= 360 && stored <= 600 ? stored : 480;
  });
  const updateTarget = (value: number) => {
    if (!Number.isInteger(value) || value < 360 || value > 600) return;
    localStorage.setItem(`biopulse.sleepTarget.${userId}`, String(value));
    setTargetMinutes(value);
  };
  const refreshMetrics = useCallback(async () => {
    try {
      setMetrics(await loadMetrics(userId));
      setError("");
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "No se pudieron cargar los datos.",
      );
    }
  }, [userId]);
  const refreshJournal = useCallback(async () => {
    try {
      setEntries(await loadJournal(userId));
    } catch {
      /* Journal consent is optional. */
    }
  }, [userId]);
  const refreshStatus = useCallback(async () => {
    try {
      setStatus((await bridge("status")) as BridgeStatus);
    } catch {
      setStatus(null);
    }
  }, []);
  useEffect(() => {
    Promise.all([refreshMetrics(), refreshJournal(), refreshStatus()]).finally(
      () => setLoading(false),
    );
  }, [refreshMetrics, refreshJournal, refreshStatus]);
  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") { setCoach(false); setDetail(null); }
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, []);
  const detailRows = useMemo(
    () =>
      metrics.daily
        .filter((r) => r.metric_kind === detail)
        .slice(0, 30)
        .reverse(),
    [metrics.daily, detail],
  );
  const currentBio = useMemo(() => bioScore(metrics.daily, daysAgo(1), targetMinutes), [metrics.daily, targetMinutes]);
  function navigate(next: Tab) {
    setTab(next);
    window.scrollTo({ top: 0, behavior: "instant" });
  }
  return (
    <div className="app-page">
      <aside className="app-sidebar">
        <a href="/" aria-label="BioPulse, sitio público">
          <Brand light />
        </a>
        <p className="side-caption">TU ESPACIO PERSONAL</p>
        <nav aria-label="Secciones">
          {tabs.map(({ name, icon: Icon }) => (
            <button
              key={name}
              onClick={() => navigate(name)}
              className={tab === name ? "active" : ""}
              aria-current={tab === name ? "page" : undefined}
            >
              <Icon size={20} strokeWidth={1.8} />
              {name}
            </button>
          ))}
        </nav>
        <div className="side-bottom">
          <span className="side-status">
            <span className={status?.connected ? "live-pip" : "neutral-pip"} />{" "}
            {status?.lastSyncAt ? "Datos recibidos" : status?.connected ? "Puente configurado" : "Esperando datos"}
          </span>
          <p>BioPulse · MVP de ciencia de datos</p>
        </div>
      </aside>
      <main className="app-main">
        <div className="mobile-app-top">
          <Brand light />
          <button onClick={() => navigate("Perfil")} aria-label="Abrir perfil">
            <UserRound size={20} />
          </button>
        </div>
        <div className="app-content">
          {loading && (
            <div className="loading-state">Consultando tus registros…</div>
          )}
          {error && (
            <div role="alert" className="notice error">
              {error}
            </div>
          )}
          {!loading &&
            (tab === "Hoy" ? (
              <Today
                daily={metrics.daily}
                hourly={metrics.hourly}
                onJournal={() => navigate("Diario")}
                onMetric={setDetail}
                onConnect={() => navigate("Perfil")}
                targetMinutes={targetMinutes}
              />
            ) : tab === "Tendencias" ? (
              <Trends daily={metrics.daily} onMetric={setDetail} />
            ) : tab === "Diario" ? (
              <JournalPage
                userId={userId}
                entries={entries}
                onReload={refreshJournal}
              />
            ) : tab === "Sueño" ? (
              <SleepPage daily={metrics.daily} sleep={metrics.sleep} targetMinutes={targetMinutes} onTargetChange={updateTarget} />
            ) : (
              <Profile
                email={session.user.email ?? "Cuenta"}
                userId={userId}
                status={status}
                refreshStatus={refreshStatus}
                refreshMetrics={refreshMetrics}
              />
            ))}
        </div>
        <button
          className="coach-fab"
          onClick={() => setCoach(true)}
          aria-label="Abrir Coach IA"
        >
          <Sparkles size={19} />
          <span>Coach IA</span>
        </button>
        <nav className="bottom-tabs" aria-label="Secciones">
          {tabs.map(({ name, icon: Icon }) => (
            <button
              key={name}
              onClick={() => navigate(name)}
              className={tab === name ? "active" : ""}
              aria-label={name}
              aria-current={tab === name ? "page" : undefined}
            >
              <Icon size={21} strokeWidth={1.8} />
              <small>{name}</small>
            </button>
          ))}
        </nav>
      </main>
      {coach && (
        <Coach
          onClose={() => setCoach(false)}
          daily={metrics.daily}
          journal={entries}
        />
      )}
      {detail && (
        <div
          className="detail-scrim"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setDetail(null);
          }}
        >
          <section
            className="detail-panel"
            role="dialog"
            aria-modal="true"
            aria-label="Detalle de señal"
          >
            <button
              className="detail-close"
              onClick={() => setDetail(null)}
              aria-label="Cerrar detalle"
            >
              <X />
            </button>
            <span className="eyebrow">
              DETALLE /{" "}
              {detail === "bioscore"
                ? "BIO SCORE"
                : metricNames[detail]?.toUpperCase()}
            </span>
            <h2>{detail === "bioscore" ? "BioScore" : metricNames[detail]}</h2>
            {detail === "bioscore" ? (
              <>
                <Ring title="BIO SCORE" compact score={currentBio} />
                <p>
                  {currentBio.reason}
                </p>
                {currentBio.value !== null && <p>
                  Sueño {currentBio.components.sleep}/100 · recuperación {currentBio.components.recovery}/100 · actividad habitual {currentBio.components.activityBalance}/100.
                  Fórmula {currentBio.version}; datos del {dateLabel(currentBio.date)}.
                </p>}
              </>
            ) : (
              <>
                <strong className="detail-value">
                  {formatMetric(latest(metrics.daily, detail))}
                </strong>
                <p>
                  Agregados observados. Un valor aislado no indica por sí mismo
                  una condición médica.
                </p>
                <BarChart
                  rows={detailRows.map((r) => ({
                    key: dateLabel(r.local_date),
                    value: r.value,
                  }))}
                  label={`Historial de ${metricNames[detail]}`}
                />
              </>
            )}
          </section>
        </div>
      )}
    </div>
  );
}

function Root() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [reset, setReset] = useState(false);
  const isApp = location.pathname.startsWith("/app");
  useEffect(() => {
    if (!isApp || !supabase) {
      setReady(true);
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data: subscription } = supabase.auth.onAuthStateChange(
      (event, next) => {
        setSession(next);
        if (event === "PASSWORD_RECOVERY") setReset(true);
        setReady(true);
      },
    );
    return () => subscription.subscription.unsubscribe();
  }, [isApp]);
  if (!isApp) return <Landing />;
  if (!ready)
    return (
      <div className="boot">
        <Brand light />
        <p>Preparando tu espacio…</p>
      </div>
    );
  if (session && reset) return <ResetPassword done={() => setReset(false)} />;
  return session ? (
    <AppShell key={session.user.id} session={session} />
  ) : (
    <Auth />
  );
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Root />
  </React.StrictMode>,
);
