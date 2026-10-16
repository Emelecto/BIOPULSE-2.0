import BioPulseDomain
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @ObservedObject var health: HealthDataController
    @ObservedObject var auth: AuthSessionStore
    @ObservedObject var personal: PersonalContextStore
    @State private var showingImporter = false
    @State private var importResult: CSVImportResult?
    @State private var importError: String?
    @State private var signOutError: String?
    @State private var isSigningOut = false

    var body: some View {
        ScreenShell(title: "Perfil", subtitle: "Tu cuenta, tus datos y tus decisiones") {
            DashboardCard {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(auth.session?.user.email ?? "Cuenta BioPulse")
                    .font(.title3.weight(.semibold)).foregroundStyle(.white)
                    .lineLimit(2).textSelection(.enabled)
                Text("Sesión activa · Tu Diario local está aislado por cuenta")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            }
            SectionHeading(title: "Apple Salud", subtitle: "La fuente principal de BioPulse")
            StatusPanel(
                symbol: "heart.text.square",
                title: health.isAvailable ? "Disponible en este iPhone" : "No disponible en este dispositivo",
                message: health.hasRequestedAccess
                    ? "La solicitud de acceso se realizó. Apple mantiene privada la decisión de lectura; solo las muestras recibidas aparecen como medidas."
                    : "Elige qué categorías permitir. Puedes cambiarlas después en Ajustes o Apple Salud."
            )
            if health.hasRequestedAccess {
                Button("Abrir Ajustes de BioPulse") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(PulseActionButtonStyle())
            } else {
                Button("Solicitar acceso") { Task { await health.requestAccess() } }
                    .buttonStyle(PulseActionButtonStyle())
                    .disabled(!health.isAvailable)
            }

            Button("Actualizar mediciones") { Task { await health.reload() } }
                .buttonStyle(PulseSecondaryButtonStyle())
                .disabled(!health.isAvailable || health.isLoading)

            SectionHeading(title: "CSV", subtitle: "Revisa un archivo antes de incorporarlo")
            StatusPanel(
                symbol: "doc.text.magnifyingglass",
                title: "Vista previa local",
                message: "Acepta los formatos tidy y wide documentados. Esta revisión no guarda registros ni reemplaza mediciones de Apple Salud."
            )
            Button("Revisar archivo CSV") { showingImporter = true }
                .buttonStyle(PulseSecondaryButtonStyle())

            if let result = importResult {
                StatusPanel(
                    symbol: "checkmark.doc",
                    title: "Archivo revisado",
                    message: "\(result.records.count) registros válidos · \(result.rejectedRows.count) filas rechazadas · \(result.warnings.count) advertencias. \(result.rejectedRows.first?.reason ?? "Los datos aún no se han guardado.")"
                )
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

            SectionHeading(title: "Privacidad", subtitle: "Diseñada para mantener tus datos cerca")
            StatusPanel(
                symbol: "arrow.triangle.2.circlepath",
                title: "Sincronización iOS pendiente",
                message: "Iniciar sesión no sube tus datos de salud ni tu Diario. La configuración por categoría aún no está disponible en esta app."
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
                let permitted = url.startAccessingSecurityScopedResource()
                defer { if permitted { url.stopAccessingSecurityScopedResource() } }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    importResult = try CSVImporter.import(content, timeZone: .current)
                    importError = nil
                } catch {
                    importResult = nil
                    importError = "Comprueba que el archivo sea UTF-8 y use un encabezado tidy o wide válido."
                }
            case .failure:
                importError = "No se pudo abrir el archivo seleccionado."
            }
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
}
