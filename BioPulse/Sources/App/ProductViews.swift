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



// MARK: - Monthly Wrapped
import BioPulseDomain
import Charts
import SwiftUI

private extension WrappedMetric {
    var accent: Color {
        switch self {
        case .sleep: Color(red: 0.72, green: 0.64, blue: 0.93)
        case .steps: Color(red: 0.82, green: 0.93, blue: 0.61)
        case .energy: Color(red: 0.94, green: 0.74, blue: 0.52)
        case .hrv: Color(red: 0.64, green: 0.84, blue: 0.82)
        case .restingHeartRate: Color(red: 0.93, green: 0.64, blue: 0.70)
        }
    }
}

struct WrappedEntryButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.right").font(.title).padding(12).overlay(Circle().stroke(.white.opacity(0.4)))
                VStack(alignment: .leading, spacing: 5) {
                    Text("BIOPULSE WRAPPED").font(.caption2.weight(.medium)).tracking(1.5)
                    Text("Tu mes tiene una historia.").font(.subheadline.weight(.semibold))
                    Text("Recórrela, explórala y hazla tuya.").font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
            }
            .foregroundStyle(.white).padding(16)
            .background(LinearGradient(colors: [Color(red: 0.15, green: 0.22, blue: 0.17), PulseStyle.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.15)))
        }.buttonStyle(PulsePressButtonStyle())
    }
}

@MainActor
struct WrappedView: View {
    @ObservedObject var health: HealthDataController
    @ObservedObject var personal: PersonalContextStore
    @ObservedObject var journal: JournalController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var page = 0
    @State private var activity: WrappedMetric = .steps
    @State private var signal: WrappedMetric = .hrv
    @State private var contextIndex = 0
    @State private var selectedShare: Set<WrappedMetric> = [.sleep, .steps]
    @State private var shareImage: Image?
    private let chapters = ["Tu mes", "Panorama", "Sueño", "Actividad", "Señales", "Diario", "Compartir"]
    private let accent = Color(red: 0.82, green: 0.93, blue: 0.61)

    private var observations: [WrappedObservation] {
        let mapping: [(HealthMetric, WrappedMetric)] = [(.stepCount, .steps), (.activeEnergyBurned, .energy), (.heartRateVariabilitySDNN, .hrv), (.restingHeartRate, .restingHeartRate)]
        var values = mapping.flatMap { native, wrapped in
            (health.dailyHistory[native] ?? []).map { WrappedObservation(day: $0.day, metric: wrapped, value: $0.value, source: $0.sourceName) }
        }
        values += health.sleepScoreData(using: personal).values.filter { $0.metric == .sleepDuration }.map {
            WrappedObservation(day: $0.day, metric: .sleep, value: $0.value, source: $0.source == .selfReported ? "Registro manual" : health.isCSVImported ? "CSV local" : "Apple Salud")
        }
        return values
    }
    private var includedEntries: [JournalEntry] { health.isCSVImported ? [] : journal.entries }
    private var contextMoments: [WrappedMoment] {
        guard !health.isCSVImported else { return [] }
        return personal.annotations.map { WrappedMoment(id: "annotation-\($0.id)", title: $0.title, notes: $0.note, occurredAt: $0.occurredAt) }
            + personal.checkIns.map { WrappedMoment(id: "checkin-\($0.id)", title: "Energía: \($0.energy.title)", notes: $0.note, occurredAt: $0.recordedAt) }
    }
    private var months: [Date] {
        let calendar = Calendar.current
        return Set(([Date.now] + observations.map(\.day) + includedEntries.map(\.occurredAt) + contextMoments.map(\.occurredAt)).filter { $0 <= .now }.compactMap { calendar.dateInterval(of: .month, for: $0)?.start }).sorted(by: >)
    }
    private var summary: MonthlyWrapped { MonthlyWrapped(month: month, observations: observations, entries: includedEntries, additionalContext: contextMoments) }
    private var source: String { health.isCSVImported ? "CSV local · Diario de la cuenta excluido" : "Apple Salud y registros personales" }

