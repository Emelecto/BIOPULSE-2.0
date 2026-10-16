import Charts
import SwiftUI

struct TodayView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var health: HealthDataController
    let openJournal: () -> Void
    @State private var selectedMetric: HealthMetric?
    @State private var showingScore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DashboardPageHeader(title: "Hoy")
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                Button { showingScore = true } label: {
                    VStack(spacing: 4) {
                        PendingScoreHero(title: "BioScore")
                        Text("Bienestar general · cálculo en desarrollo")
                            .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                        Label("Cómo funcionará", systemImage: "arrow.up.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white).padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PulsePressButtonStyle())

                if !health.hasRequestedAccess {
                    StatusPanel(symbol: "heart.text.square", title: "Conecta Apple Salud", message: "Elige qué señales compartir para ver tus mediciones. BioScore permanece pendiente.")
                    Button("Elegir datos de Salud") { Task { await health.requestAccess() } }
                        .buttonStyle(PulseActionButtonStyle()).disabled(!health.isAvailable)
                }
                if health.isLoading {
                    Label("Consultando Apple Salud…", systemImage: "arrow.clockwise")
                        .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                }
                if let error = health.errorMessage { PulseFeedback(message: error, isError: true) }

                SectionHeading(title: "Señales de hoy", subtitle: "Datos observados, no puntuaciones")
                let layout = typeSize >= .xxxLarge
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                layout {
                    energyCard.frame(maxWidth: .infinity).frame(height: 328)
                    VStack(spacing: 12) {
                        metricCard("HRV media", metric: .heartRateVariabilitySDNN, note: "Media de hoy", symbol: "waveform.path.ecg")
                            .frame(height: 158)
                        metricCard("FC en reposo", metric: .restingHeartRate, note: "Última de hoy", symbol: "heart")
                            .frame(height: 158)
                    }.frame(maxWidth: .infinity)
                }
                layout {
                    metricCard("Sueño", metric: .sleepAnalysis, note: "Última noche", symbol: "moon.stars")
                        .frame(maxWidth: .infinity).frame(height: 158)
                    metricCard("Pasos", metric: .stepCount, note: "Acumulado de hoy", symbol: "figure.walk")
                        .frame(maxWidth: .infinity).frame(height: 158)
                }

                SectionHeading(title: "Dale contexto", subtitle: "Tus datos cuentan solo una parte")
                Button(action: openJournal) {
                    DashboardCard {
                        Label("Añadir al Diario", systemImage: "square.and.pencil")
                            .font(.headline).foregroundStyle(.white)
                        Text("Registra un hábito, síntoma o evento de hoy.")
                            .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                    }
                }.buttonStyle(PulsePressButtonStyle())
                FeatureDestinationLink(symbol: "wind", title: "Una pausa para respirar", subtitle: "Sigue un ritmo visual a tu propio paso") { BreathingSessionView() }
                Text("BioPulse no ofrece diagnósticos médicos ni interpreta una lectura aislada como enfermedad.")
                    .font(.footnote).foregroundStyle(PulseStyle.secondary)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 24)
            .frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background { PulseBackdrop() }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await health.reload() }
        .sheet(item: $selectedMetric) { metric in
            NavigationStack { MetricDetailView(metric: metric, reading: health.readings[metric]) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingScore) {
            NavigationStack { ScoreExplanationView(health: health) }
                .presentationDetents([.medium, .large])
        }
    }

    private var energyCard: some View {
        Button { selectedMetric = .activeEnergyBurned } label: {
            DashboardCard {
                Label("Energía activa", systemImage: "bolt")
                    .font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
                Text(HealthMetric.activeEnergyBurned.formattedValue(health.readings[.activeEnergyBurned]))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white).monospacedDigit()
                    .minimumScaleFactor(0.7).lineLimit(1)
                Spacer(minLength: 10)
                if health.hourlyActiveEnergy.isEmpty {
                    DashboardEmptyChart(message: "Sin registros por hora").frame(height: 156)
                } else {
                    Chart(health.hourlyActiveEnergy) { observation in
                        BarMark(x: .value("Hora", observation.hour, unit: .hour),
                                y: .value("kcal", observation.kilocalories))
                            .foregroundStyle(.white.opacity(0.82))
                            .cornerRadius(3)
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
                    .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 6)) { _ in AxisValueLabel(format: .dateTime.hour()) } }
                    .chartYAxis(.hidden)
                    .frame(height: 156)
                    .accessibilityLabel("Energía activa registrada por hora en Apple Salud")
                }
                Text("Registrada por hora · Apple Salud")
                    .font(.caption2).foregroundStyle(PulseStyle.muted)
            }
        }
        .buttonStyle(PulsePressButtonStyle())
        .accessibilityLabel("Energía activa: \(HealthMetric.activeEnergyBurned.formattedValue(health.readings[.activeEnergyBurned])). Ver detalle")
    }

    private func metricCard(_ title: String, metric: HealthMetric, note: String, symbol: String) -> some View {
        let history = Array((health.dailyHistory[metric] ?? []).suffix(7))
        return Button { selectedMetric = metric } label: {
            DashboardCard {
                HStack(alignment: .top) {
                    Text(title).font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: symbol).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 7)
                Text(metric.formattedValue(health.readings[metric]))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                if !history.isEmpty {
                    Chart(history) { point in
                        BarMark(x: .value("Día", point.day, unit: .day), y: .value("Valor", point.value))
                            .foregroundStyle(.white.opacity(0.7))
                            .cornerRadius(2)
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden)
                    .frame(height: 27)
                    .accessibilityHidden(true)
                }
                Text(note).font(.caption2).foregroundStyle(PulseStyle.muted)
            }
        }
        .buttonStyle(PulsePressButtonStyle())
        .accessibilityLabel("\(title): \(metric.formattedValue(health.readings[metric])). \(note). Ver detalle")
    }
}
