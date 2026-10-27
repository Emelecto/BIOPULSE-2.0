import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { Activity, ArrowUpRight, BookOpen, ChevronLeft, ChevronRight, FileUp, Heart, Home, LockKeyhole, Moon, Plus, RefreshCw, ShieldCheck, Sparkles, TrendingUp, UserRound, Wind, X, Zap } from "lucide-react";

type DemoTab = "Hoy" | "Tendencias" | "Diario" | "Sueño" | "Perfil";
type MetricKey = "active" | "hrv" | "resting" | "sleep" | "steps";
type Panel = MetricKey | "score" | "journal-editor" | "sleep-editor" | "coach" | "health" | "csv" | "breathing";
type Entry = { id: number; day: number; title: string; note: string; time: string };
const demoTabs = [
  { name: "Hoy", icon: Home }, { name: "Tendencias", icon: TrendingUp },
  { name: "Diario", icon: BookOpen }, { name: "Sueño", icon: Moon }, { name: "Perfil", icon: UserRound },
] as const;
const energy = [8, 13, 11, 4, 3, 7, 18, 31, 22, 12, 5, 9, 14, 25, 67, 94, 51, 22, 13, 8, 5, 3, 1, 0];
const metricInfo = {
  active: { title: "Energía activa", value: "486 kcal", unit: "kcal", icon: Zap, note: "Registrada por hora", description: "Energía activa acumulada en un día de ejemplo. En iOS, las mediciones disponibles proceden de Apple Salud.", history: [390, 460, 410, 520, 440, 505, 486] },
  hrv: { title: "HRV media", value: "53 ms", unit: "ms", icon: Activity, note: "Media de hoy", description: "Variación entre latidos sucesivos. Una lectura aislada no indica una enfermedad ni permite diagnosticar tu estado.", history: [46, 50, 48, 56, 51, 55, 53] },
  resting: { title: "FC en reposo", value: "58 lpm", unit: "lpm", icon: Heart, note: "Última de hoy", description: "Frecuencia cardiaca en reposo de un día de ejemplo. La app muestra el periodo y la procedencia de cada lectura.", history: [62, 60, 61, 59, 60, 57, 58] },
  sleep: { title: "Sueño", value: "7 h 42 min", unit: "min", icon: Moon, note: "Última noche", description: "Duración de sueño de ejemplo. Los registros manuales se distinguen de las mediciones de Apple Salud.", history: [420, 450, 435, 480, 445, 465, 462] },
  steps: { title: "Pasos", value: "8.420 pasos", unit: "pasos", icon: Activity, note: "Acumulado de hoy", description: "Acumulado de pasos de un día simulado. No corresponde a una persona ni a una lectura de tu dispositivo.", history: [5400, 7200, 6400, 9100, 7600, 8800, 8420] },
} satisfies Record<MetricKey, { title: string; value: string; unit: string; icon: typeof Activity; note: string; description: string; history: number[] }>;

function DemoBars({ values, label, small = false }: { values: number[]; label: string; small?: boolean }) {
  const max = Math.max(...values, 1);
  const slot = 240 / values.length;
  return <svg className={small ? "bp-bars bp-bars-small" : "bp-bars"} viewBox="0 0 240 90" preserveAspectRatio="none" role="img" aria-label={`Datos simulados: ${label}`}>
    {!small && [20, 50, 80].map(y => <line key={y} x1="0" x2="240" y1={y} y2={y} stroke="currentColor" opacity=".08" />)}
    {values.map((value, i) => <rect key={i} x={i * slot + slot * .14} y={85 - value / max * 76} width={Math.max(1, slot * .65)} height={Math.max(1, value / max * 76)} rx={Math.min(2, slot * .15)} fill="currentColor" />)}
  </svg>;
}

