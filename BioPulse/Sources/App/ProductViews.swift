import BioPulseDomain
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
    @ObservedObject var health: HealthDataController
    @ObservedObject var journal: JournalController
    @ObservedObject var personal: PersonalContextStore

    private let metrics: [HealthMetric] = [
        .sleepAnalysis, .stepCount, .heartRateVariabilitySDNN,
        .restingHeartRate, .appleExerciseTime
    ]

    var body: some View {
        ScreenShell(title: "Resumen semanal", subtitle: "Cambios, cobertura y contexto") {
            StatusPanel(
                symbol: "calendar.badge.clock",
                title: "Últimos 7 días completos",
                message: "Cada señal resume solo los días con registros. Se necesitan al menos 4 días de 7 para mostrar un promedio; los días ausentes no se rellenan."
            )
            ForEach(metrics) { metric in weeklyMetricRow(metric) }

            SectionHeading(title: "Contexto de la semana", subtitle: "Registros y autoinformes, separados de HealthKit")
            if weeklyContext.isEmpty {
                StatusPanel(
                    symbol: "square.and.pencil",
                    title: "No hay contexto registrado en este periodo",
                    message: "Si quieres, añade una nota al Diario, una anotación o un check-in. No es necesario registrar algo cada día."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(weeklyContext.prefix(12).enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: item.symbol).foregroundStyle(PulseStyle.mint).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.title).font(.subheadline.weight(.medium))
                                    Spacer(minLength: 8)
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundStyle(PulseStyle.muted)
                                }
                                if !item.detail.isEmpty {
                                    Text(item.detail).font(.caption).foregroundStyle(PulseStyle.secondary)
                                }
                                Text(item.provenance).font(.caption2).foregroundStyle(PulseStyle.muted)
                            }
                        }
                        .padding(.vertical, 13)
                        if index < min(weeklyContext.count, 12) - 1 {
                            Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.leading, 35)
                        }
                    }
                }
                .padding(.horizontal, 15).pulseSurface()
                if weeklyContext.count > 12 {
                    Text("Se muestran 12 registros. El Diario conserva el historial completo en este dispositivo.")
                        .font(.caption).foregroundStyle(PulseStyle.muted)
                }
            }

            StatusPanel(
                symbol: "checkmark.shield",
                title: "Sin conclusiones automáticas",
                message: "Las variaciones y los registros se presentan lado a lado. Una coincidencia semanal no demuestra causalidad ni constituye un diagnóstico."
            )
        }
        .task { await journal.load() }
        .refreshable {
            await health.reload()
            await journal.load(force: true)
        }
    }

    private func weeklyMetricRow(_ metric: HealthMetric) -> some View {
        let observations = weeklyObservations(for: metric)
        let count = observations.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: metric.symbol).foregroundStyle(metric == .sleepAnalysis ? PulseStyle.lavender : PulseStyle.mint)
                Text(metric.displayName).font(.subheadline.weight(.semibold))
                Spacer(minLength: 6)
                Text("Apple Salud").font(.caption2).foregroundStyle(PulseStyle.muted)
            }
            if count >= 4 {
                let average = observations.map(\.value).reduce(0, +) / Double(count)
                let reading = HealthReading(value: average, measuredAt: weekEnd, sourceName: "Apple Salud · media de agregados diarios")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metric.formattedValue(reading)).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Text("promedio diario del periodo").font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                Text("Cobertura: \(count)/7 días con registro")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
            } else {
                Label("No se calcula: faltan registros suficientes", systemImage: "circle.dashed")
                    .font(.caption.weight(.medium)).foregroundStyle(PulseStyle.secondary)
                Text("Cobertura: \(count)/7 días · mínimo 4/7. Revisa permisos o disponibilidad en Apple Salud.")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
            }
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading).pulseSurface()
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var weekStart: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
    }

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .second, value: -1, to: today) ?? today
    }

    private func weeklyObservations(for metric: HealthMetric) -> [DailyHealthObservation] {
        (health.dailyHistory[metric] ?? []).filter { $0.day >= weekStart && $0.day < today }
    }

    private var weeklyContext: [WeeklyContextItem] {
        let notes = journal.entries
            .filter { $0.occurredAt >= weekStart && $0.occurredAt < today }
            .map {
                WeeklyContextItem(
                    id: $0.id,
                    date: $0.occurredAt,
                    title: $0.title,
                    detail: $0.notes,
                    symbol: journalSymbol(for: $0.category),
                    provenance: $0.provenance == .importedCSV ? "Importado desde CSV" : "Registrado por ti"
                )
            }
        let annotations = personal.annotations
            .filter { $0.occurredAt >= weekStart && $0.occurredAt < today }
            .map {
                WeeklyContextItem(
                    id: $0.id,
                    date: $0.occurredAt,
                    title: $0.title,
                    detail: $0.note.isEmpty ? $0.kind.title : $0.note,
                    symbol: $0.kind.symbol,
                    provenance: "Anotación tuya"
                )
            }
        let checkIns = personal.checkIns
            .filter { $0.recordedAt >= weekStart && $0.recordedAt < today }
            .map {
                WeeklyContextItem(
                    id: $0.id,
                    date: $0.recordedAt,
                    title: "Check-in: \($0.energy.title)",
                    detail: $0.note,
                    symbol: $0.energy.symbol,
                    provenance: "Autoinforme · registrado por ti"
                )
            }
        return (notes + annotations + checkIns).sorted { $0.date > $1.date }
    }

    private func journalSymbol(for category: JournalCategory) -> String {
        switch category {
        case .habit: "leaf"
        case .symptom: "cross.case"
        case .event: "calendar"
        }
    }
}

private struct WeeklyContextItem: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let symbol: String
    let provenance: String
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

