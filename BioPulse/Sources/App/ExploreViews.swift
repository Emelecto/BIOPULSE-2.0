import Charts
import BioPulseDomain
import SwiftUI

struct TrendsView: View {
    @ObservedObject var health: HealthDataController
    @ObservedObject var journal: JournalController
    @ObservedObject var personal: PersonalContextStore
    @State private var selectedMetric: HealthMetric?
    @State private var chartMetric: HealthMetric = .heartRateVariabilitySDNN
    @State private var periodDays = 7

    private let metrics: [HealthMetric] = [
        .heartRateVariabilitySDNN, .restingHeartRate, .heartRate,
        .respiratoryRate, .oxygenSaturation, .stepCount,
        .activeEnergyBurned, .appleExerciseTime
    ]

    var body: some View {
        ScreenShell(title: "Tendencias", subtitle: "Cambios observados en tus registros") {
            let yesterday = health.isCSVImported ? health.displayedDataDay : (Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now)
            let signal = WellnessScores.change(health.wellnessValues, day: yesterday)
            DashboardCard {
                Text("SEÑAL DE CAMBIO PERSONAL").font(.caption.weight(.semibold)).foregroundStyle(PulseStyle.secondary)
                Text(signal.value.map { $0 == 0 ? "Sin cambio persistente" : "\($0)/100" } ?? "—")
                    .font(.title2.weight(.semibold)).foregroundStyle(.white)
                Text(signal.reason).font(.subheadline).foregroundStyle(PulseStyle.secondary)
                Text("\(health.isCSVImported ? "Día importado" : "Ayer") · \(signal.version) · magnitud de cambio, no probabilidad de enfermedad")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
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
                        .frame(height: 205)
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
                    .frame(height: 205)
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
    @ObservedObject var health: HealthDataController
    @ObservedObject var personal: PersonalContextStore

    private var score: WellnessScore {
        let day = health.dailyHistory[.sleepAnalysis]?.last?.day ?? health.displayedDataDay
        return WellnessScores.sleep(health.wellnessValues, day: day, targetMinutes: personal.sleepTargetMinutes)
    }

    var body: some View {
        ScreenShell(title: "Sueño", subtitle: health.isCSVImported ? "El archivo no incluye sueño" : "Tu última noche registrada") {
            DashboardCard {
                PendingScoreHero(title: "Sleep Score", score: score.value.map(Double.init), subtitle: score.value == nil ? "Datos insuficientes" : "Índice exploratorio")
                Text("Tiempo dormido").font(.subheadline).foregroundStyle(PulseStyle.secondary)
                Text(HealthMetric.sleepAnalysis.formattedValue(health.readings[.sleepAnalysis]))
                    .font(.largeTitle.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(score.reason)
                    .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            }
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
                Text("Etapas de la noche").font(.headline)
                if health.sleepStages.isEmpty {
                    DashboardEmptyChart(message: health.isCSVImported ? "El CSV cargado no incluye etapas de sueño." : "Sin etapas de sueño registradas por un dispositivo compatible")
                        .frame(height: 170)
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
                    .frame(height: 170)
                    .accessibilityLabel("Etapas de sueño registradas en Apple Salud")
                    Text("\(health.sleepStages.count) intervalos registrados · Apple Salud")
                        .font(.caption2).foregroundStyle(PulseStyle.muted)
                }
            }
            if let reading = health.readings[.sleepAnalysis] {
                DataProvenance(reading: reading)
                StatusPanel(symbol: "info.circle", title: "Qué incluye este tiempo", message: "Suma los intervalos marcados como sueño, sin contar superposiciones dos veces. No incluye el tiempo simplemente en cama.")
            } else {
                StatusPanel(symbol: "moon.zzz", title: "Aún no hay una noche registrada", message: health.isCSVImported ? "Este archivo no contiene registros de sueño. Quita el CSV para volver a Apple Salud." : "Cuando Apple Salud tenga registros de sueño compartidos con BioPulse, aparecerán aquí. Revisa los permisos y desliza hacia abajo para actualizar.")
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
        let day = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return WellnessScores.bio(health.wellnessValues, day: day, targetMinutes: personal.sleepTargetMinutes)
    }

    var body: some View {
        ScreenShell(title: "BioScore", subtitle: "Bienestar general") {
            StatusPanel(symbol: score.value == nil ? "circle.dashed" : "waveform.path.ecg",
                        title: score.value.map { "BioScore \($0)/100 · ayer" } ?? "Datos insuficientes",
                        message: score.reason)
            if let _ = score.value {
                DashboardCard {
                    Text("Componentes · \(score.version)").font(.headline)
                    Text("Sueño \(Int(score.components["sleep"] ?? 0))/100 · recuperación \(Int(score.components["recovery"] ?? 0))/100 · actividad habitual \(Int(score.components["activityBalance"] ?? 0))/100")
                        .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                    Text("Pesos propuestos: 40 % sueño, 35 % recuperación y 25 % actividad. Compara solo con tu propio historial.")
                        .font(.caption).foregroundStyle(PulseStyle.secondary)
                }
            }

            SectionHeading(title: "Señales consideradas", subtitle: "Mediciones y procedencia")
            ForEach([HealthMetric.sleepAnalysis, .heartRateVariabilitySDNN, .restingHeartRate, .stepCount]) { metric in
                MetricListRow(metric: metric, reading: health.readings[metric], showsChevron: false)
            }
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
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseSurface()
    }
}
