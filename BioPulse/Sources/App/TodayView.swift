import SwiftUI

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var health: HealthDataController
    @State private var selectedMetric: HealthMetric?
    @State private var showingScore = false
    @State private var atmosphereShifted = false

    var body: some View {
        ZStack(alignment: .top) {
            PulseStyle.background.ignoresSafeArea()
            GeometryReader { geometry in
                Image("ForestNight")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: min(geometry.size.height * 0.85, 720))
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, PulseStyle.background.opacity(0.48), PulseStyle.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [.clear, PulseStyle.mint.opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: geometry.size.width * 1.2, height: min(geometry.size.height * 0.7, 620))
                .offset(x: atmosphereShifted ? 18 : -18, y: atmosphereShifted ? -5 : 7)
                .opacity(reduceMotion ? 0.06 : 0.11)
                .blendMode(.screen)
                .accessibilityHidden(true)
            }
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(alignment: .leading, spacing: 29) {
                    HStack(spacing: 8) {
                        Text("BioPulse")
                            .font(.title3.weight(.bold))
                        Image(systemName: "waveform.path.ecg")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseStyle.mint)
                        Spacer(minLength: 6)
                        Circle()
                            .fill(health.readings.isEmpty ? PulseStyle.muted : PulseStyle.mint)
                            .frame(width: 7, height: 7)
                        Text(health.readings.isEmpty
                             ? (health.hasRequestedAccess ? "Sin datos" : "Sin sincronizar")
                             : "Apple Salud")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseStyle.secondary)
                    }
                    .padding(.top, 15)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Hoy")
                            .font(.system(size: 43, weight: .bold, design: .rounded))
                            .tracking(-1.5)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(PulseStyle.secondary)
                    }
                    .padding(.top, 7)

                    HStack(alignment: .center, spacing: 18) {
                        VStack(alignment: .leading, spacing: 11) {
                            Text(health.readings.isEmpty ? "Tu bienestar, con datos reales" : "Tus señales de hoy")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .tracking(-0.7)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(health.readings.isEmpty
                                 ? "Conecta Apple Salud para explorar lo que registra tu dispositivo."
                                 : "Explora tus mediciones y entiende qué información está disponible.")
                                .font(.subheadline)
                                .foregroundStyle(PulseStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button { showingScore = true } label: {
                            VStack(spacing: 6) {
                                BioScoreRing()
                                Text("Ver detalle")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(PulseStyle.secondary)
                            }
                        }
                            .buttonStyle(.plain)
                            .accessibilityLabel("BioScore: pendiente de validación. Ver explicación")
                    }
                    .padding(.vertical, 12)

                    if !health.hasRequestedAccess {
                        VStack(alignment: .leading, spacing: 15) {
                            StatusPanel(
                                symbol: "heart.text.square",
                                title: "Conecta Apple Salud",
                                message: "Tú eliges qué datos compartir. BioPulse consulta únicamente las mediciones autorizadas."
                            )
                            Button("Solicitar acceso") {
                                Task { await health.requestAccess() }
                            }
                            .buttonStyle(PulseActionButtonStyle())
                            .disabled(!health.isAvailable)
                        }
                    } else if health.readings.isEmpty && !health.isLoading {
                        StatusPanel(
                            symbol: "waveform.path",
                            title: "Aún no hay mediciones disponibles",
                            message: "Puede que no haya registros recientes o que Apple Salud no comparta estas categorías. Revisa tus permisos y actualiza."
                        )
                    }

                    if health.isLoading {
                        HStack(spacing: 12) {
                            ProgressView().tint(PulseStyle.mint)
                            Text("Consultando Apple Salud…")
                                .foregroundStyle(PulseStyle.secondary)
                        }
                        .padding(18)
                    }

                    if let error = health.errorMessage {
                        StatusPanel(symbol: "exclamationmark.triangle", title: "Consulta parcial", message: error)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "Señales principales", subtitle: "Mediciones recientes, sin estimaciones")
                        HStack(alignment: .top, spacing: 12) {
                            signalCard("HRV", metric: .heartRateVariabilitySDNN)
                            signalCard("Sueño", metric: .sleepAnalysis)
                        }
                    }

                    Button { selectedMetric = .stepCount } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "figure.walk")
                                .font(.title2)
                                .foregroundStyle(PulseStyle.mint)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Actividad").font(.headline)
                                Text(health.readings[.stepCount].map { "\(Int($0.value.rounded()).formatted()) pasos hoy" } ?? "Sin pasos registrados hoy")
                                    .font(.subheadline)
                                    .foregroundStyle(PulseStyle.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(PulseStyle.muted)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PulseStyle.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Para hoy", subtitle: "Herramientas que no necesitan inventar datos")
                        FeatureDestinationLink(
                            symbol: "sun.horizon",
                            title: "Mapa de energía",
                            subtitle: "Entradas, cobertura y contexto del día"
                        ) {
                            EnergyMapView()
                        }
                        FeatureDestinationLink(
                            symbol: "wind",
                            title: "Respiración guiada",
                            subtitle: "Una pausa breve con ritmo visual"
                        ) {
                            BreathingSessionView()
                        }
                    }

                    Text("BioPulse describe registros disponibles; no ofrece diagnósticos médicos.")
                        .font(.footnote)
                        .foregroundStyle(PulseStyle.secondary)
                        .padding(.bottom, 18)
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
            .refreshable { await health.reload() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedMetric) { metric in
            MetricDetailView(metric: metric, reading: health.readings[metric])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingScore) {
            ScoreExplanationView(health: health)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            guard !reduceMotion, !atmosphereShifted else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                atmosphereShifted = true
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue {
                withAnimation(nil) { atmosphereShifted = false }
            } else {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    atmosphereShifted = true
                }
            }
        }
    }

    private func signalCard(_ title: String, metric: HealthMetric) -> some View {
        let reading = health.readings[metric]
        return Button { selectedMetric = metric } label: {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Image(systemName: metric.symbol).foregroundStyle(PulseStyle.mint)
                    Text(title).font(.headline)
                    Spacer(minLength: 0)
                }
                Text(metric.formattedValue(reading))
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(reading == nil ? PulseStyle.secondary : PulseStyle.mint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 5) {
                    Circle()
                        .fill(reading == nil ? PulseStyle.muted : PulseStyle.mint)
                        .frame(width: 6, height: 6)
                    Text(metric.provenanceLabel(reading))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PulseStyle.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
            .padding(15)
            .background(PulseStyle.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(metric.formattedValue(reading)). Ver detalle")
    }
}
