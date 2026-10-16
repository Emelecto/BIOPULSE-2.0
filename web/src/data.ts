import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;
function safeSupabaseUrl(value?: string): boolean {
  if (!value) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" || (parsed.protocol === "http:" && ["localhost", "127.0.0.1"].includes(parsed.hostname));
  } catch { return false; }
}
export const configured = !!key && safeSupabaseUrl(url);
export const supabase = configured
  ? createClient(url!, key!, {
      auth: {
        detectSessionInUrl: true,
        persistSession: true,
        autoRefreshToken: true,
      },
    })
  : null;
export const bridgeEndpoint = configured
  ? `${url}/functions/v1/health-bridge`
  : "";
export const phoneBridgeReady = bridgeEndpoint.startsWith("https://");

export type Daily = {
  local_date: string;
  metric_kind: string;
  value: number;
  unit: string;
  quality: string;
  source_kind: string;
  updated_at: string;
};
export type Hourly = {
  local_date: string;
  bucket_start: string;
  metric_kind: string;
  value: number;
  unit: string;
};
export type Sleep = { local_date: string; stage: string; minutes: number };
export type Journal = {
  id: string;
  category: "habit" | "symptom" | "event";
  title: string;
  notes: string;
  occurred_at: string;
  timezone_identifier: string;
};
export type BridgeStatus = {
  connected: boolean;
  lastSyncAt: string | null;
  lastDailySyncAt: string | null;
  lastIntradaySyncAt: string | null;
  dailyConsent: boolean;
  intradayConsent: boolean;
};

export function today(): string {
  return new Intl.DateTimeFormat("sv-SE", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}
export function daysAgo(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return new Intl.DateTimeFormat("sv-SE", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}
export function latest(
  rows: Daily[],
  kind: string,
  date = today(),
): Daily | undefined {
  return rows.find(
    (row) => row.metric_kind === kind && row.local_date === date,
  );
}
export function formatMetric(row?: Daily): string {
  if (!row) return "—";
  if (row.metric_kind === "sleep_duration")
    return `${Math.floor(row.value / 60)} h ${Math.round(row.value % 60)} min`;
  const amount = new Intl.NumberFormat("es-CO", {
    maximumFractionDigits:
      row.unit === "count" || row.unit === "kcal" || row.unit === "bpm" ? 0 : 1,
  }).format(row.value);
  return `${amount} ${row.unit}`;
}
export function dateLabel(date: string): string {
  return new Date(`${date}T12:00:00`).toLocaleDateString("es-CO", {
    day: "numeric",
    month: "short",
  });
}
export function timeLabel(date?: string | null): string {
  return date
    ? new Date(date).toLocaleString("es-CO", {
        dateStyle: "medium",
        timeStyle: "short",
      })
    : "Sin sincronizaciones";
}

export async function loadMetrics(
  userId: string,
): Promise<{ daily: Daily[]; hourly: Hourly[]; sleep: Sleep[] }> {
  if (!supabase) throw new Error("Falta configurar Supabase.");
  const [d, h, s] = await Promise.all([
    supabase
      .from("daily_metric_summaries")
      .select(
        "local_date,metric_kind,value,unit,quality,source_kind,updated_at",
      )
      .eq("user_id", userId)
      .eq("source_kind", "health_auto_export_aggregate")
      .gte("local_date", daysAgo(90))
      .order("local_date", { ascending: false })
      .limit(1000),
    supabase
      .from("intraday_metric_summaries")
      .select("local_date,bucket_start,metric_kind,value,unit")
      .eq("user_id", userId)
      .gte("local_date", daysAgo(7))
      .order("bucket_start", { ascending: true })
      .limit(500),
    supabase
      .from("sleep_stage_summaries")
      .select("local_date,stage,minutes")
      .eq("user_id", userId)
      .gte("local_date", daysAgo(30))
      .limit(200),
  ]);
  if (d.error || h.error || s.error)
    throw new Error(
      "No se pudieron cargar las mediciones. Comprueba permisos y conexión.",
    );
  return {
    daily: (d.data ?? []) as Daily[],
    hourly: (h.data ?? []) as Hourly[],
    sleep: (s.data ?? []) as Sleep[],
  };
}
export async function loadJournal(userId: string): Promise<Journal[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("journal_entries")
    .select("id,category,title,notes,occurred_at,timezone_identifier")
    .eq("user_id", userId)
    .order("occurred_at", { ascending: false })
    .limit(100);
  if (error) throw new Error("No se pudo cargar el Diario.");
  return (data ?? []) as Journal[];
}
export async function journalConsent(userId: string): Promise<boolean> {
  if (!supabase) return false;
  const { data } = await supabase
    .from("sync_consents")
    .select("decision")
    .eq("user_id", userId)
    .eq("data_category", "journal")
    .order("id", { ascending: false })
    .limit(1)
    .maybeSingle();
  return data?.decision === "granted";
}
export async function bridge(
  action: string,
  extra: Record<string, unknown> = {},
): Promise<Record<string, unknown>> {
  if (!supabase) throw new Error("Falta configurar Supabase.");
  const { data, error } = await supabase.functions.invoke("health-bridge", {
    body: { action, ...extra },
  });
  if (error)
    throw new Error(`No se pudo completar la conexión: ${error.message}`);
  return data as Record<string, unknown>;
}

export function automationLink(
  token: string,
  stream: "daily" | "intraday",
): string {
  if (!/^bp_[a-f0-9]{64}$/.test(token) || !phoneBridgeReady)
    throw new Error("Enlace no disponible.");
  const daily = stream === "daily";
  const params = [
    ["url", `${bridgeEndpoint}?stream=${stream}`],
    ["name", daily ? "BioPulse diario" : "BioPulse por hora"],
    ["format", "json"],
    ["datatype", "healthMetrics"],
    ["period", "none"],
    ["interval", daily ? "days" : "hours"],
    ["aggregatedata", "true"],
    ["aggregatesleep", "true"],
    ["exportversion", "v2"],
    ["syncinterval", "hours"],
    ["syncquantity", "2"],
    [
      "metrics",
      daily
        ? "Step Count,Active Energy,Resting Heart Rate,Heart Rate Variability,Sleep Analysis"
        : "Active Energy",
    ],
    ["enabled", "true"],
  ]
    .map(([k, v]) =>
      k === "metrics"
        ? `${k}=${v.split(",").map(encodeURIComponent).join(",")}`
        : `${k}=${encodeURIComponent(v)}`,
    )
    .join("&");
  return `com.HealthExport://automation?${params}&headers=Authorization,Bearer%20${token}`;
}
