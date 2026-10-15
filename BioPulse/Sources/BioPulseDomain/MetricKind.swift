import Foundation

public enum MetricKind: String, CaseIterable, Codable, Sendable {
    case heartRate
    case restingHeartRate
    case heartRateVariabilitySDNN
    case sleepDuration
    case respiratoryRate
    case oxygenSaturation
    case wristTemperatureDeviation
    case stepCount
    case walkingRunningDistance
    case activeEnergyBurned
    case exerciseDuration
    case flightsClimbed
    case vo2Max
    case heartRateRecoveryOneMinute

    public var expectedUnit: MetricUnit {
        switch self {
        case .heartRate, .restingHeartRate, .heartRateRecoveryOneMinute:
            .beatsPerMinute
        case .heartRateVariabilitySDNN:
            .milliseconds
        case .sleepDuration, .exerciseDuration:
            .minutes
        case .respiratoryRate:
            .breathsPerMinute
        case .oxygenSaturation:
            .percent
        case .wristTemperatureDeviation:
            .celsiusDelta
        case .stepCount, .flightsClimbed:
            .count
        case .walkingRunningDistance:
            .meters
        case .activeEnergyBurned:
            .kilocalories
        case .vo2Max:
            .millilitersPerKilogramPerMinute
        }
    }
}

public enum MetricUnit: String, Codable, Sendable {
    case beatsPerMinute
    case milliseconds
    case minutes
    case breathsPerMinute
    case percent
    case celsiusDelta
    case count
    case meters
    case kilocalories
    case millilitersPerKilogramPerMinute
}

public enum MetricAggregation: String, Codable, Sendable {
    case mean
    case median
    case sum
    case minimum
    case maximum
    case duration
    case latest
}
