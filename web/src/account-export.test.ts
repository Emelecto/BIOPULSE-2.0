import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { collectExportRows, exportSyncedData } from "./account-export";

describe("synced data export", () => {
  it("collects every page, including a final empty page when the count is exact", async () => {
    const rows = Array.from({ length: 6 }, (_, id) => ({ id }));
    const ranges: number[][] = [];
    const result = await collectExportRows(async (from, to) => {
      ranges.push([from, to]);
      return { data: rows.slice(from, to + 1), error: null };
    }, 3);
    expect(result).toEqual(rows);
    expect(ranges).toEqual([[0, 2], [3, 5], [6, 8]]);
  });
  it("does not return a partial file after a failed page", async () => {
    await expect(collectExportRows(async (from) => from === 0
      ? { data: [{ id: 1 }, { id: 2 }], error: null }
      : { data: null, error: { message: "network failure" } }, 2)).rejects.toThrow("incompleto");
  });
  it("fails explicitly when the history exceeds the browser bound", async () => {
    await expect(collectExportRows(async () => ({ data: [{}, {}], error: null }), 2, 3)).rejects.toThrow("tamaño");
  });
  it("rejects a changed session before querying any table", async () => {
    let queried = false;
    const client = {
      auth: { getUser: async () => ({ data: { user: { id: "other" } }, error: null }) },
      from: () => { queried = true; throw new Error("Should not read data"); },
    } as unknown as SupabaseClient;
    await expect(exportSyncedData(client, "owner")).rejects.toThrow("sesión");
    expect(queried).toBe(false);
  });
  it("scopes every table to the owner and discards output if the session changes during export", async () => {
    const owners: Array<[string, string, string]> = [];
    let authCalls = 0;
    const client = {
      auth: { getUser: async () => ({ data: { user: { id: ++authCalls === 1 ? "owner" : "other" } }, error: null }) },
      from: (table: string) => {
        const query = {
          select: () => query,
          eq: (field: string, id: string) => { owners.push([table, field, id]); return query; },
          order: () => query,
          range: async () => ({ data: [], error: null }),
        };
        return query;
      },
    } as unknown as SupabaseClient;
    await expect(exportSyncedData(client, "owner")).rejects.toThrow("durante la copia");
    expect(owners).toHaveLength(8);
    expect(owners.every(([, , id]) => id === "owner")).toBe(true);
    expect(owners.some(([table]) => table === "health_bridge_connections")).toBe(false);
  });
});
