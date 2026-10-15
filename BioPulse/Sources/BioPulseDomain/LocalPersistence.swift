import Foundation

public struct LocalDayRange: Codable, Equatable, Sendable {
    public let start: LocalDay
    public let end: LocalDay

    public init(start: LocalDay, end: LocalDay) throws {
        guard start.timeZoneIdentifier == end.timeZoneIdentifier, start <= end else {
            throw PersistenceValidationError.invalidDayRange
        }
        self.start = start
        self.end = end
    }

    public func contains(_ day: LocalDay) -> Bool {
        day.timeZoneIdentifier == start.timeZoneIdentifier && start <= day && day <= end
    }
}

public struct StoredDailySnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let snapshot: DailySnapshot
    public let revision: Int
    public let createdAt: Date
    public let updatedAt: Date
}

public struct StoredBaseline: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let baseline: PersonalBaseline
    public let storedAt: Date
}

public struct StoredTrend: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let analysis: MetricTrendAnalysis
    public let storedAt: Date
}

public enum SnapshotWriteRequest: Codable, Equatable, Sendable {
    case insert(id: UUID, snapshot: DailySnapshot)
    case replace(id: UUID, expectedRevision: Int, snapshot: DailySnapshot)

    public static func insert(snapshot: DailySnapshot, id: UUID = UUID()) -> SnapshotWriteRequest {
        .insert(id: id, snapshot: snapshot)
    }

}

public enum SnapshotWriteResult: Codable, Equatable, Sendable {
    case saved(StoredDailySnapshot)
    case conflict(SnapshotWriteConflict)
}

public enum SnapshotWriteConflict: Codable, Equatable, Sendable {
    case dayAlreadyStored(existing: StoredDailySnapshot)
    case recordNotFound(id: UUID)
    case revisionMismatch(existing: StoredDailySnapshot)
    case dayDoesNotMatchExistingRecord(existing: StoredDailySnapshot)
}

public enum PersistenceValidationError: Error, Equatable, Sendable {
    case invalidDayRange
}

public protocol BioPulseLocalStore: Sendable {
    func apply(_ request: SnapshotWriteRequest, at date: Date) async -> SnapshotWriteResult
    func snapshot(on day: LocalDay) async -> StoredDailySnapshot?
    func snapshots(in range: LocalDayRange) async -> [StoredDailySnapshot]
    func saveBaseline(_ baseline: PersonalBaseline, at date: Date) async -> StoredBaseline
    func latestBaseline(for metric: MetricKind) async -> StoredBaseline?
    func saveTrend(_ analysis: MetricTrendAnalysis, at date: Date) async -> StoredTrend
    func trend(for metric: MetricKind, on day: LocalDay) async -> StoredTrend?
}

public actor InMemoryBioPulseLocalStore: BioPulseLocalStore {
    private var snapshotsByDay: [LocalDay: StoredDailySnapshot] = [:]
    private var baselinesByMetric: [MetricKind: StoredBaseline] = [:]
    private var trendsByKey: [TrendStorageKey: StoredTrend] = [:]

    public init() {}

    public func apply(_ request: SnapshotWriteRequest, at date: Date = .now) -> SnapshotWriteResult {
        switch request {
        case let .insert(id, snapshot):
            if let existing = snapshotsByDay[snapshot.day] {
                return .conflict(.dayAlreadyStored(existing: existing))
            }

            let stored = StoredDailySnapshot(
                id: id,
                snapshot: snapshot,
                revision: 1,
                createdAt: date,
                updatedAt: date
            )
            snapshotsByDay[snapshot.day] = stored
            return .saved(stored)

        case let .replace(id, expectedRevision, snapshot):
            guard let existing = snapshotsByDay[snapshot.day] else {
                return .conflict(.recordNotFound(id: id))
            }
            guard existing.id == id else {
                return .conflict(.dayDoesNotMatchExistingRecord(existing: existing))
            }
            guard existing.revision == expectedRevision else {
                return .conflict(.revisionMismatch(existing: existing))
            }

            let stored = StoredDailySnapshot(
                id: existing.id,
                snapshot: snapshot,
                revision: existing.revision + 1,
                createdAt: existing.createdAt,
                updatedAt: date
            )
            snapshotsByDay[snapshot.day] = stored
            return .saved(stored)
        }
    }

    public func snapshot(on day: LocalDay) -> StoredDailySnapshot? {
        snapshotsByDay[day]
    }

    public func snapshots(in range: LocalDayRange) -> [StoredDailySnapshot] {
        snapshotsByDay.values
            .filter { range.contains($0.snapshot.day) }
            .sorted { $0.snapshot.day < $1.snapshot.day }
    }

    public func saveBaseline(_ baseline: PersonalBaseline, at date: Date = .now) -> StoredBaseline {
        let stored = StoredBaseline(id: UUID(), baseline: baseline, storedAt: date)
        baselinesByMetric[baseline.metric] = stored
        return stored
    }

    public func latestBaseline(for metric: MetricKind) -> StoredBaseline? {
        baselinesByMetric[metric]
    }

    public func saveTrend(_ analysis: MetricTrendAnalysis, at date: Date = .now) -> StoredTrend {
        let stored = StoredTrend(id: UUID(), analysis: analysis, storedAt: date)
        trendsByKey[TrendStorageKey(metric: analysis.metric, day: analysis.day)] = stored
        return stored
    }

    public func trend(for metric: MetricKind, on day: LocalDay) -> StoredTrend? {
        trendsByKey[TrendStorageKey(metric: metric, day: day)]
    }
}

private struct TrendStorageKey: Hashable, Sendable {
    let metric: MetricKind
    let day: LocalDay
}

public extension MetricTrendAnalysis {
    var metric: MetricKind {
        switch self {
        case let .available(trend): trend.metric
        case let .unavailable(trend): trend.metric
        }
    }

    var day: LocalDay {
        switch self {
        case let .available(trend): trend.day
        case let .unavailable(trend): trend.day
        }
    }
}
