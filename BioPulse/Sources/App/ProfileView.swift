import BioPulseDomain
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var health: HealthDataController
    @ObservedObject var auth: AuthSessionStore
    @ObservedObject var personal: PersonalContextStore
    @State private var showingImporter = false
    @State private var importResult: CSVImportResult?
    @State private var importError: String?
    @State private var isImportingCSV = false
    @State private var signOutError: String?
    @State private var isSigningOut = false
    @State private var showingAccountDeletion = false
    @State private var deletionConfirmation = ""
    @State private var isDeletingAccount = false
    @State private var deletionError: String?

    var body: some View {
        ScreenShell(title: "Perfil", subtitle: "Tu cuenta, tus datos y tus decisiones") {
            DashboardCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .font(.title2.weight(.light)).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.session?.user.email ?? "Cuenta BioPulse")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        Text("Sesión activa · Tu Diario local está aislado por cuenta")
                            .font(.caption).foregroundStyle(PulseStyle.secondary)
                    }
                }
            }
            SectionHeading(title: "Apple Salud", subtitle: "La fuente principal de BioPulse")
            StatusPanel(
                symbol: "heart.text.square",
                title: health.isAvailable ? "Disponible en este iPhone" : "No disponible en este dispositivo",
                message: health.hasRequestedAccess
                    ? "La solicitud de acceso se realizó. Apple mantiene privada la decisión de lectura; solo las muestras recibidas aparecen como medidas."
                    : "Elige qué categorías permitir. Puedes cambiarlas después en Ajustes o Apple Salud."
            )
            let actionLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            actionLayout {
                if health.hasRequestedAccess {
                    Button("Abrir Ajustes") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(PulseActionButtonStyle())
                    .accessibilityLabel("Abrir Ajustes de BioPulse")
                }
                Button(
                    health.isCSVImported
                        ? (health.hasRequestedAccess ? "Sincronizar Apple Salud" : "Conectar Apple Salud")
                        : (health.hasRequestedAccess ? "Actualizar mediciones" : "Solicitar acceso a Apple Salud")
                ) {
                    Task {
                        if health.hasRequestedAccess {
                            await health.reload()
                        } else {
                            await health.requestAccess()
                        }
                    }
                }
                .buttonStyle(PulseSecondaryButtonStyle())
                .disabled(!health.isAvailable || health.isLoading)
            }
            if health.isCSVImported {
                if health.isLoading {
                    ProgressView("Consultando Apple Salud…")
                        .font(.footnote).tint(PulseStyle.mint)
                } else if let healthKitSyncError = health.healthKitSyncError {
                    StatusPanel(symbol: "exclamationmark.triangle", title: "Consulta parcial de Apple Salud", message: healthKitSyncError)
                } else if let healthKitLastUpdated = health.healthKitLastUpdated {
                    StatusPanel(
                        symbol: "checkmark.circle",
                        title: "Apple Salud sincronizado",
                        message: "Consulta completada · \(healthKitLastUpdated.formatted(date: .abbreviated, time: .shortened)). El CSV sigue visible y ambas fuentes permanecen separadas."
                    )
                } else {
                    Text("Puedes consultar Apple Salud sin quitar el CSV. Las fuentes se mantienen separadas.")
                        .font(.footnote).foregroundStyle(PulseStyle.secondary)
                }
            }

            SectionHeading(title: "CSV", subtitle: "Revisa un archivo antes de incorporarlo")
            StatusPanel(
                symbol: "doc.text.magnifyingglass",
                title: health.hasCSVData ? (health.isCSVImported ? "CSV activo en esta sesión" : "CSV cargado en esta sesión") : "Importación privada en este iPhone",
                message: health.hasCSVData
                    ? "Las señales del archivo se conservan en memoria hasta cerrar la app. Puedes alternar entre el CSV y Apple Salud; las fuentes no se mezclan ni se envían a servicios externos."
                    : "Carga un CSV de Apple Salud para ver tendencias. El archivo se procesa en el iPhone; no se sube ni se escribe en Apple Salud."
            )
            Button(isImportingCSV ? "Procesando CSV…" : "Revisar archivo CSV") { showingImporter = true }
                .buttonStyle(PulseSecondaryButtonStyle())
                .disabled(isImportingCSV)
            if isImportingCSV {
                ProgressView("Leyendo muestras en este iPhone…")
                    .font(.footnote).tint(PulseStyle.mint)
            }

            if let result = importResult {
                StatusPanel(
                    symbol: "checkmark.doc",
                    title: "Archivo revisado",
                    message: "\(result.records.count) muestras compatibles · \(result.rejectedRows.count) filas rechazadas · \(result.warnings.count) advertencias. Se mostrarán como agregados por día. \(result.warnings.last?.message ?? "")"
                )
                if !result.records.isEmpty {
                    Button("Usar estos datos en BioPulse") {
                        if !health.useCSV(result) { importError = "El archivo no contiene señales compatibles para mostrar." }
                    }
                    .buttonStyle(PulseActionButtonStyle())
                }
            }
            if health.hasCSVData {
                Button(health.isCSVImported ? "Ver datos de Apple Salud" : "Volver a mostrar el CSV") {
                    if health.isCSVImported {
                        Task { await health.showHealthKitData() }
                    } else {
                        health.showCSVData()
                    }
                }
                .buttonStyle(PulseSecondaryButtonStyle())
                .disabled(!health.isAvailable || health.isLoading)

                Button("Quitar CSV", role: .destructive) {
                    health.clearCSV()
                    importResult = nil
                }
                .buttonStyle(PulseSecondaryButtonStyle())
            }
            if let importError {
                StatusPanel(symbol: "exclamationmark.triangle", title: "No se pudo leer el CSV", message: importError)
            }

            SectionHeading(title: "Tu cuenta", subtitle: "Requerida para usar BioPulse")
            Text("Iniciar sesión no activa la sincronización de tus datos de salud.")
                .font(.footnote).foregroundStyle(PulseStyle.secondary)
            if let signOutError {
                Text(signOutError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            Button(role: .destructive) {
                Task { await signOut() }
            } label: {
                HStack(spacing: 10) {
                    if isSigningOut { ProgressView().tint(.red) }
                    Text("Cerrar sesión")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PulseSecondaryButtonStyle())
            .disabled(isSigningOut)

            if let deletionError {
                Text(deletionError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button("Eliminar mi cuenta BioPulse", role: .destructive) {
                deletionConfirmation = ""
                deletionError = nil
                showingAccountDeletion = true
            }
            .buttonStyle(PulseSecondaryButtonStyle())

            SectionHeading(title: "Privacidad", subtitle: "Diseñada para mantener tus datos cerca")
            StatusPanel(
                symbol: "arrow.triangle.2.circlepath",
                title: "Sincronización con BioPulse web pendiente",
                message: "La consulta de Apple Salud actualiza los datos en este iPhone. Iniciar sesión no los sube a BioPulse web ni sincroniza el Diario."
            )
            Text("Las consultas de Apple Salud y la revisión del CSV se realizan en este dispositivo. Si autorizas al Coach, se enviarán métricas agregadas y contexto reciente para responder tus preguntas; no las muestras originales de HealthKit.")
                .font(.subheadline)
                .foregroundStyle(PulseStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)

            FeatureDestinationLink(
                symbol: "lock.shield",
                title: "Centro de privacidad y permisos",
                subtitle: "Datos locales, contexto del Coach y permisos"
            ) {
                PrivacyCenterView()
            }

            SectionHeading(title: "Tu experiencia", subtitle: "Enfoque, recordatorios y nivel de detalle")
            FeatureDestinationLink(
                symbol: "slider.horizontal.3",
                title: "Personalizar BioPulse",
                subtitle: "Objetivo flexible, rituales y horarios silenciosos"
            ) {
                PersonalizationSettingsView(personal: personal)
            }
            FeatureDestinationLink(
                symbol: "chart.xyaxis.line",
                title: "Vista técnica",
                subtitle: "Métodos, cobertura y límites de las mediciones"
            ) {
                TechnicalView()
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url):
                isImportingCSV = true
                Task {
                    let timeZone = TimeZone.current
                    do {
                        let parsed = try await Task.detached(priority: .userInitiated) { () throws -> CSVImportResult in
                            let permitted = url.startAccessingSecurityScopedResource()
                            defer { if permitted { url.stopAccessingSecurityScopedResource() } }
                            let content = try String(contentsOf: url, encoding: .utf8)
                            return try CSVImporter.import(content, timeZone: timeZone)
                        }.value
                        importResult = parsed
                        importError = nil
                    } catch {
                        importResult = nil
                        importError = "Comprueba que el archivo sea UTF-8 y use un encabezado tidy o wide válido."
                    }
                    isImportingCSV = false
                }
            case .failure:
                importError = "No se pudo abrir el archivo seleccionado."
            }
        }
        .sheet(isPresented: $showingAccountDeletion) {
            NavigationStack {
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Eliminar tu cuenta")
                        .font(.title2.bold())
                    Text("Se eliminarán tu acceso y los datos asociados a tu cuenta BioPulse. Las mediciones originales de Apple Salud no se borran. Esta acción no se puede deshacer.")
                        .foregroundStyle(PulseStyle.secondary)
                    TextField("Escribe ELIMINAR", text: $deletionConfirmation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(PulseStyle.elevated, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Escribe ELIMINAR para confirmar")
                    Button(role: .destructive) {
                        Task { await deleteAccount() }
                    } label: {
                        if isDeletingAccount { ProgressView() }
                        else { Text("Eliminar cuenta definitivamente") }
                    }
                    .buttonStyle(PulseActionButtonStyle())
                    .disabled(deletionConfirmation != "ELIMINAR" || isDeletingAccount)
                    if let deletionError {
                        Text(deletionError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
                }
                .background(PulseStyle.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showingAccountDeletion = false }
                            .disabled(isDeletingAccount)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(isDeletingAccount)
        }
    }

    private func signOut() async {
        signOutError = nil
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await auth.signOut()
        } catch {
            signOutError = "No se pudo cerrar la sesión. Comprueba tu conexión e inténtalo otra vez."
        }
    }

    private func deleteAccount() async {
        guard deletionConfirmation == "ELIMINAR", !isDeletingAccount else { return }
        deletionError = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await auth.deleteAccount()
            let localDataRemoved: Bool
            do {
                try personal.deleteLocalAccountData()
                localDataRemoved = true
            } catch {
                localDataRemoved = false
            }
            await auth.finishDeletedAccount(localDataRemoved: localDataRemoved)
            showingAccountDeletion = false
        } catch {
            deletionError = "No pudimos confirmar la eliminación. Comprueba tu conexión y tu cuenta antes de intentarlo otra vez."
        }
    }
}
