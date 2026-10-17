import SwiftUI
import UIKit

enum PulseStyle {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.055)
    static let surface = Color(red: 0.09, green: 0.105, blue: 0.115)
    static let elevated = Color(red: 0.14, green: 0.16, blue: 0.17)
    // Navigation and controls stay neutral; only validated scores receive semantic colors.
    static let mint = Color.white
    static let secondary = Color(red: 0.77, green: 0.79, blue: 0.80)
    static let muted = Color(red: 0.60, green: 0.63, blue: 0.65)
    static let lavender = Color.white
    static let warning = Color(red: 1, green: 0.72, blue: 0.67)
}

// Observatorio personal: landscape behind opaque readings, materials for floating controls.
// Motion follows actions; decoration never represents physiological measurements.
struct PulseSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    var accent: Color = PulseStyle.mint
    var prominent = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: prominent ? 24 : 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [prominent ? PulseStyle.elevated : PulseStyle.surface, PulseStyle.surface],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [accent.opacity(0.13), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: prominent ? 24 : 18, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: prominent ? 24 : 18, style: .continuous)
                            .strokeBorder(LinearGradient(
                                colors: [.white.opacity(contrast == .increased ? 0.7 : 0.24), .white.opacity(0.03)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(prominent ? 0.3 : 0.18), radius: prominent ? 18 : 10, x: 0, y: prominent ? 12 : 6)
            }
    }
}

extension View {
    func pulseSurface(accent: Color = PulseStyle.mint, prominent: Bool = false) -> some View {
        modifier(PulseSurface(accent: accent, prominent: prominent))
    }

    func pulseEntrance(visible: Bool, reduceMotion: Bool, delay: Double = 0) -> some View {
        opacity(visible ? 1 : 0.85)
            .offset(y: visible || reduceMotion ? 0 : 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(delay), value: visible)
    }
}

struct PulseBackdrop: View {
    var forest = false
    var accent: Color = PulseStyle.mint

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                PulseStyle.background
                RadialGradient(colors: [.white.opacity(0.045), .clear], center: .topLeading, startRadius: 0, endRadius: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Landscape contours, decorative only: never a chart or a health signal.
struct PulseContours: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<5 {
            let y = rect.height * (0.15 + Double(index) * 0.16)
            path.move(to: CGPoint(x: 0, y: y + rect.height * 0.25))
            path.addCurve(to: CGPoint(x: rect.width, y: y),
                          control1: CGPoint(x: rect.width * 0.35, y: y - rect.height * 0.5),
                          control2: CGPoint(x: rect.width * 0.65, y: y + rect.height * 0.55))
        }
        return path
    }
}

struct PulseIcon: View {
    let symbol: String
    var accent: Color = PulseStyle.mint

    var body: some View {
        Image(systemName: symbol)
            .font(.title3.weight(.medium))
            .foregroundStyle(accent)
            .frame(width: 44, height: 44)
            .background(LinearGradient(colors: [accent.opacity(0.18), accent.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }
}

struct PulseFeedback: View {
    let message: String
    var isError = false

    var body: some View {
        Label(message, systemImage: isError ? "exclamationmark.circle" : "checkmark.circle")
            .font(.subheadline)
            .foregroundStyle(isError ? PulseStyle.warning : PulseStyle.mint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.updatesFrequently)
            .transition(.opacity)
            .onChange(of: message, initial: true) { _, value in
                UIAccessibility.post(notification: .announcement, argument: value)
            }
    }
}

struct PulseInputSurface: ViewModifier {
    let focused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(.white)
            .frame(minHeight: 50)
            .background(PulseStyle.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(focused ? PulseStyle.mint : .white.opacity(contrast == .increased ? 0.65 : 0.16), lineWidth: focused ? 2 : 1)
                    .allowsHitTesting(false)
            }
    }
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
            PulseIcon(symbol: symbol)
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
        .pulseSurface()
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
                DashboardPageHeader(title: title)
                    .padding(.top, 15)
                Text(subtitle).font(.subheadline).foregroundStyle(PulseStyle.secondary)
                content
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background { PulseBackdrop() }
    }
}

struct PulseActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(PulseStyle.background)
            .background(LinearGradient(colors: [.white, Color(red: 0.86, green: 0.87, blue: 0.88)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.24), radius: configuration.isPressed ? 2 : 8, x: 0, y: configuration.isPressed ? 1 : 5)
            .opacity(!isEnabled ? 0.5 : configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct PulseSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(PulseStyle.mint)
            .pulseSurface()
            .opacity(!isEnabled ? 0.5 : configuration.isPressed ? 0.72 : 1)
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
                PulseIcon(symbol: symbol)
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
            .pulseSurface()
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
        if reading?.sourceName.hasPrefix("CSV") == true { return "Agregado diario · CSV" }
        switch self {
        case .sleepAnalysis: return "Calculado de registros · Salud"
        case .stepCount, .activeEnergyBurned, .appleExerciseTime: return "Acumulado · Salud"
        case .heartRateVariabilitySDNN: return "Media de hoy · Salud"
        default: return "Muestra · Salud"
        }
    }

    var plainDescription: String {
        switch self {
        case .heartRateVariabilitySDNN:
            "Variación entre latidos sucesivos registrada por Apple Salud. Se muestra la media de las muestras de hoy, sin interpretarla como diagnóstico."
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

    var possibleInfluencesDescription: String {
        switch self {
        case .heartRateVariabilitySDNN, .restingHeartRate, .heartRate:
            "El momento y las circunstancias del registro, el dispositivo y las muestras que llegan a Apple Salud pueden influir en el valor observado. Esta pantalla no separa esos factores ni atribuye una causa."
        case .sleepAnalysis:
            "El dispositivo, la cobertura y qué intervalos se registraron influyen en el tiempo mostrado. BioPulse suma etapas marcadas como sueño; no estima lo que no se registró."
        case .stepCount, .walkingRunningDistance, .flightsClimbed:
            "El dispositivo que llevabas, las fuentes disponibles y la cobertura del día influyen en el total. Apple Salud puede combinar fuentes compatibles."
        case .activeEnergyBurned, .appleExerciseTime, .workout:
            "El dispositivo, la fuente y cómo se registró la actividad pueden cambiar qué aparece en Apple Salud. Un día sin registro no equivale a inactividad."
        case .respiratoryRate, .oxygenSaturation, .wristTemperature:
            "La disponibilidad depende del hardware, del momento de medición y de la cobertura. BioPulse no completa lecturas ausentes ni usa una muestra aislada para concluir una causa."
        default:
            "La fuente, el dispositivo, el momento y la cobertura disponible pueden influir en lo que se observa. La pantalla no identifica por sí sola qué factor explica una variación."
        }
    }
}
