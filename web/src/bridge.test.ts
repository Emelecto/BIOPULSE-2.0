import { describe, expect, it } from "vitest";
import { normalizeExport } from "../../supabase/functions/health-bridge/normalize";

describe("Health Auto Export aggregate contract", () => {
  it("normalizes daily metrics and summarized sleep", () => {
    const rows = normalizeExport({ data: { metrics: [
      { name: "step_count", units: "count", data: [{ date: "2026-10-15 00:00:00 -0500", qty: 8124 }] },
      { name: "heart_rate_variability", units: "ms", data: [{ date: "2026-10-15", qty: 45.2 }] },
      { name: "sleep_analysis", units: "hr", data: [{ date: "2026-10-15", totalSleep: 7.5, core: 3.5, deep: 1.5, rem: 2.5 }] },
    ] } }, "daily");
    expect(rows.daily.map((r) => r.metric_kind)).toEqual(["steps", "hrv_sdnn", "sleep_duration"]);
    expect(rows.daily[2].value).toBe(450);
    expect(rows.sleep).toHaveLength(3);
    expect(rows.sleep[0].minutes).toBe(210);
  });
  it("accepts only hourly energy, preserving timezone offset", () => {
    const rows = normalizeExport({ data: { metrics: [{ name: "active_energy", units: "kcal", data: [{ date: "2026-10-15 08:00:00 -0500", qty: 42 }] }] } }, "intraday");
    expect(rows.hourly[0].bucket_start).toBe("2026-10-15T13:00:00.000Z");
    expect(rows.hourly[0].value).toBe(42);
  });
  it("rejects original sleep segments and unaggregated times", () => {
    expect(() => normalizeExport({ data: { metrics: [{ name: "sleep_analysis", units: "hr", data: [{ date: "2026-10-15", startDate: "2026-10-14 22:00:00 -0500", totalSleep: 7 }] }] } }, "daily")).toThrow("aggregate_sleep_required");
    expect(() => normalizeExport({ data: { metrics: [{ name: "active_energy", units: "kcal", data: [{ date: "2026-10-15 08:30:00 -0500", qty: 42 }] }] } }, "intraday")).toThrow("hourly_aggregation_required");
  });
  it("rejects unsupported metric and duplicate buckets", () => {
    expect(() => normalizeExport({ data: { metrics: [{ name: "blood_glucose", units: "mg/dL", data: [] }] } }, "daily")).toThrow("unsupported_metric");
    expect(() => normalizeExport({ data: { metrics: [{ name: "step_count", units: "count", data: [{ date: "2026-10-15", qty: 4 }, { date: "2026-10-15", qty: 5 }] }] } }, "daily")).toThrow("duplicate_bucket");
  });
});
