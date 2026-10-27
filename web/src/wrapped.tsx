import { useEffect, useId, useMemo, useRef, useState, type CSSProperties } from "react";
import { ArrowLeft, ArrowRight, Check, Download, Maximize2, X } from "lucide-react";
import type { Daily, Journal } from "./data";
import { today } from "./data";
import { buildWrapped, journalDay, metricText, monthLabel, previousMonth, wrappedMetrics, wrappedMonths, type WrappedKind } from "./wrapped-data";
import "./wrapped.css";
import { useMotionVisibility } from "./motion";

type Props = { daily: Daily[]; journal: Journal[]; source: string; simulated?: boolean; onClose: () => void; embedded?: boolean; onExpand?: () => void };
const chapters = ["Tu mes", "Panorama", "Sueño", "Actividad", "Señales", "Diario", "Compartir"];
const kinds = Object.keys(wrappedMetrics) as WrappedKind[];

export function WrappedEntry({ onClick }: { onClick: () => void }) {
  return <button type="button" className="wrapped-entry" onClick={onClick}><span className="wrapped-entry-art" aria-hidden="true">↗</span><span><small>BIOPULSE WRAPPED</small><strong>Tu mes tiene una historia.</strong><span>Recórrela, explórala y hazla tuya.</span></span><ArrowRight size={20} /></button>;
}

function MetricScene({ kind, snapshot, onCompare, compare, source }: { kind: WrappedKind; snapshot: ReturnType<typeof buildWrapped>; onCompare: () => void; compare: boolean; source: string }) {
  const [dayIndex, setDayIndex] = useState(0);
  const [detail, setDetail] = useState(false);
  const values = snapshot.series(kind); const stats = snapshot.stats(kind); const previous = snapshot.stats(kind, previousMonth(snapshot.month));
  const index = Math.min(dayIndex, snapshot.days.length - 1); const selectedDay = snapshot.days[index];
  const selected = values.find(p => p.day === selectedDay);
  const notes = snapshot.entries.filter(e => journalDay(e) === selectedDay);
  const ceiling = Math.max(...values.map(p => p.value), 1);
  const label = wrappedMetrics[kind];
  const change = stats.mean !== null && previous.mean !== null ? stats.mean - previous.mean : null;
  return <div className="wrap-metric" style={{ "--wrap-accent": label.accent } as CSSProperties}>
    <span className="wrap-kicker">{label.title} / media de días registrados</span>
    <button type="button" className="wrap-big-value" onClick={() => setDetail(!detail)} aria-expanded={detail}>{metricText(stats.mean, kind)}<small>{detail ? "Ocultar detalles −" : "Explorar detalles +"}</small></button>
    <p>{stats.count} de {snapshot.dayCount} días con esta señal.</p>
    <div className="wrap-chart" role="group" aria-label={`Explorar ${label.title} día a día`}>
      <svg viewBox="0 0 310 130" preserveAspectRatio="none" role="img" aria-label={`${label.title}: ${stats.count} días registrados. Selecciona un día debajo.`}>
        {[30, 75, 120].map(y => <line x1="0" x2="310" y1={y} y2={y} key={y} />)}
        {snapshot.days.map((day, i) => { const point = values.find(p => p.day === day); const slot = 310 / snapshot.dayCount; return point ? <rect key={day} className={i === index ? "is-selected" : ""} x={i * slot + 1} y={120 - point.value / ceiling * 108} width={slot - 2} height={Math.max(2, point.value / ceiling * 108)} rx="2" /> : <circle key={day} cx={i * slot + slot / 2} cy="123" r="1" />; })}
      </svg>
      <label className="wrap-scrubber">Recorre los días<input type="range" min="0" max={snapshot.dayCount - 1} value={index} onChange={e => setDayIndex(Number(e.target.value))} aria-label={`Día de ${label.title}`} aria-valuetext={`${selectedDay}: ${metricText(selected?.value ?? null, kind)}`} /></label>
      <div className="wrap-day-readout" aria-live="polite"><span>{new Date(`${selectedDay}T12:00:00`).toLocaleDateString("es", { day: "numeric", month: "short" })}</span><strong>{metricText(selected?.value ?? null, kind)}</strong></div>
      <small>{selected ? `${selected.source === "simulated" ? "Dato simulado" : selected.source.includes("csv") ? "CSV local" : selected.source.includes("manual") ? "Registro manual" : source}${selected.quality !== "observed" && selected.quality !== "simulated" ? ` · ${selected.quality === "estimated" ? "estimado" : selected.quality}` : ""}` : "Este día no tiene registros de esta señal."}</small>
      {notes.map(e => <p className="wrap-note" key={e.id}>✎ {e.title}</p>)}
    </div>
    {detail && <div className="wrap-facts"><div><small>Mínimo</small><strong>{metricText(stats.min, kind)}</strong></div><div><small>Máximo</small><strong>{metricText(stats.max, kind)}</strong></div>{["steps", "active_energy", "sleep_duration"].includes(kind) && <div><small>Total registrado</small><strong>{metricText(stats.total, kind)}</strong></div>}<div className="wrap-weekly"><small>Medias por tramo de la semana</small>{Array.from({ length: Math.ceil(snapshot.dayCount / 7) }, (_, week) => {
      const points = values.filter(p => Math.floor((Number(p.day.slice(-2)) - 1) / 7) === week);
      return points.length ? <button type="button" key={week} onClick={() => setDayIndex(Number(points[0].day.slice(-2)) - 1)}><span>Días {week * 7 + 1}–{Math.min((week + 1) * 7, snapshot.dayCount)} <small>({points.length} registrados)</small></span><b>{metricText(points.reduce((total, p) => total + p.value, 0) / points.length, kind)}</b></button> : null;
    })}</div></div>}
    <button type="button" className="wrap-compare" onClick={onCompare} aria-pressed={compare}>{compare ? "Ocultar comparación" : "Comparar con el mes anterior"}</button>
    {compare && <div className="wrap-comparison"><small>{monthLabel(previousMonth(snapshot.month))}</small><strong>{metricText(previous.mean, kind)}</strong><span>{previous.count} días registrados{change !== null ? ` · diferencia media: ${change >= 0 ? "+" : "−"}${metricText(Math.abs(change), kind)}` : ""}</span><small>Se comparan las medias de los días disponibles; la cobertura puede ser diferente.</small></div>}
  </div>;
}

