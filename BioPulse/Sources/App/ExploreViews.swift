import Charts
import BioPulseDomain
import SwiftUI
import UserNotifications

struct ScoreCalibrationCard: View {
    let values: [WellnessValue]
    let day: Date
    let isBioScore: Bool
    let reason: String

    private var requirements: [ScoreHistoryRequirement] {
        WellnessScores.calibration(values, day: day, includeBiometrics: isBioScore)
    }

    var body: some View {
        DashboardCard {
            Label(requirements.allSatisfy(\.isReady) ? "Tu referencia está lista; falta el día evaluado" : "Tus scores necesitan conocerte", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Text("Es normal ver el anillo sin número al comenzar. La app reúne historial para comparar tus registros contigo mismo. Si Apple Salud ya tiene historial compatible, se aprovecha desde el primer día.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            ForEach(requirements) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title(for: item.metric)).font(.subheadline)
                        Spacer()
                        Text("\(min(item.available, item.required))/\(item.required) \(item.metric == .sleepDuration ? "noches" : "días")")
                            .font(.caption.monospacedDigit())
                    }
                    ProgressView(value: Double(min(item.available, item.required)), total: Double(item.required))
                        .tint(.white)
                    Text("Registros previos dentro de \(item.windowDays) días")
                        .font(.caption2).foregroundStyle(PulseStyle.muted)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Progreso para el \(day.formatted(date: .abbreviated, time: .omitted)). La noche o el día evaluado también debe tener datos y no cuenta como historial previo.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)
            Text(isBioScore ? "Registrar sueño ayuda, pero el BioScore también necesita HRV, pulso en reposo y energía activa de Apple Salud. No exige llevar el reloj todas las noches si registras tu sueño." : "Puedes reunir las noches con Apple Salud o con tus registros manuales. La duración puede mostrarse desde el primer registro; el score espera siete noches previas.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)
            if requirements.allSatisfy(\.isReady) {
                Text(reason).font(.caption).foregroundStyle(PulseStyle.secondary)
            }
            Text("Este proceso construye una referencia personal; no es una calibración médica ni garantiza una fecha si faltan registros.")
                .font(.caption2).foregroundStyle(PulseStyle.muted)
        }
    }

    private func title(for metric: MetricKind) -> String {
        switch metric {
        case .sleepDuration: "Sueño"
        case .heartRateVariabilitySDNN: "HRV"
        case .restingHeartRate: "Pulso en reposo"
        default: "Energía activa"
        }
    }
}

struct SleepCheckInCard: View {
    private struct Night: Identifiable { let id = UUID(); let date: Date }
    @ObservedObject var personal: PersonalContextStore
    @ObservedObject var health: HealthDataController
    var showsHistory: Bool
    @State private var editingNight: Night?

