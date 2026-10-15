import Foundation

enum HealthMetric: String, CaseIterable, Sendable, Identifiable, Hashable {
    case heartRate
    case restingHeartRate
    case heartRateVariabilitySDNN
    case sleepAnalysis
    case respiratoryRate
    case oxygenSaturation
    case wristTemperature
    case stepCount
    case walkingRunningDistance
    case activeEnergyBurned
    case appleExerciseTime
    case flightsClimbed
    case workout
    case vo2Max
    case heartRateRecoveryOneMinute

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heartRate: return "Frecuencia cardiaca"
        case .restingHeartRate: return "Frecuencia cardiaca en reposo"
        case .heartRateVariabilitySDNN: return "Variabilidad cardiaca (SDNN)"
        case .sleepAnalysis: return "Sueño"
        case .respiratoryRate: return "Frecuencia respiratoria"
        case .oxygenSaturation: return "Oxígeno en sangre"
        case .wristTemperature: return "Temperatura de muñeca durante el sueño"
        case .stepCount: return "Pasos"
        case .walkingRunningDistance: return "Distancia caminando o corriendo"
        case .activeEnergyBurned: return "Energía activa"
        case .appleExerciseTime: return "Tiempo de ejercicio"
        case .flightsClimbed: return "Pisos subidos"
        case .workout: return "Entrenamientos"
        case .vo2Max: return "VO₂ máximo"
        case .heartRateRecoveryOneMinute: return "Recuperación cardiaca al minuto"
        }
    }

    var tier: HealthMetricTier {
        switch self {
        case .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
             .sleepAnalysis, .stepCount, .walkingRunningDistance,
             .activeEnergyBurned, .appleExerciseTime, .workout:
            .core
        case .respiratoryRate, .oxygenSaturation, .wristTemperature,
             .flightsClimbed, .vo2Max, .heartRateRecoveryOneMinute:
            .enhanced
        }
    }
}

enum HealthMetricTier: String, Sendable {
    case core
    case enhanced
    case advanced
}

enum HealthMetricCapabilityState: String, Sendable {
    case supported
    case authorizationRequestNeeded
    case readAccessIndeterminate
    case noSamples
    case partial
    case restricted
    case unsupported
    case invalid
}

struct HealthMetricCapability: Identifiable, Sendable {
    let metric: HealthMetric
    let state: HealthMetricCapabilityState
    let detail: String?

    var id: HealthMetric { metric }
}
