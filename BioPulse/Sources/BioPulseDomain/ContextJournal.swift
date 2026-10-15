import Foundation

public enum JournalCategory: String, CaseIterable, Codable, Sendable {
    case habit
    case symptom
    case event
}

public enum JournalProvenance: String, Codable, Sendable {
    case userEntered
    case importedCSV
}

public struct JournalEntryDraft: Codable, Equatable, Sendable {
    public static let maximumTitleLength = 120
    public static let maximumNotesLength = 2_000

    public let category: JournalCategory
    public let title: String
    public let notes: String
    public let occurredAt: Date
    public let timeZoneIdentifier: String

    public init(
        category: JournalCategory,
        title: String,
        notes: String = "",
        occurredAt: Date,
        timeZoneIdentifier: String
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            throw JournalValidationError.emptyTitle
        }
        guard normalizedTitle.count <= Self.maximumTitleLength else {
            throw JournalValidationError.titleTooLong(maximum: Self.maximumTitleLength)
        }
        guard normalizedNotes.count <= Self.maximumNotesLength else {
            throw JournalValidationError.notesTooLong(maximum: Self.maximumNotesLength)
        }
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw JournalValidationError.invalidTimeZone(identifier: timeZoneIdentifier)
        }

        self.category = category
        self.title = normalizedTitle
        self.notes = normalizedNotes
        self.occurredAt = occurredAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public struct JournalEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let category: JournalCategory
    public let title: String
    public let notes: String
    public let occurredAt: Date
    public let timeZoneIdentifier: String
    public let provenance: JournalProvenance
    public let revision: Int
    public let createdAt: Date
    public let updatedAt: Date

    init(
        id: UUID,
        draft: JournalEntryDraft,
        provenance: JournalProvenance,
        revision: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.category = draft.category
        self.title = draft.title
        self.notes = draft.notes
        self.occurredAt = draft.occurredAt
        self.timeZoneIdentifier = draft.timeZoneIdentifier
        self.provenance = provenance
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var draft: JournalEntryDraft {
        get throws {
            try JournalEntryDraft(
                category: category,
                title: title,
                notes: notes,
                occurredAt: occurredAt,
                timeZoneIdentifier: timeZoneIdentifier
            )
        }
    }
}

public struct JournalQuery: Codable, Equatable, Sendable {
    public let start: Date?
    public let end: Date?
    public let categories: Set<JournalCategory>?

    public init(
        start: Date? = nil,
        end: Date? = nil,
        categories: Set<JournalCategory>? = nil
    ) throws {
        if let start, let end, start > end {
            throw JournalValidationError.invalidDateRange
        }
        self.start = start
        self.end = end
        self.categories = categories?.isEmpty == true ? nil : categories
    }

    public func contains(_ entry: JournalEntry) -> Bool {
        if let start, entry.occurredAt < start { return false }
        if let end, entry.occurredAt > end { return false }
        if let categories, !categories.contains(entry.category) { return false }
        return true
    }
}

public enum JournalWriteRequest: Codable, Equatable, Sendable {
    case insert(id: UUID, draft: JournalEntryDraft, provenance: JournalProvenance)
    case replace(id: UUID, expectedRevision: Int, draft: JournalEntryDraft)

    public static func insert(
        draft: JournalEntryDraft,
        provenance: JournalProvenance = .userEntered,
        id: UUID = UUID()
    ) -> JournalWriteRequest {
        .insert(id: id, draft: draft, provenance: provenance)
    }

    public static func replace(
        id: UUID,
        expectedRevision: Int,
        draft: JournalEntryDraft
    ) -> JournalWriteRequest {
        .replace(id: id, expectedRevision: expectedRevision, draft: draft)
    }
}

public enum JournalWriteResult: Codable, Equatable, Sendable {
    case saved(JournalEntry)
    case conflict(JournalMutationConflict)
}

public enum JournalDeleteResult: Codable, Equatable, Sendable {
    case deleted(JournalEntry)
    case conflict(JournalMutationConflict)
}

public enum JournalMutationConflict: Codable, Equatable, Sendable {
    case identifierAlreadyStored(existing: JournalEntry)
    case recordNotFound(id: UUID)
    case revisionMismatch(existing: JournalEntry)
}

public enum JournalValidationError: Error, Equatable, Sendable {
    case emptyTitle
    case titleTooLong(maximum: Int)
    case notesTooLong(maximum: Int)
    case invalidTimeZone(identifier: String)
    case invalidDateRange
}

public enum JournalStoreError: Error, Equatable, Sendable {
    case unreadableFile
    case unsupportedSchema(version: Int)
    case duplicateIdentifier(id: UUID)
    case unableToCreateDirectory
    case unableToWriteFile
}

public protocol ContextJournalStore: Sendable {
    func entries(matching query: JournalQuery?) async throws -> [JournalEntry]
    func entry(id: UUID) async throws -> JournalEntry?
    func apply(_ request: JournalWriteRequest, at date: Date) async throws -> JournalWriteResult
    func delete(id: UUID, expectedRevision: Int) async throws -> JournalDeleteResult
}

