import Combine
import Foundation
import HealthKit
import BioPulseDomain

struct HealthReading: Equatable {
    let value: Double
    let measuredAt: Date
    let sourceName: String
}

struct DailyHealthObservation: Identifiable, Equatable, Sendable {
    let day: Date
    let value: Double
    let sourceName: String

    var id: TimeInterval { day.timeIntervalSince1970 }
}

struct HourlyEnergyObservation: Identifiable, Equatable, Sendable {
    let hour: Date
    let kilocalories: Double
    var id: TimeInterval { hour.timeIntervalSince1970 }
}

enum SleepStageKind: String, Equatable, Sendable {
    case core, deep, rem, unspecified

    var title: String {
        switch self {
        case .core: "Ligero"
        case .deep: "Profundo"
        case .rem: "REM"
        case .unspecified: "Sueño"
        }
    }
}

struct SleepStageObservation: Identifiable, Equatable, Sendable {
    let start: Date
    let end: Date
    let stage: SleepStageKind
    var id: String { "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)-\(stage.rawValue)" }
}

private struct HealthDataSnapshot {
    let readings: [HealthMetric: HealthReading]
    let dailyHistory: [HealthMetric: [DailyHealthObservation]]
    let hourlyActiveEnergy: [HourlyEnergyObservation]
    let sleepStages: [SleepStageObservation]
    let lastUpdated: Date?
}

