import Foundation
import Testing
@testable import BioPulseDomain

struct LocalPersistenceTests {
    @Test func refusesToSilentlyOverwriteADailySnapshot() async throws {
        let store = InMemoryBioPulseLocalStore()
        let day = try LocalDay(year: 2026, month: 10, day: 13, timeZoneIdentifier: "America/Bogota")
        let first = try snapshot(day: day, steps: 8_000)
        let second = try snapshot(day: day, steps: 9_000)
        let firstID = UUID()

        let firstResult = await store.apply(.insert(snapshot: first, id: firstID), at: Date(timeIntervalSince1970: 0))
        let secondResult = await store.apply(.insert(snapshot: second), at: Date(timeIntervalSince1970: 1))

        guard case let .saved(stored) = firstResult else {
            Issue.record("La primera inserción debía guardarse.")
            return
        }
        #expect(stored.revision == 1)
        #expect(secondResult == .conflict(.dayAlreadyStored(existing: stored)))
        let retained = await store.snapshot(on: day)
        #expect(retained?.snapshot.metric(.stepCount)?.value == 8_000)
    }

    @Test func replacesOnlyWithTheExpectedRevision() async throws {
        let store = InMemoryBioPulseLocalStore()
        let day = try LocalDay(year: 2026, month: 10, day: 13, timeZoneIdentifier: "America/Bogota")
        let first = try snapshot(day: day, steps: 8_000)
        let replacement = try snapshot(day: day, steps: 9_000)
        let identifier = UUID()

        let inserted = await store.apply(.insert(snapshot: first, id: identifier), at: Date(timeIntervalSince1970: 0))
        let replacementResult = await store.apply(
            .replace(id: identifier, expectedRevision: 1, snapshot: replacement),
            at: Date(timeIntervalSince1970: 1)
        )

        guard case .saved = inserted, case let .saved(storedReplacement) = replacementResult else {
            Issue.record("El reemplazo con la revisión correcta debía guardarse.")
            return
        }
        #expect(storedReplacement.revision == 2)
        #expect(storedReplacement.snapshot.metric(.stepCount)?.value == 9_000)
    }

    @Test func returnsSnapshotsInChronologicalOrderInsideARange() async throws {
        let store = InMemoryBioPulseLocalStore()
        let dayOne = try LocalDay(year: 2026, month: 10, day: 11, timeZoneIdentifier: "America/Bogota")
        let dayTwo = try LocalDay(year: 2026, month: 10, day: 12, timeZoneIdentifier: "America/Bogota")
        let dayThree = try LocalDay(year: 2026, month: 10, day: 13, timeZoneIdentifier: "America/Bogota")

        _ = await store.apply(.insert(snapshot: try snapshot(day: dayThree, steps: 3)))
        _ = await store.apply(.insert(snapshot: try snapshot(day: dayOne, steps: 1)))
        _ = await store.apply(.insert(snapshot: try snapshot(day: dayTwo, steps: 2)))

        let range = try LocalDayRange(start: dayOne, end: dayThree)
        let records = await store.snapshots(in: range)

        #expect(records.map(\.snapshot.day) == [dayOne, dayTwo, dayThree])
    }

    private func snapshot(day: LocalDay, steps: Double) throws -> DailySnapshot {
        let metric = try DailyMetric(
            day: day,
            metric: .stepCount,
            value: steps,
            unit: .count,
            aggregation: .sum,
            sampleCount: 1,
            coverage: 1,
            source: .testFixture,
            quality: .simulatedForTest,
            sourceReferences: ["simulated-test-only"]
        )
        return try DailySnapshot(day: day, metrics: [metric])
    }
}
