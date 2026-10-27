import { describe, expect, it } from "vitest";
import type { Daily, Journal } from "./data";
import { buildWrapped, journalDay, metricText, previousMonth, wrappedDemoData, wrappedMonths } from "./wrapped-data";

const point = (day: string, value: number, updated = "2026-10-20T12:00:00Z"): Daily => ({ local_date: day, metric_kind: "steps", value, unit: "count", quality: "observed", source_kind: "csv", updated_at: updated });

describe("monthly Wrapped", () => {
  it("deduplicates revisions and never fills missing or future days", () => {
    const snapshot = buildWrapped([point("2026-10-01", 100), point("2026-10-01", 200, "2026-10-21T12:00:00Z"), point("2026-10-03", 400), point("2026-10-27", 900), point("2026-09-30", 800), point("2026-10-04", NaN), point("2026-10-05", -5)], [], "2026-10", "2026-10-26");
    expect(snapshot.stats("steps")).toEqual({ count: 2, mean: 300, total: 600, min: 200, max: 400 });
    expect(snapshot.recorded.size).toBe(2); expect(snapshot.days).toHaveLength(31); expect(snapshot.series("steps").some(p => p.day === "2026-10-02")).toBe(false);
    expect(snapshot.stats("sleep_duration").mean).toBeNull(); expect(snapshot.partial).toBe(true);
    expect(snapshot.stats("steps", "2026-09").mean).toBe(800);
  });
  it("handles leap months, zero values, invalid dates and year boundaries", () => {
    const snapshot = buildWrapped([point("2024-02-29", 0), point("2024-02-30", 300), point("2024-13-01", 300)], [], "2024-02", "2026-10-26");
    expect(snapshot.days).toHaveLength(29); expect(snapshot.stats("steps").count).toBe(1); expect(snapshot.stats("steps").mean).toBe(0);
    expect(previousMonth("2026-01")).toBe("2025-12"); expect(metricText(479.8, "sleep_duration")).toBe("8 h 0 min");
  });
  it("places Diary entries in their recorded timezone and excludes later dates", () => {
    const entry: Journal = { id: "local", title: "Noche", notes: "", category: "event", occurred_at: "2026-11-01T02:00:00Z", timezone_identifier: "America/Bogota" };
    expect(journalDay(entry)).toBe("2026-10-31");
    expect(buildWrapped([], [entry], "2026-10", "2026-10-31").entries).toHaveLength(1);
    expect(buildWrapped([], [entry], "2026-10", "2026-10-26").entries).toHaveLength(0);
  });
  it("keeps demo fixtures explicit and includes both months", () => {
    const fixture = wrappedDemoData(); const snapshot = buildWrapped(fixture.daily, fixture.journal, "2026-10", "2026-10-26");
    expect(snapshot.stats("steps").count).toBe(24); expect(snapshot.stats("steps", "2026-09").count).toBe(28);
    expect(fixture.daily.every(row => row.source_kind === "simulated")).toBe(true);
    expect(wrappedMonths(fixture.daily, fixture.journal, new Date("2026-10-26T12:00:00Z"))).toEqual(["2026-10", "2026-09"]);
  });
  it("excludes incompatible units instead of aggregating them", () => {
    const snapshot = buildWrapped([{ ...point("2026-10-01", 10), unit: "km" }, point("2026-10-02", 50)], [], "2026-10", "2026-10-26");
    expect(snapshot.stats("steps").count).toBe(1); expect(snapshot.stats("steps").mean).toBe(50);
  });
});
