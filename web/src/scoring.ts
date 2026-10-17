import type { Daily } from "./data";

// Exploratory wellness indexes. These constants are product hypotheses, not clinical cutoffs.
export const SCORE_VERSION = "personal-v1";
export type ScoreResult = {
  value: number | null;
  date: string;
  version: string;
  reason: string;
  components: Record<string, number>;
  observations: Record<string, number>;
};

const units: Record<string, string> = {
  sleep_duration: "min", hrv_sdnn: "ms", resting_heart_rate: "bpm", active_energy: "kcal",
};
const clamp = (value: number) => Math.max(0, Math.min(100, value));
const isoDay = (value: string, delta: number) => {
  const day = new Date(`${value}T12:00:00Z`);
  day.setUTCDate(day.getUTCDate() + delta);
  return day.toISOString().slice(0, 10);
};
function observed(rows: Daily[], kind: string, date: string): number | null {
  const row = rows.find(r => r.metric_kind === kind && r.local_date === date);
  return row && row.quality === "observed" && row.unit === units[kind] &&
    Number.isFinite(row.value) && (kind === "active_energy" ? row.value >= 0 : row.value > 0) ? row.value : null;
}
function history(rows: Daily[], kind: string, date: string, window: number): number[] {
  const start = isoDay(date, -window);
  return rows.filter(r => r.metric_kind === kind && r.local_date >= start && r.local_date < date)
    .map(r => observed(rows, kind, r.local_date))
    .filter((value): value is number => value !== null);
}
function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
function baseline(rows: Daily[], kind: string, date: string, min = 14, window = 28) {
  const values = history(rows, kind, date, window);
  if (values.length < min) return null;
  const center = median(values);
  return { center, mad: median(values.map(value => Math.abs(value - center))), count: values.length };
}
function unavailable(date: string, reason: string): ScoreResult {
  return { value: null, date, version: SCORE_VERSION, reason, components: {}, observations: {} };
}
export function sleepScore(rows: Daily[], date: string, targetMinutes = 480): ScoreResult {
  if (!Number.isInteger(targetMinutes) || targetMinutes < 360 || targetMinutes > 600)
    return unavailable(date, "Configura una meta de sueño entre 6 y 10 horas.");
  const duration = observed(rows, "sleep_duration", date);
  if (duration === null) return unavailable(date, "Falta la duración observada de esta noche.");
  const prior = history(rows, "sleep_duration", date, 14);
  if (prior.length < 7) return unavailable(date, `Se necesitan 7 noches previas en 14 días; hay ${prior.length}.`);
  const durationScore = clamp(100 - Math.max(0, Math.abs(duration - targetMinutes) - 30) * 100 / 240);
  const consistencyScore = clamp(100 - Math.max(0, Math.abs(duration - median(prior)) - 30) * 100 / 150);
  const value = Math.round(0.65 * durationScore + 0.35 * consistencyScore);
  return {
    value, date, version: SCORE_VERSION,
    reason: "Índice exploratorio de duración y constancia; no mide etapas ni diagnostica sueño.",
    components: { duration: Math.round(durationScore), consistency: Math.round(consistencyScore) },
    observations: { durationMinutes: duration, priorNights: prior.length, targetMinutes },
  };
}
export function bioScore(rows: Daily[], date: string, targetMinutes = 480): ScoreResult {
  const sleep = sleepScore(rows, date, targetMinutes);
  if (sleep.value === null) return unavailable(date, `Sueño: ${sleep.reason}`);
  const kinds = ["hrv_sdnn", "resting_heart_rate", "active_energy"];
  const current = kinds.map(kind => observed(rows, kind, date));
  if (current.some(value => value === null))
    return unavailable(date, "Faltan HRV, FC en reposo o energía activa del día completo.");
  const references = kinds.map(kind => baseline(rows, kind, date));
  if (references.some(value => value === null))
    return unavailable(date, "Se necesitan 14 días previos de HRV, FC en reposo y energía activa en los últimos 28 días.");
  const [hrv, rhr, energy] = current as number[];
  const [hrvBase, rhrBase, energyBase] = references as NonNullable<ReturnType<typeof baseline>>[];
  const hrvScale = Math.max(1.4826 * hrvBase.mad, hrvBase.center * 0.1, 5);
  const rhrScale = Math.max(1.4826 * rhrBase.mad, rhrBase.center * 0.1, 3);
  const hrvIndex = clamp(75 + 15 * (hrv - hrvBase.center) / hrvScale);
  const rhrIndex = clamp(75 - 15 * (rhr - rhrBase.center) / rhrScale);
  const recovery = (hrvIndex + rhrIndex) / 2;
  // Activity balance expresses departure from routine, not a reward for exertion.
  const activity = clamp(100 - 60 * Math.abs(Math.log2((energy + 50) / (energyBase.center + 50))));
  return {
    value: Math.round(0.4 * sleep.value + 0.35 * recovery + 0.25 * activity),
    date, version: SCORE_VERSION,
    reason: "Índice exploratorio frente a tu historial; no es una medida de salud clínica.",
    components: { sleep: sleep.value, recovery: Math.round(recovery), activityBalance: Math.round(activity) },
    observations: { hrv, restingHeartRate: rhr, activeEnergy: energy, priorDays: Math.min(...references.map(r => r!.count)) },
  };
}
export function changeSignal(rows: Daily[], date: string): ScoreResult {
  const kinds = ["sleep_duration", "hrv_sdnn", "resting_heart_rate"];
  const levels = [date, isoDay(date, -1)].map(day => {
    const deviations = kinds.map((kind, index) => {
      const current = observed(rows, kind, day);
      const reference = baseline(rows, kinds[index], day);
      if (current === null || reference === null) return null;
      const floor = kind === "sleep_duration" ? 45 : kind === "hrv_sdnn" ? 5 : 3;
      const spread = Math.max(1.4826 * reference.mad, reference.center * 0.1, floor);
      return Math.abs(current - reference.center) / spread;
    });
    if (deviations.some(value => value === null)) return null;
    return deviations as number[];
  });
  if (levels.some(day => day === null)) return unavailable(date, "Se necesitan dos días completos y 14 días previos por señal para cada uno.");
  const persistent = levels.every(day => day!.filter(value => value >= 1.5).length >= 2);
  return {
    value: persistent ? Math.round(clamp(Math.max(...levels[0]!) * 20)) : 0,
    date, version: SCORE_VERSION,
    reason: persistent
      ? "Cambio persistente en al menos dos señales frente a tu referencia. Busca contexto; no indica una enfermedad."
      : "Sin cambio persistente en varias señales; esto no descarta problemas de salud.",
    components: Object.fromEntries(kinds.map((kind, index) => [kind, Math.round(levels[0]![index] * 10) / 10])),
    observations: { persistentDays: persistent ? 2 : 0 },
  };
}

const colorStops = [[0,232,79,88],[25,231,122,63],[50,229,198,74],[70,185,203,89],[82,169,217,104],[90,76,203,114],[100,24,199,96]];
export function scoreColor(value: number | null): string | undefined {
  if (value === null || !Number.isFinite(value)) return undefined;
  const capped = clamp(value);
  const upper = colorStops.findIndex(stop => capped <= stop[0]);
  const a = colorStops[Math.max(0, upper - 1)];
  const b = colorStops[upper];
  const ratio = a[0] === b[0] ? 0 : (capped - a[0]) / (b[0] - a[0]);
  return `rgb(${[1,2,3].map(i => Math.round(a[i] + (b[i] - a[i]) * ratio)).join(",")})`;
}
