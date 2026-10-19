import type { Daily } from "./data";

type Aggregation = "sum" | "median" | "latest";
type MetricSpec = { kind: string; unit: string; aggregation: Aggregation };
type Sample = { day: string; spec: MetricSpec; value: number; timestamp: number };
type Group = { spec: MetricSpec; day: string; values: number[]; sum: number; latest: number; latestAt: number };

const definitions: { names: string[]; spec: MetricSpec }[] = [
  { names: ["heartrate", "hkquantitytypeidentifierheartrate", "walkingheartrateaverage", "hkquantitytypeidentifierwalkingheartrateaverage"], spec: { kind: "heart_rate", unit: "bpm", aggregation: "median" } },
  { names: ["restingheartrate", "hkquantitytypeidentifierrestingheartrate"], spec: { kind: "resting_heart_rate", unit: "bpm", aggregation: "median" } },
  { names: ["heartratevariabilitysdnn", "hkquantitytypeidentifierheartratevariabilitysdnn"], spec: { kind: "hrv_sdnn", unit: "ms", aggregation: "median" } },
  { names: ["sleepduration"], spec: { kind: "sleep_duration", unit: "min", aggregation: "sum" } },
  { names: ["respiratoryrate", "hkquantitytypeidentifierrespiratoryrate"], spec: { kind: "respiratory_rate", unit: "breaths/min", aggregation: "median" } },
  { names: ["oxygensaturation", "hkquantitytypeidentifieroxygensaturation"], spec: { kind: "oxygen_saturation", unit: "%", aggregation: "median" } },
  { names: ["wristtemperaturedeviation"], spec: { kind: "wrist_temperature_deviation", unit: "°C", aggregation: "median" } },
  { names: ["stepcount", "hkquantitytypeidentifierstepcount"], spec: { kind: "steps", unit: "count", aggregation: "sum" } },
  { names: ["walkingrunningdistance", "hkquantitytypeidentifierdistancewalkingrunning"], spec: { kind: "walking_running_distance", unit: "m", aggregation: "sum" } },
  { names: ["activeenergyburned", "hkquantitytypeidentifieractiveenergyburned"], spec: { kind: "active_energy", unit: "kcal", aggregation: "sum" } },
  { names: ["appleexercisetime", "hkquantitytypeidentifierappleexercisetime"], spec: { kind: "exercise_duration", unit: "min", aggregation: "sum" } },
  { names: ["flightsclimbed", "hkquantitytypeidentifierflightsclimbed"], spec: { kind: "flights_climbed", unit: "count", aggregation: "sum" } },
  { names: ["vo2max", "hkquantitytypeidentifiervo2max"], spec: { kind: "vo2_max", unit: "ml/kg/min", aggregation: "median" } },
  { names: ["heartraterecoveryoneminute"], spec: { kind: "heart_rate_recovery_one_minute", unit: "bpm", aggregation: "latest" } },
];
const specs = new Map(definitions.flatMap(({ names, spec }) => names.map((name) => [name, spec] as const)));
const normalize = (value: string) => value.trim().replace(/\uFEFF/g, "").toLowerCase().replace(/[_\s]/g, "");
const dayPattern = /^(\d{4})-(\d{2})-(\d{2})$/;

export type CSVImportResult = {
  format: "tidy" | "wide";
  daily: Daily[];
  sourceRows: number;
  acceptedValues: number;
  rejectedValues: number;
  rejectedExamples: { row: number; reason: string }[];
  skippedRows: number;
  skippedTypes: string[];
  mappedMetrics: string[];
  firstDay: string;
  lastDay: string;
  warnings: string[];
};

function validDay(value: string): string | null {
  const match = dayPattern.exec(value.trim());
  if (!match) return null;
  const [, year, month, day] = match.map(Number);
  const candidate = new Date(Date.UTC(year, month - 1, day));
  return candidate.getUTCFullYear() === year && candidate.getUTCMonth() + 1 === month && candidate.getUTCDate() === day
    ? value.trim() : null;
}