function DemoRing({ title, value }: { title: string; value: number | null }) {
  const tint = value === null ? "#e5e8e9" : value === 78 ? "#aed463" : "#92d56b";
  return <div className="bp-score" style={{ "--bp-score-tint": tint } as CSSProperties}>
    <svg viewBox="0 0 240 240" aria-hidden="true">{[0, 1, 2, 3].map(strand => {
      const points = Array.from({ length: 181 }, (_, step) => {
        const a = step / 180 * Math.PI * 2;
        const r = 100 + Math.sin(a * (5 + strand) + strand * 1.4) * 3.5 + Math.sin(a * 3 + strand) * 2 + (strand - 2) * 2;
        return `${120 + Math.cos(a) * r},${120 + Math.sin(a) * r}`;
      }).join(" ");
      return <polyline key={strand} points={points} fill="none" stroke="currentColor" strokeWidth={strand === 0 ? 1.8 : .8} opacity={strand === 0 ? .82 : .38} />;
    })}</svg>
    <div><span>{title}</span><strong>{value ?? "—"}</strong><small>{value === null ? "Sin calcular en la demo" : "Índice exploratorio"}</small></div>
  </div>;
}

function DemoSection({ title, subtitle }: { title: string; subtitle?: string }) {
  return <div className="bp-section"><strong>{title}</strong>{subtitle && <span>{subtitle}</span>}</div>;
}

function DemoCard({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`bp-card ${className}`}>{children}</div>;
}

