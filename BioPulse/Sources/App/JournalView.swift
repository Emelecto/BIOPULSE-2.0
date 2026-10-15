import BioPulseDomain
import SwiftUI

struct JournalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var journal: JournalController
    @State private var showingComposer = false
    @State private var editingEntry: JournalEntry?
    @State private var deletionCandidate: JournalEntry?
    @State private var showsSaveConfirmation = false
    @State private var announcedSaveRevision = 0

    var body: some View {
        ScreenShell(title: "Diario", subtitle: "Hábitos, síntomas y eventos en contexto") {
            StatusPanel(
                symbol: "lock.shield",
                title: "Privado en este dispositivo",
                message: "Tus registros se guardan localmente. Si autorizas al Coach, podrá recibir entradas recientes al enviarle una pregunta."
            )

            Button("Registrar contexto") { showingComposer = true }
                .buttonStyle(PulseActionButtonStyle())

            if showsSaveConfirmation {
                PulseFeedback(message: "Registro guardado en tu Diario.")
            }

            SectionHeading(
                title: "Tus registros",
                subtitle: journal.entries.isEmpty ? "Aún no has añadido contexto" : "\(journal.entries.count) guardados"
            )

            journalContent
        }
        .task { await journal.load() }
        .refreshable { await journal.load(force: true) }
        .sheet(isPresented: $showingComposer, onDismiss: presentSaveConfirmation) {
            JournalEntryComposer { draft in
                await journal.create(draft)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingEntry, onDismiss: presentSaveConfirmation) { entry in
            JournalEntryComposer(entry: entry) { draft in
                await journal.update(entry, with: draft)
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "¿Eliminar este registro?",
            isPresented: deletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                guard let deletionCandidate else { return }
                Task { await journal.delete(deletionCandidate) }
                self.deletionCandidate = nil
            }
            Button("Cancelar", role: .cancel) { deletionCandidate = nil }
        } message: {
            Text("Esta acción elimina la entrada guardada en el dispositivo.")
        }
        .alert(
            "No se pudo completar la acción",
            isPresented: errorPresentation,
            actions: { Button("Aceptar") { journal.dismissError() } },
            message: { Text(journal.errorMessage ?? "Error desconocido") }
        )
        .sensoryFeedback(.success, trigger: announcedSaveRevision)
        .task(id: announcedSaveRevision) {
            guard showsSaveConfirmation else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showsSaveConfirmation = false }
        }
        .onDisappear { showsSaveConfirmation = false }
    }

    private func presentSaveConfirmation() {
        guard journal.saveRevision > announcedSaveRevision else { return }
        announcedSaveRevision = journal.saveRevision
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showsSaveConfirmation = true }
    }

    @ViewBuilder
    private var journalContent: some View {
        if journal.isLoading && !journal.hasLoaded {
            HStack(spacing: 12) {
                ProgressView().tint(PulseStyle.mint)
                Text("Abriendo tu diario…")
                    .font(.subheadline)
                    .foregroundStyle(PulseStyle.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .pulseSurface()
        } else if journal.entries.isEmpty {
            StatusPanel(
                symbol: "square.and.pencil",
                title: "Empieza cuando algo importe",
                message: "Registra un hábito, síntoma o evento. BioPulse podrá compararlo con tendencias cuando exista suficiente historial, sin afirmar causalidad."
            )
        } else {
            ForEach(journal.entries) { entry in
                journalCard(entry)
            }
        }
    }

    private var deletionConfirmation: Binding<Bool> {
        Binding(
            get: { deletionCandidate != nil },
            set: { if !$0 { deletionCandidate = nil } }
        )
    }

    private var errorPresentation: Binding<Bool> {
        Binding(
            get: { journal.errorMessage != nil && !showingComposer && editingEntry == nil },
            set: { if !$0 { journal.dismissError() } }
        )
    }

    private func journalCard(_ entry: JournalEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: entry.category.symbol)
                .foregroundStyle(PulseStyle.mint)
                .frame(width: 25)

            VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.category.localizedName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseStyle.mint)
                    Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(PulseStyle.muted)
                }

                Text(entry.title).font(.headline)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(entry.provenance.localizedName)
                    .font(.caption2)
                    .foregroundStyle(PulseStyle.muted)
            }

            Menu {
                Button("Editar", systemImage: "pencil") { editingEntry = entry }
                Button("Eliminar", systemImage: "trash", role: .destructive) {
                    deletionCandidate = entry
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(PulseStyle.secondary)
            .accessibilityLabel("Acciones para \(entry.title)")
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseSurface()
    }
}

