import BioPulseDomain
import Foundation
import SwiftUI

@MainActor
final class JournalController: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?
    @Published private(set) var saveRevision = 0

    private let store: any ContextJournalStore

    init(store: any ContextJournalStore) {
        self.store = store
    }

    static func live(userID: UUID) -> JournalController {
        JournalController(store: JSONContextJournalStore(fileURL: journalFileURL(userID: userID)))
    }

    func seedPresentationSample() async {
        guard !hasLoaded else { return }
        guard let memoryStore = store as? InMemoryContextJournalStore else { return }
        let samples: [(JournalCategory, String, String, Int)] = [
            (.habit, "Caminata matutina", "Una vuelta corta antes de empezar el día.", 2),
            (.event, "Entrenamiento de fuerza", "Sesión de 40 minutos por la tarde.", 6),
            (.habit, "Rutina de descanso", "Dejé el teléfono fuera de la habitación.", 10),
            (.symptom, "Energía estable", "Me sentí bien durante la mayor parte del día.", 15),
            (.event, "Día de recuperación", "Actividad ligera y una noche más larga.", 21)
        ]
        for (category, title, notes, daysAgo) in samples {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            guard let draft = try? JournalEntryDraft(category: category, title: title, notes: notes, occurredAt: date, timeZoneIdentifier: TimeZone.current.identifier) else { continue }
            _ = await memoryStore.apply(.insert(draft: draft), at: date)
        }
        await load()
    }

    func resetPresentationSample() async {
        guard let memoryStore = store as? InMemoryContextJournalStore else { return }
        let current = await memoryStore.entries(matching: nil)
        for entry in current { _ = await memoryStore.delete(id: entry.id, expectedRevision: entry.revision) }
        entries = []
        hasLoaded = false
        await seedPresentationSample()
    }

    func load(force: Bool = false) async {
        guard force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil

        do {
            entries = try await store.entries(matching: nil)
            hasLoaded = true
        } catch {
            errorMessage = "No fue posible abrir el diario local. Tus demás datos no fueron modificados."
        }

        isLoading = false
    }

    @discardableResult
    func create(_ draft: JournalEntryDraft) async -> Bool {
        errorMessage = nil
        do {
            let result = try await store.apply(.insert(draft: draft), at: .now)
            return handle(result)
        } catch {
            errorMessage = "No fue posible guardar esta entrada en el dispositivo."
            return false
        }
    }

    @discardableResult
    func update(_ entry: JournalEntry, with draft: JournalEntryDraft) async -> Bool {
        errorMessage = nil
        do {
            let result = try await store.apply(
                .replace(id: entry.id, expectedRevision: entry.revision, draft: draft),
                at: .now
            )
            return handle(result)
        } catch {
            errorMessage = "No fue posible actualizar esta entrada."
            return false
        }
    }

    func delete(_ entry: JournalEntry) async {
        errorMessage = nil
        do {
            let result = try await store.delete(id: entry.id, expectedRevision: entry.revision)
            switch result {
            case let .deleted(deleted):
                entries.removeAll { $0.id == deleted.id }
            case .conflict:
                errorMessage = "La entrada cambió antes de poder eliminarla. Recarga el diario e inténtalo de nuevo."
            }
        } catch {
            errorMessage = "No fue posible eliminar esta entrada."
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func handle(_ result: JournalWriteResult) -> Bool {
        switch result {
        case let .saved(saved):
            entries.removeAll { $0.id == saved.id }
            entries.append(saved)
            entries.sort {
                if $0.occurredAt == $1.occurredAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.occurredAt > $1.occurredAt
            }
            saveRevision += 1
            return true
        case .conflict:
            errorMessage = "La entrada cambió antes de poder guardarla. Recarga el diario e inténtalo de nuevo."
            return false
        }
    }
}

private func journalFileURL(userID: UUID) -> URL {
    guard let baseURL = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first else {
        preconditionFailure("Application Support must be available on iOS.")
    }

    return baseURL
        .appendingPathComponent("BioPulse", isDirectory: true)
        .appendingPathComponent("Accounts", isDirectory: true)
        .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
        .appendingPathComponent("context-journal-v1.json", isDirectory: false)
}
