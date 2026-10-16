export type Stream = "daily" | "intraday";
type RecordValue = Record<string, unknown>;
export type DailyRow = {
  local_date: string;
  timezone_identifier: string;
  metric_kind: string;
  value: number;
  unit: string;
  aggregation: string;
  sample_count: number;
  coverage_fraction: null;
  quality: "observed";
  source_kind: "health_auto_export_aggregate";
  formula_version: "hae-v2-aggregate-v1";
};
export type HourlyRow = {
  bucket_start: string;
  local_date: string;
  timezone_identifier: string;
  metric_kind: string;
  value: number;
  unit: string;
  aggregation: string;
  source_kind: "health_auto_export_aggregate";
};
export type SleepRow = {
  local_date: string;
  stage: string;
  minutes: number;
  source_kind: "health_auto_export_aggregate";
};
export type Normalized = {
  daily: DailyRow[];
  hourly: HourlyRow[];
  sleep: SleepRow[];
};

const dailyNames: Record<string, [string, string, string]> = {
  step_count: ["steps", "count", "sum"],
  active_energy: ["active_energy", "kcal", "sum"],
  resting_heart_rate: ["resting_heart_rate", "bpm", "mean"],
  heart_rate_variability: ["hrv_sdnn", "ms", "mean"],
  hrv_sdnn: ["hrv_sdnn", "ms", "mean"],
};
const hourlyNames: Record<string, [string, string, string]> = {
  active_energy: ["active_energy", "kcal", "sum"],
};
const units: Record<string, string[]> = {
  count: ["count"],
  kcal: ["kcal"],
  bpm: ["bpm"],
  ms: ["ms"],
};
const dayPattern = /^\d{4}-\d{2}-\d{2}$/;
const timestampPattern =
  /^(\d{4}-\d{2}-\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{2}:?\d{2})$/;
function object(value: unknown): value is RecordValue {
  return !!value && typeof value === "object" && !Array.isArray(value);
}
function number(value: unknown, max: number): number {
  if (
    typeof value !== "number" || !Number.isFinite(value) || value < 0 ||
    value > max
  ) throw new Error("invalid_value");
  return value;
}
function dateParts(
  raw: unknown,
  stream: Stream,
): { day: string; timezone: string; iso?: string } {
  if (typeof raw !== "string") throw new Error("invalid_date");
  if (stream === "daily" && dayPattern.test(raw)) {
    if (Number.isNaN(Date.parse(`${raw}T00:00:00Z`))) {
      throw new Error("invalid_date");
    }
    return { day: raw, timezone: "local-day" };
  }
  const match = timestampPattern.exec(raw);
  if (!match) throw new Error("invalid_date");
  const [, day, hour, minute, second = "00", zone] = match;
  if (
    Number.isNaN(
      Date.parse(
        `${day}T${hour}:${minute}:${second}${
          zone.replace(/([+-]\d{2})(\d{2})$/, "$1:$2")
        }`,
      ),
    )
  ) throw new Error("invalid_date");
  if (
    stream === "daily" && (hour !== "00" || minute !== "00" || second !== "00")
  ) throw new Error("daily_aggregation_required");
  if (stream === "intraday" && (minute !== "00" || second !== "00")) {
    throw new Error("hourly_aggregation_required");
  }
  const offset = zone.includes(":")
    ? zone
    : `${zone.slice(0, 3)}:${zone.slice(3)}`;
  const iso = new Date(`${day}T${hour}:${minute}:${second}${offset}`)
    .toISOString();
  return { day, timezone: `UTC${offset}`, iso };
}
function metricValue(row: RecordValue, kind: string): number {
  const value = number(
    kind === "heart_rate" ? row.Avg : row.qty,
    kind === "steps" ? 200000 : 100000,
  );
  if (
    ["resting_heart_rate", "hrv_sdnn", "heart_rate"].includes(kind) &&
    value === 0
  ) throw new Error("invalid_value");
  return value;
}

export function normalizeExport(payload: unknown, stream: Stream): Normalized {
  if (
    !object(payload) || !object(payload.data) ||
    !Array.isArray(payload.data.metrics)
  ) throw new Error("invalid_export");
  const result: Normalized = { daily: [], hourly: [], sleep: [] };
  const metrics = payload.data.metrics;
  if (metrics.length > 16) throw new Error("too_many_metrics");
  const seen = new Set<string>();
  for (const metric of metrics) {
    if (
      !object(metric) || typeof metric.name !== "string" ||
      !Array.isArray(metric.data) || metric.data.length > 32
    ) throw new Error("invalid_metric");
    if (seen.has(metric.name)) throw new Error("duplicate_metric");
    seen.add(metric.name);
    if (metric.name === "sleep_analysis") {
      if (stream !== "daily" || metric.units !== "hr") {
        throw new Error("unsupported_metric");
      }
      for (const row of metric.data) {
        if (
          !object(row) || typeof row.date !== "string" ||
          !dayPattern.test(row.date) || "startDate" in row || "endDate" in row
        ) throw new Error("aggregate_sleep_required");
        const { day, timezone } = dateParts(row.date, "daily");
        const hours = number(row.totalSleep ?? row.asleep, 24);
        result.daily.push({
          local_date: day,
          timezone_identifier: timezone,
          metric_kind: "sleep_duration",
          value: hours * 60,
          unit: "min",
          aggregation: "duration",
          sample_count: 1,
          coverage_fraction: null,
          quality: "observed",
          source_kind: "health_auto_export_aggregate",
          formula_version: "hae-v2-aggregate-v1",
        });
        for (
          const [field, stage] of [
            ["core", "core"],
            ["deep", "deep"],
            ["rem", "rem"],
            ["asleep", "asleep"],
            ["inBed", "in_bed"],
          ]
        ) {
          if (row[field] !== undefined) {
            result.sleep.push({
              local_date: day,
              stage,
              minutes: number(row[field], 24) * 60,
              source_kind: "health_auto_export_aggregate",
            });
          }
        }
      }
      continue;
    }
    const specification =
      (stream === "daily" ? dailyNames : hourlyNames)[metric.name];
    if (!specification) throw new Error("unsupported_metric");
    const [kind, unit, aggregation] = specification;
    if (
      typeof metric.units !== "string" || !units[unit].includes(metric.units)
    ) throw new Error("unsupported_unit");
    for (const row of metric.data) {
      if (!object(row) || "startDate" in row || "endDate" in row) {
        throw new Error("aggregate_required");
      }
      const { day, timezone, iso } = dateParts(row.date, stream);
      const value = metricValue(row, kind);
      if (stream === "daily") {
        result.daily.push({
          local_date: day,
          timezone_identifier: timezone,
          metric_kind: kind,
          value,
          unit,
          aggregation,
          sample_count: 1,
          coverage_fraction: null,
          quality: "observed",
          source_kind: "health_auto_export_aggregate",
          formula_version: "hae-v2-aggregate-v1",
        });
      } else {result.hourly.push({
          bucket_start: iso!,
          local_date: day,
          timezone_identifier: timezone,
          metric_kind: kind,
          value,
          unit,
          aggregation,
          source_kind: "health_auto_export_aggregate",
        });}
    }
  }
  for (const row of [...result.daily, ...result.hourly, ...result.sleep]) {
    const key = "metric_kind" in row
      ? `${row.local_date}:${row.metric_kind}:${
        "bucket_start" in row ? row.bucket_start : ""
      }`
      : `${row.local_date}:${row.stage}`;
    if (seen.has(`row:${key}`)) throw new Error("duplicate_bucket");
    seen.add(`row:${key}`);
  }
  return result;
}
