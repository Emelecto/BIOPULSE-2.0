import Foundation
import Testing
@testable import BioPulseDomain

struct CSVImporterTests {
    private let timeZone = TimeZone(identifier: "America/Bogota")!

    @Test func importsASupportedTidyMeasurement() throws {
        let csv = """
        type,sourceName,unit,startDate,endDate,value
        heartRate,simulated-test-fixture,count/min,2026-10-13T08:30:00Z,2026-10-13T08:30:00Z,62
        """

        let result = try CSVImporter.import(csv, timeZone: timeZone)
        let record = try #require(result.records.first)
        let expectedDay = try LocalDay(year: 2026, month: 10, day: 13, timeZoneIdentifier: "America/Bogota")

        #expect(result.format == .tidy)
        #expect(record.metric == .heartRate)
        #expect(record.unit == .beatsPerMinute)
        #expect(record.source == .csvImport)
        #expect(record.quality == .observed)
        #expect(record.day == expectedDay)
    }

    @Test func preservesABlankWideMetricAsAbsent() throws {
        let csv = """
        date,heartRate,heartRateVariabilitySDNN,sleepEfficiency
        2026-10-13,62,,95
        """

        let result = try CSVImporter.import(csv, timeZone: timeZone)

        #expect(result.format == .wide)
        #expect(result.records.count == 1)
        #expect(result.records.first?.metric == .heartRate)
        #expect(result.unmappedColumns == ["sleepefficiency"])
        #expect(result.warnings.count == 1)
    }

    @Test func rejectsAmbiguousDatesAndIncompatibleUnits() throws {
        let invalidDateCSV = """
        date,heartRate
        13/10/2026,62
        """
        let invalidUnitCSV = """
        type,sourceName,unit,startDate,endDate,value
        heartRate,simulated-test-fixture,ms,2026-10-13T08:30:00Z,2026-10-13T08:30:00Z,62
        """

        let invalidDateResult = try CSVImporter.import(invalidDateCSV, timeZone: timeZone)
        let invalidUnitResult = try CSVImporter.import(invalidUnitCSV, timeZone: timeZone)

        #expect(invalidDateResult.records.isEmpty)
        #expect(invalidDateResult.rejectedRows.count == 1)
        #expect(invalidUnitResult.records.isEmpty)
        #expect(invalidUnitResult.rejectedRows.count == 1)
    }
}
