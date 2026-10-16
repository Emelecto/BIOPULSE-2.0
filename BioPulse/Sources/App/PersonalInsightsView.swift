import BioPulseDomain
import Charts
import SwiftUI

struct PersonalInsightsView: View {
    @ObservedObject var health: HealthDataController
    @ObservedObject var journal: JournalController
    @ObservedObject var personal: PersonalContextStore

    @State private var selectedEnergy: CheckInEnergy?
    @State private var checkInNote = ""
    @State private var showingAnnotationComposer = false
    @State private var showingExperimentComposer = false
    @State private var experimentToReview: PersonalExperiment?
    @State private var checkInSaved = false
    @State private var selectedTrendMetric: HealthMetric = .sleepAnalysis
    @State private var includeSleep = false
    @State private var includeActivity = false
    @State private var includeJournal = false
    @State private var includeCheckIn = false
    @State private var includeAnnotations = false

    private let comparisonMetrics: [HealthMetric] = [
        .sleepAnalysis, .stepCount, .heartRateVariabilitySDNN,
        .restingHeartRate, .appleExerciseTime
    ]

    var body: some View {
        ScreenShell(title: "Tu contexto", subtitle: "Observa cambios junto a lo que viviste") {
            if let persistenceMessage = personal.persistenceMessage {
                StatusPanel(symbol: "lock.trianglebadge.exclamationmark", title: "Datos locales protegidos", message: persistenceMessage)
            }

            focusSection
            trendSection
            changeSection
            timelineSection
            checkInSection
            annotationSection
            experimentSection
            progressSection
            learningSection
            reportSection
            watchLaterSection
        }
        .task {
            await journal.load()
            if let checkIn = personal.checkIn() {
                selectedEnergy = checkIn.energy
                checkInNote = checkIn.note
            }
        }
        .refreshable {
            await health.reload()
            await journal.load(force: true)
        }
        .sheet(isPresented: $showingAnnotationComposer) {
            AnnotationComposer { kind, title, note, date in
                personal.addAnnotation(kind: kind, title: title, note: note, at: date)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingExperimentComposer) {
            ExperimentComposer { question, habit, days in
                personal.startExperiment(question: question, habit: habit, plannedDays: days)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $experimentToReview) { experiment in
            ExperimentReviewSheet(experiment: experiment) { reflection in
                personal.finishExperiment(experiment, reflection: reflection)
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: personal.checkIns) { _, values in
            guard let latest = values.first(where: { Calendar.current.isDateInToday($0.recordedAt) }) else { return }
            selectedEnergy = latest.energy
            checkInNote = latest.note
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeading(title: "Tu enfoque flexible", subtitle: personal.preferences.focus.title)
            Text("Un tema para explorar, no una meta numérica ni una puntuación de rendimiento.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)
            switch personal.preferences.focus {
            case .sleep:
                FeatureDestinationLink(symbol: "moon.stars", title: "Revisar sueño registrado", subtitle: "Fuente y límites de la última noche") {
                    SleepView(health: health)
                }
            case .activity:
                FeatureDestinationLink(symbol: "figure.walk", title: "Revisar pasos de hoy", subtitle: "Dato disponible y procedencia") {
                    MetricDetailView(metric: .stepCount, reading: health.readings[.stepCount], readingLevel: personal.preferences.readingLevel)
                }
            case .journal:
                FeatureDestinationLink(symbol: "square.and.pencil", title: "Abrir tu Diario", subtitle: "Añade el contexto que quieras conservar") {
                    JournalView(journal: journal, personal: personal)
                }
            case .understanding:
                FeatureDestinationLink(symbol: "book.closed", title: "Aprender sobre tus señales", subtitle: "Definiciones, fuente, cobertura y límites") {
                    LearningCenterView(health: health, readingLevel: personal.preferences.readingLevel)
                }
            }
        }
        .padding(16)
        .pulseSurface()
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Tendencia y contexto", subtitle: "Las marcas señalan fechas, no explicaciones")
            Picker("Métrica de tendencia", selection: $selectedTrendMetric) {
                ForEach(comparisonMetrics) { metric in
                    Text(metric.displayName).tag(metric)
                }
            }
            .pickerStyle(.menu)

            let observations = trendObservations
            let visibleAnnotations = trendAnnotations
            if observations.isEmpty {
                StatusPanel(
                    symbol: "chart.xyaxis.line",
                    title: "Aún no hay historial para graficar",
                    message: "La gráfica usa agregados diarios disponibles en Apple Salud. Revisa permisos o vuelve cuando haya registros; BioPulse no inventa puntos."
                )
            } else {
                Chart {
                    ForEach(observations) { observation in
                        LineMark(
                            x: .value("Día", observation.day),
                            y: .value(selectedTrendMetric.displayName, observation.value),
                            series: .value("Métrica", selectedTrendMetric.displayName)
                        )
                        .foregroundStyle(PulseStyle.mint)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Día", observation.day),
                            y: .value(selectedTrendMetric.displayName, observation.value)
                        )
                        .foregroundStyle(PulseStyle.mint)
                    }

                    ForEach(visibleAnnotations) { annotation in
                        RuleMark(x: .value("Fecha anotada", annotation.occurredAt))
                            .foregroundStyle(PulseStyle.lavender.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisTick().foregroundStyle(.white.opacity(0.18))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(PulseStyle.muted)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 190)
                .accessibilityLabel("Tendencia de hasta 28 fechas completas: \(selectedTrendMetric.displayName)")
                .accessibilityHint("Cada punto es un agregado diario de Apple Salud. Las líneas discontinuas indican fechas anotadas por ti.")

                HStack(spacing: 8) {
                    Rectangle().fill(PulseStyle.mint).frame(width: 16, height: 2)
                    Text("Agregado diario · Apple Salud")
                    Spacer(minLength: 8)
                    Rectangle().fill(PulseStyle.lavender).frame(width: 1, height: 15)
                    Text("Anotación")
                }
                .font(.caption2)
                .foregroundStyle(PulseStyle.muted)

                if !visibleAnnotations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleAnnotations.prefix(4)) { annotation in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(annotation.occurredAt.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(PulseStyle.muted)
                                Text(annotation.title).foregroundStyle(PulseStyle.secondary)
                            }
                            .font(.caption)
                        }
                    }
                } else {
                    Text("Puedes añadir una anotación para verla junto a las fechas del historial.")
                        .font(.caption).foregroundStyle(PulseStyle.muted)
                }
                Text("La cercanía en el tiempo no demuestra que una anotación haya causado un cambio.")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
            }
        }
        .padding(16)
        .pulseSurface(accent: PulseStyle.lavender)
    }

    private var trendAnnotations: [PersonalAnnotation] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        return personal.annotations
            .filter { $0.occurredAt >= start && $0.occurredAt < today }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    private var trendObservations: [DailyHealthObservation] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        return (health.dailyHistory[selectedTrendMetric] ?? [])
            .filter { $0.day >= start && $0.day < today }
            .sorted { $0.day < $1.day }
    }

