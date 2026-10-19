import { describe, expect, it } from "vitest";
import { parseHealthCSV } from "./csv";

describe("CSV local de salud", () => {
  it("agrupa tidy por día, suma actividad y usa la mediana para HRV", () => {
    const text = [
      "type,sourceName,unit,startDate,endDate,value",
      "HKQuantityTypeIdentifierStepCount,Watch,count,2026-10-15 08:00:00 -0500,2026-10-15 08:05:00 -0500,100",
      "HKQuantityTypeIdentifierStepCount,iPhone,count,2026-10-15 09:00:00 -0500,2026-10-15 09:05:00 -0500,40",
      "HKQuantityTypeIdentifierHeartRateVariabilitySDNN,Watch,ms,2026-10-15 08:00:00 -0500,2026-10-15 08:05:00 -0500,40",
      "HKQuantityTypeIdentifierHeartRateVariabilitySDNN,Watch,ms,2026-10-15 09:00:00 -0500,2026-10-15 09:05:00 -0500,60",
      "Unsupported,Watch,ms,2026-10-15 09:00:00 -0500,2026-10-15 09:05:00 -0500,1",
    ].join("\n");
    const result = parseHealthCSV(text, "America/Bogota");
    expect(result.format).toBe("tidy");
    expect(result.sourceRows).toBe(5);
    expect(result.acceptedValues).toBe(4);
    expect(result.skippedRows).toBe(1);
    expect(result.daily.find((row) => row.metric_kind === "steps")?.value).toBe(140);
    expect(result.daily.find((row) => row.metric_kind === "hrv_sdnn")?.value).toBe(50);
    expect(result.daily.every((row) => row.source_kind === "csv_local")).toBe(true);
    expect(result.warnings.some((warning) => warning.includes("no incluye duración de sueño"))).toBe(true);
  });

  it("acepta wide con fechas antiguas y rechaza celdas inválidas sin inventar sueño", () => {
    const text = [
      "date,heart_rate_variability_sdnn,resting_heart_rate,active_energy_burned,step_count",
      "2025-05-01,42,61,320,8000",
      "2025-05-02,no,60,350,8400",
      "2025-02-30,40,59,300,8200",
    ].join("\n");
    const result = parseHealthCSV(text, "America/Bogota");
    expect(result.format).toBe("wide");
    expect(result.firstDay).toBe("2025-05-01");
    expect(result.lastDay).toBe("2025-05-02");
    expect(result.rejectedValues).toBe(2);
    expect(result.daily.some((row) => row.metric_kind === "sleep_duration")).toBe(false);
    expect(result.daily.find((row) => row.metric_kind === "active_energy" && row.local_date === "2025-05-02")?.value).toBe(350);
  });

  it("requiere encabezado válido y rechaza comillas sin cerrar", () => {
    expect(() => parseHealthCSV("foo,bar\n1,2", "UTC")).toThrow(/Encabezado/);
    expect(() => parseHealthCSV('date,step_count\n"2026-10-15,10', "UTC")).toThrow(/comillas/);
  });

  it("respeta la zona horaria y convierte kilómetros a metros", () => {
    const text = [
      "type,sourceName,unit,startDate,endDate,value",
      'WalkingRunningDistance,"Watch, personal",km,2026-10-16T01:30:00Z,2026-10-16T01:40:00Z,2.5',
    ].join("\n");
    const result = parseHealthCSV(text, "America/Bogota");
    expect(result.daily[0]).toMatchObject({ local_date: "2026-10-15", metric_kind: "walking_running_distance", value: 2500, unit: "m" });
  });
});