    var body: some View {
        DashboardCard {
            Label("¿Cómo dormiste?", systemImage: "moon.stars")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            if let report = personal.sleepReport() {
                Text("Hoy registraste \(report.durationMinutes / 60) h \(report.durationMinutes % 60) min · descanso \(report.restfulness)/5 · calidad \(report.quality)/5")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            } else {
                Text("No necesitas dormir con el reloj. Estima cuánto dormiste y cómo te sientes al despertar.")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            }
            Button(personal.sleepReport() == nil ? "Registrar mi sueño" : "Editar el sueño de hoy") {
                editingNight = Night(date: .now)
            }
            .buttonStyle(PulseActionButtonStyle())
            Text("Tu registro se guarda en este iPhone para tu cuenta. El Sleep Score usa la fecha al despertar; el BioScore evalúa el último día completo.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)
            if health.isCSVImported {
                Text("Hay un CSV activo. Tus registros se guardan, pero no se mezclan con ese archivo. Cambia a Apple Salud desde Perfil para utilizarlos en tus scores.")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            }
            if showsHistory, !personal.sleepReports.isEmpty {
                DisclosureGroup("Mis registros de sueño (\(personal.sleepReports.count))") {
                    ForEach(personal.sleepReports) { report in
                        Button {
                            editingNight = Night(date: report.date() ?? .now)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text((report.date() ?? report.recordedAt).formatted(date: .abbreviated, time: .omitted))
                                    Text("\(report.durationMinutes / 60) h \(report.durationMinutes % 60) min · descanso \(report.restfulness)/5 · calidad \(report.quality)/5")
                                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil").font(.caption)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.subheadline).tint(.white)
            }
        }
        .sheet(item: $editingNight) { night in
            SleepReportEditor(personal: personal, health: health, date: night.date)
        }
    }
}

struct SleepReminderControls: View {
    @ObservedObject var personal: PersonalContextStore
    @State private var message: String?
    @State private var requestingPermission = false

    var body: some View {
        DashboardCard {
            Toggle("Recordarme registrar mi sueño", isOn: Binding(
                get: { personal.sleepReminder.enabled },
                set: { enabled in
                    Task {
                        requestingPermission = true
                        defer { requestingPermission = false }
                        if enabled {
                            do {
                                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                                guard granted else {
                                    message = "Activa las notificaciones en Ajustes de iOS para recibir este aviso."
                                    return
                                }
                            } catch {
                                message = "No pudimos solicitar permiso. Inténtalo de nuevo."
                                return
                            }
                        }
                        guard personal.updateSleepReminder({ $0.enabled = enabled }) else {
                            message = personal.persistenceMessage
                            return
                        }
                        message = await personal.scheduleSleepReminder()
                    }
                }
            ))
            .font(.subheadline.weight(.semibold)).tint(.white).disabled(requestingPermission)
            if personal.sleepReminder.enabled {
                DatePicker("Hora del recordatorio", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: personal.sleepReminder.hour, minute: personal.sleepReminder.minute, second: 0, of: .now) ?? .now },
                    set: { date in
                        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
                        guard personal.updateSleepReminder({ $0.hour = time.hour ?? 9; $0.minute = time.minute ?? 0 }) else {
                            message = personal.persistenceMessage
                            return
                        }
                        Task { message = await personal.scheduleSleepReminder() }
                    }
                ), displayedComponents: .hourAndMinute)
            }
            DisclosureGroup("Detalles del recordatorio") {
                Text("Opcional · 9:00 a. m. por defecto. Al tocarlo se abre tu registro de sueño. Respeta el horario silencioso de Personalizar; iOS puede silenciar o retrasar el aviso según tus ajustes.")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            }
            .font(.caption).tint(.white).frame(minHeight: 44)
            if let message { Text(message).font(.caption).foregroundStyle(PulseStyle.secondary) }
        }
        .task { message = await personal.scheduleSleepReminder() }
    }
}

struct SleepReportEditor: View {
    @ObservedObject var personal: PersonalContextStore
    @ObservedObject var health: HealthDataController
    @Environment(\.dismiss) private var dismiss
    @State private var wakeDate: Date
    @State private var hours = ""
    @State private var minutes = "0"
    @State private var restfulness = 0
    @State private var quality = 0
    @State private var awakenings = -1
    @State private var factors: Set<SleepFactor> = []
    @State private var note = ""
    @State private var preferManual = false
    @State private var errorMessage: String?
    @State private var confirmingDeletion = false

    init(personal: PersonalContextStore, health: HealthDataController, date: Date = .now) {
        self.personal = personal
        self.health = health
        _wakeDate = State(initialValue: Calendar.current.startOfDay(for: date))
    }