    var body: some View {
        let snapshot = summary
        VStack(spacing: 0) {
            HStack {
                Text("BIOPULSE WRAPPED").font(.caption.weight(.medium)).tracking(2)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44).background(.white.opacity(0.05), in: Circle()) }
                    .accessibilityLabel("Cerrar Wrapped").buttonStyle(PulsePressButtonStyle())
            }.padding(.horizontal, 22).padding(.top, 8)
            HStack {
                Picker("Archivo mensual", selection: $month) {
                    ForEach(months, id: \.self) { value in Text(value.formatted(.dateTime.month(.wide).year())).tag(value) }
                }.tint(.white)
                Spacer(minLength: 4)
                Text(snapshot.isPartial ? "MES EN CURSO" : "TU HISTORIAL").font(.caption2).foregroundStyle(accent)
            }.padding(.horizontal, 16)
            HStack(spacing: 5) {
                ForEach(0..<7) { index in
                    Button { move(to: index) } label: {
                        Capsule().fill(index == page ? accent : .white.opacity(0.18)).frame(height: 3).frame(maxWidth: .infinity).frame(minHeight: 30)
                    }.accessibilityLabel("\(index + 1). \(chapters[index])").accessibilityAddTraits(index == page ? .isSelected : [])
                }
            }.padding(.horizontal, 22)
            TabView(selection: $page) {
                scene(index: 0, kicker: "UNA NUEVA PERSPECTIVA", title: "Tu \(month.formatted(.dateTime.month(.wide))).", italic: "En BioPulse.") {
                    ZStack {
                        OrganicScoreRing(score: nil).frame(height: 200)
                        Image(systemName: "arrow.up.right").font(.system(size: 74, weight: .ultraLight)).foregroundStyle(accent)
                    }.accessibilityHidden(true)
                    Text("Pequeñas señales. Un mes entero de historias.").foregroundStyle(PulseStyle.secondary)
                    Text("\(snapshot.recordedDays)").font(.system(.largeTitle, design: .rounded, weight: .regular)).contentTransition(.numericText())
                    Text("días con registros").font(.caption).foregroundStyle(PulseStyle.secondary)
                    Button { move(to: 1) } label: { Label("Explorar mi mes", systemImage: "arrow.right") }.buttonStyle(PulseActionButtonStyle())
                    Text(snapshot.isPartial ? "Un vistazo al mes hasta hoy." : "Vuelve a las señales y momentos del mes.").font(.caption).foregroundStyle(PulseStyle.secondary)
                }.tag(0)
                scene(index: 1, kicker: "LA VISTA COMPLETA", title: "Un mes.", italic: "Muchas señales.") {
                    ForEach(WrappedMetric.allCases) { kind in
                        Button {
                            if kind == .energy { activity = kind }; if kind == .restingHeartRate { signal = kind }
                            move(to: kind == .sleep ? 2 : (kind == .steps || kind == .energy) ? 3 : 4)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(kind.title).font(.caption).foregroundStyle(PulseStyle.secondary)
                                    Text(kind.formatted(snapshot.statistics(kind).mean)).font(.title3.weight(.medium)).foregroundStyle(kind.accent)
                                    Text("\(snapshot.statistics(kind).count) días · media registrada").font(.caption2).foregroundStyle(PulseStyle.secondary)
                                }; Spacer(); Image(systemName: "arrow.up.right")
                            }.padding(.vertical, 10).overlay(alignment: .bottom) { Divider().overlay(.white.opacity(0.12)) }
                        }.buttonStyle(PulsePressButtonStyle())
                    }
                    Text("\(snapshot.moments.count) entradas de Diario acompañaron este mes.").font(.caption)
                    Text(source).font(.caption2).foregroundStyle(PulseStyle.secondary)
                }.tag(1)
                scene(index: 2, kicker: "TUS NOCHES", title: "El ritmo", italic: "del descanso.") {
                    WrappedMetricScene(metric: .sleep, summary: snapshot, previous: previousSummary)
                }.tag(2)
                scene(index: 3, kicker: "EN MOVIMIENTO", title: "Cada día", italic: "suma su parte.") {
                    Picker("Actividad", selection: $activity) { Text("Pasos").tag(WrappedMetric.steps); Text("Energía activa").tag(WrappedMetric.energy) }.pickerStyle(.segmented)
                    WrappedMetricScene(metric: activity, summary: snapshot, previous: previousSummary).id("\(month)-\(activity)")
                }.tag(3)
                scene(index: 4, kicker: "TU PROPIO PATRÓN", title: "Escucha", italic: "tus señales.") {
                    Picker("Señal", selection: $signal) { Text("HRV").tag(WrappedMetric.hrv); Text("FC en reposo").tag(WrappedMetric.restingHeartRate) }.pickerStyle(.segmented)
                    WrappedMetricScene(metric: signal, summary: snapshot, previous: previousSummary).id("\(month)-\(signal)")
                }.tag(4)
                scene(index: 5, kicker: "LO QUE VIVISTE", title: "Los números", italic: "tienen contexto.") {
                    context(snapshot)
                }.tag(5)
                scene(index: 6, kicker: "TU MES, CONTIGO", title: "Hazlo tuyo.", italic: "Compártelo a tu manera.") {
                    WrappedShareCard(summary: snapshot, metrics: WrappedMetric.allCases.filter { selectedShare.contains($0) }, source: source)
                    ForEach(WrappedMetric.allCases) { kind in
                        Toggle(kind.title, isOn: Binding(get: { selectedShare.contains(kind) }, set: { enabled in
                            if enabled { selectedShare.insert(kind) } else { selectedShare.remove(kind) }; shareImage = nil
                        })).tint(accent)
                    }
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Mi mes en BioPulse", image: shareImage)) { Label("Compartir imagen", systemImage: "square.and.arrow.up") }.buttonStyle(PulseActionButtonStyle())
                    } else {
                        Button { renderShare(snapshot) } label: { Label("Crear imagen", systemImage: "photo") }.buttonStyle(PulseActionButtonStyle()).disabled(selectedShare.isEmpty)
                    }
                    Text("Revisa la vista previa. Las notas del Diario no se incluyen.").font(.caption).foregroundStyle(PulseStyle.secondary)
                }.tag(6)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            HStack {
                Button { move(to: page - 1) } label: { Image(systemName: "arrow.left").frame(width: 44, height: 44) }.disabled(page == 0).accessibilityLabel("Escena anterior")
                Spacer(); Text("\(page + 1) / 7 · \(chapters[page])").font(.caption).foregroundStyle(PulseStyle.secondary); Spacer()
                Button { if page == 6 { dismiss() } else { move(to: page + 1) } } label: { Image(systemName: page == 6 ? "checkmark" : "arrow.right").frame(width: 44, height: 44) }.accessibilityLabel(page == 6 ? "Terminar Wrapped" : "Siguiente escena")
            }.buttonStyle(PulsePressButtonStyle()).padding(.horizontal, 22).padding(.bottom, 8)
        }
        .foregroundStyle(.white).background(Color(red: 0.055, green: 0.085, blue: 0.07)).preferredColorScheme(.dark)
        .task {
            await journal.load()
            if let latest = (observations.map(\.day) + includedEntries.map(\.occurredAt) + contextMoments.map(\.occurredAt)).filter({ $0 <= .now }).max(),
               let latestMonth = Calendar.current.dateInterval(of: .month, for: latest)?.start { month = latestMonth }
        }
        .onChange(of: month) { _, _ in page = 0; contextIndex = 0; shareImage = nil }
        .onChange(of: health.lastUpdated) { _, _ in shareImage = nil }
        .onChange(of: personal.sleepReports) { _, _ in shareImage = nil }
        .sensoryFeedback(.selection, trigger: page)
    }

    private var previousSummary: MonthlyWrapped {
        MonthlyWrapped(month: Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month, observations: observations, entries: includedEntries, additionalContext: contextMoments)
    }
    private func move(to next: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 1)) { page = min(6, max(0, next)) }
    }
    private func scene<Content: View>(index: Int, kicker: String, title: String, italic: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(format: "%02d / %@", index + 1, kicker)).font(.caption2).tracking(1.4).foregroundStyle(PulseStyle.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.largeTitle.weight(.medium))
                    Text(italic).font(.system(.largeTitle, design: .serif).italic()).foregroundStyle(accent)
                }.accessibilityAddTraits(.isHeader)
                content()
            }.frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 26).padding(.vertical, 20)
        }.scrollIndicators(.hidden).environment(\.pulseMotionEnabled, page == index)
    }
    @ViewBuilder private func context(_ snapshot: MonthlyWrapped) -> some View {
        Text("Toca un día para reunir tus señales y tus palabras.").font(.subheadline).foregroundStyle(PulseStyle.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 3)], spacing: 3) {
            ForEach(Array(snapshot.days.enumerated()), id: \.offset) { index, day in
                Button { contextIndex = index } label: {
                    VStack(spacing: 2) {
                        Text("\(index + 1)").font(.caption)
                        Circle().fill(snapshot.moments.contains { Calendar.current.isDate($0.occurredAt, inSameDayAs: day) } ? accent : .clear).frame(width: 4, height: 4)
                    }.frame(maxWidth: .infinity, minHeight: 44).background(contextIndex == index ? .white.opacity(0.18) : .white.opacity(0.04), in: Circle())
                }.buttonStyle(PulsePressButtonStyle()).disabled(day > .now).accessibilityLabel(day.formatted(date: .complete, time: .omitted)).accessibilityAddTraits(contextIndex == index ? .isSelected : [])
            }
        }
        if let day = snapshot.days[safeWrapped: contextIndex] {
            Text(day.formatted(.dateTime.day().month(.wide))).font(.headline)
            ForEach(WrappedMetric.allCases) { kind in
                if let point = snapshot.series(kind).first(where: { $0.day == day }) {
                    HStack { Text(kind.title); Spacer(); Text(kind.formatted(point.value)).foregroundStyle(kind.accent) }.font(.subheadline)
                }
            }
            let entries = snapshot.moments.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: day) }
            if entries.isEmpty { Text("Sin anotaciones de Diario para este día.").font(.caption).foregroundStyle(PulseStyle.secondary) }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 5) { Label(entry.title, systemImage: "pencil").font(.subheadline.weight(.medium)); if !entry.notes.isEmpty { Text(entry.notes).font(.caption).foregroundStyle(PulseStyle.secondary) } }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        Text("Explora coincidencias entre registros; no establecen una causa.").font(.caption2).foregroundStyle(PulseStyle.secondary)
    }
    private func renderShare(_ snapshot: MonthlyWrapped) {
        let renderer = ImageRenderer(content: WrappedShareCard(summary: snapshot, metrics: WrappedMetric.allCases.filter { selectedShare.contains($0) }, source: source).padding(30).frame(width: 540).background(Color(red: 0.055, green: 0.085, blue: 0.07)).environment(\.colorScheme, .dark))
        renderer.scale = 2
        if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }
}

