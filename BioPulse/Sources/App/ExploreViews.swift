import Charts
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
            DashboardCard {
                Text("Tu historia, día a día").font(.headline)
                Text("Solo se muestran días con datos de Apple Salud; los huecos no se rellenan.")
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
                Text("Agregados reales · Apple Salud")
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
        let start = Calendar.current.date(byAdding: .day, value: -periodDays, to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        return (health.dailyHistory[chartMetric] ?? []).filter { $0.day >= start }
    }
}

struct SleepView: View {
    @ObservedObject var health: HealthDataController

    var body: some View {
        ScreenShell(title: "Sueño", subtitle: "Tu última noche registrada") {
            DashboardCard {
                PendingScoreHero(title: "Sleep Score", subtitle: "Cálculo en preparación")
                Text("Tiempo dormido").font(.subheadline).foregroundStyle(PulseStyle.secondary)
                Text(HealthMetric.sleepAnalysis.formattedValue(health.readings[.sleepAnalysis]))
                    .font(.largeTitle.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tiempo observado en Apple Salud, no una puntuación.")
                    .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            }
            DashboardCard {
                Text("Etapas de la noche").font(.headline)
                if health.sleepStages.isEmpty {
                    DashboardEmptyChart(message: "Sin etapas de sueño registradas por un dispositivo compatible")
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
                StatusPanel(symbol: "moon.zzz", title: "Aún no hay una noche registrada", message: "Cuando Apple Salud tenga registros de sueño compartidos con BioPulse, aparecerán aquí. Revisa los permisos y desliza hacia abajo para actualizar.")
            }
            Text("Sleep Score requiere una fórmula validada y datos suficientes. BioPulse no estima etapas ausentes.")
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

    var body: some View {
        ScreenShell(title: "BioScore", subtitle: "Bienestar general") {
            StatusPanel(
                symbol: "circle.dashed",
                title: "Puntuación aún no disponible",
                message: "Estamos definiendo cómo combinar estas señales de forma fiable. Aquí puedes consultar las mediciones disponibles y su procedencia."
            )

            SectionHeading(title: "Señales consideradas", subtitle: "Disponibilidad de datos, no puntuación")
            ForEach([HealthMetric.sleepAnalysis, .heartRateVariabilitySDNN, .restingHeartRate, .stepCount]) { metric in
                MetricListRow(metric: metric, reading: health.readings[metric], showsChevron: false)
            }
            Text("Un dato disponible no implica que sea suficiente para calcular bienestar general. No mostraremos una cifra inventada.")
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