@MainActor
final class HealthDataController: ObservableObject {
    @Published private(set) var readings: [HealthMetric: HealthReading] = [:]
    @Published private(set) var dailyHistory: [HealthMetric: [DailyHealthObservation]] = [:]
    @Published private(set) var hourlyActiveEnergy: [HourlyEnergyObservation] = []
    @Published private(set) var sleepStages: [SleepStageObservation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hasRequestedAccess = UserDefaults.standard.bool(forKey: "BioPulse.hasRequestedHealthAccess")
    @Published private(set) var isCSVImported = false
    @Published private(set) var hasCSVData = false
    @Published private(set) var csvLastDay: Date?
    @Published private(set) var healthKitLastUpdated: Date?
    @Published private(set) var healthKitSyncError: String?

    private let store = HKHealthStore()
    private let catalog = HealthKitCapabilityCatalog()
    let isPresentationMode: Bool
    private var csvSnapshot: HealthDataSnapshot?
    private var healthKitSnapshot: HealthDataSnapshot?

    var isAvailable: Bool { isPresentationMode || HKHealthStore.isHealthDataAvailable() }
    var displayedDataDay: Date {
        isCSVImported ? (csvLastDay ?? Calendar.current.startOfDay(for: .now)) : Calendar.current.startOfDay(for: .now)
    }

    init(presentationMode: Bool = false) {
        isPresentationMode = presentationMode
        if presentationMode {
            hasRequestedAccess = true
            apply(Self.presentationSnapshot())
        }
    }

    func resetPresentationData() {
        guard isPresentationMode else { return }
        apply(Self.presentationSnapshot())
        errorMessage = nil
        isCSVImported = false
        hasCSVData = false
    }

    private static func presentationSnapshot() -> HealthDataSnapshot {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: .now)
        let definitions: [(HealthMetric, Double, Double, String)] = [
            (.stepCount, 8_420, 2_050, "pasos"),
            (.activeEnergyBurned, 512, 118, "kcal"),
            (.appleExerciseTime, 46, 12, "min"),
            (.heartRateVariabilitySDNN, 54, 13, "ms"),
            (.restingHeartRate, 58, 5, "lpm"),
            (.sleepAnalysis, 438, 48, "min"),
            (.walkingRunningDistance, 6.1, 1.4, "km"),
            (.respiratoryRate, 15.2, 1.2, "rpm"),
            (.oxygenSaturation, 0.98, 0.01, "%")
        ]
        var history: [HealthMetric: [DailyHealthObservation]] = [:]
        for (metric, base, swing, _) in definitions {
            history[metric] = (0..<120).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset - 119, to: today) else { return nil }
                let wave = sin(Double(offset) * 0.31) * 0.58 + cos(Double(offset) * 0.13) * 0.27
                let weekly = offset.isMultiple(of: 7) ? -0.22 : 0.08
                let value = max(metric == .oxygenSaturation ? 0.94 : 1, base + swing * (wave + weekly))
                return DailyHealthObservation(day: day, value: value, sourceName: "BioPulse")
            }
        }
        let readings: [HealthMetric: HealthReading] = Dictionary(uniqueKeysWithValues: definitions.compactMap { item in
            guard let latest = history[item.0]?.last else { return nil }
            return (item.0, HealthReading(value: latest.value, measuredAt: latest.day, sourceName: "BioPulse"))
        })
        let stageDefinitions: [(stage: SleepStageKind, start: Int, end: Int)] = [
            (.core, 0, 95), (.deep, 95, 165), (.core, 165, 250),
            (.rem, 250, 310), (.core, 310, 375), (.rem, 375, 430)
        ]
        let stages: [SleepStageObservation] = stageDefinitions.compactMap { item in
            guard let startDate = calendar.date(byAdding: .minute, value: item.start, to: today.addingTimeInterval(-8 * 60 * 60)),
                  let endDate = calendar.date(byAdding: .minute, value: item.end, to: today.addingTimeInterval(-8 * 60 * 60)) else { return nil }
            return SleepStageObservation(start: startDate, end: endDate, stage: item.stage)
        }
        let energy = (7..<22).compactMap { hour -> HourlyEnergyObservation? in
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) else { return nil }
            let calories = max(0, 34 + 26 * sin(Double(hour) * 0.7))
            return HourlyEnergyObservation(hour: date, kilocalories: calories)
        }
        return HealthDataSnapshot(readings: readings, dailyHistory: history, hourlyActiveEnergy: energy, sleepStages: stages, lastUpdated: .now)
    }

    func useCSV(_ result: CSVImportResult) -> Bool {
        guard !isPresentationMode else { return false }
        guard !result.records.isEmpty else { return false }
        let mapped: [(MetricKind, HealthMetric)] = [
            (.heartRate, .heartRate), (.restingHeartRate, .restingHeartRate),
            (.heartRateVariabilitySDNN, .heartRateVariabilitySDNN), (.sleepDuration, .sleepAnalysis),
            (.stepCount, .stepCount), (.walkingRunningDistance, .walkingRunningDistance),
            (.activeEnergyBurned, .activeEnergyBurned), (.exerciseDuration, .appleExerciseTime),
            (.flightsClimbed, .flightsClimbed)
        ]
        var history: [HealthMetric: [DailyHealthObservation]] = [:]
        for (domainMetric, appMetric) in mapped {
            let grouped = Dictionary(grouping: result.records.filter { $0.metric == domainMetric }, by: \.day)
            let points = grouped.compactMap { day, records -> DailyHealthObservation? in
                guard let date = date(for: day), !records.isEmpty else { return nil }
                let values = records.map(\.value).sorted()
                let value: Double
                switch domainMetric {
                case .stepCount, .walkingRunningDistance, .activeEnergyBurned, .exerciseDuration, .flightsClimbed, .sleepDuration:
                    value = values.reduce(0, +)
                case .heartRateRecoveryOneMinute:
                    value = values.last ?? 0
                default:
                    let middle = values.count / 2
                    value = values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
                }
                return DailyHealthObservation(day: date, value: value, sourceName: "CSV · agregado diario")
            }.sorted { $0.day < $1.day }
            if !points.isEmpty { history[appMetric] = points }
        }

        var latest: [HealthMetric: HealthReading] = [:]
        for (metric, points) in history {
            guard let point = points.last else { continue }
            latest[metric] = HealthReading(value: point.value, measuredAt: point.day, sourceName: "CSV · último día disponible")
        }
        let snapshot = HealthDataSnapshot(
            readings: latest,
            dailyHistory: history,
            hourlyActiveEnergy: [],
            sleepStages: [],
            lastUpdated: .now
        )
        csvSnapshot = snapshot
        apply(snapshot)
        csvLastDay = result.records.compactMap { date(for: $0.day) }.max()
        hasCSVData = true
        isCSVImported = true
        errorMessage = nil
        return true
    }

    func showCSVData() {
        guard !isPresentationMode else { return }
        guard let csvSnapshot else { return }
        isCSVImported = true
        apply(csvSnapshot)
    }

    func showHealthKitData() async {
        guard !isPresentationMode else { return }
        isCSVImported = false
        if let healthKitSnapshot {
            apply(healthKitSnapshot)
        }
        if hasRequestedAccess {
            await reload()
        } else {
            await requestAccess()
        }
    }

    func clearCSV() {
        guard !isPresentationMode else { return }
        isCSVImported = false
        hasCSVData = false
        csvLastDay = nil
        csvSnapshot = nil
        if let healthKitSnapshot {
            apply(healthKitSnapshot)
        } else {
            apply(HealthDataSnapshot(readings: [:], dailyHistory: [:], hourlyActiveEnergy: [], sleepStages: [], lastUpdated: nil))
        }
        Task { await reload() }
    }

    private func apply(_ snapshot: HealthDataSnapshot) {
        readings = snapshot.readings
        dailyHistory = snapshot.dailyHistory
        hourlyActiveEnergy = snapshot.hourlyActiveEnergy
        sleepStages = snapshot.sleepStages
        lastUpdated = snapshot.lastUpdated
    }

    private func date(for day: LocalDay) -> Date? {
        guard let timeZone = TimeZone(identifier: day.timeZoneIdentifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    }

    func requestAccess() async {
        guard !isPresentationMode else { return }
        guard isAvailable else {
            errorMessage = "Apple Salud no está disponible en este dispositivo."
            return
        }
        do {
            let displayedMetrics: [HealthMetric] = [
                .heartRateVariabilitySDNN, .restingHeartRate, .heartRate,
                .respiratoryRate, .oxygenSaturation, .stepCount,
                .activeEnergyBurned, .appleExerciseTime, .sleepAnalysis
            ]
            let types = Set(displayedMetrics.compactMap(catalog.objectType(for:)))
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestAuthorization(toShare: [], read: types) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            hasRequestedAccess = true
            UserDefaults.standard.set(true, forKey: "BioPulse.hasRequestedHealthAccess")
            await reload()
        } catch {
            errorMessage = "No se pudo solicitar acceso a Apple Salud. Revisa los permisos en Ajustes."
        }
    }

    func reload() async {
        guard !isPresentationMode else { return }
        guard isAvailable, hasRequestedAccess, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        healthKitSyncError = nil
        defer { isLoading = false }

        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        var updated: [HealthMetric: HealthReading] = [:]
        var failedQueries = 0

        let latestMetrics: [(HealthMetric, HKQuantityTypeIdentifier, HKUnit, Date)] = [
            (.restingHeartRate, .restingHeartRate, HKUnit.count().unitDivided(by: .minute()), today),
            (.heartRate, .heartRate, HKUnit.count().unitDivided(by: .minute()), today),
            (.respiratoryRate, .respiratoryRate, HKUnit.count().unitDivided(by: .minute()), today),
            (.oxygenSaturation, .oxygenSaturation, HKUnit.percent(), today)
        ]
        for (metric, identifier, unit, start) in latestMetrics {
            do {
                updated[metric] = try await latestQuantity(identifier, unit: unit, from: start, to: now)
            } catch {
                failedQueries += 1
            }
        }

        do {
            updated[.heartRateVariabilitySDNN] = try await averageQuantity(
                .heartRateVariabilitySDNN,
                unit: .secondUnit(with: .milli),
                from: today,
                to: now
            )
        } catch {
            failedQueries += 1
        }

        for (metric, identifier, unit) in [
            (HealthMetric.stepCount, HKQuantityTypeIdentifier.stepCount, HKUnit.count()),
            (.activeEnergyBurned, .activeEnergyBurned, HKUnit.kilocalorie()),
            (.appleExerciseTime, .appleExerciseTime, HKUnit.minute())
        ] {
            do {
                updated[metric] = try await cumulativeQuantity(identifier, unit: unit, from: today, to: now)
            } catch {
                failedQueries += 1
            }
        }

        do {
            updated[.sleepAnalysis] = try await lastNightSleep(now: now)
        } catch {
            failedQueries += 1
        }

        var updatedEnergy: [HourlyEnergyObservation] = []
        do {
            updatedEnergy = try await hourlyEnergy(from: today, to: now)
        } catch {
            failedQueries += 1
        }
        var updatedStages: [SleepStageObservation] = []
        do {
            updatedStages = try await lastNightStages(now: now)
        } catch {
            failedQueries += 1
        }

        let historyStart = Calendar.current.date(byAdding: .day, value: -90, to: today) ?? today
        var updatedHistory: [HealthMetric: [DailyHealthObservation]] = [:]
        let quantityHistories: [(
            HealthMetric,
            HKQuantityTypeIdentifier,
            HKUnit,
            HKStatisticsOptions
        )] = [
            (.stepCount, .stepCount, .count(), .cumulativeSum),
            (.activeEnergyBurned, .activeEnergyBurned, .kilocalorie(), .cumulativeSum),
            (.appleExerciseTime, .appleExerciseTime, .minute(), .cumulativeSum),
            (.heartRateVariabilitySDNN, .heartRateVariabilitySDNN, .secondUnit(with: .milli), .discreteAverage),
            (.restingHeartRate, .restingHeartRate, .count().unitDivided(by: .minute()), .discreteAverage)
        ]

        for (metric, identifier, unit, options) in quantityHistories {
            do {
                updatedHistory[metric] = try await dailyQuantityHistory(
                    identifier,
                    unit: unit,
                    options: options,
                    from: historyStart,
                    to: today
                )
            } catch {
                failedQueries += 1
            }
        }
        do {
            updatedHistory[.sleepAnalysis] = try await dailySleepHistory(from: historyStart, to: now)
        } catch {
            failedQueries += 1
        }

        let snapshot = HealthDataSnapshot(
            readings: updated,
            dailyHistory: updatedHistory,
            hourlyActiveEnergy: updatedEnergy,
            sleepStages: updatedStages,
            lastUpdated: now
        )
        healthKitSnapshot = snapshot
        healthKitLastUpdated = now
        if !isCSVImported { apply(snapshot) }
        if failedQueries > 0 {
            errorMessage = "Algunas señales no pudieron consultarse. Puedes volver a intentarlo."
            healthKitSyncError = errorMessage
        }
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> HealthReading? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
            let order = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [order]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample,
                      sample.quantity.is(compatibleWith: unit) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: HealthReading(
                    value: sample.quantity.doubleValue(for: unit),
                    measuredAt: sample.endDate,
                    sourceName: sample.sourceRevision.source.name
                ))
            }
            store.execute(query)
        }
    }

    private func cumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> HealthReading? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let quantity = statistics?.sumQuantity(),
                      quantity.is(compatibleWith: unit) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: HealthReading(
                    value: quantity.doubleValue(for: unit),
                    measuredAt: end,
                    sourceName: "Apple Salud · total del día"
                ))
            }
            store.execute(query)
        }
    }

    private func averageQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> HealthReading? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let quantity = statistics?.averageQuantity(), quantity.is(compatibleWith: unit) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: HealthReading(
                    value: quantity.doubleValue(for: unit),
                    measuredAt: end,
                    sourceName: "Apple Salud · media de muestras de hoy"
                ))
            }
            store.execute(query)
        }
    }

    private func hourlyEnergy(from start: Date, to end: Date) async throws -> [HourlyEnergyObservation] {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: DateComponents(hour: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }
                var observations: [HourlyEnergyObservation] = []
                collection.enumerateStatistics(from: start, to: end) { statistics, _ in
                    guard let quantity = statistics.sumQuantity() else { return }
                    let value = quantity.doubleValue(for: .kilocalorie())
                    guard value.isFinite, value >= 0 else { return }
                    observations.append(HourlyEnergyObservation(hour: statistics.startDate, kilocalories: value))
                }
                continuation.resume(returning: observations.sorted { $0.hour < $1.hour })
            }
            store.execute(query)
        }
    }

    private func lastNightStages(now: Date) async throws -> [SleepStageObservation] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let today = Calendar.current.startOfDay(for: now)
        let start = today.addingTimeInterval(-6 * 60 * 60)
        let end = min(now, today.addingTimeInterval(12 * 60 * 60))
        guard end > start else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let mapped: [(sample: HKCategorySample, stage: SleepStageKind)] = (samples ?? []).compactMap { item in
                    guard let sample = item as? HKCategorySample else { return nil }
                    let stage: SleepStageKind
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue: stage = .core
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: stage = .deep
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue: stage = .rem
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: stage = .unspecified
                    default: return nil
                    }
                    return (sample, stage)
                }
                guard let mostRecent = mapped.max(by: { $0.sample.endDate < $1.sample.endDate }) else {
                    continuation.resume(returning: [])
                    return
                }
                let sourceID = mostRecent.sample.sourceRevision.source.bundleIdentifier
                let stages = mapped
                    .filter { $0.sample.sourceRevision.source.bundleIdentifier == sourceID }
                    .compactMap { item -> SleepStageObservation? in
                        let clippedStart = max(item.sample.startDate, start)
                        let clippedEnd = min(item.sample.endDate, end)
                        guard clippedEnd > clippedStart else { return nil }
                        return SleepStageObservation(start: clippedStart, end: clippedEnd, stage: item.stage)
                    }
                    .sorted { $0.start < $1.start }
                continuation.resume(returning: stages)
            }
            store.execute(query)
        }
    }

    private func lastNightSleep(now: Date) async throws -> HealthReading? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let today = Calendar.current.startOfDay(for: now)
        let start = today.addingTimeInterval(-6 * 60 * 60)
        let end = min(now, today.addingTimeInterval(12 * 60 * 60))
        guard end > start else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let intervals = (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { sleepValues.contains($0.value) }
                    .map { (max($0.startDate, start), min($0.endDate, end)) }
                    .filter { $0.1 > $0.0 }
                    .sorted { $0.0 < $1.0 }
                guard let first = intervals.first else {
                    continuation.resume(returning: nil)
                    return
                }
                var currentStart = first.0
                var currentEnd = first.1
                var seconds = 0.0
                for interval in intervals.dropFirst() {
                    if interval.0 <= currentEnd {
                        currentEnd = max(currentEnd, interval.1)
                    } else {
                        seconds += currentEnd.timeIntervalSince(currentStart)
                        currentStart = interval.0
                        currentEnd = interval.1
                    }
                }
                seconds += currentEnd.timeIntervalSince(currentStart)
                continuation.resume(returning: HealthReading(
                    value: seconds / 60,
                    measuredAt: currentEnd,
                    sourceName: "Apple Salud · sueño registrado"
                ))
            }
            store.execute(query)
        }
    }

    private func dailyQuantityHistory(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        from start: Date,
        to end: Date
    ) async throws -> [DailyHealthObservation] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            var calendar = Calendar.current
            calendar.timeZone = .current
            let anchor = calendar.startOfDay(for: start)
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }
                var observations: [DailyHealthObservation] = []
                collection.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let quantity = options.contains(.cumulativeSum)
                        ? statistics.sumQuantity()
                        : statistics.averageQuantity()
                    guard let quantity, quantity.is(compatibleWith: unit) else { return }
                    let value = quantity.doubleValue(for: unit)
                    guard value.isFinite else { return }
                    observations.append(DailyHealthObservation(
                        day: calendar.startOfDay(for: statistics.startDate),
                        value: value,
                        sourceName: "Apple Salud · agregado diario"
                    ))
                }
                continuation.resume(returning: observations.sorted { $0.day < $1.day })
            }
            store.execute(query)
        }
    }

    private func dailySleepHistory(from start: Date, to end: Date) async throws -> [DailyHealthObservation] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                var calendar = Calendar.current
                calendar.timeZone = .current
                let intervals = (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { sleepValues.contains($0.value) }
                    .map { (max($0.startDate, start), min($0.endDate, end)) }
                    .filter { $0.1 > $0.0 }
                let grouped = Dictionary(grouping: intervals) { calendar.startOfDay(for: $0.1) }
                let observations = grouped.compactMap { day, dayIntervals -> DailyHealthObservation? in
                    let sorted = dayIntervals.sorted { $0.0 < $1.0 }
                    guard let first = sorted.first else { return nil }
                    var segmentStart = first.0
                    var segmentEnd = first.1
                    var seconds = 0.0
                    for interval in sorted.dropFirst() {
                        if interval.0 <= segmentEnd {
                            segmentEnd = max(segmentEnd, interval.1)
                        } else {
                            seconds += segmentEnd.timeIntervalSince(segmentStart)
                            segmentStart = interval.0
                            segmentEnd = interval.1
                        }
                    }
                    seconds += segmentEnd.timeIntervalSince(segmentStart)
                    return DailyHealthObservation(
                        day: day,
                        value: seconds / 60,
                        sourceName: "Apple Salud · sueño por noche"
                    )
                }
                continuation.resume(returning: observations.sorted { $0.day < $1.day })
            }
            store.execute(query)
        }
    }
}
