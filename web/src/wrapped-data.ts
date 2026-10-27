import type { Daily, Journal } from "./data";

export const wrappedMetrics = {
  sleep_duration: { title: "Sueño", unit: "min", accent: "#b8a4ee" },
  steps: { title: "Pasos", unit: "pasos", accent: "#d1ed9b" },
  active_energy: { title: "Energía activa", unit: "kcal", accent: "#efbc85" },
  hrv_sdnn: { title: "HRV", unit: "ms", accent: "#a3d7d0" },
  resting_heart_rate: { title: "FC en reposo", unit: "lpm", accent: "#eea3b3" },
} as const;
export type WrappedKind = keyof typeof wrappedMetrics;
export type WrappedPoint = { day: string; value: number; source: string; quality: string };
const acceptedUnits: Record<WrappedKind, string[]> = { sleep_duration: ["min"], steps: ["count", "pasos"], active_energy: ["kcal"], hrv_sdnn: ["ms"], resting_heart_rate: ["bpm", "lpm"] };
const validDay = (day: string) => { const date = new Date(`${day}T12:00:00Z`); return /^\d{4}-\d{2}-\d{2}$/.test(day) && Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === day; };

export function journalDay(entry: Journal): string {
  try {
    return new Intl.DateTimeFormat("sv-SE", { timeZone: entry.timezone_identifier, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(entry.occurred_at));
  } catch { return entry.occurred_at.slice(0, 10); }
}
export function wrappedMonths(daily: Daily[], journal: Journal[], now = new Date()): string[] {
  const current = new Intl.DateTimeFormat("sv-SE", { year: "numeric", month: "2-digit" }).format(now);
  return [...new Set([current, ...daily.filter(r => validDay(r.local_date)).map(r => r.local_date.slice(0, 7)), ...journal.map(journalDay).filter(validDay).map(d => d.slice(0, 7))])].filter(m => m <= current).sort().reverse();
}
export function monthLabel(month: string): string {
  return new Date(`${month}-01T12:00:00`).toLocaleDateString("es", { month: "long", year: "numeric" });
}
export function previousMonth(month: string): string {
  const [year, m] = month.split("-").map(Number);
  const date = new Date(Date.UTC(year, m - 2, 1));
  return date.toISOString().slice(0, 7);
}
export function metricText(value: number | null, kind: WrappedKind): string {
  if (value === null) return "Sin registros";
  if (kind === "sleep_duration") { const minutes = Math.round(value); return `${Math.floor(minutes / 60)} h ${minutes % 60} min`; }
  return `${new Intl.NumberFormat("es", { maximumFractionDigits: kind === "hrv_sdnn" ? 1 : 0 }).format(value)} ${wrappedMetrics[kind].unit}`;
}
export function buildWrapped(daily: Daily[], journal: Journal[], month: string, today: string) {
  const unique = new Map<string, Daily>();
  // One aggregate per metric/day. Keep the latest revision; missing days remain absent.
  for (const row of daily) {
    if (!validDay(row.local_date) || row.local_date > today || !Number.isFinite(row.value) || row.value < 0 || row.value >= 1e12 || !(row.metric_kind in wrappedMetrics) || !acceptedUnits[row.metric_kind as WrappedKind].includes(row.unit)) continue;
    const key = `${row.local_date}/${row.metric_kind}`;
    if (!unique.has(key) || row.updated_at > unique.get(key)!.updated_at) unique.set(key, row);
  }
  const rows = [...unique.values()];
  const series = (kind: WrappedKind, selected = month): WrappedPoint[] => rows.filter(r => r.metric_kind === kind && r.local_date.startsWith(`${selected}-`)).map(r => ({ day: r.local_date, value: r.value, source: r.source_kind, quality: r.quality })).sort((a, b) => a.day.localeCompare(b.day));
  const stats = (kind: WrappedKind, selected = month) => {
    const points = series(kind, selected); const values = points.map(p => p.value); const total = values.reduce((a, b) => a + b, 0);
    return { count: values.length, mean: values.length ? total / values.length : null, total: values.length ? total : null, min: values.length ? Math.min(...values) : null, max: values.length ? Math.max(...values) : null };
  };
  const [year, m] = month.split("-").map(Number);
  const dayCount = new Date(year, m, 0).getDate();
  const days = Array.from({ length: dayCount }, (_, i) => `${month}-${String(i + 1).padStart(2, "0")}`);
  const entries = journal.filter(e => journalDay(e).startsWith(`${month}-`) && journalDay(e) <= today).sort((a, b) => a.occurred_at.localeCompare(b.occurred_at));
  const covered = new Set(rows.filter(r => r.local_date.startsWith(`${month}-`)).map(r => r.local_date));
  const recorded = new Set([...covered, ...entries.map(journalDay)]);
  return { month, dayCount, days, entries, covered, recorded, series, stats, partial: today.slice(0, 7) === month };
}

// Isolated fixture for the public phone: never passed to an authenticated account.
export function wrappedDemoData(): { daily: Daily[]; journal: Journal[] } {
  const daily: Daily[] = [];
  const bases: Record<WrappedKind, number> = { sleep_duration: 450, steps: 7800, active_energy: 460, hrv_sdnn: 51, resting_heart_rate: 59 };
  for (const month of [8, 9]) for (let day = 1; day <= (month === 9 ? 26 : 30); day++) {
    if (day === 6 || day === 19) continue;
    for (const [kind, base] of Object.entries(bases)) {
      const value = Math.round(base * (1 + Math.sin(day * .72 + kind.length) * .15 + (month === 9 ? .015 : 0)));
      daily.push({ local_date: `2026-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`, metric_kind: kind, value, unit: wrappedMetrics[kind as WrappedKind].unit, source_kind: "simulated", quality: "simulated", updated_at: "2026-10-26T12:00:00Z" });
    }
  }
  const journal: Journal[] = [3, 8, 12, 17, 22, 25].map((day, i) => ({ id: `demo-${day}`, category: "event", title: ["Caminata al aire libre", "Cambio de horario", "Entrenamiento suave", "Tarde tranquila", "Viaje de fin de semana", "Una pausa para mí"][i], notes: "Anotación de ejemplo para explorar el mes.", occurred_at: `2026-10-${String(day).padStart(2, "0")}T12:00:00Z`, timezone_identifier: "UTC" }));
  return { daily, journal };
}
