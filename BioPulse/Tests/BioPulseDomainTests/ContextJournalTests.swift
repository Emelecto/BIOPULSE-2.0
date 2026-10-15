import Foundation
import Testing
@testable import BioPulseDomain

struct ContextJournalTests {
    @Test func validatesAndNormalizesUserInput() throws {
        let draft = try JournalEntryDraft(
            category: .habit,
            title: "  Caminata después de almorzar  ",
            notes: "  Me ayudó a despejarme.  ",
            occurredAt: Date(timeIntervalSince1970: 100),
            timeZoneIdentifier: "America/Bogota"
        )

        #expect(draft.title == "Caminata después de almorzar")
        #expect(draft.notes == "Me ayudó a despejarme.")

        do {
            _ = try JournalEntryDraft(
                category: .event,
                title: "   ",
                occurredAt: .now,
                timeZoneIdentifier: "America/Bogota"
            )
            Issue.record("Un título vacío no debe aceptarse.")
        } catch let error as JournalValidationError {
            #expect(error == .emptyTitle)
        }

        do {
            _ = try JournalEntryDraft(
                category: .event,
                title: "Viaje",
                occurredAt: .now,
                timeZoneIdentifier: "Zona/Inexistente"
            )
            Issue.record("Una zona horaria desconocida no debe aceptarse.")
        } catch let error as JournalValidationError {
            #expect(error == .invalidTimeZone(identifier: "Zona/Inexistente"))
        }
    }

    @Test func refusesDuplicateIdentifiers() async throws {
        let store = InMemoryContextJournalStore()
        let identifier = UUID()
        let firstDraft = try draft(title: "Primera entrada", at: 100)
        let secondDraft = try draft(title: "Segunda entrada", at: 200)

        let first = await store.apply(
            .insert(draft: firstDraft, id: identifier),
            at: Date(timeIntervalSince1970: 101)
        )
        let duplicate = await store.apply(
            .insert(draft: secondDraft, id: identifier),
            at: Date(timeIntervalSince1970: 201)
        )

        guard case let .saved(stored) = first else {
            Issue.record("La primera inserción debía guardarse.")
            return
        }
        #expect(stored.revision == 1)
        #expect(duplicate == .conflict(.identifierAlreadyStored(existing: stored)))
        let retained = await store.entry(id: identifier)
        #expect(retained?.title == "Primera entrada")
    }

    @Test func replacesAndDeletesOnlyTheExpectedRevision() async throws {
        let store = InMemoryContextJournalStore()
        let identifier = UUID()
        let originalDraft = try draft(title: "Original", at: 100)
        let replacementDraft = try draft(title: "Actualizada", at: 200)

        let inserted = await store.apply(
            .insert(draft: originalDraft, id: identifier),
            at: Date(timeIntervalSince1970: 110)
        )
        guard case let .saved(original) = inserted else {
            Issue.record("La entrada inicial debía guardarse.")
            return
        }

        let replaced = await store.apply(
            .replace(id: identifier, expectedRevision: original.revision, draft: replacementDraft),
            at: Date(timeIntervalSince1970: 210)
        )
        guard case let .saved(updated) = replaced else {
            Issue.record("La revisión vigente debía permitir el reemplazo.")
            return
        }

        #expect(updated.revision == 2)
        #expect(updated.createdAt == original.createdAt)
        #expect(updated.title == "Actualizada")

        let staleDelete = await store.delete(id: identifier, expectedRevision: 1)
        #expect(staleDelete == .conflict(.revisionMismatch(existing: updated)))
        let retained = await store.entry(id: identifier)
        #expect(retained != nil)

        let deleted = await store.delete(id: identifier, expectedRevision: updated.revision)
        #expect(deleted == .deleted(updated))
        let removed = await store.entry(id: identifier)
        #expect(removed == nil)
    }

    @Test func filtersInclusiveDatesAndCategories() async throws {
        let store = InMemoryContextJournalStore()
        _ = await store.apply(.insert(draft: try draft(category: .habit, title: "A", at: 100)))
        _ = await store.apply(.insert(draft: try draft(category: .symptom, title: "B", at: 200)))
        _ = await store.apply(.insert(draft: try draft(category: .event, title: "C", at: 300)))

        let query = try JournalQuery(
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200),
            categories: [.habit, .symptom]
        )
        let records = await store.entries(matching: query)

        #expect(records.map(\.title) == ["B", "A"])

        do {
            _ = try JournalQuery(
                start: Date(timeIntervalSince1970: 300),
                end: Date(timeIntervalSince1970: 100)
            )
            Issue.record("Un rango invertido no debe aceptarse.")
        } catch let error as JournalValidationError {
            #expect(error == .invalidDateRange)
        }
    }

    @Test func persistsAndReloadsJSONWithoutChangingProvenance() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BioPulseJournalTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("journal.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = JSONContextJournalStore(fileURL: fileURL)
        let originalDraft = try draft(category: .event, title: "Cambio de horario", at: 500)
        let result = try await writer.apply(
            .insert(draft: originalDraft, provenance: .importedCSV),
            at: Date(timeIntervalSince1970: 510)
        )
        guard case let .saved(saved) = result else {
            Issue.record("La entrada debía persistirse.")
            return
        }

        let reader = JSONContextJournalStore(fileURL: fileURL)
        let reloaded = try await reader.entries(matching: nil)

        #expect(reloaded == [saved])
        #expect(reloaded.first?.provenance == .importedCSV)
        #expect(reloaded.first?.revision == 1)
    }

    @Test func persistsEditsAndDeletionAcrossStoreReopens() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BioPulseJournalCRUDTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("journal.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let initialDraft = try draft(category: .habit, title: "Paseo corto", at: 100)
        let insertedResult = try await JSONContextJournalStore(fileURL: fileURL).apply(
            .insert(draft: initialDraft),
            at: Date(timeIntervalSince1970: 101)
        )
        guard case let .saved(inserted) = insertedResult else {
            Issue.record("La entrada inicial debía persistirse.")
            return
        }

        let revisedDraft = try draft(category: .event, title: "Paseo cancelado", at: 200)
        let revisedResult = try await JSONContextJournalStore(fileURL: fileURL).apply(
            .replace(id: inserted.id, expectedRevision: inserted.revision, draft: revisedDraft),
            at: Date(timeIntervalSince1970: 201)
        )
        guard case let .saved(revised) = revisedResult else {
            Issue.record("La edición con la revisión vigente debía persistirse.")
            return
        }

        #expect(revised.title == "Paseo cancelado")
        #expect(revised.revision == 2)

        let deletedResult = try await JSONContextJournalStore(fileURL: fileURL).delete(
            id: revised.id,
            expectedRevision: revised.revision
        )
        #expect(deletedResult == .deleted(revised))

        let afterDeletion = try await JSONContextJournalStore(fileURL: fileURL).entries(matching: nil)
        #expect(afterDeletion.isEmpty)
    }

    private func draft(
        category: JournalCategory = .habit,
        title: String,
        at timestamp: TimeInterval
    ) throws -> JournalEntryDraft {
        try JournalEntryDraft(
            category: category,
            title: title,
            occurredAt: Date(timeIntervalSince1970: timestamp),
            timeZoneIdentifier: "America/Bogota"
        )
    }
}
