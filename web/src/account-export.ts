import type { SupabaseClient } from "@supabase/supabase-js";

type Row = Record<string, unknown>;
type Page = { data: Row[] | null; error: unknown };

export async function collectExportRows(
  load: (from: number, to: number) => PromiseLike<Page>,
  pageSize = 500,
  maxRows = 100_000,
): Promise<Row[]> {
  const rows: Row[] = [];
  for (let from = 0; ; from += pageSize) {
    const page = await load(from, from + pageSize - 1);
    if (page.error || !page.data) throw new Error("No se pudo completar la copia. No se descargó un archivo incompleto.");
    if (rows.length + page.data.length > maxRows) throw new Error("Tu historial supera el tamaño de descarga disponible en este navegador.");
    rows.push(...page.data);
    if (page.data.length < pageSize) return rows;
  }
}

const tables = [
  { name: "profiles", owner: "id", columns: "id,display_name,created_at,updated_at", order: ["id"] },
  { name: "user_settings", owner: "user_id", columns: "user_id,timezone_identifier,unit_system,created_at,updated_at", order: ["user_id"] },
  { name: "journal_entries", owner: "user_id", columns: "id,category,title,notes,occurred_at,timezone_identifier,provenance,revision,created_at,updated_at", order: ["id"] },
  { name: "daily_metric_summaries", owner: "user_id", columns: "id,local_date,timezone_identifier,metric_kind,value,unit,aggregation,sample_count,coverage_fraction,quality,source_kind,formula_version,revision,created_at,updated_at", order: ["id"] },
  { name: "intraday_metric_summaries", owner: "user_id", columns: "bucket_start,local_date,timezone_identifier,metric_kind,value,unit,aggregation,source_kind,updated_at", order: ["bucket_start", "metric_kind", "source_kind"] },
  { name: "sleep_stage_summaries", owner: "user_id", columns: "local_date,stage,minutes,source_kind,updated_at", order: ["local_date", "stage", "source_kind"] },
  { name: "sync_consents", owner: "user_id", columns: "id,data_category,decision,policy_version,recorded_at", order: ["id"] },
  { name: "coach_consents", owner: "user_id", columns: "id,decision,policy_version,recorded_at", order: ["id"] },
] as const;

export async function exportSyncedData(client: SupabaseClient, userId: string) {
  const startedAt = new Date().toISOString();
  const before = await client.auth.getUser();
  if (before.error || before.data.user?.id !== userId) throw new Error("Tu sesión cambió. Vuelve a iniciar sesión antes de descargar tus datos.");
  const entries = await Promise.all(tables.map(async (table) => {
    const rows = await collectExportRows((from, to) => {
      let query = client.from(table.name).select(table.columns as string).eq(table.owner, userId);
      for (const column of table.order) query = query.order(column, { ascending: true });
      return query.range(from, to) as unknown as PromiseLike<Page>;
    });
    return [table.name, rows] as const;
  }));
  const after = await client.auth.getUser();
  if (after.error || after.data.user?.id !== userId) throw new Error("Tu sesión cambió durante la copia. No se descargaron los datos.");
  return {
    format: "biopulse-synced-data-v1",
    startedAt,
    completedAt: new Date().toISOString(),
    account: { id: before.data.user.id, email: before.data.user.email },
    scope: "Perfil, preferencias, Diario web, agregados sincronizados y consentimientos accesibles por el titular.",
    excluded: ["Muestras originales de Apple Salud", "CSV local", "Datos guardados solo en iOS", "Memoria temporal y contadores internos del Coach"],
    note: "Copia de los registros disponibles durante la descarga; los cambios concurrentes pueden reflejar momentos distintos.",
    data: Object.fromEntries(entries),
  };
}
