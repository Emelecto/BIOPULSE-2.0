import { describe, expect, it } from "vitest";
import type { Daily } from "./data";
import { bioScore, changeSignal, scoreColor, sleepScore } from "./scoring";

const start = new Date("2026-09-01T12:00:00Z");
function date(offset: number) {
  const day = new Date(start);
  day.setUTCDate(day.getUTCDate() + offset);
  return day.toISOString().slice(0, 10);
}
function metric(offset: number, metric_kind: string, value: number, quality = "observed"): Daily {
  const unit = { sleep_duration: "min", hrv_sdnn: "ms", resting_heart_rate: "bpm", active_energy: "kcal" }[metric_kind] ?? "";
  return { local_date: date(offset), metric_kind, value, unit, quality, source_kind: "health_auto_export_aggregate", updated_at: "" };
}
function series(days = 23): Daily[] {
  return Array.from({ length: days }, (_, day) => [
    metric(day, "sleep_duration", 480), metric(day, "hrv_sdnn", 50),
    metric(day, "resting_heart_rate", 60), metric(day, "active_energy", 400),
  ]).flat();
}

describe("versioned personal indexes", () => {
  it("requires independent prior nights and reports components", () => {
    const rows = series(8);
    expect(sleepScore(rows, date(6)).value).toBeNull();
    expect(sleepScore(rows, date(7))).toMatchObject({ value: 100, components: { duration: 100, consistency: 100 } });
    rows[7 * 4].value = 240;
    expect(sleepScore(rows, date(7)).value).toBeLessThan(100);
  });
  it("never treats missing, wrong-unit or estimated measurements as observed", () => {
    const rows = series();
    rows[22 * 4].quality = "estimated";
    expect(sleepScore(rows, date(22)).value).toBeNull();
    rows[22 * 4].quality = "observed";
    rows[22 * 4 + 1].unit = "bpm";
    expect(bioScore(rows, date(22)).value).toBeNull();
  });
  it("excludes today's measurements from its own baseline", () => {
    const rows = series();
    expect(bioScore(rows, date(22))).toMatchObject({ value: 91, components: { sleep: 100, recovery: 75, activityBalance: 100 } });
    rows[22 * 4 + 1].value = 80;
    expect(bioScore(rows, date(22)).value).toBeGreaterThan(91);
  });
  it("accepts an observed zero-energy day without treating it as missing", () => {
    const rows = series();
    rows[22 * 4 + 3].value = 0;
    expect(bioScore(rows, date(22)).value).not.toBeNull();
    expect(bioScore(rows, date(22)).components.activityBalance).toBeLessThan(100);
  });
  it("signals only persistent multi-metric change; no disease probability", () => {
    const rows = series();
    expect(changeSignal(rows, date(22)).value).toBe(0);
    rows[22 * 4].value = 240;
    rows[22 * 4 + 1].value = 20;
    expect(changeSignal(rows, date(22)).value).toBe(0);
    rows[21 * 4].value = 240;
    rows[21 * 4 + 1].value = 20;
    expect(changeSignal(rows, date(22)).value).toBeGreaterThan(0);
  });
  it("keeps absent score neutral and maps every valid value smoothly", () => {
    expect(scoreColor(null)).toBeUndefined();
    expect(scoreColor(90)).not.toBe(scoreColor(92));
  });
});