export function LandingPhone() {
  const [tab, setTab] = useState<DemoTab>("Hoy");
  const [panel, setPanel] = useState<Panel | null>(null);
  const [period, setPeriod] = useState(7);
  const [trendMetric, setTrendMetric] = useState<MetricKey>("hrv");
  const [journalDay, setJournalDay] = useState(0);
  const [moods, setMoods] = useState<Record<number, string>>({ 0: "Con energía" });
  const [entries, setEntries] = useState<Entry[]>([
    { id: 1, day: 0, title: "Caminata matutina", note: "30 minutos al aire libre.", time: "08:15" },
    { id: 2, day: 0, title: "Día tranquilo", note: "Una nota para acompañar mis señales.", time: "12:40" },
  ]);
  const [sleepMinutes, setSleepMinutes] = useState(462);
  const [sleepReported, setSleepReported] = useState(false);
  const [coachExample, setCoachExample] = useState(false);
  const dialogRef = useRef<HTMLDivElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const visibleEntries = entries.filter(entry => entry.day === journalDay);
  const journalDate = new Date(Date.UTC(2026, 9, 26 + journalDay, 12));
  const dayLabel = new Intl.DateTimeFormat("es", { day: "numeric", month: "short", timeZone: "UTC" }).format(journalDate);
  const sleepValue = `${Math.floor(sleepMinutes / 60)} h ${sleepMinutes % 60} min`;
  const selectedMetric = panel && panel in metricInfo ? metricInfo[panel as MetricKey] : null;
  const trend = metricInfo[trendMetric];
  const trendHistory = trendMetric === "sleep" ? [...trend.history.slice(0, -1), sleepMinutes] : trend.history;
  const trendValues = Array.from({ length: period }, (_, i) => trendHistory[i % 7] * (period === 7 ? 1 : .97 + Math.sin(i * .8) * .04));

  useEffect(() => {
    if (!panel) return;
    const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const scrollArea = rootRef.current?.querySelector<HTMLElement>(".bp-scroll");
    if (scrollArea) scrollArea.inert = true;
    closeRef.current?.focus({ preventScroll: true });
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") { event.preventDefault(); setPanel(null); }
      if (event.key !== "Tab") return;
      const controls = Array.from(dialogRef.current?.querySelectorAll<HTMLElement>("button:not([disabled]), input, select, textarea, [tabindex='0']") ?? []).filter(el => el.getClientRects().length);
      const first = controls[0]; const last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      if (scrollArea) scrollArea.inert = false;
      document.removeEventListener("keydown", onKey);
      previous?.focus({ preventScroll: true });
    };
  }, [panel]);

  const metricButton = (key: MetricKey) => {
    const metric = metricInfo[key]; const Icon = metric.icon;
    return <button className={`bp-card bp-metric bp-metric-${key}`} type="button" onClick={() => setPanel(key)}>
      <span className="bp-metric-label">{metric.title}<Icon size={13} /></span>
      <strong>{key === "sleep" ? sleepValue : metric.value}</strong>
      {(key === "sleep" || key === "steps") && <DemoBars values={key === "sleep" ? [...metric.history.slice(0, -1), sleepMinutes] : metric.history} label={metric.title} small />}
      <small>{key === "sleep" && sleepReported ? "Estimado por ti · demo" : metric.note}</small>
    </button>;
  };

  return <div className="land-iphone bp-demo" ref={rootRef}>
    <div className="land-iphone-glass">
      <div className="land-iphone-status" aria-hidden="true"><span>9:41</span><span className="land-iphone-island" /><span className="land-iphone-system"><i /><i /><i /><b /></span></div>
      <div className="bp-demo-label"><span /> DEMO INTERACTIVA · DATOS SIMULADOS</div>
      <div className="bp-scroll" key={tab}>
        <header className="bp-header"><div className="bp-brand"><img src="/images/biopulse-brand-mark.png" alt="" /><span>BioPulse</span></div><h2>{tab}</h2><p>{tab === "Hoy" ? "Lunes, 26 de octubre" : tab === "Tendencias" ? "Cambios observados en tus registros" : tab === "Diario" ? "Tu contexto, en tus palabras" : tab === "Sueño" ? "Con tu reloj o con tu propio registro" : "Tu cuenta, tus datos y tus decisiones"}</p></header>
        {tab === "Hoy" && <>
          <button className="bp-score-button" type="button" onClick={() => setPanel("score")}><DemoRing title="BioScore" value={78} /><span>Índice personal · ayer · ejemplo simulado</span><small><ArrowUpRight size={11} /> Ver componentes</small></button>
          <DemoSection title="Señales de hoy" subtitle="Mediciones y registros, no puntuaciones" />
          <div className="bp-metric-grid"><button className="bp-card bp-energy" type="button" onClick={() => setPanel("active")}><span className="bp-metric-label"><Zap size={12} /> Energía activa</span><strong>486 kcal</strong><DemoBars values={energy} label="Energía activa por hora" /><span className="bp-chart-labels"><span>6 a. m.</span><span>12 p. m.</span><span>6 p. m.</span></span><small>Registrada por hora · simulada</small></button><div className="bp-metric-stack">{metricButton("hrv")}{metricButton("resting")}</div>{metricButton("sleep")}{metricButton("steps")}</div>
          <DemoCard><strong>¿Cómo dormiste?</strong><p>No necesitas dormir con el reloj. También puedes registrar tu descanso.</p><button className="bp-primary" type="button" onClick={() => setPanel("sleep-editor")}>{sleepReported ? "Editar mi sueño" : "Registrar mi sueño"}</button></DemoCard>
          <DemoSection title="Dale contexto" subtitle="Tus datos cuentan solo una parte" />
          <button className="bp-card bp-link" type="button" onClick={() => setTab("Diario")}><BookOpen size={17} /><span><strong>Añadir al Diario</strong><small>Registra un hábito, síntoma o evento.</small></span><ChevronRight size={13} /></button>
          <button className="bp-card bp-link" type="button" onClick={() => setPanel("breathing")}><Wind size={17} /><span><strong>Una pausa para respirar</strong><small>Sigue un ritmo visual a tu propio paso.</small></span><ChevronRight size={13} /></button>
          <p className="bp-footnote">BioPulse no ofrece diagnósticos médicos. Todas las cifras de este teléfono son simuladas.</p>
        </>}
        {tab === "Tendencias" && <>
          <DemoCard><span className="bp-caption">SEÑAL DE CAMBIO PERSONAL</span><strong>Sin cambio persistente</strong><p>Lectura de ejemplo, sin valor clínico.</p><details><summary>Cómo se interpreta</summary><p>Compara señales con tu propio historial. Una coincidencia no demuestra una causa. Aquí se usan únicamente datos simulados.</p></details></DemoCard>
          <DemoCard><strong>Tu historia, día a día</strong><p>Los huecos no se rellenan.</p><div className="bp-segments" role="group" aria-label="Periodo de tendencias de demostración">{[7, 30, 90].map(days => <button type="button" key={days} aria-pressed={period === days} onClick={() => setPeriod(days)}>{days} días</button>)}</div><label className="bp-chart-select">Señal<select value={trendMetric} onChange={e => setTrendMetric(e.target.value as MetricKey)}>{(["hrv", "resting", "sleep", "active"] as MetricKey[]).map(key => <option value={key} key={key}>{metricInfo[key].title}</option>)}</select></label><DemoBars values={trendValues} label={`${trend.title}, ${period} días`} /><div className="bp-chart-labels"><span>Hace {period} días</span><span>Hoy</span></div><small>Agregados simulados · {trend.unit}</small></DemoCard>
          <DemoCard><span className="bp-caption">MODELO ML · ISOLATION FOREST</span><strong>Datos insuficientes</strong><details><summary>Método y cobertura</summary><p>La app iOS evalúa un patrón personal en el dispositivo. Esta demo no entrena ni ejecuta modelos.</p></details></DemoCard>
          <DemoSection title="Mediciones" subtitle="Toca una señal para conocerla" />
          {(["hrv", "resting", "active", "steps"] as MetricKey[]).map(key => <button key={key} className="bp-card bp-link" type="button" onClick={() => setPanel(key)}><Activity size={14} /><span><strong>{metricInfo[key].title}</strong><small>Ejemplo simulado</small></span><b>{metricInfo[key].value}</b><ChevronRight size={12} /></button>)}
        </>}
        {tab === "Diario" && <>
          <div className="bp-day-picker"><button type="button" aria-label="Ver día anterior del diario demo" onClick={() => setJournalDay(day => day - 1)}><ChevronLeft size={15} /></button><span>{journalDay === 0 ? "Hoy" : dayLabel}</span><button type="button" aria-label="Ver día siguiente del diario demo" disabled={journalDay === 0} onClick={() => setJournalDay(day => Math.min(0, day + 1))}><ChevronRight size={15} /></button></div>
          <DemoCard><strong>¿Cómo te sientes{journalDay === 0 ? " hoy" : " ese día"}?</strong><p>Tu respuesta es subjetiva, no una medición.</p><div className="bp-moods" role="group" aria-label="Energía subjetiva de demostración">{["Con poca energía", "Intermedia", "Con energía"].map(mood => <button type="button" key={mood} aria-pressed={moods[journalDay] === mood} onClick={() => setMoods(current => ({ ...current, [journalDay]: mood }))}>{mood}</button>)}</div></DemoCard>
          <button className="bp-primary" type="button" onClick={() => setPanel("journal-editor")}><Plus size={13} /> Añadir registro</button>
          <DemoSection title="Línea de tiempo" subtitle={`${visibleEntries.length} registros de demostración`} />
          {visibleEntries.length ? visibleEntries.map(entry => <DemoCard key={entry.id} className="bp-entry"><BookOpen size={14} /><div><small>{entry.time} · EJEMPLO</small><strong>{entry.title}</strong><p>{entry.note}</p></div></DemoCard>) : <DemoCard><strong>Empieza cuando algo importe</strong><p>Añade un registro para explorar esta vista.</p></DemoCard>}
          <DemoCard className="bp-link"><LockKeyhole size={16} /><span><strong>Privado en este dispositivo</strong><small>Esta demo conserva tus cambios solo hasta recargar la página. No los envía.</small></span></DemoCard>
        </>}
        {tab === "Sueño" && <>
          <DemoCard><div className="bp-sleep-summary"><DemoRing title="Sleep Score" value={sleepReported ? null : 84} /><div><span>Tiempo dormido</span><strong>{sleepValue}</strong><small>{sleepReported ? "Estimado por ti · demo" : "Duración simulada"}</small></div></div><p>{sleepReported ? "El registro manual es un ejemplo. El índice no se recalcula en esta demo." : "Índice exploratorio y duración de ejemplo."}</p></DemoCard>
          <DemoCard><strong>¿Cómo dormiste?</strong><p>Con tu reloj o con tu propio registro.</p><button className="bp-primary" type="button" onClick={() => setPanel("sleep-editor")}>{sleepReported ? "Editar el sueño de hoy" : "Registrar mi sueño"}</button></DemoCard>
          <DemoCard><strong>Meta personal de sueño</strong><span className="bp-setting-value">8,0 horas</span><small>Valor de ejemplo</small></DemoCard>
          <DemoCard><details><summary>Qué resume este índice</summary><p>Combina duración y cercanía a tu duración habitual. Requiere historial suficiente y no representa un diagnóstico ni estima etapas ausentes.</p></details></DemoCard>
          <DemoCard><strong>Etapas disponibles en Apple Salud</strong><div className="bp-empty-chart"><TrendingUp size={18} /><p>No se incluyen etapas del dispositivo en esta demo.</p></div></DemoCard>
        </>}
        {tab === "Perfil" && <>
          <DemoCard className="bp-account"><UserRound size={26} /><div><strong>Cuenta de demostración</strong><small>Sesión de ejemplo · sin datos personales</small></div></DemoCard>
          <DemoSection title="Apple Salud" subtitle="La fuente principal de BioPulse en iOS" />
          <DemoCard className="bp-link"><Heart size={17} /><span><strong>Disponible en un iPhone</strong><small>Elige las categorías que quieres compartir. La web no solicita permisos de Salud.</small></span></DemoCard>
          <div className="bp-action-pair"><button className="bp-primary" type="button" onClick={() => setPanel("health")}>Abrir Ajustes</button><button className="bp-secondary" type="button" onClick={() => setPanel("health")}><RefreshCw size={12} /> Actualizar mediciones</button></div>
          <DemoSection title="CSV" subtitle="Revisa un archivo antes de incorporarlo" />
          <DemoCard className="bp-link"><FileUp size={17} /><span><strong>Importación privada en el iPhone</strong><small>La app procesa el archivo localmente.</small></span></DemoCard>
          <button className="bp-secondary" type="button" onClick={() => setPanel("csv")}>Revisar archivo CSV</button>
          <DemoSection title="Privacidad" subtitle="Tus datos, tus decisiones" />
          <DemoCard><details><summary>Centro de privacidad y permisos</summary><p>Iniciar sesión no conecta automáticamente tus datos de salud. En iOS se usa Apple Health; en la web, Health Auto Export es un servicio diferente.</p></details></DemoCard>
        </>}
      </div>
      <button type="button" className="bp-coach" onClick={() => { setCoachExample(false); setPanel("coach"); }} aria-label="Ver demostración del Coach IA"><Sparkles size={13} /> Coach IA</button>
      <nav className="bp-tabbar" aria-label="Pestañas de la demo de BioPulse">{demoTabs.map(({ name, icon: Icon }) => <button key={name} type="button" aria-label={`Ver pestaña ${name}`} aria-current={tab === name ? "page" : undefined} onClick={() => setTab(name)}><Icon size={18} strokeWidth={tab === name ? 2.4 : 1.7} /><span>{name}</span></button>)}</nav>
      <div className="land-iphone-home-indicator" />
      {panel && <div className="bp-modal-layer"><button className="bp-modal-shade" type="button" tabIndex={-1} onClick={() => setPanel(null)} aria-label="Cerrar panel de demostración" /><div ref={dialogRef} className="bp-sheet" role="dialog" aria-modal="true" aria-labelledby="bp-sheet-title"><div className="bp-sheet-handle" /><div className="bp-sheet-top"><h3 id="bp-sheet-title">{selectedMetric?.title ?? (panel === "score" ? "BioScore" : panel === "journal-editor" ? "Añadir registro" : panel === "sleep-editor" ? "Registrar mi sueño" : panel === "coach" ? "Coach IA" : panel === "health" ? "Apple Salud" : panel === "csv" ? "Importar CSV" : "Una pausa para respirar")}</h3><button ref={closeRef} type="button" onClick={() => setPanel(null)} aria-label="Cerrar detalle de la demo"><X size={17} /></button></div><span className="bp-sheet-demo">DEMO · DATOS SIMULADOS</span>
        {selectedMetric && <><div className="bp-detail-value">{panel === "sleep" ? sleepValue : selectedMetric.value}</div><DemoBars values={panel === "sleep" ? [...selectedMetric.history.slice(0, -1), sleepMinutes] : selectedMetric.history} label={selectedMetric.title} /><p>{selectedMetric.description}</p><small>Fuente de esta vista: simulación. No son datos de Apple Salud ni de tu dispositivo.</small></>}
        {panel === "score" && <><DemoRing title="BioScore" value={78} /><p>Índice personal exploratorio. En la app real requiere historial y cobertura suficiente.</p><ul className="bp-component-list"><li>Sueño <b>{sleepValue}</b></li><li>HRV <b>53 ms</b></li><li>FC en reposo <b>58 lpm</b></li><li>Energía activa <b>486 kcal</b></li></ul><small>Estos componentes y el índice son ejemplos simulados. No evalúan tu salud.</small></>}
        {panel === "journal-editor" && <form className="bp-form" onSubmit={event => { event.preventDefault(); const data = new FormData(event.currentTarget); setEntries(current => [...current, { id: Date.now(), day: journalDay, title: String(data.get("title")).trim(), note: String(data.get("note")).trim(), time: "Ahora" }]); setPanel(null); }}><p>Explora el registro. Se conserva en esta página hasta recargarla.</p><label>Título<input name="title" required maxLength={80} placeholder="Por ejemplo: salí a caminar" /></label><label>Nota opcional<textarea name="note" maxLength={240} rows={3} placeholder="¿Qué quieres recordar?" /></label><button className="bp-primary" type="submit">Añadir a la demo</button></form>}
        {panel === "sleep-editor" && <form className="bp-form" onSubmit={event => { event.preventDefault(); const data = new FormData(event.currentTarget); setSleepMinutes(Math.min(1440, Number(data.get("hours")) * 60 + Number(data.get("minutes")))); setSleepReported(true); setPanel(null); }}><p>Estimación subjetiva para explorar la interfaz.</p><div className="bp-action-pair"><label>Horas<input name="hours" type="number" min="0" max="23" required defaultValue={Math.floor(sleepMinutes / 60)} /></label><label>Minutos<input name="minutes" type="number" min="0" max="59" required defaultValue={sleepMinutes % 60} /></label></div><button className="bp-primary" type="submit">Guardar en la demo</button><small>No se escribe en Apple Salud ni en tu cuenta.</small></form>}
        {panel === "coach" && <><p>Vista previa del Coach de BioPulse. Esta demo no envía datos ni consulta un modelo.</p><button type="button" className="bp-secondary" onClick={() => setCoachExample(true)}>Ver una respuesta de ejemplo</button>{coachExample && <DemoCard><strong>Respuesta de demostración</strong><p>En el ejemplo aparecen sueño, actividad y notas personales. Puedes revisar su evolución y añadir contexto; una coincidencia entre registros no demuestra una causa.</p></DemoCard>}</>}
        {panel === "health" && <><ShieldCheck size={28} /><p>En la app iOS puedes elegir categorías de Apple Health y revisar sus permisos. Este teléfono de demostración no accede a tus datos.</p><small>En la versión web se usa Health Auto Export, un servicio diferente y opcional.</small></>}
        {panel === "csv" && <><FileUp size={28} /><p>En la app iOS puedes revisar un CSV antes de usarlo. El archivo se procesa localmente y se mantiene separado de Apple Salud.</p><small>La carga de archivos se realiza en la app. Esta vista es una demostración.</small></>}
        {panel === "breathing" && <><div className="bp-breathing-orb" aria-hidden="true" /><p>Haz una pausa y respira a tu propio ritmo.</p><small>Animación ilustrativa. Sin seguimiento ni mediciones.</small></>}
      </div></div>}
    </div>
    <p className="bp-demo-hint">Explora las pestañas y toca las tarjetas.</p>
  </div>;
}
