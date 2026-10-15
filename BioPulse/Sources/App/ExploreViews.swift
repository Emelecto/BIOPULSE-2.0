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
    @ObservedObject var health: HealthDataController

    var body: some View {
        ScreenShell(title: "Sueño", subtitle: "Tu última noche registrada") {
            HStack(spacing: 20) {
                ScorePlaceholderRing(label: "Sleep Score")
                VStack(alignment: .leading, spacing: 7) {
                    Text("Puntuación pendiente")
                        .font(.title3.weight(.semibold))
                    Text("El score aparecerá cuando la fórmula y la cobertura de sueño estén validadas.")
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 20))

            HStack(alignment: .top, spacing: 18) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PulseStyle.mint)
                VStack(alignment: .leading, spacing: 8) {
                    Text(HealthMetric.sleepAnalysis.formattedValue(health.readings[.sleepAnalysis]))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                    Text("Tiempo dormido registrado")
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 20))

            if let reading = health.readings[.sleepAnalysis] {
                DataProvenance(reading: reading)
                StatusPanel(
                    symbol: "info.circle",
                    title: "Qué incluye este tiempo",
                    message: "Suma las etapas que Apple Salud marca como sueño y evita contar intervalos superpuestos dos veces. No incluye el tiempo simplemente en cama."
                )
            } else {
                StatusPanel(
                    symbol: "moon.zzz",
                    title: "Sin sueño disponible",
                    message: "Usa un dispositivo compatible durante la noche y revisa los permisos de Sueño en Apple Salud."
                )
            }
        }
        .refreshable { await health.reload() }
    }
}

struct ScoreExplanationView: View {
    @ObservedObject var health: HealthDataController

    var body: some View {
        ScreenShell(title: "BioScore", subtitle: "Bienestar general") {
            HStack(spacing: 20) {
                BioScoreRing()
                VStack(alignment: .leading, spacing: 7) {
                    Text("Cálculo pendiente")
                        .font(.title3.weight(.semibold))
                    Text("La fórmula aún necesita validación. El anillo indica dónde aparecerá tu score cuando sea fiable.")
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 20))

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
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseStyle.mint)
                Text(metric.provenanceLabel(reading))
                    .foregroundStyle(PulseStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 20))

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
        .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct MetricListRow: View {
    let metric: HealthMetric
    let reading: HealthReading?
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.symbol)
                .foregroundStyle(PulseStyle.mint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.displayName).font(.subheadline.weight(.semibold))
                Text(metric.provenanceLabel(reading))
                    .font(.caption)
                    .foregroundStyle(PulseStyle.secondary)
            }
            Spacer(minLength: 5)
            Text(metric.formattedValue(reading))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(reading == nil ? PulseStyle.secondary : PulseStyle.mint)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PulseStyle.muted)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