private struct JournalEntryComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: JournalCategory
    @State private var title: String
    @State private var notes: String
    @State private var occurredAt: Date
    @State private var validationMessage: String?
    @State private var isSaving = false

    private let entry: JournalEntry?
    let onSave: (JournalEntryDraft) async -> Bool

    init(entry: JournalEntry? = nil, onSave: @escaping (JournalEntryDraft) async -> Bool) {
        self.entry = entry
        self.onSave = onSave
        _category = State(initialValue: entry?.category ?? .habit)
        _title = State(initialValue: entry?.title ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _occurredAt = State(initialValue: entry?.occurredAt ?? .now)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $category) {
                    ForEach(JournalCategory.allCases, id: \.self) { item in
                        Label(item.localizedName, systemImage: item.symbol).tag(item)
                    }
                }

                Section {
                    TextField("Título breve", text: $title)
                    Text("\(title.count)/\(JournalEntryDraft.maximumTitleLength)")
                        .font(.caption2)
                        .foregroundStyle(PulseStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    DatePicker("Momento", selection: $occurredAt)
                }

                Section("Notas opcionales") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                    Text("\(notes.count)/\(JournalEntryDraft.maximumNotesLength)")
                        .font(.caption2)
                        .foregroundStyle(PulseStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text("Las asociaciones futuras serán exploratorias y nunca se presentarán como causalidad.")
                        .font(.footnote)
                        .foregroundStyle(PulseStyle.secondary)
                }
            }
            .disabled(isSaving)
            .scrollContentBackground(.hidden)
            .background { PulseBackdrop() }
            .navigationTitle(entry == nil ? "Nuevo registro" : "Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Guardando…" : "Guardar") { Task { await save() } }
                        .disabled(trimmedTitle.isEmpty || isSaving)
                }
            }
            .onChange(of: title) { _, value in
                if value.count > JournalEntryDraft.maximumTitleLength {
                    title = String(value.prefix(JournalEntryDraft.maximumTitleLength))
                }
            }
            .onChange(of: notes) { _, value in
                if value.count > JournalEntryDraft.maximumNotesLength {
                    notes = String(value.prefix(JournalEntryDraft.maximumNotesLength))
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        guard !isSaving else { return }
        validationMessage = nil
        do {
            let draft = try JournalEntryDraft(
                category: category,
                title: title,
                notes: notes,
                occurredAt: occurredAt,
                timeZoneIdentifier: entry?.timeZoneIdentifier ?? TimeZone.current.identifier
            )
            isSaving = true
            defer { isSaving = false }
            if await onSave(draft) {
                dismiss()
            } else {
                validationMessage = "No se pudo guardar. Conservamos lo que escribiste; vuelve a intentarlo o recarga el Diario si el registro cambió."
            }
        } catch {
            validationMessage = "Revisa el título, las notas y la fecha antes de guardar."
        }
    }
}

private extension JournalCategory {
    var localizedName: String {
        switch self {
        case .habit: "Hábito"
        case .symptom: "Síntoma"
        case .event: "Evento"
        }
    }

    var symbol: String {
        switch self {
        case .habit: "leaf"
        case .symptom: "cross.case"
        case .event: "calendar"
        }
    }
}

private extension JournalProvenance {
    var localizedName: String {
        switch self {
        case .userEntered: "Registrado por ti"
        case .importedCSV: "Importado desde CSV"
        }
    }
}
