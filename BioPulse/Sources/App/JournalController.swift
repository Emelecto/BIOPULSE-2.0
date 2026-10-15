import BioPulseDomain
import Foundation
import SwiftUI

@MainActor
final class JournalController: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    private let store: any ContextJournalStore

    init(store: any ContextJournalStore) {
        self.store = store
    }

    static func live(userID: UUID) -> JournalController {
        JournalController(store: JSONContextJournalStore(fileURL: journalFileURL(userID: userID)))
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

    func create(_ draft: JournalEntryDraft) async {
        errorMessage = nil
        do {
            let result = try await store.apply(.insert(draft: draft), at: .now)
            handle(result)
        } catch {
            errorMessage = "No fue posible guardar esta entrada en el dispositivo."
        }
    }

    func update(_ entry: JournalEntry, with draft: JournalEntryDraft) async {
        errorMessage = nil
        do {
            let result = try await store.apply(
                .replace(id: entry.id, expectedRevision: entry.revision, draft: draft),
                at: .now
            )
            handle(result)
        } catch {
            errorMessage = "No fue posible actualizar esta entrada."
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

    private func handle(_ result: JournalWriteResult) {
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
        case .conflict:
            errorMessage = "La entrada cambió antes de poder guardarla. Recarga el diario e inténtalo de nuevo."
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
