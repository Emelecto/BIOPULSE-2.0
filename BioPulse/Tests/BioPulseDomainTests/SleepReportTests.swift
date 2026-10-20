import Foundation
import Testing
@testable import BioPulseDomain

// All dates and physiological values below are synthetic test fixtures, not user measurements.

struct SleepReportTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_760_400_000))!
    }
    private func report(_ offset: Int, duration: Int = 480, preferManual: Bool = false) throws -> SleepReport {
        try SleepReport(wakeDate: day(offset), durationMinutes: duration, restfulness: 4, quality: 3,
                        preferManual: preferManual, recordedAt: day(40), calendar: calendar)
    }

    @Test func manuallyReportedNightsEnableScoresOnlyWithEnoughHistory() throws {
        let oneNight = ResolvedSleepValues.resolve(observed: [], reports: [try report(14)], calendar: calendar)
        #expect(WellnessScores.sleep(oneNight.values, day: day(14), calendar: calendar).value == nil)
        let reports = try (0...14).map { try report($0) }
        let sleepOnly = ResolvedSleepValues.resolve(observed: [], reports: reports, calendar: calendar)
        #expect(WellnessScores.sleep(sleepOnly.values, day: day(14), calendar: calendar).value == 100)
        #expect(WellnessScores.bio(sleepOnly.values, day: day(14), calendar: calendar).value == nil)
        let physiology = (0...14).flatMap { offset in
            [WellnessValue(day: day(offset), metric: .heartRateVariabilitySDNN, value: 50),
             WellnessValue(day: day(offset), metric: .restingHeartRate, value: 60),
             WellnessValue(day: day(offset), metric: .activeEnergyBurned, value: 400)]
        }
        let resolved = ResolvedSleepValues.resolve(observed: physiology, reports: reports, calendar: calendar)
        #expect(WellnessScores.bio(resolved.values, day: day(14), calendar: calendar).value == 91)
        #expect(resolved.includesSelfReport(on: day(14), calendar: calendar))
    }

    @Test func choosesOneSourcePerNightAndPreservesOtherSignals() throws {
        let observed = [WellnessValue(day: day(0), metric: .sleepDuration, value: 420),
                        WellnessValue(day: day(0), metric: .heartRateVariabilitySDNN, value: 50)]
        let defaultSource = ResolvedSleepValues.resolve(observed: observed, reports: [try report(0)], calendar: calendar)
        #expect(defaultSource.values.filter { $0.metric == .sleepDuration }.map(\.value) == [420])
        #expect(defaultSource.reportedDays.isEmpty)
        let preferred = ResolvedSleepValues.resolve(observed: observed, reports: [try report(0, preferManual: true)], calendar: calendar)
        #expect(preferred.values.filter { $0.metric == .sleepDuration }.map(\.value) == [480])
        #expect(preferred.values.filter { $0.metric == .heartRateVariabilitySDNN }.map(\.value) == [50])
        let restored = ResolvedSleepValues.resolve(observed: observed,
            reports: [try report(0, preferManual: true),
                      try SleepReport(wakeDate: day(0), durationMinutes: 470, restfulness: 3, quality: 4,
                                      recordedAt: day(41), calendar: calendar)], calendar: calendar)
        #expect(restored.values.filter { $0.metric == .sleepDuration }.map(\.value) == [420])
        #expect(restored.reportedDays.isEmpty)
    }

    @Test func editingOrDuplicatingNightDoesNotAccelerateCalibration() throws {
        let reports = [try report(0), try report(0, duration: 390)]
        let resolved = ResolvedSleepValues.resolve(observed: [], reports: reports, calendar: calendar)
        #expect(resolved.values.count == 1)
        let progress = WellnessScores.calibration(resolved.values, day: day(1), includeBiometrics: false, calendar: calendar)
        #expect(progress.first?.available == 1)
        let repeated = (0..<8).map { _ in WellnessValue(day: day(0), metric: .sleepDuration, value: 480) }
            + [WellnessValue(day: day(1), metric: .sleepDuration, value: 480)]
        #expect(WellnessScores.sleep(repeated, day: day(1), calendar: calendar).value == nil)
    }

    @Test func calibrationExcludesEvaluatedDayFutureAndExpiredHistory() throws {
        let reports = try [-20, -14, -1, 0, 1].map { try report($0) }
        let resolved = ResolvedSleepValues.resolve(observed: [], reports: reports, calendar: calendar)
        let progress = WellnessScores.calibration(resolved.values, day: day(0), includeBiometrics: true, calendar: calendar)
        #expect(progress.first?.available == 2)
        #expect(progress.first?.required == 7)
        #expect(progress.dropFirst().allSatisfy { $0.available == 0 && $0.required == 14 })
    }

    @Test func permitsExplicitSleeplessNightAndRejectsInvalidAnswers() throws {
        let reports = try (0...7).map { try report($0, duration: $0 == 7 ? 0 : 480) }
        let resolved = ResolvedSleepValues.resolve(observed: [], reports: reports, calendar: calendar)
        #expect(WellnessScores.sleep(resolved.values, day: day(7), calendar: calendar).value == 0)
        let observedZeros = (0...7).map { WellnessValue(day: day($0), metric: .sleepDuration, value: 0) }
        #expect(WellnessScores.sleep(observedZeros, day: day(7), calendar: calendar).value == nil)
        #expect(WellnessScores.calibration(observedZeros, day: day(7), includeBiometrics: false, calendar: calendar).first?.available == 0)
        #expect(throws: SleepReportError.self) { try report(0, duration: 1441) }
        #expect(throws: SleepReportError.self) {
            try SleepReport(wakeDate: day(0), durationMinutes: 480, restfulness: 0, quality: 3, recordedAt: day(1))
        }
        #expect(throws: SleepReportError.self) {
            try SleepReport(wakeDate: day(1), durationMinutes: 480, restfulness: 3, quality: 3, recordedAt: day(0), calendar: calendar)
        }
    }

    @Test func subjectiveFeedbackIsPreservedButDoesNotChangeFormula() throws {
        let first = try report(0)
        let second = try SleepReport(id: first.id, wakeDate: day(0), durationMinutes: 480, restfulness: 1, quality: 1,
                                     awakenings: 3, factors: [.noise, .stress], note: "Me desperté varias veces",
                                     recordedAt: day(40), calendar: calendar)
        let decoded = try JSONDecoder().decode(SleepReport.self, from: JSONEncoder().encode(second))
        #expect(decoded == second)
        let a = ResolvedSleepValues.resolve(observed: [], reports: [first], calendar: calendar)
        let b = ResolvedSleepValues.resolve(observed: [], reports: [second], calendar: calendar)
        #expect(a.values.map(\.value) == b.values.map(\.value))
    }

    @Test func civilWakeDateIsPreservedWhenTimeZoneChanges() throws {
        let report = try report(0)
        var otherCalendar = calendar
        otherCalendar.timeZone = try #require(TimeZone(identifier: "America/Bogota"))
        let date = try #require(report.date(calendar: otherCalendar))
        let components = otherCalendar.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == report.wakeDay.year)
        #expect(components.month == report.wakeDay.month)
        #expect(components.day == report.wakeDay.day)
    }

    @Test func decodingRejectsCorruptRatings() throws {
        let report = try report(0)
        let data = try JSONEncoder().encode(report)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["restfulness"] = 12
        let corrupt = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: SleepReportError.self) { try JSONDecoder().decode(SleepReport.self, from: corrupt) }
    }
}