    private var duration: Int? {
        guard let hour = Int(hours), let minute = Int(minutes), (0...24).contains(hour), (0...59).contains(minute),
              hour * 60 + minute <= 1440 else { return nil }
        return hour * 60 + minute
    }
    private var canSave: Bool { duration != nil && (1...5).contains(restfulness) && (1...5).contains(quality) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha al despertar", selection: $wakeDate, in: ...Date.now, displayedComponents: .date)
                    Text("Registra la noche que terminó en esta fecha. Puedes completar o corregir noches anteriores.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                Section("¿Cuánto tiempo crees que dormiste?") {
                    HStack {
                        TextField("Horas", text: $hours).keyboardType(.numberPad).accessibilityLabel("Horas dormidas")
                        Text("h").foregroundStyle(PulseStyle.secondary)
                        TextField("Minutos", text: $minutes).keyboardType(.numberPad).accessibilityLabel("Minutos dormidos")
                        Text("min").foregroundStyle(PulseStyle.secondary)
                    }
                    Text("Estima el tiempo dormido, sin incluir el tiempo despierto en cama. Si no dormiste, puedes registrar 0 horas.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                    if !hours.isEmpty, duration == nil {
                        Text("Escribe horas entre 0 y 24 y minutos entre 0 y 59, sin superar 24 horas en total.")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Tu experiencia") {
                    Picker("Descanso al despertar", selection: $restfulness) {
                        Text("Seleccionar").tag(0)
                        Text("1 · Nada descansado").tag(1)
                        Text("2 · Poco descansado").tag(2)
                        Text("3 · Intermedio").tag(3)
                        Text("4 · Descansado").tag(4)
                        Text("5 · Muy descansado").tag(5)
                    }
                    Picker("Calidad del sueño", selection: $quality) {
                        Text("Seleccionar").tag(0)
                        Text("1 · Muy mala").tag(1)
                        Text("2 · Mala").tag(2)
                        Text("3 · Intermedia").tag(3)
                        Text("4 · Buena").tag(4)
                        Text("5 · Muy buena").tag(5)
                    }
                    Picker("Despertares (opcional)", selection: $awakenings) {
                        Text("Sin responder").tag(-1)
                        Text("Ninguno").tag(0)
                        Text("Uno").tag(1)
                        Text("Dos").tag(2)
                        Text("Tres o más").tag(3)
                    }
                    DisclosureGroup("¿Algo afectó tu descanso? (opcional)") {
                        ForEach(SleepFactor.allCases) { factor in
                            Toggle(factor.title, isOn: Binding(
                                get: { factors.contains(factor) },
                                set: { selected in if selected { factors.insert(factor) } else { factors.remove(factor) } }
                            ))
                        }
                    }
                    TextField("Algo más que quieras recordar (opcional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: note) { _, value in if value.count > 280 { note = String(value.prefix(280)) } }
                }
                Section("Fuente para los scores") {
                    if !health.isCSVImported, let observed = health.dailyHistory[.sleepAnalysis]?.first(where: { Calendar.current.isDate($0.day, inSameDayAs: wakeDate) }) {
                        Text("Apple Salud tiene \(Int(observed.value) / 60) h \(Int(observed.value) % 60) min para esta fecha.")
                            .font(.subheadline)
                    }
                    Toggle("Priorizar mi estimación para esta noche", isOn: $preferManual)
                    Text("Si existe una duración en Apple Salud, se usa esa salvo que elijas tu estimación. Nunca sumamos ambas. Descanso y calidad quedan como contexto, sin cambiar la fórmula.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                    if health.isCSVImported {
                        Text("Con un CSV activo, este registro se conserva para tu cuenta y solo alimenta los scores cuando vuelvas a Apple Salud desde Perfil.")
                            .font(.caption).foregroundStyle(PulseStyle.secondary)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
                }
                if let report = personal.sleepReport(on: wakeDate) {
                    Section {
                        Button("Eliminar registro de esta noche", role: .destructive) { confirmingDeletion = true }
                            .confirmationDialog("¿Eliminar este registro de sueño?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                                Button("Eliminar registro", role: .destructive) {
                                    if personal.deleteSleepReport(report) { dismiss() }
                                    else { errorMessage = personal.persistenceMessage }
                                }
                            }
                    }
                }
                Section {
                    Text("Autorreporte guardado en este iPhone. No se escribe en Apple Salud ni se generan mediciones o etapas. Los scores necesitan historial previo antes de mostrar un número.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseStyle.background)
            .navigationTitle("Mi noche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!canSave) }
            }
            .tint(.white)
            .onAppear(perform: loadReport)
            .onChange(of: wakeDate) { _, _ in loadReport() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadReport() {
        errorMessage = nil
        let report = personal.sleepReport(on: wakeDate)
        hours = report.map { String($0.durationMinutes / 60) } ?? ""
        minutes = report.map { String($0.durationMinutes % 60) } ?? "0"
        restfulness = report?.restfulness ?? 0
        quality = report?.quality ?? 0
        awakenings = report?.awakenings ?? -1
        factors = Set(report?.factors ?? [])
        note = report?.note ?? ""
        preferManual = report?.preferManual ?? false
    }

    private func save() {
        guard let duration else { return }
        do {
            let report = try SleepReport(id: personal.sleepReport(on: wakeDate)?.id ?? UUID(), wakeDate: wakeDate,
                                         durationMinutes: duration, restfulness: restfulness, quality: quality,
                                         awakenings: awakenings < 0 ? nil : awakenings,
                                         factors: Array(factors), note: note, preferManual: preferManual)
            if personal.saveSleepReport(report) { dismiss() }
            else { errorMessage = personal.persistenceMessage ?? "No pudimos guardar esta noche. Inténtalo de nuevo." }
        } catch { errorMessage = error.localizedDescription }
    }
}

struct TrendsView: View {
    var openWrapped: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var health: HealthDataController
    @ObservedObject var journal: JournalController
    @ObservedObject var personal: PersonalContextStore
    @State private var selectedMetric: HealthMetric?
    @State private var chartMetric: HealthMetric = .heartRateVariabilitySDNN
    @State private var periodDays = 7
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 150

    private let metrics: [HealthMetric] = [
        .heartRateVariabilitySDNN, .restingHeartRate, .heartRate,
        .respiratoryRate, .oxygenSaturation, .stepCount,
        .activeEnergyBurned, .appleExerciseTime
    ]

    var body: some View {
        ScreenShell(title: "Tendencias", subtitle: "Cambios observados en tus registros") {
            WrappedEntryButton(action: openWrapped)
            let yesterday = health.isCSVImported ? health.displayedDataDay : (Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now)
            let signal = WellnessScores.change(health.wellnessValues, day: yesterday)
            let anomaly = PersonalAnomalyForest.evaluate(health.personalAnomalyObservations, on: yesterday)
            DashboardCard {
                Text("SEÑAL DE CAMBIO PERSONAL").font(.caption.weight(.semibold)).foregroundStyle(PulseStyle.secondary)
                Text(signal.value.map { $0 == 0 ? "Sin cambio persistente" : "\($0)/100" } ?? "—")
                    .font(.title2.weight(.semibold)).foregroundStyle(.white)
                Text(signal.reason).font(.caption).foregroundStyle(PulseStyle.secondary)
                Text("\(health.isCSVImported ? "Día importado" : "Ayer") · \(signal.version) · magnitud de cambio, no probabilidad de enfermedad")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
                DisclosureGroup("Cómo se interpreta") {
                    Text("Es una regla fija, no ML: compara sueño, HRV y frecuencia en reposo con tu historial. Solo marca un cambio si al menos dos señales se desvían durante dos días seguidos. Un 0 no descarta un problema de salud.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                .font(.caption).tint(.white).frame(minHeight: 44)
            }
            DashboardCard {
                Text("Tu historia, día a día").font(.headline)
                Text(health.isCSVImported ? "Solo se muestran días con muestras compatibles del archivo; los huecos no se rellenan." : "Solo se muestran días con datos de Apple Salud; los huecos no se rellenan.")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
                Picker("Periodo", selection: $periodDays) {
                    Text("7 días").tag(7)
                    Text("30 días").tag(30)
                    Text("90 días").tag(90)
                }
                .pickerStyle(.segmented)
                Picker("Señal", selection: $chartMetric) {
                    Text("HRV").tag(HealthMetric.heartRateVariabilitySDNN)
                    Text("FC reposo").tag(HealthMetric.restingHeartRate)
                    Text("Sueño").tag(HealthMetric.sleepAnalysis)
                    Text("Energía").tag(HealthMetric.activeEnergyBurned)
                }
                .pickerStyle(.menu)
                if chartObservations.isEmpty {
                    DashboardEmptyChart(message: "Aún no hay registros para este periodo")
                        .frame(height: chartHeight)
                } else {
                    Chart(chartObservations) { point in
                        BarMark(x: .value("Día", point.day, unit: .day), y: .value("Valor", point.value))
                            .foregroundStyle(.white)
                            .cornerRadius(2)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    } }
                    .chartYAxis { AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel()
                    } }
                    .frame(height: chartHeight)
                    .pulseChartReveal()
                    .accessibilityLabel("Historial de \(chartMetric.displayName), \(chartObservations.count) días con registros")
                }
                Text(health.isCSVImported ? "Agregados diarios · CSV" : "Agregados reales · Apple Salud")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
            }
            FeatureDestinationLink(
                symbol: "waveform.path.ecg.rectangle",
                title: "¿Qué cambió? y tu contexto",
                subtitle: "Compara periodos reales, añade anotaciones y revisa tu día"
            ) {
                PersonalInsightsView(health: health, journal: journal, personal: personal)
            }
            DashboardCard {
                Text("MODELO ML · ISOLATION FOREST · \(anomaly.version)")
                    .font(.caption.weight(.semibold)).foregroundStyle(PulseStyle.secondary)
                Text(anomaly.value.map { "\($0)/100" } ?? "Datos insuficientes")
                    .font(.headline).foregroundStyle(.white)
                DisclosureGroup("Método y cobertura") {
                    Text(anomaly.reason)
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                    Text("Aprende tu patrón con HRV, pulso en reposo y energía activa. Entrena y analiza en este iPhone; no necesita datos de sueño ni envía mediciones a un modelo remoto.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                .font(.caption).tint(.white).frame(minHeight: 44)
            }
            SectionHeading(title: "Mediciones", subtitle: "Toca una señal para conocerla")
            ForEach(metrics) { metric in
                Button { selectedMetric = metric } label: {
                    MetricListRow(metric: metric, reading: health.readings[metric], showsChevron: true)
                }
                .buttonStyle(.plain)
            }

            SectionHeading(title: "Lecturas amplias", subtitle: "Contexto antes que conclusiones")
            FeatureDestinationLink(
                symbol: "calendar.badge.clock",
                title: "Resumen semanal",
                subtitle: "Cambios, cobertura y registros del diario"
            ) {
                WeeklySummaryView(health: health, journal: journal, personal: personal)
            }
            FeatureDestinationLink(
                symbol: "flask",
                title: "Vista técnica",
                subtitle: "Datasets, métodos, evaluación y limitaciones"
            ) {
                TechnicalView()
            }
        }
        .refreshable { await health.reload() }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: periodDays)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: chartMetric)
        .sheet(item: $selectedMetric) { metric in
            MetricDetailView(metric: metric, reading: health.readings[metric])
                .presentationDetents([.medium, .large])
        }
    }

    private var chartObservations: [DailyHealthObservation] {
        let start = Calendar.current.date(byAdding: .day, value: -periodDays, to: health.displayedDataDay) ?? .distantPast
        return (health.dailyHistory[chartMetric] ?? []).filter { $0.day >= start }
    }
}

struct SleepView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var stageChartHeight: CGFloat = 132
    @ObservedObject var health: HealthDataController
    @ObservedObject var personal: PersonalContextStore

    private var sleepData: ResolvedSleepValues { health.sleepScoreData(using: personal) }
    private var sleepDay: Date {
        sleepData.values.filter { $0.metric == .sleepDuration && $0.day <= .now }.map(\.day).max() ?? health.displayedDataDay
    }
    private var sleepMinutes: Double? {
        sleepData.values.first { $0.metric == .sleepDuration && Calendar.current.isDate($0.day, inSameDayAs: sleepDay) }?.value
    }
    private var isReported: Bool { sleepData.reportedDays.contains(Calendar.current.startOfDay(for: sleepDay)) }
    private var needsHistory: Bool {
        WellnessScores.calibration(sleepData.values, day: sleepDay, includeBiometrics: false).contains { !$0.isReady }
    }
    private var score: WellnessScore {
        WellnessScores.sleep(sleepData.values, day: sleepDay, targetMinutes: personal.sleepTargetMinutes)
    }

    var body: some View {
        ScreenShell(title: "Sueño", subtitle: health.isCSVImported ? "Sueño del archivo importado" : "Con tu reloj o con tu propio registro") {
            DashboardCard {
                let summaryLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
                summaryLayout {
                    PendingScoreHero(title: "Sleep Score", score: score.value.map(Double.init), subtitle: score.value == nil ? (needsHistory ? "Construyendo tu referencia" : "Falta registrar la noche") : "Índice exploratorio")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isReported ? "Duración estimada por ti" : "Tiempo dormido").font(.caption).foregroundStyle(PulseStyle.secondary)
                        Text(sleepMinutes.map { "\(Int($0) / 60) h \(Int($0) % 60) min" } ?? "—")
                            .font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Noche que termina el \(sleepDay.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(PulseStyle.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(score.reason)
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
                if sleepData.includesSelfReport(on: sleepDay) {
                    Label("Incluye sueño reportado por ti", systemImage: "pencil.circle")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
            }
            if score.value == nil {
                DisclosureGroup("Tu referencia de sueño") {
                    ScoreCalibrationCard(values: sleepData.values, day: sleepDay, isBioScore: false, reason: score.reason)
                }
                .font(.subheadline).tint(.white).frame(minHeight: 44)
            }
            SleepCheckInCard(personal: personal, health: health, showsHistory: true)
            SleepReminderControls(personal: personal)
            DashboardCard {
                Text("Meta personal de sueño").font(.headline)
                Picker("Duración objetivo", selection: Binding(
                    get: { personal.sleepTargetMinutes },
                    set: { personal.updateSleepTarget($0) }
                )) {
                    ForEach(Array(stride(from: 360, through: 600, by: 30)), id: \.self) { minutes in
                        Text("\(Double(minutes) / 60, specifier: "%.1f") horas").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                Text("Se guarda en este iPhone para tu cuenta. La fórmula usa duración y constancia.")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            }
            DashboardCard {
                DisclosureGroup("Qué resume este índice") {
                    Text("Combina duración de sueño (65 %) y cercanía a tu duración habitual (35 %). Necesita la noche evaluada y siete noches previas dentro de 14 días. No analiza etapas, calidad percibida ni es un modelo de aprendizaje automático.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                .font(.subheadline).tint(.white).frame(minHeight: 44)
            }
            DashboardCard {
                Text("Etapas disponibles en Apple Salud").font(.headline)
                if isReported {
                    Text("Mediciones del dispositivo, separadas de tu estimación. Registrar duración no genera etapas.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                if health.sleepStages.isEmpty {
                    DashboardEmptyChart(message: health.isCSVImported ? "El CSV cargado no incluye etapas de sueño." : "Sin etapas de sueño registradas por un dispositivo compatible")
                        .frame(height: stageChartHeight)
                } else {
                    Chart(health.sleepStages) { interval in
                        BarMark(
                            xStart: .value("Inicio", interval.start),
                            xEnd: .value("Fin", interval.end),
                            y: .value("Etapa", interval.stage.title)
                        )
                        .foregroundStyle(stageColor(interval.stage))
                        .cornerRadius(2)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    } }
                    .frame(height: stageChartHeight)
                    .accessibilityLabel("Etapas de sueño registradas en Apple Salud")
                    Text("\(health.sleepStages.count) intervalos registrados · Apple Salud")
                        .font(.caption2).foregroundStyle(PulseStyle.muted)
                }
            }
            if isReported {
                StatusPanel(symbol: "pencil.circle", title: "Sueño reportado por ti", message: "La duración es tu estimación para esa noche. Descanso, calidad, despertares y factores quedan como contexto; no modifican los pesos del score ni generan etapas de sueño.")
            } else if let reading = health.readings[.sleepAnalysis] {
                DataProvenance(reading: reading)
                StatusPanel(symbol: "info.circle", title: "Qué incluye este tiempo", message: "Suma los intervalos marcados como sueño, sin contar superposiciones dos veces. No incluye el tiempo simplemente en cama.")
            } else {
                StatusPanel(symbol: "moon.zzz", title: "Aún no hay una noche registrada", message: health.isCSVImported ? "Si el archivo no incluye sueño, vuelve a Apple Salud desde Perfil para utilizar tus registros manuales." : "Puedes registrar tu sueño sin llevar el reloj o compartir las mediciones de Apple Salud. No rellenamos noches ausentes.")
            }
            Text("Fórmula \(score.version) · parámetros exploratorios pendientes de evaluación; BioPulse no estima etapas ausentes.")
                .font(.footnote).foregroundStyle(PulseStyle.secondary)
        }
        .refreshable { await health.reload() }
    }

    private func stageColor(_ stage: SleepStageKind) -> Color {
        switch stage {
        case .deep: Color.white.opacity(0.92)
        case .rem: Color.white.opacity(0.72)
        case .core: Color.white.opacity(0.5)
        case .unspecified: Color.white.opacity(0.3)
        }
    }
}

struct ScoreExplanationView: View {
    @ObservedObject var health: HealthDataController
    @ObservedObject var personal: PersonalContextStore

    private var score: WellnessScore {
        WellnessScores.bio(health.sleepScoreData(using: personal).values, day: health.bioScoreDay, targetMinutes: personal.sleepTargetMinutes)
    }

    private var scoreDateLabel: String { health.isCSVImported ? "día importado" : "ayer" }

    var body: some View {
        ScreenShell(title: "BioScore", subtitle: "Bienestar general") {
            StatusPanel(symbol: score.value == nil ? "circle.dashed" : "waveform.path.ecg",
                        title: score.value.map { "BioScore \($0)/100 · \(scoreDateLabel)" } ?? "Datos insuficientes",
                        message: score.reason)
            if score.value == nil {
                ScoreCalibrationCard(values: health.sleepScoreData(using: personal).values,
                                     day: health.bioScoreDay, isBioScore: true, reason: score.reason)
            }
            Text("Día evaluado: \(health.bioScoreDay.formatted(date: .abbreviated, time: .omitted)). El BioScore usa un día completo; el registro de sueño de esta mañana corresponde a la fecha de hoy.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)
            if health.sleepScoreData(using: personal).includesSelfReport(on: health.bioScoreDay) {
                StatusPanel(symbol: "pencil.circle", title: "Incluye autorreportes de sueño", message: "Una parte de la duración y la referencia de sueño procede de tus estimaciones. No se presenta como una medición del reloj.")
            }
            if let _ = score.value {
                DashboardCard {
                    Text("Componentes · \(score.version)").font(.headline)
                    Text("Sueño \(Int(score.components["sleep"] ?? 0))/100 · recuperación \(Int(score.components["recovery"] ?? 0))/100 · actividad habitual \(Int(score.components["activityBalance"] ?? 0))/100")
                        .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                    Text("Pesos exploratorios: 40 % sueño, 35 % recuperación (HRV y pulso en reposo) y 25 % actividad habitual. Compara solo con tu historial.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
            }

            StatusPanel(
                symbol: "function",
                title: "Es una fórmula, no un modelo ML",
                message: "Resume sueño, HRV, frecuencia cardiaca en reposo y energía activa frente a tu historial. Necesita datos del día y al menos 14 días previos para cada señal en una ventana de 28 días. Sus pesos son una hipótesis de producto, no una receta médica ni una medida clínica validada."
            )

            SectionHeading(title: "Señales consideradas", subtitle: "Mediciones y procedencia")
            ForEach([HealthMetric.heartRateVariabilitySDNN, .restingHeartRate, .activeEnergyBurned]) { metric in
                MetricListRow(metric: metric, reading: health.readings[metric], showsChevron: false)
            }
            Text("El sueño se obtiene de Apple Salud o de tu registro para cada noche. Si hay ambos, Apple Salud tiene prioridad salvo que elijas tu estimación. Las mediciones de las tarjetas son las últimas disponibles; el cálculo utiliza la fecha indicada arriba.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)
            Text("Este índice personal es exploratorio. No equivale a un diagnóstico ni confirma un estado de salud.")
                .font(.footnote)
                .foregroundStyle(PulseStyle.secondary)
        }
    }
}

struct MetricDetailView: View {
    let metric: HealthMetric
    let reading: HealthReading?
    var readingLevel: PersonalReadingLevel = .simple

    var body: some View {
        ScreenShell(title: metric.displayName, subtitle: "Detalle de medición") {
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.formattedValue(reading))
                    .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(PulseStyle.mint)
                Text(metric.provenanceLabel(reading))
                    .foregroundStyle(PulseStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .pulseSurface(prominent: true)

            if let reading {
                DataProvenance(reading: reading)
            } else {
                StatusPanel(
                    symbol: "circle.dashed",
                    title: "Falta esta señal",
                    message: "Puede no haber registros recientes o esta categoría puede no estar compartida. BioPulse no completa los datos ausentes."
                )
            }
            StatusPanel(symbol: "info.circle", title: "Qué significa", message: metric.plainDescription)
            StatusPanel(symbol: "slider.horizontal.3", title: "Qué puede influir", message: metric.possibleInfluencesDescription)
            StatusPanel(
                symbol: "questionmark.circle",
                title: "Qué no permite concluir",
                message: "Una medición aislada o un cambio entre periodos no identifica su causa, no predice una enfermedad y no sustituye la evaluación de un profesional."
            )
            if readingLevel == .technical, let reading {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Detalle técnico").font(.headline)
                    Text("Valor: \(metric.formattedValue(reading))")
                    Text("Fuente: \(reading.sourceName)")
                    Text("Momento: \(reading.measuredAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Los agregados diarios omiten días sin muestras; la cobertura depende de los registros disponibles.")
                }
                .font(.caption)
                .foregroundStyle(PulseStyle.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17).pulseSurface()
            }
        }
    }
}

struct DataProvenance: View {
    let reading: HealthReading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Procedencia").font(.headline).foregroundStyle(.white)
            Text("Fuente: \(reading.sourceName)")
            Text("Último registro: \(reading.measuredAt.formatted(date: .abbreviated, time: .shortened))")
            Text("Consultado desde Apple Salud")
        }
        .font(.subheadline)
        .foregroundStyle(PulseStyle.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .pulseSurface()
    }
}

struct MetricListRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let metric: HealthMetric
    let reading: HealthReading?
    let showsChevron: Bool

    var body: some View {
        let layout = typeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Image(systemName: metric.symbol)
                .foregroundStyle(PulseStyle.mint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.displayName).font(.subheadline.weight(.semibold))
                Text(metric.provenanceLabel(reading))
                    .font(.caption)
                    .foregroundStyle(PulseStyle.secondary)
            }
            if typeSize < .xxxLarge { Spacer(minLength: 5) }
            Text(metric.formattedValue(reading))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(reading == nil ? PulseStyle.secondary : PulseStyle.mint)
            if showsChevron && typeSize < .xxxLarge {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PulseStyle.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseSurface()
    }
}
