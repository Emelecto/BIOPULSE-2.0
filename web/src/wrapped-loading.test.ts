import { beforeEach, describe, expect, it, vi } from "vitest";

const query = vi.hoisted(() => ({ range: vi.fn(), filters: [] as string[] }));
vi.mock("@supabase/supabase-js", () => ({ createClient: () => ({ from: (table: string) => {
  const chain = {
    select: () => chain,
    eq: (key: string, value: string) => { query.filters.push(`${table}:${key}=${value}`); return chain; },
    gte: () => chain, order: () => chain,
    range: (start: number, end: number) => query.range(table, start, end),
    limit: () => Promise.resolve({ data: [], error: null }),
  };
  return chain;
} }) }));

beforeEach(() => {
  vi.resetModules(); query.range.mockReset(); query.filters.length = 0;
  vi.stubEnv("VITE_SUPABASE_URL", "https://example.supabase.co");
  vi.stubEnv("VITE_SUPABASE_PUBLISHABLE_KEY", "test-public-fixture");
});
describe("complete Wrapped history loading", () => {
  it("loads every Diary page while retaining the owner filter", async () => {
    query.range.mockImplementation((_table, start) => Promise.resolve({ data: Array.from({ length: start === 0 ? 1000 : 2 }, (_, i) => ({ id: String(start + i) })), error: null }));
    const { loadJournal } = await import("./data");
    expect(await loadJournal("synthetic-owner")).toHaveLength(1002);
    expect(query.range).toHaveBeenCalledTimes(2);
    expect(query.filters).toEqual(["journal_entries:user_id=synthetic-owner", "journal_entries:user_id=synthetic-owner"]);
  });
  it("loads daily history beyond the old 1000-row limit", async () => {
    query.range.mockImplementation((_table, start) => Promise.resolve({ data: Array.from({ length: start === 0 ? 1000 : 4 }, (_, i) => ({ local_date: String(start + i) })), error: null }));
    const { loadMetrics } = await import("./data");
    expect((await loadMetrics("synthetic-owner")).daily).toHaveLength(1004);
    expect(query.filters).toContain("daily_metric_summaries:source_kind=health_auto_export_aggregate");
  });
  it("rejects a later page failure instead of returning a partial month", async () => {
    query.range.mockImplementation((_table, start) => Promise.resolve(start === 0 ? { data: Array.from({ length: 1000 }, () => ({})), error: null } : { data: null, error: { message: "Fixture failure" } }));
    const { loadJournal } = await import("./data");
    await expect(loadJournal("synthetic-owner")).rejects.toThrow("Diario completo");
  });
});