private struct WrappedMetricScene: View {
    let metric: WrappedMetric
    let summary: MonthlyWrapped
    let previous: MonthlyWrapped
    @State private var index = 0.0
    @State private var details = false
    @State private var compare = false
    @State private var chartDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selected: Date { summary.days[min(Int(index), max(0, summary.days.count - 1))] }

    var body: some View {
        let stats = summary.statistics(metric)
        VStack(alignment: .leading, spacing: 16) {
            Text("\(metric.title) / media de días registrados").font(.caption).foregroundStyle(PulseStyle.secondary)
            Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { details.toggle() } } label: {
                VStack(alignment: .leading, spacing: 6) { Text(metric.formatted(stats.mean)).font(.largeTitle.weight(.medium)).foregroundStyle(metric.accent).contentTransition(.numericText()); Text(details ? "Ocultar detalles −" : "Explorar detalles +").font(.caption).foregroundStyle(PulseStyle.secondary) }
            }.buttonStyle(PulsePressButtonStyle())
            Text("\(stats.count) de \(summary.days.count) días con esta señal.").font(.caption).foregroundStyle(PulseStyle.secondary)
            Chart {
                ForEach(summary.series(metric), id: \.day) { point in
                    BarMark(x: .value("Día", point.day, unit: .day), y: .value(metric.title, point.value)).foregroundStyle(metric.accent.opacity(point.day == selected ? 1 : 0.4)).cornerRadius(2)
                }
                RuleMark(x: .value("Seleccionado", selected)).foregroundStyle(.white.opacity(0.45)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            .chartXScale(domain: summary.month...(Calendar.current.date(byAdding: .month, value: 1, to: summary.month) ?? summary.month))
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day()) } }
            .chartYAxis(.hidden).pulseChartReveal().frame(height: 150).chartXSelection(value: $chartDate)
            .onChange(of: chartDate) { _, value in if let value, let next = summary.days.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: value) }) { index = Double(next) } }
            Slider(value: $index, in: 0...Double(max(1, summary.days.count - 1)), step: 1) { Text("Recorre los días") }.tint(metric.accent).accessibilityValue(selected.formatted(.dateTime.day().month()))
            HStack { Text(selected.formatted(.dateTime.day().month())).font(.caption); Spacer(); Text(metric.formatted(summary.series(metric).first { $0.day == selected }?.value)).font(.title3).foregroundStyle(metric.accent).contentTransition(.numericText()) }
            Text(summary.series(metric).first { $0.day == selected }?.source ?? "Este día no tiene registros de esta señal.").font(.caption2).foregroundStyle(PulseStyle.secondary)
            ForEach(summary.moments.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: selected) }) { entry in Label(entry.title, systemImage: "pencil").font(.caption) }
            if details {
                VStack(alignment: .leading, spacing: 10) {
                    fact("Mínimo", stats.minimum); fact("Máximo", stats.maximum)
                    if metric == .sleep || metric == .steps || metric == .energy { fact("Total registrado", stats.total) }
                    Divider()
                    ForEach(0..<5) { week in
                        let points = summary.series(metric).filter { (Calendar.current.component(.day, from: $0.day) - 1) / 7 == week }
                        if !points.isEmpty {
                            Button { if let first = points.first, let next = summary.days.firstIndex(of: first.day) { index = Double(next) } } label: {
                                HStack { Text("Días \(week * 7 + 1)–\(min((week + 1) * 7, summary.days.count))"); Spacer(); Text(metric.formatted(points.map(\.value).reduce(0, +) / Double(points.count))) }.font(.caption)
                            }.buttonStyle(PulsePressButtonStyle()).frame(minHeight: 44)
                        }
                    }
                }.padding(14).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12)).transition(.opacity)
            }
            Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { compare.toggle() } } label: { Text(compare ? "Ocultar comparación" : "Comparar con el mes anterior").font(.subheadline).underline() }.buttonStyle(PulsePressButtonStyle())
            if compare {
                let other = previous.statistics(metric)
                VStack(alignment: .leading, spacing: 8) {
                    Text(previous.month.formatted(.dateTime.month(.wide).year())).font(.caption)
                    Text(metric.formatted(other.mean)).font(.title2).foregroundStyle(metric.accent)
                    Text("\(other.count) días registrados").font(.caption)
                    if let current = stats.mean, let old = other.mean { Text("Diferencia media: \(current >= old ? "+" : "−")\(metric.formatted(abs(current - old)))").font(.subheadline) }
                    Text("Se comparan medias de los días disponibles; la cobertura puede ser diferente.").font(.caption2).foregroundStyle(PulseStyle.secondary)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12)).transition(.opacity)
            }
        }
    }
    private func fact(_ title: String, _ value: Double?) -> some View { HStack { Text(title); Spacer(); Text(metric.formatted(value)) }.font(.caption) }
}

private struct WrappedShareCard: View {
    let summary: MonthlyWrapped
    let metrics: [WrappedMetric]
    let source: String
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("BIOPULSE / WRAPPED").font(.caption).tracking(2)
            Text(summary.month.formatted(.dateTime.month(.wide).year())).font(.system(.title, design: .serif).italic())
            Text("\(summary.recordedDays) días con registros\(summary.isPartial ? " · mes en curso" : "")").font(.caption)
            ForEach(metrics) { metric in VStack(alignment: .leading, spacing: 6) { Text(metric.title).font(.caption).foregroundStyle(metric.accent); Text(metric.formatted(summary.statistics(metric).mean)).font(.title.weight(.medium)) } }
            Text("Medias de días registrados · \(source)").font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text("Mi mes, en perspectiva.").font(.caption)
        }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(24).background(LinearGradient(colors: [Color(red: 0.14, green: 0.23, blue: 0.17), Color(red: 0.08, green: 0.13, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
    }
}

private extension Array {
    subscript(safeWrapped index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
