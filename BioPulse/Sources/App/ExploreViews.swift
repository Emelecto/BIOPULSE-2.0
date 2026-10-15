import SwiftUI

struct TrendsView: View {
    @ObservedObject var health: HealthDataController
    @State private var selectedMetric: HealthMetric?

    private let metrics: [HealthMetric] = [
        .heartRateVariabilitySDNN, .restingHeartRate, .heartRate,
        .respiratoryRate, .oxygenSaturation, .stepCount,
        .activeEnergyBurned, .appleExerciseTime
    ]

    var body: some View {
        ScreenShell(title: "Tendencias", subtitle: "Entiende cada señal en su contexto") {
            StatusPanel(
                symbol: "chart.xyaxis.line",
                title: "Tu referencia personal está en preparación",
                message: "Una tendencia requiere historial y cobertura suficientes. Ahora puedes consultar cada medición real y su procedencia."
            )
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
                WeeklySummaryView()
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
}

struct SleepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var health: HealthDataController

    var body: some View {
        ScreenShell(title: "Sueño", subtitle: "Tu última noche registrada") {
            VStack(alignment: .leading, spacing: 18) {
                PulseIcon(symbol: "moon.stars.fill", accent: PulseStyle.lavender)
                Text("Tiempo dormido").font(.headline)
                Text(HealthMetric.sleepAnalysis.formattedValue(health.readings[.sleepAnalysis]))
                    .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(PulseStyle.lavender)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: health.readings[.sleepAnalysis])
                Text("Calculado a partir de los registros de Apple Salud.")
                    .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24).pulseSurface(accent: PulseStyle.lavender, prominent: true)

            if let reading = health.readings[.sleepAnalysis] {
                DataProvenance(reading: reading)
                StatusPanel(symbol: "info.circle", title: "Qué incluye este tiempo", message: "Suma las etapas que Apple Salud marca como sueño y evita contar intervalos superpuestos dos veces. No incluye el tiempo simplemente en cama.")
            } else {
                StatusPanel(symbol: "moon.zzz", title: "Aún no hay una noche registrada", message: "Cuando Apple Salud tenga registros de sueño compartidos con BioPulse, aparecerán aquí. Revisa los permisos y desliza hacia abajo para actualizar.")
            }
            Label("Sleep Score aún no disponible", systemImage: "circle.dashed")
                .font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
            Text("La puntuación necesita una fórmula validada y suficientes datos. Mientras tanto, puedes consultar el tiempo dormido y su procedencia.")
                .font(.footnote).foregroundStyle(PulseStyle.secondary)
        }
        .refreshable { await health.reload() }
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