export function WrappedStory({ daily, journal, source, simulated = false, onClose, embedded = false, onExpand }: Props) {
  const now = simulated ? new Date("2026-10-26T12:00:00Z") : new Date();
  const available = useMemo(() => wrappedMonths(daily, journal, now), [daily, journal, simulated]);
  const [month, setMonth] = useState(() => available.find(m => daily.some(r => r.local_date.startsWith(`${m}-`)) || journal.some(e => journalDay(e).startsWith(`${m}-`))) ?? available[0]);
  const selectedMonth = available.includes(month) ? month : available[0];
  const snapshot = useMemo(() => buildWrapped(daily, journal, selectedMonth, simulated ? "2026-10-26" : today()), [daily, journal, selectedMonth, simulated]);
  const [page, setPage] = useState(0); const pages = useRef<HTMLDivElement>(null);
  const [activeKind, setActiveKind] = useState<WrappedKind>("steps"); const [signalKind, setSignalKind] = useState<WrappedKind>("hrv_sdnn");
  const [compare, setCompare] = useState(false); const [contextDay, setContextDay] = useState(0);
  const [shareKinds, setShareKinds] = useState<WrappedKind[]>(["sleep_duration", "steps"]); const [message, setMessage] = useState("");
  const titleId = useId();
  const motion = useMotionVisibility<HTMLElement>();
  const go = (next: number) => { const target = Math.max(0, Math.min(6, next)); const root = pages.current; root?.scrollTo({ left: root.clientWidth * target, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" }); };
  const day = snapshot.days[contextDay] ?? snapshot.days[0]; const notes = snapshot.entries.filter(e => journalDay(e) === day);

  useEffect(() => {
    const focused = document.activeElement;
    if (focused instanceof HTMLElement && focused.closest(".wrap-page[inert]")) {
      pages.current?.children[page]?.querySelector<HTMLElement>("h2")?.focus({ preventScroll: true });
    }
  }, [page]);

  async function download() {
    setMessage("");
    try {
      const canvas = document.createElement("canvas"); canvas.width = 1080; canvas.height = 1350;
      const ctx = canvas.getContext("2d"); if (!ctx) throw new Error();
      ctx.fillStyle = "#101817"; ctx.fillRect(0, 0, 1080, 1350);
      ctx.strokeStyle = "#b9dba2"; ctx.lineWidth = 2;
      for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.ellipse(850, 180, 290 + i * 16, 300 + i * 11, i * .07, 0, Math.PI * 2); ctx.stroke(); }
      ctx.fillStyle = "#e8efe9"; ctx.font = "32px system-ui"; ctx.fillText("BIOPULSE / WRAPPED", 80, 105);
      ctx.font = "bold 65px system-ui"; ctx.fillText(monthLabel(selectedMonth), 80, 355, 920);
      ctx.font = "30px system-ui"; ctx.fillStyle = "#b9c8bf"; ctx.fillText(`${snapshot.recorded.size} días con registros${snapshot.partial ? " · mes en curso" : ""}`, 80, 420);
      shareKinds.forEach((kind, i) => { ctx.fillStyle = wrappedMetrics[kind].accent; ctx.font = "28px system-ui"; ctx.fillText(wrappedMetrics[kind].title.toUpperCase(), 80, 540 + i * 125); ctx.fillStyle = "#f5f7f4"; ctx.font = "bold 44px system-ui"; ctx.fillText(metricText(snapshot.stats(kind).mean, kind), 80, 595 + i * 125); });
      ctx.fillStyle = "#bac5be"; ctx.font = "25px system-ui"; ctx.fillText("Medias de días registrados · " + source, 80, 1245, 920); ctx.fillText(simulated ? "DATOS SIMULADOS · DEMOSTRACIÓN" : "Mi mes, en perspectiva. · BioPulse", 80, 1290, 920);
      const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(b => b ? resolve(b) : reject(new Error()), "image/png"));
      const url = URL.createObjectURL(blob); const anchor = document.createElement("a"); anchor.href = url; anchor.download = `biopulse-wrapped-${selectedMonth}.png`; anchor.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); setMessage("Imagen preparada. Incluye solo las métricas que elegiste.");
    } catch { setMessage("No se pudo crear la imagen. Inténtalo de nuevo."); }
  }

  return <section ref={motion.ref} data-motion-active={motion.active} data-page={page} className={`wrapped-story ${embedded ? "is-embedded" : ""}`} aria-labelledby={titleId}>
    <header className="wrap-header"><span id={titleId}>BIOPULSE <b>WRAPPED</b></span>{onExpand && <button type="button" onClick={onExpand} aria-label="Ver Wrapped en pantalla completa"><Maximize2 size={17} /></button>}<button type="button" onClick={onClose} aria-label="Cerrar Wrapped"><X size={21} /></button></header>
    <div className="wrap-month"><label>Tu archivo mensual<select value={selectedMonth} onChange={e => { setMonth(e.target.value); setContextDay(0); setCompare(false); setMessage(""); go(0); }}>{available.map(m => <option key={m} value={m}>{monthLabel(m)}</option>)}</select></label><small>{simulated ? "DATOS SIMULADOS" : snapshot.partial ? "MES EN CURSO" : "TU HISTORIAL"}</small></div>
    <nav className="wrap-progress" aria-label="Escenas de Wrapped">{chapters.map((chapter, i) => <button type="button" key={chapter} onClick={() => go(i)} aria-current={page === i ? "step" : undefined} aria-label={`${i + 1}. ${chapter}`}><span /></button>)}</nav>
    <div className="wrap-pages" ref={pages} onScroll={e => { const element = e.currentTarget; const next = Math.round(element.scrollLeft / element.clientWidth); if (next !== page) setPage(next); }}>
      <article inert={page !== 0} aria-hidden={page !== 0} className="wrap-page wrap-cover" aria-label="Portada"><div className="wrap-orbit" aria-hidden="true"><i /><i /><i /><span>↗</span></div><span className="wrap-kicker">01 / UNA NUEVA PERSPECTIVA</span><h2 tabIndex={-1}>Tu {new Date(`${selectedMonth}-01T12:00:00`).toLocaleDateString("es", { month: "long" })}.<br /><em>En BioPulse.</em></h2><p>Pequeñas señales. Un mes entero de historias.</p><strong className="wrap-cover-number">{snapshot.recorded.size}<small>días con registros</small></strong><button type="button" className="wrap-primary" onClick={() => go(1)}>Explorar mi mes <ArrowRight size={18} /></button>{snapshot.partial && <small>Un vistazo al mes hasta hoy.</small>}</article>
      <article inert={page !== 1} aria-hidden={page !== 1} className="wrap-page" aria-label="Panorama"><span className="wrap-kicker">02 / LA VISTA COMPLETA</span><h2 tabIndex={-1}>Un mes.<br /><em>Muchas señales.</em></h2><div className="wrap-overview">{kinds.map(kind => <button type="button" key={kind} onClick={() => { if (kind === "active_energy") setActiveKind(kind); if (kind === "resting_heart_rate") setSignalKind(kind); go(kind === "sleep_duration" ? 2 : kind === "steps" || kind === "active_energy" ? 3 : 4); }}><small>{wrappedMetrics[kind].title}</small><strong>{metricText(snapshot.stats(kind).mean, kind)}</strong><span>{snapshot.stats(kind).count} días · explorar ↗</span></button>)}</div><p>{snapshot.entries.length} entradas del Diario acompañaron este mes.</p><small>{source} · medias de días con registros. Los días sin señal quedan vacíos.</small></article>
      <article inert={page !== 2} aria-hidden={page !== 2} className="wrap-page" aria-label="Sueño"><span className="wrap-kicker">03 / TUS NOCHES</span><h2 tabIndex={-1}>El ritmo<br /><em>del descanso.</em></h2><MetricScene key={`${selectedMonth}-sleep`} kind="sleep_duration" snapshot={snapshot} compare={compare} onCompare={() => setCompare(!compare)} source={source} /></article>
      <article inert={page !== 3} aria-hidden={page !== 3} className="wrap-page" aria-label="Actividad"><span className="wrap-kicker">04 / EN MOVIMIENTO</span><h2 tabIndex={-1}>Cada día<br /><em>suma su parte.</em></h2><div className="wrap-segments">{(["steps", "active_energy"] as WrappedKind[]).map(kind => <button type="button" key={kind} aria-pressed={activeKind === kind} onClick={() => setActiveKind(kind)}>{wrappedMetrics[kind].title}</button>)}</div><MetricScene key={`${selectedMonth}-${activeKind}`} kind={activeKind} snapshot={snapshot} compare={compare} onCompare={() => setCompare(!compare)} source={source} /></article>
      <article inert={page !== 4} aria-hidden={page !== 4} className="wrap-page" aria-label="Señales"><span className="wrap-kicker">05 / TU PROPIO PATRÓN</span><h2 tabIndex={-1}>Escucha<br /><em>tus señales.</em></h2><div className="wrap-segments">{(["hrv_sdnn", "resting_heart_rate"] as WrappedKind[]).map(kind => <button type="button" key={kind} aria-pressed={signalKind === kind} onClick={() => setSignalKind(kind)}>{wrappedMetrics[kind].title}</button>)}</div><MetricScene key={`${selectedMonth}-${signalKind}`} kind={signalKind} snapshot={snapshot} compare={compare} onCompare={() => setCompare(!compare)} source={source} /></article>
      <article inert={page !== 5} aria-hidden={page !== 5} className="wrap-page" aria-label="Diario"><span className="wrap-kicker">06 / LO QUE VIVISTE</span><h2 tabIndex={-1}>Los números<br /><em>tienen contexto.</em></h2><p>Toca un día para reunir tus señales y tus palabras.</p><div className="wrap-context-layout"><div className="wrap-calendar">{snapshot.days.map((d, i) => <button type="button" key={d} disabled={d > (simulated ? "2026-10-26" : today())} className={contextDay === i ? "selected" : ""} onClick={() => setContextDay(i)} aria-pressed={contextDay === i} aria-label={`${d}${snapshot.entries.some(e => journalDay(e) === d) ? ", con Diario" : ""}`}>{i + 1}{snapshot.entries.some(e => journalDay(e) === d) && <span />}</button>)}</div><div className="wrap-context-day"><strong>{new Date(`${day}T12:00:00`).toLocaleDateString("es", { day: "numeric", month: "long" })}</strong>{kinds.map(k => { const p = snapshot.series(k).find(p => p.day === day); return p ? <p key={k}>{wrappedMetrics[k].title}<b>{metricText(p.value, k)}</b></p> : null; })}{notes.length ? notes.map(n => <div className="wrap-note" key={n.id}><strong>✎ {n.title}</strong><p>{n.notes}</p></div>) : <small>Sin anotaciones de Diario para este día.</small>}</div></div><small>Explora coincidencias entre registros; no establecen una causa.</small></article>
      <article inert={page !== 6} aria-hidden={page !== 6} className="wrap-page" aria-label="Compartir"><span className="wrap-kicker">07 / TU MES, CONTIGO</span><h2 tabIndex={-1}>Hazlo tuyo.<br /><em>Compártelo a tu manera.</em></h2><div className="wrap-share-preview"><span>BIOPULSE / {monthLabel(selectedMonth)}</span>{shareKinds.length ? shareKinds.map(k => <div key={k}><small>{wrappedMetrics[k].title}</small><strong>{metricText(snapshot.stats(k).mean, k)}</strong></div>) : <p>Elige las métricas de tu tarjeta.</p>}<small>{simulated ? "Datos simulados · " : ""}Medias de días registrados</small></div><fieldset className="wrap-share-choices"><legend>Qué incluir en la imagen</legend>{kinds.map(k => <label key={k}><input type="checkbox" checked={shareKinds.includes(k)} onChange={e => { setShareKinds(current => e.target.checked ? [...current, k] : current.filter(value => value !== k)); setMessage(""); }} />{wrappedMetrics[k].title}</label>)}</fieldset><button type="button" className="wrap-primary" onClick={download} disabled={!shareKinds.length}><Download size={18} /> Crear imagen</button><p className="wrap-download-message" role="status">{message && <><Check size={16} />{message}</>}</p><small>Revisa la vista previa. Las notas del Diario no se incluyen.</small></article>
    </div>
    <footer className="wrap-footer"><button type="button" onClick={() => go(page - 1)} disabled={page === 0} aria-label="Escena anterior"><ArrowLeft size={20} /></button><span>{String(page + 1).padStart(2, "0")} / 07 · {chapters[page]}</span><button type="button" onClick={() => page === 6 ? onClose() : go(page + 1)} aria-label={page === 6 ? "Terminar Wrapped" : "Siguiente escena"}>{page === 6 ? <Check size={20} /> : <ArrowRight size={20} />}</button></footer>
  </section>;
}

export function WrappedDialog(props: Props) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = dialog.current; const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const oldOverflow = document.body.style.overflow; document.body.style.overflow = "hidden";
    element?.showModal();
    return () => { element?.close(); document.body.style.overflow = oldOverflow; previous?.focus({ preventScroll: true }); };
  }, []);
  return <dialog aria-label="BioPulse Wrapped" className="wrapped-dialog" ref={dialog} onCancel={e => { e.preventDefault(); props.onClose(); }}><WrappedStory {...props} /></dialog>;
}
