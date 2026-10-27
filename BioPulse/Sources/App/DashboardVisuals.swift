import SwiftUI

/// Visual mapping only. A score is never inferred from a raw HealthKit value here.
enum ScoreColor {
    private struct Anchor {
        let score: Double
        let red: Double
        let green: Double
        let blue: Double
    }

    private static let anchors: [Anchor] = [
        Anchor(score: 0, red: 232, green: 79, blue: 88),
        Anchor(score: 25, red: 231, green: 122, blue: 63),
        Anchor(score: 50, red: 229, green: 198, blue: 74),
        Anchor(score: 70, red: 185, green: 203, blue: 89),
        Anchor(score: 82, red: 169, green: 217, blue: 104),
        Anchor(score: 90, red: 76, green: 203, blue: 114),
        Anchor(score: 100, red: 24, green: 199, blue: 96)
    ]

    static func color(for score: Double?) -> Color {
        guard let score, score.isFinite, (0...100).contains(score) else { return .white }
        let value = score
        guard let upperIndex = anchors.firstIndex(where: { value <= $0.score }) else { return .white }
        let upper = anchors[upperIndex]
        let lower = anchors[max(upperIndex - 1, 0)]
        let fraction = upper.score == lower.score ? 0 : (value - lower.score) / (upper.score - lower.score)
        func channel(_ from: Double, _ to: Double) -> Double { (from + (to - from) * fraction) / 255 }
        return Color(red: channel(lower.red, upper.red), green: channel(lower.green, upper.green), blue: channel(lower.blue, upper.blue))
    }
}

struct DashboardPageHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image("BioPulseBrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                Text("BioPulse")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(PulseStyle.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct DashboardCard<Content: View>: View {
    var accent: Color = .white
    let content: Content

    init(accent: Color = .white, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PulseStyle.surface)
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(RadialGradient(colors: [accent.opacity(0.09), .clear], center: .topLeading, startRadius: 0, endRadius: 220))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 7)
            }
    }
}

/// The strands are decorative, not a progress indicator. A missing score stays neutral.
struct OrganicScoreRing: View {
    let score: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = ScoreColor.color(for: score)
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 0.22
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.42
                for strand in 0..<4 {
                    var path = Path()
                    for step in 0...180 {
                        let angle = Double(step) / 180 * Double.pi * 2
                        let ripple = sin(angle * Double(5 + strand) + phase + Double(strand) * 1.4) * 3.5
                        let drift = sin(angle * 3 - phase * 0.6 + Double(strand)) * 2
                        let distance = radius + ripple + drift + Double(strand - 2) * 2
                        let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                        if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(tint.opacity(strand == 0 ? 0.82 : 0.38)), lineWidth: strand == 0 ? 1.8 : 0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct PendingScoreHero: View {
    let title: String
    var score: Double? = nil
    var subtitle: String = "Puntuación en preparación"
    @ScaledMetric(relativeTo: .body) private var ringHeight: CGFloat = 176

    private var validScore: Double? {
        guard let score, score.isFinite, (0...100).contains(score) else { return nil }
        return score
    }

    var body: some View {
        ZStack {
            OrganicScoreRing(score: validScore)
            VStack(spacing: 5) {
                Text(title).font(.subheadline).foregroundStyle(PulseStyle.secondary)
                Text(validScore.map { String(Int($0.rounded())) } ?? "—")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .contentTransition(.numericText())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PulseStyle.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ringHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(validScore.map { "\(title): \(Int($0.rounded())) de 100. \(subtitle)" } ?? "\(title): puntuación aún no disponible")
    }
}

struct DashboardEmptyChart: View {
    let message: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(PulseStyle.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