    private var changeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "¿Qué cambió?", subtitle: "Periodo reciente frente a tu referencia")
            Text("Comparamos los últimos 7 días completos con la mediana de hasta 21 días previos. La diferencia describe valores observados; no explica su causa ni indica si algo es bueno o malo.")
                .font(.subheadline)
                .foregroundStyle(PulseStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(comparisonMetrics) { metric in
                comparisonPanel(for: metric)
            }

            if personal.preferences.readingLevel == .technical {
                Text("Método: media aritmética de los días recientes con muestra y mediana de días de referencia. Requisito mínimo: 4/7 días recientes y 7/21 de referencia. Los días sin registro se excluyen; nunca se completan.")
                    .font(.caption)
                    .foregroundStyle(PulseStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func comparisonPanel(for metric: HealthMetric) -> some View {
        let result = comparison(for: metric)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: metric.symbol).foregroundStyle(metric == .sleepAnalysis ? PulseStyle.lavender : PulseStyle.mint)
                Text(metric.displayName).font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Text("Apple Salud").font(.caption2).foregroundStyle(PulseStyle.muted)
            }

            switch result {
            case let .available(comparison):
                comparisonRow("Últimos 7 días", value: formatted(comparison.recentAverage, metric: metric))
                comparisonRow("Referencia personal", value: formatted(comparison.referenceMedian, metric: metric))
                comparisonRow("Diferencia observada", value: signedDifference(comparison.absoluteDifference, metric: metric), accent: PulseStyle.mint)
                Text("Cobertura: \(comparison.recentObservationCount)/7 días recientes · \(comparison.referenceObservationCount)/21 de referencia")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
            case let .insufficientData(recentCount, referenceCount):
                Label("Aún no hay datos suficientes", systemImage: "circle.dashed")
                    .font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
                Text("Hay \(recentCount)/4 días recientes y \(referenceCount)/7 de referencia como mínimo. Revisa permisos y registros en Apple Salud; no rellenamos los días ausentes.")
                    .font(.caption).foregroundStyle(PulseStyle.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseSurface(accent: metric == .sleepAnalysis ? PulseStyle.lavender : PulseStyle.mint)
    }

    private func comparison(for metric: HealthMetric) -> MetricPeriodComparisonResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let recentStart = calendar.date(byAdding: .day, value: -7, to: today),
              let referenceStart = calendar.date(byAdding: .day, value: -28, to: today) else {
            return .insufficientData(recentObservationCount: 0, referenceObservationCount: 0)
        }
        let values = health.dailyHistory[metric] ?? []
        let recent = values.filter { $0.day >= recentStart && $0.day < today }.map(\.value)
        let reference = values.filter { $0.day >= referenceStart && $0.day < recentStart }.map(\.value)
        return MetricPeriodComparisonCalculator.compare(recentValues: recent, referenceValues: reference)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Línea de tiempo", subtitle: "Señales y contexto, sin atribuir causas")

            let userMoments = timelineMoments
            if userMoments.isEmpty && health.readings.isEmpty {
                StatusPanel(
                    symbol: "calendar.badge.clock",
                    title: "Todavía no hay elementos para este día",
                    message: "Conecta Apple Salud o añade una anotación o check-in. Las señales y los recuerdos se mostrarán por separado, con su procedencia."
                )
            } else {
                if !userMoments.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(userMoments.indices, id: \.self) { index in
                            timelineRow(userMoments[index])
                            if index < userMoments.count - 1 {
                                Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.leading, 50)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .pulseSurface()
                }

                if timelineMetrics.contains(where: { health.readings[$0] != nil }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Señales observadas").font(.subheadline.weight(.semibold))
                        ForEach(timelineMetrics) { metric in
                            if let reading = health.readings[metric] {
                                HStack(alignment: .top, spacing: 11) {
                                    Image(systemName: metric.symbol)
                                        .foregroundStyle(metric == .sleepAnalysis ? PulseStyle.lavender : PulseStyle.mint)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(metric.displayName).font(.subheadline.weight(.medium))
                                        Text(metric.formattedValue(reading)).font(.subheadline).foregroundStyle(.white)
                                        Text(metric.provenanceLabel(reading) + " · \(reading.sourceName)")
                                            .font(.caption2).foregroundStyle(PulseStyle.muted)
                                    }
                                    Spacer(minLength: 0)
                                    Text(metric == .stepCount || metric == .activeEnergyBurned || metric == .appleExerciseTime ? "Acumulado" : reading.measuredAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2).foregroundStyle(PulseStyle.secondary)
                                }
                            }
                        }
                    }
                    .padding(17).pulseSurface()
                }
            }
        }
    }

    private var timelineMetrics: [HealthMetric] {
        [.sleepAnalysis, .heartRateVariabilitySDNN, .restingHeartRate, .stepCount, .appleExerciseTime]
    }

    private var timelineMoments: [TimelineMoment] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? .now
        let notes = journal.entries
            .filter { $0.occurredAt >= today && $0.occurredAt < tomorrow }
            .map { TimelineMoment(id: $0.id, date: $0.occurredAt, title: $0.title, detail: $0.notes, symbol: $0.category.insightSymbol, provenance: $0.provenance.insightName) }
        let annotations = personal.annotations
            .filter { $0.occurredAt >= today && $0.occurredAt < tomorrow }
            .map { TimelineMoment(id: $0.id, date: $0.occurredAt, title: $0.title, detail: $0.note.isEmpty ? $0.kind.title : $0.note, symbol: $0.kind.symbol, provenance: "Anotación tuya") }
        let checkIns = personal.checkIns
            .filter { $0.recordedAt >= today && $0.recordedAt < tomorrow }
            .map { TimelineMoment(id: $0.id, date: $0.recordedAt, title: "Check-in: \($0.energy.title)", detail: $0.note, symbol: $0.energy.symbol, provenance: "Autoinforme · registrado por ti") }
        return (notes + annotations + checkIns).sorted { $0.date < $1.date }
    }

    private func timelineRow(_ moment: TimelineMoment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: moment.symbol).foregroundStyle(PulseStyle.mint).frame(width: 28, height: 30)
                Rectangle().fill(PulseStyle.mint.opacity(0.32)).frame(width: 1, height: 25)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(moment.title).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    Text(moment.date.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(PulseStyle.muted)
                }
                if !moment.detail.isEmpty { Text(moment.detail).font(.caption).foregroundStyle(PulseStyle.secondary) }
                Text(moment.provenance).font(.caption2).foregroundStyle(PulseStyle.muted)
            }
            .padding(.bottom, 15)
        }
        .padding(.top, 13)
    }

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Un momento para ti", subtitle: "Check-in opcional · autoinforme")
            Text("¿Cómo sientes tu energía hoy? Esta respuesta es subjetiva y no es una medición de Apple Salud.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(CheckInEnergy.allCases) { energy in
                Button {
                    selectedEnergy = energy
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: energy.symbol).foregroundStyle(selectedEnergy == energy ? PulseStyle.background : PulseStyle.mint)
                        Text(energy.title).font(.subheadline.weight(.medium))
                        Spacer()
                        if selectedEnergy == energy { Image(systemName: "checkmark.circle.fill") }
                    }
                    .foregroundStyle(selectedEnergy == energy ? PulseStyle.background : .white)
                    .padding(14)
                    .background(selectedEnergy == energy ? PulseStyle.mint : PulseStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedEnergy == energy ? .isSelected : [])
            }
            TextField("Nota opcional", text: $checkInNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(13).background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 12))
            Button("Guardar check-in") {
                guard let selectedEnergy else { return }
                personal.saveCheckIn(energy: selectedEnergy, note: checkInNote)
                withAnimation(.easeOut(duration: 0.2)) { checkInSaved = true }
            }
            .buttonStyle(PulseActionButtonStyle())
            .disabled(selectedEnergy == nil)
            if checkInSaved { PulseFeedback(message: "Check-in guardado solo en este dispositivo.") }
        }
    }

    private var annotationSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: "Anota un cambio", subtitle: "Añade contexto a lo que observas")
            Text("Viaje, entrenamiento, café tarde o cambio de horario: la anotación queda junto a la fecha. No se interpreta como causa.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary).fixedSize(horizontal: false, vertical: true)
            Button { showingAnnotationComposer = true } label: {
                Label("Añadir anotación", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PulseSecondaryButtonStyle())

            ForEach(personal.annotations.prefix(5)) { annotation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: annotation.kind.symbol).foregroundStyle(PulseStyle.mint).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(annotation.title).font(.subheadline.weight(.semibold))
                        Text("\(annotation.kind.title) · \(annotation.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(PulseStyle.muted)
                        if !annotation.note.isEmpty { Text(annotation.note).font(.caption).foregroundStyle(PulseStyle.secondary) }
                    }
                    Spacer(minLength: 0)
                    Button(role: .destructive) { personal.deleteAnnotation(annotation) } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Eliminar anotación: \(annotation.title)")
                }
                .padding(14).pulseSurface()
            }
        }
    }

    private var experimentSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: "Experimento personal", subtitle: "Una pregunta y un hábito para observar")
            Text("Exploración individual, no ensayo clínico. BioPulse no asigna causas ni recomienda cambios de tratamiento.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary).fixedSize(horizontal: false, vertical: true)
            Button { showingExperimentComposer = true } label: {
                Label("Plantear una pregunta", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PulseActionButtonStyle())

            ForEach(personal.activeExperiments) { experiment in
                experimentCard(experiment, isActive: true)
            }
            ForEach(personal.completedExperiments.prefix(3)) { experiment in
                experimentCard(experiment, isActive: false)
            }
        }
    }

    private func experimentCard(_ experiment: PersonalExperiment, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isActive ? "EN OBSERVACIÓN" : "REFLEXIÓN GUARDADA")
                .font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(PulseStyle.mint)
            Text(experiment.question).font(.subheadline.weight(.semibold))
            Text("Hábito: \(experiment.habit)").font(.caption).foregroundStyle(PulseStyle.secondary)
            if isActive {
                let elapsed = max(0, Calendar.current.dateComponents([.day], from: experiment.startedAt, to: .now).day ?? 0)
                Text("Día \(min(elapsed + 1, experiment.plannedDays)) de \(experiment.plannedDays) · los registros dependen de ti")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
                Button("Revisar lo observado") { experimentToReview = experiment }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(PulseStyle.mint)
                    .frame(minHeight: 44)
            } else if !experiment.reflection.isEmpty {
                Text(experiment.reflection).font(.caption).foregroundStyle(PulseStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).pulseSurface()
    }

    private var progressSection: some View {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? .now
        let interval = DateInterval(start: monthStart, end: nextMonth)
        let personalDates = personal.checkIns.map(\.recordedAt) + personal.annotations.map(\.occurredAt)
        let journalDates = journal.entries.map(\.occurredAt)
        let allDays = Set((personalDates + journalDates)
            .filter { interval.contains($0) }
            .map { calendar.startOfDay(for: $0) }).count

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Tu progreso personal", subtitle: "Registro y exploración, no una nota de bienestar")
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("\(allDays)").font(.largeTitle.weight(.semibold)).monospacedDigit().foregroundStyle(PulseStyle.mint)
                Text("días con contexto registrado este mes")
                    .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            }
            Text("Cuenta los días únicos en que añadiste contexto este mes. No mide cuánto entendiste: no hay rachas ni penalizaciones por descansar, no usar el reloj o tener días sin datos.")
                .font(.caption).foregroundStyle(PulseStyle.muted).fixedSize(horizontal: false, vertical: true)
            Label("Enfoque actual · \(personal.preferences.focus.title)", systemImage: personal.preferences.focus.symbol)
                .font(.caption.weight(.medium)).foregroundStyle(PulseStyle.mint)
        }
        .padding(17).frame(maxWidth: .infinity, alignment: .leading).pulseSurface()
    }

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Centro de aprendizaje", subtitle: "Qué significa una señal y qué no permite concluir")
            FeatureDestinationLink(
                symbol: "book.closed",
                title: "Explorar métricas",
                subtitle: "Definición, origen, cobertura y límites"
            ) {
                LearningCenterView(health: health, readingLevel: personal.preferences.readingLevel)
            }
            if personal.preferences.readingLevel == .technical {
                Text("Vista técnica activa: se muestran ventanas y cobertura disponibles. Las métricas siguen siendo observaciones, no una valoración médica.")
                    .font(.caption).foregroundStyle(PulseStyle.muted)
            }
        }
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Resumen para compartir", subtitle: "Tú eliges qué incluir y lo revisas antes")
            Text("Generado en el dispositivo para apoyar una conversación con un profesional. No es un historial clínico certificado ni se envía automáticamente.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Sueño registrado", isOn: $includeSleep).tint(PulseStyle.mint)
            Toggle("Actividad de hoy", isOn: $includeActivity).tint(PulseStyle.mint)
            Toggle("Registros del Diario", isOn: $includeJournal).tint(PulseStyle.mint)
            Toggle("Check-in subjetivo", isOn: $includeCheckIn).tint(PulseStyle.mint)
            Toggle("Anotaciones de contexto", isOn: $includeAnnotations).tint(PulseStyle.mint)

            if hasReportContent {
                Text(reportText)
                    .font(.caption.monospaced())
                    .foregroundStyle(PulseStyle.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(PulseStyle.background, in: RoundedRectangle(cornerRadius: 12))
                ShareLink(item: reportText, subject: Text("Resumen personal BioPulse"), preview: SharePreview("Resumen personal BioPulse")) {
                    Label("Compartir resumen revisado", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PulseActionButtonStyle())
            } else {
                Text("Selecciona al menos una categoría para crear la vista previa.")
                    .font(.caption).foregroundStyle(PulseStyle.muted)
            }
        }
    }

    private var hasReportContent: Bool {
        includeSleep || includeActivity || includeJournal || includeCheckIn || includeAnnotations
    }

    private var reportText: String {
        var lines = ["BioPulse · resumen informativo", Date.now.formatted(date: .long, time: .shortened), "No es un historial clínico ni un diagnóstico."]
        if includeSleep {
            lines.append("Sueño registrado: \(HealthMetric.sleepAnalysis.formattedValue(health.readings[.sleepAnalysis])) · \(health.readings[.sleepAnalysis]?.sourceName ?? "sin dato reciente")")
        }
        if includeActivity {
            lines.append("Pasos de hoy: \(HealthMetric.stepCount.formattedValue(health.readings[.stepCount])) · \(health.readings[.stepCount]?.sourceName ?? "sin dato reciente")")
            lines.append("Ejercicio de hoy: \(HealthMetric.appleExerciseTime.formattedValue(health.readings[.appleExerciseTime])) · \(health.readings[.appleExerciseTime]?.sourceName ?? "sin dato reciente")")
        }
        if includeJournal {
            let recentEntries = journal.entries.prefix(8)
            if recentEntries.isEmpty {
                lines.append("Diario: no hay registros disponibles")
            } else {
                lines.append("Diario (entradas personales, hasta 8):")
                lines += recentEntries.map { "• \($0.occurredAt.formatted(date: .abbreviated, time: .shortened)): \($0.title) — \($0.notes)" }
            }
        }
        if includeCheckIn, let checkIn = personal.checkIn() {
            lines.append("Check-in subjetivo: \(checkIn.energy.title) · \(checkIn.note.isEmpty ? "sin nota" : checkIn.note)")
        } else if includeCheckIn {
            lines.append("Check-in subjetivo: no registrado hoy")
        }
        if includeAnnotations {
            let recent = personal.annotations.prefix(8)
            if recent.isEmpty {
                lines.append("Anotaciones: no hay anotaciones registradas")
            } else {
                lines.append("Anotaciones de contexto (registradas por la persona):")
                lines += recent.map { "• \($0.occurredAt.formatted(date: .abbreviated, time: .shortened)): \($0.title) — \($0.note)" }
            }
        }
        return lines.joined(separator: "\n")
    }

    private var watchLaterSection: some View {
        StatusPanel(
            symbol: "applewatch",
            title: "Apple Watch: etapa posterior",
            message: "Los widgets y complicaciones aún no están incluidos. Cuando se implementen, priorizarán respiración o estado de sincronización y ocultarán métricas sensibles en la pantalla bloqueada."
        )
    }

    private func comparisonRow(_ label: String, value: String, accent: Color = PulseStyle.secondary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundStyle(PulseStyle.muted)
            Spacer(minLength: 8)
            Text(value).font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(accent)
        }
    }

    private func formatted(_ value: Double, metric: HealthMetric) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        switch metric {
        case .sleepAnalysis: "\(number) min"
        case .stepCount: "\(number) pasos"
        case .heartRateVariabilitySDNN: "\(number) ms"
        case .restingHeartRate: "\(number) lpm"
        case .appleExerciseTime: "\(number) min"
        default: number
        }
    }

    private func signedDifference(_ value: Double, metric: HealthMetric) -> String {
        let sign = value > 0 ? "+" : ""
        return sign + formatted(value, metric: metric)
    }
}

