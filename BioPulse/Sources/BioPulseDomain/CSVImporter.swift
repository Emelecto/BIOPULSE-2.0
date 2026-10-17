import Foundation

public enum CSVFormat: String, Codable, Sendable {
    case tidy
    case wide
}

public struct CSVRejectedRow: Codable, Equatable, Sendable {
    public let rowNumber: Int
    public let column: String?
    public let reason: String

    public init(rowNumber: Int, column: String? = nil, reason: String) {
        self.rowNumber = rowNumber
        self.column = column
        self.reason = reason
    }
}

public struct CSVImportWarning: Codable, Equatable, Sendable {
    public let rowNumber: Int?
    public let column: String?
    public let message: String

    public init(rowNumber: Int? = nil, column: String? = nil, message: String) {
        self.rowNumber = rowNumber
        self.column = column
        self.message = message
    }
}

public struct CSVImportResult: Codable, Equatable, Sendable {
    public let format: CSVFormat
    public let records: [DailyMetric]
    public let mappedColumns: [String: MetricKind]
    public let unmappedColumns: [String]
    public let warnings: [CSVImportWarning]
    public let rejectedRows: [CSVRejectedRow]

    public init(
        format: CSVFormat,
        records: [DailyMetric],
        mappedColumns: [String: MetricKind],
        unmappedColumns: [String],
        warnings: [CSVImportWarning],
        rejectedRows: [CSVRejectedRow]
    ) {
        self.format = format
        self.records = records
        self.mappedColumns = mappedColumns
        self.unmappedColumns = unmappedColumns
        self.warnings = warnings
        self.rejectedRows = rejectedRows
    }
}

public enum CSVImportError: Error, Equatable, Sendable {
    case emptyFile
    case malformedQuotedField
    case duplicateHeader(String)
    case unsupportedHeader
}

public enum CSVImporter {
    public static func `import`(
        _ text: String,
        timeZone: TimeZone
    ) throws -> CSVImportResult {
        let rows = try parseRows(text)
        guard let header = rows.first, !header.isEmpty else { throw CSVImportError.emptyFile }

        let normalizedHeaders = header.map(normalizeHeader)
        guard Set(normalizedHeaders).count == normalizedHeaders.count else {
            let duplicate = firstDuplicate(in: normalizedHeaders) ?? ""
            throw CSVImportError.duplicateHeader(duplicate)
        }

        if isTidyHeader(normalizedHeaders) {
            return importTidy(rows: Array(rows.dropFirst()), headers: normalizedHeaders, timeZone: timeZone)
        }
        if normalizedHeaders.contains("date") {
            return importWide(rows: Array(rows.dropFirst()), headers: normalizedHeaders, timeZone: timeZone)
        }
        throw CSVImportError.unsupportedHeader
    }

