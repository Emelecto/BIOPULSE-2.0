import Foundation

/// Daily observations used by the on-device, unsupervised personal anomaly model.
public struct PersonalAnomalyObservation: Sendable {
    public let day: Date
    public let hrvSDNNMilliseconds: Double
    public let restingHeartRateBPM: Double
    public let activeEnergyKilocalories: Double

    public init(day: Date, hrvSDNNMilliseconds: Double, restingHeartRateBPM: Double, activeEnergyKilocalories: Double) {
        self.day = day
        self.hrvSDNNMilliseconds = hrvSDNNMilliseconds
        self.restingHeartRateBPM = restingHeartRateBPM
        self.activeEnergyKilocalories = activeEnergyKilocalories
    }

    fileprivate var features: [Double] {
        [hrvSDNNMilliseconds, restingHeartRateBPM, activeEnergyKilocalories]
    }

    fileprivate var isValid: Bool {
        hrvSDNNMilliseconds.isFinite && hrvSDNNMilliseconds > 0
            && restingHeartRateBPM.isFinite && restingHeartRateBPM > 0
            && activeEnergyKilocalories.isFinite && activeEnergyKilocalories >= 0
    }
}

public struct PersonalAnomalyResult: Sendable {
    public let value: Int?
    public let day: Date
    public let trainingDays: Int
    public let version: String
    public let reason: String

    fileprivate init(value: Int?, day: Date, trainingDays: Int, reason: String) {
        self.value = value
        self.day = day
        self.trainingDays = trainingDays
        self.version = "isolation-forest-personal-v1"
        self.reason = reason
    }
}

/// A small Isolation Forest trained against the same person's recent daily history.
/// Its output is an anomaly score, not a probability or a health risk estimate.
public enum PersonalAnomalyForest {
    private static let minimumTrainingDays = 30
    private static let lookbackDays = 90
    private static let treeCount = 100
    private static let maximumSamplesPerTree = 32

    private indirect enum Node {
        case leaf(size: Int)
        case branch(feature: Int, split: Double, left: Node, right: Node)
    }

    private struct SplitMix64 {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }

        mutating func unitInterval() -> Double {
            Double(next() >> 11) / 9_007_199_254_740_992
        }

        mutating func index(lessThan upperBound: Int) -> Int {
            Int(next() % UInt64(upperBound))
        }
    }

    public static func evaluate(
        _ observations: [PersonalAnomalyObservation],
        on day: Date,
        calendar: Calendar = .current
    ) -> PersonalAnomalyResult {
        let targetDay = calendar.startOfDay(for: day)
        let lookbackStart = calendar.date(byAdding: .day, value: -lookbackDays, to: targetDay) ?? .distantPast
        let valid = observations.filter(\.isValid)
        guard let target = valid.first(where: { calendar.isDate($0.day, inSameDayAs: targetDay) }) else {
            return PersonalAnomalyResult(
                value: nil,
                day: targetDay,
                trainingDays: 0,
                reason: "Para calcular el modelo se necesitan HRV, pulso en reposo y energía activa en el día evaluado."
            )
        }

        let training = valid
            .filter { $0.day >= lookbackStart && calendar.startOfDay(for: $0.day) < targetDay }
            .sorted { $0.day < $1.day }
        guard training.count >= minimumTrainingDays else {
            return PersonalAnomalyResult(
                value: nil,
                day: targetDay,
                trainingDays: training.count,
                reason: "Se necesitan al menos 30 días completos previos con HRV, pulso en reposo y energía activa; hay \(training.count)."
            )
        }

        let model = Forest(training: training.map(\.features), targetDay: targetDay)
        let score = model.anomalyScore(for: target.features)
        let index = Int((score * 100).rounded()).clamped(to: 0...100)
        return PersonalAnomalyResult(
            value: index,
            day: targetDay,
            trainingDays: training.count,
            reason: "Isolation Forest personal · \(training.count) días de referencia. Un valor mayor indica que la combinación de señales se aísla más de tu patrón reciente; no es una probabilidad ni un diagnóstico."
        )
    }

    private struct Forest {
        let trees: [Node]
        let sampleSize: Int

        init(training: [[Double]], targetDay: Date) {
            let sampleSize = min(training.count, maximumSamplesPerTree)
            self.sampleSize = sampleSize
            let heightLimit = Int(ceil(log2(Double(max(sampleSize, 2)))))
            var random = SplitMix64(state: UInt64(bitPattern: Int64(targetDay.timeIntervalSince1970.rounded())) ^ 0x0B10_B15E)
            self.trees = (0..<treeCount).map { _ in
                let sample = Self.sample(training, count: sampleSize, using: &random)
                return Self.build(sample, depth: 0, heightLimit: heightLimit, using: &random)
            }
        }

        func anomalyScore(for features: [Double]) -> Double {
            let averagePathLength = trees.reduce(0.0) { $0 + Self.pathLength(features, in: $1, depth: 0) } / Double(trees.count)
            let normalization = Self.averagePathLength(for: sampleSize)
            guard normalization > 0 else { return 0.5 }
            return pow(2, -averagePathLength / normalization)
        }

        private static func sample(_ rows: [[Double]], count: Int, using random: inout SplitMix64) -> [[Double]] {
            var indices = Array(rows.indices)
            if indices.count > count {
                for index in 0..<count {
                    let selected = index + random.index(lessThan: indices.count - index)
                    indices.swapAt(index, selected)
                }
                indices = Array(indices.prefix(count))
            }
            return indices.map { rows[$0] }
        }

        private static func build(_ rows: [[Double]], depth: Int, heightLimit: Int, using random: inout SplitMix64) -> Node {
            guard rows.count > 1, depth < heightLimit else { return .leaf(size: rows.count) }
            let featureCount = rows[0].count
            let splittable = (0..<featureCount).filter { feature in
                let values = rows.map { $0[feature] }
                return (values.min() ?? 0) < (values.max() ?? 0)
            }
            guard !splittable.isEmpty else { return .leaf(size: rows.count) }

            let feature = splittable[random.index(lessThan: splittable.count)]
            let values = rows.map { $0[feature] }
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 0
            let split = minimum + random.unitInterval() * (maximum - minimum)
            let leftRows = rows.filter { $0[feature] < split }
            let rightRows = rows.filter { $0[feature] >= split }
            guard !leftRows.isEmpty, !rightRows.isEmpty else { return .leaf(size: rows.count) }

            return .branch(
                feature: feature,
                split: split,
                left: build(leftRows, depth: depth + 1, heightLimit: heightLimit, using: &random),
                right: build(rightRows, depth: depth + 1, heightLimit: heightLimit, using: &random)
            )
        }

        private static func pathLength(_ features: [Double], in node: Node, depth: Int) -> Double {
            switch node {
            case let .leaf(size):
                Double(depth) + averagePathLength(for: size)
            case let .branch(feature, split, left, right):
                pathLength(features, in: features[feature] < split ? left : right, depth: depth + 1)
            }
        }

        private static func averagePathLength(for size: Int) -> Double {
            guard size > 2 else { return size == 2 ? 1 : 0 }
            let harmonic = (1..<size).reduce(0.0) { $0 + 1 / Double($1) }
            return 2 * harmonic - 2 * Double(size - 1) / Double(size)
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