private extension JournalCategory {
    var insightSymbol: String {
        switch self {
        case .habit: "leaf"
        case .symptom: "cross.case"
        case .event: "calendar"
        }
    }
}

private extension JournalProvenance {
    var insightName: String {
        switch self {
        case .userEntered: "Registrado por ti"
        case .importedCSV: "Importado desde CSV"
        }
    }
}

private struct TimelineMoment: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let symbol: String
    let provenance: String
}

private struct LearningCenterView: View {
    @ObservedObject var health: HealthDataController
    let readingLevel: PersonalReadingLevel

    private let metrics: [HealthMetric] = [
        .sleepAnalysis, .heartRateVariabilitySDNN, .restingHeartRate,
        .stepCount, .appleExerciseTime, .respiratoryRate, .oxygenSaturation
    ]

    var body: some View {
        ScreenShell(title: "Aprender", subtitle: "Una definición clara, con sus límites") {
            StatusPanel(
                symbol: "info.circle",
                title: "Una métrica no cuenta toda la historia",
                message: "Su significado depende de la fuente, el dispositivo, el momento y la cobertura. Los cambios no identifican por sí solos una causa."
            )
            ForEach(metrics) { metric in
                FeatureDestinationLink(
                    symbol: metric.symbol,
                    title: metric.displayName,
                    subtitle: health.readings[metric].map { metric.provenanceLabel($0) + " · " + $0.sourceName } ?? "Sin dato reciente · definición y límites"
                ) {
                    MetricDetailView(metric: metric, reading: health.readings[metric], readingLevel: readingLevel)
                }
            }
        }
    }
}

