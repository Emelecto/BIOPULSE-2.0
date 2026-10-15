import SwiftUI

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var health: HealthDataController
    let openJournal: () -> Void
    @State private var selectedMetric: HealthMetric?
    @State private var showingScore = false
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header.pulseEntrance(visible: hasAppeared, reduceMotion: reduceMotion)
                introduction.pulseEntrance(visible: hasAppeared, reduceMotion: reduceMotion, delay: 0.05)

                if !health.hasRequestedAccess {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Conecta Apple Salud", systemImage: "heart.text.square").font(.headline)
                        Text(health.isAvailable
                             ? "Elige las mediciones que quieres consultar. Tus señales aparecerán aquí cuando haya registros disponibles."
                             : "Apple Salud no está disponible en este dispositivo. Puedes seguir usando tu Diario.")
                            .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                        Button("Elegir datos de Salud") { Task { await health.requestAccess() } }
                            .buttonStyle(PulseActionButtonStyle())
                            .disabled(!health.isAvailable)
                    }
                    .padding(20).pulseSurface(prominent: true)
                } else if health.readings.isEmpty && !health.isLoading {
                    StatusPanel(symbol: "waveform.path", title: "Tu espacio está listo", message: "Aún no hay mediciones recientes disponibles. Revisa los registros y permisos en Apple Salud y desliza hacia abajo para actualizar.")
                }

                if health.isLoading {
                    HStack(spacing: 12) {
                        ProgressView().tint(PulseStyle.mint)
                        Text("Consultando Apple Salud…").font(.subheadline)
                    }
                    .foregroundStyle(PulseStyle.secondary)
                    .accessibilityElement(children: .combine)
                }
                if let error = health.errorMessage {
                    PulseFeedback(message: error, isError: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Tus señales", subtitle: "Lo que registra tu dispositivo")
                    let layout = typeSize >= .xxxLarge
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
                    layout {
                        signalCard("Sueño", metric: .sleepAnalysis, accent: PulseStyle.lavender)
                        signalCard("HRV", metric: .heartRateVariabilitySDNN, accent: PulseStyle.mint)
                    }
                    activityCard
                }
                .pulseEntrance(visible: hasAppeared, reduceMotion: reduceMotion, delay: 0.1)

                Button { showingScore = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.dashed").foregroundStyle(PulseStyle.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BioScore").font(.subheadline.weight(.semibold))
                            Text("Puntuación aún no disponible · Ver explicación")
                                .font(.caption).foregroundStyle(PulseStyle.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PulsePressButtonStyle())

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Dale contexto a tu día", subtitle: "Las cifras cuentan solo una parte")
                    Button(action: openJournal) {
                        HStack(spacing: 16) {
                            PulseIcon(symbol: "square.and.pencil")
                            VStack(alignment: .leading, spacing: 5) {
                                Text("¿Qué quieres recordar?").font(.headline)
                                Text("Registra un hábito, síntoma o evento en tu Diario.")
                                    .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white).padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pulseSurface(prominent: true)
                    }
                    .buttonStyle(PulsePressButtonStyle())
                    FeatureDestinationLink(symbol: "wind", title: "Una pausa para respirar", subtitle: "Sigue un ritmo visual a tu propio paso") {
                        BreathingSessionView()
                    }
                    FeatureDestinationLink(symbol: "sun.horizon", title: "Mapa de energía", subtitle: "Consulta su alcance y los datos necesarios") {
                        EnergyMapView()
                    }
                }
                Text("Mediciones para conocerte mejor. BioPulse no ofrece diagnósticos médicos.")
                    .font(.footnote).foregroundStyle(PulseStyle.secondary)
            }
            .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 24)
            .frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background { PulseBackdrop(forest: true) }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await health.reload() }
        .sheet(item: $selectedMetric) { metric in
            NavigationStack { MetricDetailView(metric: metric, reading: health.readings[metric]) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingScore) {
            NavigationStack { ScoreExplanationView(health: health) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { hasAppeared = true }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) { brand; Spacer(minLength: 16); sourceStatus }
            VStack(alignment: .leading, spacing: 10) { brand; sourceStatus }
        }
    }

    private var brand: some View {
        Label("BioPulse", systemImage: "waveform.path.ecg")
            .font(.headline).foregroundStyle(PulseStyle.mint)
    }

    private var sourceStatus: some View {
        Label(health.readings.isEmpty ? "Sin datos recientes" : "Apple Salud", systemImage: "heart")
            .font(.caption.weight(.medium)).foregroundStyle(PulseStyle.secondary)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hoy").font(.largeTitle.bold())
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            Text(health.readings.isEmpty ? "Tu bienestar empieza\npor conocerte." : "Tu día, en perspectiva.")
                .font(.title.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            if let lastUpdated = health.lastUpdated {
                Text("Última consulta: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) {
            PulseContours().stroke(PulseStyle.mint.opacity(0.15), lineWidth: 0.7)
                .frame(width: 110, height: 100)
                .clipped().accessibilityHidden(true).allowsHitTesting(false)
        }
    }

    private func signalCard(_ title: String, metric: HealthMetric, accent: Color) -> some View {
        let reading = health.readings[metric]
        let value = metric.formattedValue(reading)
        return Button { selectedMetric = metric } label: {
            VStack(alignment: .leading, spacing: 16) {
                PulseIcon(symbol: metric.symbol, accent: accent)
                Text(title).font(.headline).foregroundStyle(.white)
                Text(value)
                    .font(.title2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(reading == nil ? PulseStyle.secondary : accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: value)
                Text(metric.provenanceLabel(reading))
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Ver detalle", systemImage: "arrow.up.right")
                    .font(.caption.weight(.medium)).foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).pulseSurface(accent: accent, prominent: true)
        }
        .buttonStyle(PulsePressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value). \(metric.provenanceLabel(reading)). Ver detalle")
    }

    private var activityCard: some View {
        Button { selectedMetric = .stepCount } label: {
            HStack(spacing: 14) {
                PulseIcon(symbol: "figure.walk")
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tu movimiento").font(.headline)
                    Text(HealthMetric.stepCount.formattedValue(health.readings[.stepCount]))
                        .font(.title3.weight(.semibold)).monospacedDigit()
                    Text("Acumulado de hoy").font(.caption).foregroundStyle(PulseStyle.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white).padding(18)
            .frame(maxWidth: .infinity, alignment: .leading).pulseSurface()
        }
        .buttonStyle(PulsePressButtonStyle())
    }
}