function observedDay(value: string, formatter: Intl.DateTimeFormat): { day: string; timestamp: number } | null {
  const raw = value.trim();
  const apple = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$/.exec(raw);
  let timestamp: number;
  if (apple) {
    const [, y, m, d, hh, mm, ss, sign, offsetHours, offsetMinutes] = apple;
    const clock = Date.UTC(Number(y), Number(m) - 1, Number(d), Number(hh), Number(mm), Number(ss));
    if (!validDay(`${y}-${m}-${d}`) || Number(hh) > 23 || Number(mm) > 59 || Number(ss) > 59 || Number(offsetHours) > 23 || Number(offsetMinutes) > 59) return null;
    const offset = (Number(offsetHours) * 60 + Number(offsetMinutes)) * 60_000;
    timestamp = clock - (sign === "+" ? offset : -offset);
  } else {
    if (!/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:?\d{2})$/i.test(raw)) return null;
    timestamp = Date.parse(raw);
  }
  if (!Number.isFinite(timestamp)) return null;
  return { day: formatter.format(timestamp), timestamp };
}

function canonicalValue(rawValue: string, rawUnit: string, spec: MetricSpec): number | null {
  if (!rawValue.trim()) return null;
  const value = Number(rawValue.trim());
  if (!Number.isFinite(value)) return null;
  const unit = rawUnit.trim().toLowerCase();
  const compatible: Record<string, string[]> = {
    bpm: ["bpm", "count/min"],
    ms: ["ms"],
    min: ["min", "minute", "minutes"],
    "breaths/min": ["breaths/min"],
    "%": ["%", "percent"],
    "°C": ["degc", "°c", "celsius-delta"],
    count: ["count"],
    m: ["m", "km"],
    kcal: ["kcal"],
    "ml/kg/min": ["ml/(kg*min)", "ml/kg/min"],
  };
  if (!compatible[spec.unit]?.includes(unit)) return null;
  const normalized = spec.unit === "m" && unit === "km" ? value * 1_000 : value;
  if (spec.aggregation === "sum" && normalized < 0) return null;
  if (spec.aggregation !== "sum" && spec.kind !== "wrist_temperature_deviation" && normalized <= 0) return null;
  return Number.isFinite(normalized) ? normalized : null;
}

function median(values: number[]): number {
  values.sort((a, b) => a - b);
  const middle = Math.floor(values.length / 2);
  return values.length % 2 ? values[middle] : (values[middle - 1] + values[middle]) / 2;
}

function eachCSVRow(text: string, onRow: (fields: string[], rowNumber: number) => void): void {
  let fields: string[] = [];
  let field = "";
  let quoted = false;
  let line = 1;
  let rowStart = 1;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === '"') {
      if (quoted && text[i + 1] === '"') { field += '"'; i++; }
      else quoted = !quoted;
    } else if (char === "," && !quoted) {
      fields.push(field); field = "";
    } else if ((char === "\n" || char === "\r") && !quoted) {
      fields.push(field);
      if (fields.some((value) => value.trim())) onRow(fields, rowStart);
      fields = []; field = "";
      if (char === "\r" && text[i + 1] === "\n") i++;
      line++;
      rowStart = line;
    } else {
      field += char;
      if (char === "\n") line++;
    }
  }
  if (quoted) throw new Error("El CSV tiene comillas sin cerrar.");
  if (fields.length || field) {
    fields.push(field);
    if (fields.some((value) => value.trim())) onRow(fields, rowStart);
  }
}