private struct AnnotationComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: AnnotationKind = .other
    @State private var title = ""
    @State private var note = ""
    @State private var date = Date.now
    let onSave: (AnnotationKind, String, String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $kind) {
                    ForEach(AnnotationKind.allCases) { Text($0.title).tag($0) }
                }
                TextField("Título", text: $title).textInputAutocapitalization(.sentences)
                TextField("Nota opcional", text: $note, axis: .vertical).lineLimit(2...5)
                DatePicker("Cuándo ocurrió", selection: $date, in: Date.distantPast...Date.now, displayedComponents: [.date, .hourAndMinute])
                Section {
                    Text("Es un recuerdo escrito por ti. BioPulse lo muestra junto a las señales, pero no lo convierte en explicación médica.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Anotar contexto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(kind, title, note, date)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ExperimentComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var habit = ""
    @State private var days = 7
    let onSave: (String, String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("¿Qué te gustaría observar?", text: $question, axis: .vertical).lineLimit(2...4)
                TextField("Hábito que vas a observar", text: $habit)
                Picker("Duración", selection: $days) {
                    ForEach([3, 7, 14, 21, 28], id: \.self) { Text("\($0) días").tag($0) }
                }
                Section {
                    Text("Exploración personal, no ensayo clínico. Mantén cualquier tratamiento indicado por un profesional; BioPulse no propone cambios médicos.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nueva observación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Empezar") {
                        onSave(question, habit, days)
                        dismiss()
                    }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || habit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ExperimentReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reflection = ""
    let experiment: PersonalExperiment
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Pregunta", value: experiment.question)
                LabeledContent("Hábito", value: experiment.habit)
                LabeledContent("Periodo", value: "\(experiment.startedAt.formatted(date: .abbreviated, time: .omitted)) · objetivo \(experiment.plannedDays) días")
                TextField("¿Qué observaste? (opcional)", text: $reflection, axis: .vertical).lineLimit(4...8)
                Section {
                    Text("Registra tu propia reflexión. La coincidencia temporal no demuestra causalidad.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Revisar observación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Seguir observando") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar reflexión") {
                        onSave(reflection)
                        dismiss()
                    }
                }
            }
        }
    }
}
