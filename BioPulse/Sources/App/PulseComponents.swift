import SwiftUI

enum PulseStyle {
    static let background = Color(red: 0.035, green: 0.075, blue: 0.11)
    static let surface = Color(red: 0.075, green: 0.13, blue: 0.17)
    static let elevated = Color(red: 0.10, green: 0.18, blue: 0.21)
    static let mint = Color(red: 0.59, green: 0.94, blue: 0.82)
    static let secondary = Color(red: 0.73, green: 0.82, blue: 0.84)
    static let muted = Color(red: 0.52, green: 0.65, blue: 0.68)
}

struct ScorePlaceholderRing: View {
    let label: String

    var body: some View {
        ZStack {
            Circle().stroke(PulseStyle.mint.opacity(0.32), lineWidth: 8)
            Circle()
                .fill(PulseStyle.mint)
                .frame(width: 7, height: 7)
                .offset(y: -53)
            VStack(spacing: 1) {
                Text("—").font(.system(size: 31, weight: .medium, design: .rounded))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PulseStyle.secondary)
            }
        }
        .frame(width: 106, height: 106)
    }
}

struct BioScoreRing: View {
    var body: some View {
        ScorePlaceholderRing(label: "BioScore")
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle).font(.subheadline).foregroundStyle(PulseStyle.secondary)
        }
    }
}

struct StatusPanel: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).foregroundStyle(PulseStyle.mint).frame(width: 24)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PulseStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ScreenShell<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(subtitle).font(.subheadline).foregroundStyle(PulseStyle.secondary)
                }
                .padding(.top, 15)
                content
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(PulseStyle.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct PulseActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(PulseStyle.background)
            .background(PulseStyle.mint, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct PulseSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(PulseStyle.mint)
            .background(PulseStyle.elevated, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct PulsePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

struct FeatureDestinationLink<Destination: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    let destination: Destination

    init(
        symbol: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(PulseStyle.mint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PulseStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseStyle.muted)
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(PulsePressButtonStyle())
    }
}

extension HealthMetric {
    var symbol: String {
        switch self {
        case .sleepAnalysis: "moon.stars"
        case .stepCount, .walkingRunningDistance, .flightsClimbed: "figure.walk"
        case .activeEnergyBurned, .appleExerciseTime, .workout: "figure.run"
        case .respiratoryRate, .oxygenSaturation: "lungs"
        case .wristTemperature: "thermometer.medium"
        default: "waveform.path.ecg"
        }
    }

    func formattedValue(_ reading: HealthReading?) -> String {
        guard let reading, reading.value.isFinite,
              reading.value >= 0, reading.value < Double(Int.max) / 100 else { return "—" }
        let number = Int(reading.value.rounded())
        switch self {
        case .sleepAnalysis:
            return "\(number / 60) h \(number % 60) min"
        case .appleExerciseTime:
            return "\(number) min"
        case .heartRateVariabilitySDNN:
            return "\(number) ms"
        case .heartRate, .restingHeartRate:
            return "\(number) lpm"
        case .respiratoryRate:
            return "\(number) rpm"
        case .oxygenSaturation:
            return "\(Int((reading.value * 100).rounded())) %"
        case .stepCount:
            return "\(number.formatted()) pasos"
        case .activeEnergyBurned:
            return "\(number) kcal"
        default:
            return number.formatted()
        }
    }

    func provenanceLabel(_ reading: HealthReading?) -> String {
        guard reading != nil else { return "Sin dato reciente" }
        switch self {
        case .sleepAnalysis: return "Calculado de registros · Salud"
        case .stepCount, .activeEnergyBurned, .appleExerciseTime: return "Acumulado · Salud"
        default: return "Muestra · Salud"
        }
    }

    var plainDescription: String {
        switch self {
        case .heartRateVariabilitySDNN:
            "Variación entre latidos sucesivos registrada por Apple Salud. Se muestra la última muestra del día, sin interpretarla como diagnóstico."
        case .sleepAnalysis:
            "Tiempo en etapas de sueño registradas durante la última noche. No incluye el tiempo simplemente en cama."
        case .stepCount:
            "Suma de pasos desde el inicio del día local. Apple Salud puede combinar varias fuentes."
        case .restingHeartRate:
            "Última frecuencia cardiaca en reposo registrada hoy por Apple Salud."
        case .heartRate:
            "Última frecuencia cardiaca registrada hoy; no es una señal continua en tiempo real."
        case .respiratoryRate:
            "Última frecuencia respiratoria registrada hoy, si está disponible."
        case .oxygenSaturation:
            "Última medición de oxígeno en sangre hoy, según dispositivo y región."
        case .activeEnergyBurned:
            "Energía activa acumulada desde el inicio del día local."
        case .appleExerciseTime:
            "Minutos de ejercicio acumulados desde el inicio del día local."
        default:
            "Medición de Apple Salud disponible cuando hay hardware, permisos y muestras compatibles."
        }
    }
}