public actor InMemoryContextJournalStore: ContextJournalStore {
    private var entriesByID: [UUID: JournalEntry] = [:]

    public init() {}

    public func entries(matching query: JournalQuery? = nil) -> [JournalEntry] {
        sortedEntries(entriesByID.values.filter { query?.contains($0) ?? true })
    }

    public func entry(id: UUID) -> JournalEntry? {
        entriesByID[id]
    }

    public func apply(
        _ request: JournalWriteRequest,
        at date: Date = .now
    ) -> JournalWriteResult {
        applyJournalWrite(request, to: &entriesByID, at: date)
    }

    public func delete(id: UUID, expectedRevision: Int) -> JournalDeleteResult {
        applyJournalDelete(id: id, expectedRevision: expectedRevision, to: &entriesByID)
    }
}

public actor JSONContextJournalStore: ContextJournalStore {
    private static let currentSchemaVersion = 1

    private let fileURL: URL
    private var loadedEntries: [UUID: JournalEntry]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func entries(matching query: JournalQuery? = nil) throws -> [JournalEntry] {
        let entries = try entriesByID()
        return sortedEntries(entries.values.filter { query?.contains($0) ?? true })
    }

    public func entry(id: UUID) throws -> JournalEntry? {
        try entriesByID()[id]
    }

    public func apply(
        _ request: JournalWriteRequest,
        at date: Date = .now
    ) throws -> JournalWriteResult {
        var candidate = try entriesByID()
        let result = applyJournalWrite(request, to: &candidate, at: date)

        if case .saved = result {
            try persist(candidate)
            loadedEntries = candidate
        }
        return result
    }

    public func delete(id: UUID, expectedRevision: Int) throws -> JournalDeleteResult {
        var candidate = try entriesByID()
        let result = applyJournalDelete(id: id, expectedRevision: expectedRevision, to: &candidate)

        if case .deleted = result {
            try persist(candidate)
            loadedEntries = candidate
        }
        return result
    }

    private func entriesByID() throws -> [UUID: JournalEntry] {
        if let loadedEntries { return loadedEntries }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loadedEntries = [:]
            return [:]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let envelope = try decoder.decode(JournalFileEnvelope.self, from: data)

            guard envelope.schemaVersion == Self.currentSchemaVersion else {
                throw JournalStoreError.unsupportedSchema(version: envelope.schemaVersion)
            }

            var indexed: [UUID: JournalEntry] = [:]
            for entry in envelope.entries {
                guard indexed[entry.id] == nil else {
                    throw JournalStoreError.duplicateIdentifier(id: entry.id)
                }
                indexed[entry.id] = entry
            }
            loadedEntries = indexed
            return indexed
        } catch let error as JournalStoreError {
            throw error
        } catch {
            throw JournalStoreError.unreadableFile
        }
    }

    private func persist(_ entries: [UUID: JournalEntry]) throws {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw JournalStoreError.unableToCreateDirectory
        }

        let envelope = JournalFileEnvelope(
            schemaVersion: Self.currentSchemaVersion,
            entries: sortedEntries(entries.values)
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(envelope)
            try data.write(to: fileURL, options: journalWriteOptions)
        } catch {
            throw JournalStoreError.unableToWriteFile
        }
    }
}

private struct JournalFileEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let entries: [JournalEntry]
}

private var journalWriteOptions: Data.WritingOptions {
    #if os(iOS)
    [.atomic, .completeFileProtection]
    #else
    [.atomic]
    #endif
}

private func sortedEntries<S: Sequence>(_ entries: S) -> [JournalEntry]
where S.Element == JournalEntry {
    entries.sorted {
        if $0.occurredAt == $1.occurredAt {
            return $0.createdAt > $1.createdAt
        }
        return $0.occurredAt > $1.occurredAt
    }
}

private func applyJournalWrite(
    _ request: JournalWriteRequest,
    to entries: inout [UUID: JournalEntry],
    at date: Date
) -> JournalWriteResult {
    switch request {
    case let .insert(id, draft, provenance):
        if let existing = entries[id] {
            return .conflict(.identifierAlreadyStored(existing: existing))
        }
        let entry = JournalEntry(
            id: id,
            draft: draft,
            provenance: provenance,
            revision: 1,
            createdAt: date,
            updatedAt: date
        )
        entries[id] = entry
        return .saved(entry)

    case let .replace(id, expectedRevision, draft):
        guard let existing = entries[id] else {
            return .conflict(.recordNotFound(id: id))
        }
        guard existing.revision == expectedRevision else {
            return .conflict(.revisionMismatch(existing: existing))
        }
        let entry = JournalEntry(
            id: existing.id,
            draft: draft,
            provenance: existing.provenance,
            revision: existing.revision + 1,
            createdAt: existing.createdAt,
            updatedAt: date
        )
        entries[id] = entry
        return .saved(entry)
    }
}

private func applyJournalDelete(
    id: UUID,
    expectedRevision: Int,
    to entries: inout [UUID: JournalEntry]
) -> JournalDeleteResult {
    guard let existing = entries[id] else {
        return .conflict(.recordNotFound(id: id))
    }
    guard existing.revision == expectedRevision else {
        return .conflict(.revisionMismatch(existing: existing))
    }
    entries[id] = nil
    return .deleted(existing)
}
