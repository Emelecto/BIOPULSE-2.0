import SwiftUI

struct BreathingSessionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    var body: some View {
        ScreenShell(title: "Respiración", subtitle: "Una pausa guiada, sin interpretar biometría") {
            TimelineView(.periodic(from: .now, by: startedAt == nil || reduceMotion ? 1 : 1.0 / 30.0)) { context in
                let elapsed = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
                let position = elapsed.truncatingRemainder(dividingBy: 8)
                let inhaling = position < 4
                let progress = inhaling ? position / 4 : (8 - position) / 4

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(PulseStyle.mint.opacity(0.12))
                            .frame(width: 230, height: 230)
                            .scaleEffect(reduceMotion ? 0.9 : 0.72 + (0.24 * progress))
                        Circle()
                            .stroke(PulseStyle.mint.opacity(0.7), lineWidth: 2)
                            .frame(width: 150, height: 150)
                        Text(startedAt == nil ? "Listo" : inhaling ? "Inhala" : "Exhala")
                            .font(.title2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(startedAt == nil ? "Sesión detenida" : inhaling ? "Inhala" : "Exhala")

                    Text("Ritmo inicial: 4 segundos al inhalar y 4 al exhalar. Detén la sesión si sientes incomodidad.")
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .pulseSurface(prominent: true)
            }

            Button(startedAt == nil ? "Comenzar sesión" : "Detener sesión") {
                startedAt = startedAt == nil ? .now : nil
            }
            .buttonStyle(startedAt == nil ? AnyPulseButtonStyle.primary : AnyPulseButtonStyle.secondary)
        }
    }
}

private enum AnyPulseButtonStyle: ButtonStyle {
    case primary
    case secondary

    func makeBody(configuration: Configuration) -> some View {
        BreathingButtonLabel(label: configuration.label, primary: self == .primary, pressed: configuration.isPressed)
    }
}

private struct BreathingButtonLabel: View {
    let label: ButtonStyleConfiguration.Label
    let primary: Bool
    let pressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(primary ? PulseStyle.background : PulseStyle.mint)
            .background(primary ? PulseStyle.mint : PulseStyle.elevated, in: RoundedRectangle(cornerRadius: 14))
            .opacity(pressed ? 0.8 : 1)
            .scaleEffect(pressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1), value: pressed)
    }
}

struct EnergyMapView: View {
    var body: some View {
        ScreenShell(title: "Mapa de energía", subtitle: "Cómo cambia tu día, con procedencia visible") {
            StatusPanel(
                symbol: "sun.horizon",
                title: "Esperando historial suficiente",
                message: "El mapa se construirá con sueño, actividad y señales observadas. No dibujaremos una curva estimada como si fuera una medición."
            )
            SectionHeading(title: "Entradas previstas", subtitle: "Cada una mostrará cobertura y fuente")
            dataRequirement("Sueño", symbol: "moon.stars")
            dataRequirement("Actividad y entrenamientos", symbol: "figure.run")
            dataRequirement("HRV y frecuencia en reposo", symbol: "waveform.path.ecg")
            dataRequirement("Contexto del diario", symbol: "square.and.pencil")
        }
    }

    private func dataRequirement(_ title: String, symbol: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).foregroundStyle(PulseStyle.mint).frame(width: 25)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text("Pendiente").font(.caption).foregroundStyle(PulseStyle.secondary)
        }
        .padding(16)
        .pulseSurface()
    }
}

struct WeeklySummaryView: View {
    var body: some View {
        ScreenShell(title: "Resumen semanal", subtitle: "Cambios, cobertura y contexto") {
            StatusPanel(
                symbol: "calendar.badge.clock",
                title: "Aún no hay una semana completa",
                message: "El resumen aparecerá cuando exista historial real suficiente. Incluirá cambios, datos ausentes y contexto del diario."
            )
            StatusPanel(
                symbol: "checkmark.shield",
                title: "Sin conclusiones automáticas",
                message: "BioPulse describirá asociaciones y variaciones; no convertirá una coincidencia semanal en causalidad o diagnóstico."
            )
        }
    }
}

struct TechnicalView: View {
    var body: some View {
        ScreenShell(title: "Vista técnica", subtitle: "Métodos, evidencia y limitaciones") {
            StatusPanel(
                symbol: "flask",
                title: "Resultados verificables únicamente",
                message: "Esta vista solo mostrará ejecuciones reproducibles. Las cifras de demostración del proyecto anterior no se tratarán como evidencia."
            )
            SectionHeading(title: "Pipeline", subtitle: "La trazabilidad será parte del producto")
            technicalStep("01", "Dataset y licencia", "Origen, población, periodo y uso permitido")
            technicalStep("02", "Variables y procesamiento", "Unidades, ventanas, faltantes y transformaciones")
            technicalStep("03", "Evaluación", "Separación temporal o por sujeto, baseline y leakage")
            technicalStep("04", "Resultados", "Métricas, intervalos, versión y limitaciones")
        }
    }

    private func technicalStep(_ index: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(index)
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseStyle.mint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(PulseStyle.secondary)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseSurface()
    }
}

struct AccountRoadmapView: View {
    var body: some View {
        ScreenShell(title: "Cuenta", subtitle: "Acceso y sincronización, en una fase posterior") {
            StatusPanel(
                symbol: "person.crop.circle.badge.checkmark",
                title: "Inicia sesión para continuar",
                message: "BioPulse requerirá una cuenta para abrir la app. Estamos preparando el registro con Apple, correo y contraseña, o Google. La sincronización cloud se controlará por separado y requerirá tu consentimiento."
            )
            SectionHeading(title: "Métodos previstos", subtitle: "Ningún proveedor está conectado todavía")
            provider("apple.logo", "Iniciar sesión con Apple")
            provider("envelope", "Correo y contraseña")
            provider("g.circle", "Continuar con Google")
        }
    }

    private func provider(_ symbol: String, _ name: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).foregroundStyle(PulseStyle.mint).frame(width: 28)
            Text(name).font(.headline)
            Spacer()
            Text("Futuro").font(.caption).foregroundStyle(PulseStyle.secondary)
        }
        .padding(17)
        .pulseSurface()
    }
}

struct PrivacyCenterView: View {
    var body: some View {
        ScreenShell(title: "Privacidad", subtitle: "Permisos y control de tus datos") {
            StatusPanel(
                symbol: "iphone.gen3",
                title: "HealthKit permanece local",
                message: "Las muestras originales se consultan en este dispositivo. El Coach recibe métricas agregadas solo cuando lo autorizas."
            )
            StatusPanel(
                symbol: "icloud",
                title: "Sincronización opcional",
                message: "Iniciar sesión no activa la sincronización del Diario ni de tus mediciones. La sincronización general sigue en preparación."
            )
            StatusPanel(
                symbol: "sparkles",
                title: "Coach con autorización",
                message: "Antes del primer envío, eliges si compartes métricas agregadas y contexto reciente con Groq. Puedes borrar la memoria de siete días o revocar el permiso desde el Coach."
            )
        }
    }
}