export function parseHealthCSV(text: string, timeZone: string): CSVImportResult {
  if (!text.trim()) throw new Error("El archivo está vacío.");
  const formatter = new Intl.DateTimeFormat("sv-SE", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" });
  let headers: string[] | null = null;
  let format: "tidy" | "wide" | null = null;
  let dateColumn = -1;
  let sourceRows = 0;
  let acceptedValues = 0;
  let rejectedValues = 0;
  let skippedRows = 0;
  const rejectedExamples: CSVImportResult["rejectedExamples"] = [];
  const skippedTypes = new Set<string>();
  const mappedMetrics = new Set<string>();
  const groups = new Map<string, Group>();
  const reject = (row: number, reason: string) => {
    rejectedValues++;
    if (rejectedExamples.length < 5) rejectedExamples.push({ row, reason });
  };
  const add = ({ day, spec, value, timestamp }: Sample) => {
    const key = `${day}:${spec.kind}`;
    let group = groups.get(key);
    if (!group) {
      group = { spec, day, values: [], sum: 0, latest: value, latestAt: timestamp };
      groups.set(key, group);
    }
    if (spec.aggregation === "median") group.values.push(value);
    else if (spec.aggregation === "sum") group.sum += value;
    else if (timestamp >= group.latestAt) { group.latest = value; group.latestAt = timestamp; }
    mappedMetrics.add(spec.kind);
    acceptedValues++;
  };
  eachCSVRow(text, (row, rowNumber) => {
    if (!headers) {
      headers = row.map(normalize);
      if (new Set(headers).size !== headers.length) throw new Error("El encabezado tiene columnas duplicadas.");
      const tidyRequired = ["type", "sourcename", "unit", "startdate", "enddate", "value"];
      if (tidyRequired.every((column) => headers!.includes(column))) format = "tidy";
      else if (headers.includes("date")) { format = "wide"; dateColumn = headers.indexOf("date"); }
      else throw new Error("Encabezado no compatible. Usa el formato tidy de Apple Salud o un CSV wide con columna date.");
      return;
    }
    sourceRows++;
    if (row.length !== headers.length) { reject(rowNumber, "Cantidad de columnas diferente al encabezado."); return; }
    if (format === "tidy") {
      const type = row[headers.indexOf("type")].trim();
      const spec = specs.get(normalize(type));
      if (!spec) { skippedRows++; skippedTypes.add(type); return; }
      const observation = observedDay(row[headers.indexOf("startdate")], formatter);
      if (!observation) { reject(rowNumber, "Fecha u hora no válida."); return; }
      const value = canonicalValue(row[headers.indexOf("value")], row[headers.indexOf("unit")], spec);
      if (value === null) { reject(rowNumber, "Valor o unidad incompatible."); return; }
      add({ day: observation.day, spec, value, timestamp: observation.timestamp });
    } else {
      const day = validDay(row[dateColumn]);
      if (!day) { reject(rowNumber, "La fecha debe usar YYYY-MM-DD."); return; }
      headers.forEach((header, index) => {
        if (index === dateColumn || !row[index].trim()) return;
        const spec = specs.get(header);
        if (!spec) { skippedTypes.add(header); return; }
        const value = canonicalValue(row[index], spec.unit, spec);
        if (value === null) { reject(rowNumber, `Valor no válido en ${header}.`); return; }
        add({ day, spec, value, timestamp: rowNumber });
      });
    }
  });
  if (!headers || !format) throw new Error("El archivo está vacío.");
  const daily = [...groups.values()].map((group): Daily => ({
    local_date: group.day,
    metric_kind: group.spec.kind,
    value: group.spec.aggregation === "sum" ? group.sum : group.spec.aggregation === "median" ? median(group.values) : group.latest,
    unit: group.spec.unit,
    quality: "observed",
    source_kind: "csv_local",
    updated_at: "",
  })).sort((a, b) => b.local_date.localeCompare(a.local_date) || a.metric_kind.localeCompare(b.metric_kind));
  if (!daily.length) throw new Error("El archivo no contiene señales compatibles para mostrar.");
  const days = daily.map((row) => row.local_date);
  const warnings: string[] = [];
  if (!mappedMetrics.has("sleep_duration")) warnings.push("El archivo no incluye duración de sueño. Sleep Score y BioScore no aparecerán hasta tener esa señal y suficiente historial.");
  if (format === "tidy" && [...mappedMetrics].some((kind) => ["steps", "active_energy", "sleep_duration"].includes(kind)))
    warnings.push("Los totales diarios suman las filas del archivo. Muestras solapadas de iPhone y Watch pueden duplicar actividad frente al agregado de Apple Salud.");
  if (skippedTypes.size) warnings.push(`${skippedTypes.size} tipos o columnas sin mapeo se omitieron.`);
  return {
    format, daily, sourceRows, acceptedValues, rejectedValues, rejectedExamples, skippedRows,
    skippedTypes: [...skippedTypes].slice(0, 12), mappedMetrics: [...mappedMetrics].sort(),
    firstDay: days[days.length - 1], lastDay: days[0], warnings,
  };
}

export function inspectHealthCSV(file: File, timeZone: string): Promise<CSVImportResult> {
  if (file.size > 100 * 1024 * 1024) return Promise.reject(new Error("El archivo supera el límite de 100 MB."));
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL("./csv.worker.ts", import.meta.url), { type: "module" });
    worker.onmessage = (event: MessageEvent<{ result?: CSVImportResult; error?: string }>) => {
      worker.terminate();
      if (event.data.error) reject(new Error(event.data.error));
      else if (event.data.result) resolve(event.data.result);
      else reject(new Error("No se pudo revisar el archivo."));
    };
    worker.onerror = () => { worker.terminate(); reject(new Error("No se pudo procesar el CSV en este navegador.")); };
    worker.postMessage({ file, timeZone });
  });
}
