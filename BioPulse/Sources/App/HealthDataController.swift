import Combine
import Foundation
import HealthKit

struct HealthReading: Equatable {
    let value: Double
    let measuredAt: Date
    let sourceName: String
}

@MainActor
final class HealthDataController: ObservableObject {
    @Published private(set) var readings: [HealthMetric: HealthReading] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hasRequestedAccess = UserDefaults.standard.bool(forKey: "BioPulse.hasRequestedHealthAccess")

    private let store = HKHealthStore()
    private let catalog = HealthKitCapabilityCatalog()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async {
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
        guard isAvailable, hasRequestedAccess else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        var updated: [HealthMetric: HealthReading] = [:]
        var failedQueries = 0

        for (metric, identifier, unit, start) in [
            (HealthMetric.heartRateVariabilitySDNN, HKQuantityTypeIdentifier.heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli), today),
            (.restingHeartRate, .restingHeartRate, HKUnit.count().unitDivided(by: .minute()), today),
            (.heartRate, .heartRate, HKUnit.count().unitDivided(by: .minute()), today),
            (.respiratoryRate, .respiratoryRate, HKUnit.count().unitDivided(by: .minute()), today),
            (.oxygenSaturation, .oxygenSaturation, HKUnit.percent(), today)
        ] {
            do {
                updated[metric] = try await latestQuantity(identifier, unit: unit, from: start, to: now)
            } catch {
                failedQueries += 1
            }
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

        readings = updated
        lastUpdated = now
        if failedQueries > 0 {
            errorMessage = "Algunas señales no pudieron consultarse. Puedes volver a intentarlo."
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
}