    private static func importTidy(
        rows: [[String]],
        headers: [String],
        timeZone: TimeZone
    ) -> CSVImportResult {
        let columnIndex = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($0.element, $0.offset) })
        var records: [DailyMetric] = []
        var warnings: [CSVImportWarning] = []
        var rejectedRows: [CSVRejectedRow] = []
        var mappedColumns: [String: MetricKind] = [:]
        var unsupportedTypes = Set<String>()

        for (offset, row) in rows.enumerated() {
            let rowNumber = offset + 2
            guard row.count == headers.count else {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, reason: "El número de campos no coincide con el encabezado."))
                continue
            }

            let type = value(named: "type", from: row, indexes: columnIndex)
            let unit = value(named: "unit", from: row, indexes: columnIndex)
            let startDate = value(named: "startdate", from: row, indexes: columnIndex)
            let sourceName = value(named: "sourcename", from: row, indexes: columnIndex)
            let rawValue = value(named: "value", from: row, indexes: columnIndex)

            guard let metric = metricKind(for: type) else {
                if unsupportedTypes.insert(type).inserted {
                    warnings.append(CSVImportWarning(rowNumber: rowNumber, column: "type", message: "El tipo \(type) no está soportado; sus filas no se importaron."))
                }
                continue
            }
            mappedColumns["type"] = metric

            guard let day = localDay(fromISO8601: startDate, fallbackTimeZone: timeZone) else {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, column: "startDate", reason: "La fecha debe incluir día y zona horaria reconocibles."))
                continue
            }
            guard let sourceValue = Double(rawValue), sourceValue.isFinite else {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, column: "value", reason: "El valor debe ser numérico y finito."))
                continue
            }
            guard let metricUnit = metricUnit(for: unit, metric: metric), metricUnit == metric.expectedUnit else {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, column: "unit", reason: "La unidad no coincide con la métrica canónica."))
                continue
            }
            let numericValue = normalizedValue(sourceValue, unit: unit, metric: metric)

            do {
                let record = try DailyMetric(
                    day: day,
                    metric: metric,
                    value: numericValue,
                    unit: metricUnit,
                    aggregation: defaultAggregation(for: metric),
                    sampleCount: 1,
                    coverage: 1,
                    source: .csvImport,
                    quality: .observed,
                    sourceReferences: ["csv-row-\(rowNumber)", sourceName].filter { !$0.isEmpty }
                )
                records.append(record)
            } catch {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, reason: "No se pudo normalizar la métrica: \(error)."))
            }
        }

        if !records.isEmpty {
            warnings.append(CSVImportWarning(message: "Los totales de actividad se suman por día a partir de las filas del archivo. Si el CSV contiene muestras solapadas de varios dispositivos, el total puede diferir del agregado de Apple Salud."))
        }

        return CSVImportResult(
            format: .tidy,
            records: records,
            mappedColumns: mappedColumns,
            unmappedColumns: [],
            warnings: warnings,
            rejectedRows: rejectedRows
        )
    }

    private static func importWide(
        rows: [[String]],
        headers: [String],
        timeZone: TimeZone
    ) -> CSVImportResult {
        var mappedColumns: [String: MetricKind] = [:]
        var unmappedColumns: [String] = []

        for header in headers where header != "date" {
            if let metric = metricKind(for: header) {
                mappedColumns[header] = metric
            } else {
                unmappedColumns.append(header)
            }
        }

        let dateIndex = headers.firstIndex(of: "date") ?? 0
        var records: [DailyMetric] = []
        var warnings: [CSVImportWarning] = []
        var rejectedRows: [CSVRejectedRow] = []

        for (offset, row) in rows.enumerated() {
            let rowNumber = offset + 2
            guard row.count == headers.count else {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, reason: "El número de campos no coincide con el encabezado."))
                continue
            }
            guard let day = localDay(fromDateOnly: row[dateIndex], timeZone: timeZone) else {
                rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, column: "date", reason: "La fecha debe usar el formato no ambiguo YYYY-MM-DD."))
                continue
            }

            for (index, header) in headers.enumerated() {
                guard let metric = mappedColumns[header] else { continue }
                let rawValue = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawValue.isEmpty else { continue }
                guard let numericValue = Double(rawValue), numericValue.isFinite else {
                    rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, column: header, reason: "El valor debe ser numérico y finito."))
                    continue
                }

                do {
                    records.append(try DailyMetric(
                        day: day,
                        metric: metric,
                        value: numericValue,
                        unit: metric.expectedUnit,
                        aggregation: defaultAggregation(for: metric),
                        sampleCount: 1,
                        coverage: 1,
                        source: .csvImport,
                        quality: .observed,
                        sourceReferences: ["csv-row-\(rowNumber)", "column-\(header)"]
                    ))
                } catch {
                    rejectedRows.append(CSVRejectedRow(rowNumber: rowNumber, column: header, reason: "No se pudo normalizar la métrica: \(error)."))
                }
            }
        }

        if !unmappedColumns.isEmpty {
            warnings.append(CSVImportWarning(message: "Hay columnas sin un mapeo canónico y no se importaron."))
        }

        return CSVImportResult(
            format: .wide,
            records: records,
            mappedColumns: mappedColumns,
            unmappedColumns: unmappedColumns,
            warnings: warnings,
            rejectedRows: rejectedRows
        )
    }

    private static func isTidyHeader(_ headers: [String]) -> Bool {
        Set(["type", "sourcename", "unit", "startdate", "enddate", "value"]).isSubset(of: Set(headers))
    }

    private static func value(named name: String, from row: [String], indexes: [String: Int]) -> String {
        guard let index = indexes[name] else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func metricKind(for rawName: String) -> MetricKind? {
        switch normalizeHeader(rawName) {
        case "heartrate", "hkquantitytypeidentifierheartrate": .heartRate
        case "restingheartrate", "hkquantitytypeidentifierrestingheartrate": .restingHeartRate
        case "heartratevariabilitysdnn", "hkquantitytypeidentifierheartratevariabilitysdnn": .heartRateVariabilitySDNN
        case "sleepduration": .sleepDuration
        case "respiratoryrate", "hkquantitytypeidentifierrespiratoryrate": .respiratoryRate
        case "oxygensaturation", "hkquantitytypeidentifieroxygensaturation": .oxygenSaturation
        case "wristtemperaturedeviation": .wristTemperatureDeviation
        case "stepcount", "hkquantitytypeidentifierstepcount": .stepCount
        case "walkingrunningdistance", "hkquantitytypeidentifierdistancewalkingrunning": .walkingRunningDistance
        case "walkingheartrateaverage", "hkquantitytypeidentifierwalkingheartrateaverage": .heartRate
        case "activeenergyburned", "hkquantitytypeidentifieractiveenergyburned": .activeEnergyBurned
        case "appleexercisetime", "hkquantitytypeidentifierappleexercisetime": .exerciseDuration
        case "flightsclimbed", "hkquantitytypeidentifierflightsclimbed": .flightsClimbed
        case "vo2max", "hkquantitytypeidentifiervo2max": .vo2Max
        case "heartraterecoveryoneminute": .heartRateRecoveryOneMinute
        default: nil
        }
    }

    private static func metricUnit(for rawUnit: String, metric: MetricKind) -> MetricUnit? {
        switch rawUnit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "count/min", "bpm": .beatsPerMinute
        case "ms": .milliseconds
        case "min", "minute", "minutes": .minutes
        case "breaths/min": .breathsPerMinute
        case "%", "percent": .percent
        case "degc", "°c", "celsius-delta": .celsiusDelta
        case "count": .count
        case "m": .meters
        case "km": metric == .walkingRunningDistance ? .meters : nil
        case "kcal": .kilocalories
        case "ml/(kg*min)", "ml/kg/min": .millilitersPerKilogramPerMinute
        default: nil
        }
    }

    private static func normalizedValue(_ value: Double, unit: String, metric: MetricKind) -> Double {
        if metric == .walkingRunningDistance, unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "km" {
            return value * 1_000
        }
        return value
    }

    private static func defaultAggregation(for metric: MetricKind) -> MetricAggregation {
        switch metric {
        case .stepCount, .walkingRunningDistance, .activeEnergyBurned, .exerciseDuration, .flightsClimbed, .sleepDuration:
            .sum
        case .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .respiratoryRate, .oxygenSaturation, .wristTemperatureDeviation, .vo2Max:
            .median
        case .heartRateRecoveryOneMinute:
            .latest
        }
    }

    private static func localDay(fromISO8601 string: String, fallbackTimeZone: TimeZone) -> LocalDay? {
        if !string.contains("T"), let date = appleExportDate(string) {
            return LocalDay(date: date, timeZone: fallbackTimeZone)
        }
        let formatters = [
            ISO8601DateFormatter(),
            ISO8601DateFormatter()
        ]
        formatters[0].formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatters[1].formatOptions = [.withInternetDateTime]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return LocalDay(date: date, timeZone: fallbackTimeZone)
            }
        }
        return nil
    }

    private static func appleExportDate(_ string: String) -> Date? {
        let fields = string.split(separator: " ")
        guard fields.count >= 3 else { return nil }
        let dateFields = fields[0].split(separator: "-").compactMap { Int($0) }
        let timeFields = fields[1].split(separator: ":").compactMap { Int($0) }
        let offset = String(fields[2])
        guard dateFields.count == 3, timeFields.count == 3,
              offset.count == 5, let sign = offset.first,
              sign == "+" || sign == "-",
              let offsetHours = Int(offset.dropFirst().prefix(2)),
              let offsetMinutes = Int(offset.suffix(2)) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let wallClockAsUTC = calendar.date(from: DateComponents(
            year: dateFields[0], month: dateFields[1], day: dateFields[2],
            hour: timeFields[0], minute: timeFields[1], second: timeFields[2]
        )) else { return nil }
        let seconds = (offsetHours * 60 + offsetMinutes) * 60 * (sign == "+" ? 1 : -1)
        return wallClockAsUTC.addingTimeInterval(TimeInterval(-seconds))
    }

    private static func localDay(fromDateOnly string: String, timeZone: TimeZone) -> LocalDay? {
        let components = string.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3,
              components[0].count == 4,
              components[1].count == 2,
              components[2].count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              let localDay = try? LocalDay(year: year, month: month, day: day, timeZoneIdentifier: timeZone.identifier) else {
            return nil
        }
        return localDay
    }

    private static func normalizeHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func firstDuplicate(in values: [String]) -> String? {
        var seen = Set<String>()
        for value in values where !seen.insert(value).inserted {
            return value
        }
        return nil
    }

    private static func parseRows(_ text: String) throws -> [[String]] {
        let bytes = Array(text.utf8)
        guard !bytes.isEmpty else { return [] }

        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var isInsideQuotes = false
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]

            if byte == 34 {
                if isInsideQuotes, index + 1 < bytes.count, bytes[index + 1] == 34 {
                    field.append(34)
                    index += 1
                } else {
                    isInsideQuotes.toggle()
                }
            } else if byte == 44, !isInsideQuotes {
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll(keepingCapacity: true)
            } else if byte == 10, !isInsideQuotes {
                row.append(String(decoding: field, as: UTF8.self))
                rows.append(row)
                row = []
                field.removeAll(keepingCapacity: true)
            } else if byte != 13 {
                field.append(byte)
            }

            index += 1
        }

        guard !isInsideQuotes else { throw CSVImportError.malformedQuotedField }
        if !row.isEmpty || !field.isEmpty {
            row.append(String(decoding: field, as: UTF8.self))
            rows.append(row)
        }
        return rows
    }
}
