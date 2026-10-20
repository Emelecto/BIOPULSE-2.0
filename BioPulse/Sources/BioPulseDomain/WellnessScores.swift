import Foundation

/// Product hypothesis, versioned for reproducibility. These indexes are not clinical outcomes.
public struct WellnessValue: Sendable {
    public let day: Date
    public let metric: MetricKind
    public let value: Double

    public init(day: Date, metric: MetricKind, value: Double) {
        self.day = day
        self.metric = metric
        self.value = value
    }
}

public struct WellnessScore: Sendable {
    public let value: Int?
    public let day: Date
    public let version: String
    public let reason: String
    public let components: [String: Double]

    init(value: Int?, day: Date, reason: String, components: [String: Double] = [:]) {
        self.value = value
        self.day = day
        self.version = "personal-v2"
        self.reason = reason
        self.components = components
    }
}

public enum WellnessScores {
    private static func bounded(_ value: Double) -> Double { min(100, max(0, value)) }
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
    private static func value(_ values: [WellnessValue], _ kind: MetricKind, _ day: Date, _ calendar: Calendar) -> Double? {
        guard let number = values.first(where: { $0.metric == kind && calendar.isDate($0.day, inSameDayAs: day) })?.value,
              number.isFinite, ((kind == .activeEnergyBurned || kind == .sleepDuration) ? number >= 0 : number > 0) else { return nil }
        return number
    }
    private static func history(_ values: [WellnessValue], _ kind: MetricKind, _ day: Date, window: Int, calendar: Calendar) -> [Double] {
        guard let start = calendar.date(byAdding: .day, value: -window, to: calendar.startOfDay(for: day)) else { return [] }
        let valid = values.filter { $0.metric == kind && $0.day >= start && $0.day < calendar.startOfDay(for: day) && $0.value.isFinite && ((kind == .activeEnergyBurned || kind == .sleepDuration) ? $0.value >= 0 : $0.value > 0) }
        let byDay = Dictionary(valid.map { (calendar.startOfDay(for: $0.day), $0.value) }, uniquingKeysWith: { first, _ in first })
        return Array(byDay.values)
    }
    private static func baseline(_ values: [WellnessValue], _ kind: MetricKind, _ day: Date, calendar: Calendar) -> (center: Double, mad: Double)? {
        let prior = history(values, kind, day, window: 28, calendar: calendar)
        guard prior.count >= 14 else { return nil }
        let center = median(prior)
        return (center, median(prior.map { abs($0 - center) }))
    }

    public static func sleep(_ values: [WellnessValue], day: Date, targetMinutes: Int = 480, calendar: Calendar = .current) -> WellnessScore {
        guard (360...600).contains(targetMinutes) else { return WellnessScore(value: nil, day: day, reason: "Configura una meta de sueño entre 6 y 10 horas.") }
        guard let duration = value(values, .sleepDuration, day, calendar) else { return WellnessScore(value: nil, day: day, reason: "Falta la duración de esta noche. Puedes conectar Apple Salud o registrar tu sueño.") }
        let prior = history(values, .sleepDuration, day, window: 14, calendar: calendar)
        guard prior.count >= 7 else { return WellnessScore(value: nil, day: day, reason: "Se necesitan 7 noches previas en 14 días; hay \(prior.count).") }
        let durationIndex = bounded(100 - max(0, abs(duration - Double(targetMinutes)) - 30) * 100 / 240)
        let consistencyIndex = bounded(100 - max(0, abs(duration - median(prior)) - 30) * 100 / 150)
        return WellnessScore(value: Int((0.65 * durationIndex + 0.35 * consistencyIndex).rounded()), day: day,
                             reason: "Índice exploratorio de duración y constancia; no mide etapas ni diagnostica sueño.",
                             components: ["duration": durationIndex.rounded(), "consistency": consistencyIndex.rounded()])
    }

    public static func bio(_ values: [WellnessValue], day: Date, targetMinutes: Int = 480, calendar: Calendar = .current) -> WellnessScore {
        let sleepIndex = sleep(values, day: day, targetMinutes: targetMinutes, calendar: calendar)
        guard let sleepValue = sleepIndex.value else { return WellnessScore(value: nil, day: day, reason: "Sueño: \(sleepIndex.reason)") }
        guard let hrv = value(values, .heartRateVariabilitySDNN, day, calendar),
              let rhr = value(values, .restingHeartRate, day, calendar),
              let energy = value(values, .activeEnergyBurned, day, calendar) else {
            return WellnessScore(value: nil, day: day, reason: "Faltan HRV, FC en reposo o energía activa del día completo.")
        }
        guard let hrvBase = baseline(values, .heartRateVariabilitySDNN, day, calendar: calendar),
              let rhrBase = baseline(values, .restingHeartRate, day, calendar: calendar),
              let energyBase = baseline(values, .activeEnergyBurned, day, calendar: calendar) else {
            return WellnessScore(value: nil, day: day, reason: "Se necesitan 14 días previos de HRV, FC en reposo y energía activa en los últimos 28 días.")
        }
        let hrvScale = max(max(1.4826 * hrvBase.mad, hrvBase.center * 0.1), 5)
        let rhrScale = max(max(1.4826 * rhrBase.mad, rhrBase.center * 0.1), 3)
        let recovery = (bounded(75 + 15 * (hrv - hrvBase.center) / hrvScale) + bounded(75 - 15 * (rhr - rhrBase.center) / rhrScale)) / 2
        let activity = bounded(100 - 60 * abs(log2((energy + 50) / (energyBase.center + 50))))
        return WellnessScore(value: Int((0.4 * Double(sleepValue) + 0.35 * recovery + 0.25 * activity).rounded()), day: day,
                             reason: "Índice exploratorio frente a tu historial; no es una medida de salud clínica.",
                             components: ["sleep": Double(sleepValue), "recovery": recovery.rounded(), "activityBalance": activity.rounded()])
    }

    public static func change(_ values: [WellnessValue], day: Date, calendar: Calendar = .current) -> WellnessScore {
        let kinds: [MetricKind] = [.sleepDuration, .heartRateVariabilitySDNN, .restingHeartRate]
        let days = [day, calendar.date(byAdding: .day, value: -1, to: day) ?? day]
        let levels = days.map { evaluatedDay -> [Double]? in
            var result: [Double] = []
            for kind in kinds {
                guard let current = value(values, kind, evaluatedDay, calendar),
                      let reference = baseline(values, kind, evaluatedDay, calendar: calendar) else { return nil }
                let floor: Double = kind == .sleepDuration ? 45 : kind == .heartRateVariabilitySDNN ? 5 : 3
                let spread = max(max(1.4826 * reference.mad, reference.center * 0.1), floor)
                result.append(abs(current - reference.center) / spread)
            }
            return result
        }
        guard let current = levels[0], let previous = levels[1] else {
            return WellnessScore(value: nil, day: day, reason: "Se necesitan dos días completos y 14 días previos por señal para cada uno.")
        }
        let persistent = [current, previous].allSatisfy { $0.filter { $0 >= 1.5 }.count >= 2 }
        return WellnessScore(value: persistent ? Int(bounded((current.max() ?? 0) * 20).rounded()) : 0, day: day,
                             reason: persistent
                                ? "Cambio persistente en al menos dos señales frente a tu referencia. Busca contexto; no indica una enfermedad."
                                : "Sin cambio persistente en varias señales; esto no descarta problemas de salud.",
                             components: Dictionary(uniqueKeysWithValues: zip(kinds.map(\.rawValue), current.map { ($0 * 10).rounded() / 10 })))
    }
}
