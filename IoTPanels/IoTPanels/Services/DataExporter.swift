import Foundation
import SwiftUI

#if canImport(UIKit)
/// Wraps UIActivityViewController for sharing files via the system share sheet.
struct DataShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

enum DataExporter {

    // MARK: - Shared

    private static func combinedPoints(from points: [ChartDataPoint], comparisonPoints: [ChartDataPoint]) -> [ChartDataPoint] {
        var result = points
        result += comparisonPoints.map {
            ChartDataPoint(time: $0.time, value: $0.value, field: "cmp_\($0.field)")
        }
        return result
    }

    private static func pivoted(from allPoints: [ChartDataPoint]) -> (fields: [String], rows: [(time: Date, values: [String: Double])]) {
        guard !allPoints.isEmpty else { return ([], []) }

        let fields = Array(Set(allPoints.map(\.field))).sorted()

        var grouped: [Date: [String: Double]] = [:]
        for point in allPoints {
            grouped[point.time, default: [:]][point.field] = point.value
        }

        let rows = grouped.keys.sorted().map { time in
            (time: time, values: grouped[time] ?? [:])
        }

        return (fields, rows)
    }

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - CSV

    static func csv(from points: [ChartDataPoint], comparisonPoints: [ChartDataPoint] = []) -> String {
        let combined = combinedPoints(from: points, comparisonPoints: comparisonPoints)
        let (fields, rows) = pivoted(from: combined)
        guard !fields.isEmpty else { return "timestamp\n" }

        let header = "timestamp," + fields.map { escapeCSV($0) }.joined(separator: ",")
        let dataRows = rows.map { row in
            let cells = fields.map { field in
                row.values[field].map { String($0) } ?? ""
            }
            return formatter.string(from: row.time) + "," + cells.joined(separator: ",")
        }

        return header + "\n" + dataRows.joined(separator: "\n") + "\n"
    }

    // MARK: - JSON

    static func json(from points: [ChartDataPoint], comparisonPoints: [ChartDataPoint] = []) -> String {
        let combined = combinedPoints(from: points, comparisonPoints: comparisonPoints)
        let (fields, rows) = pivoted(from: combined)
        guard !fields.isEmpty else { return "[]" }

        let jsonArray: [[String: Any]] = rows.map { row in
            var obj: [String: Any] = ["timestamp": formatter.string(from: row.time)]
            for field in fields {
                if let value = row.values[field] {
                    obj[field] = value
                }
            }
            return obj
        }

        guard let data = try? JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    // MARK: - File Helpers

    static func tempFile(name: String, ext: String, content: String) -> URL? {
        let safeName = name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeName)_\(ISO8601DateFormatter().string(from: Date())).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func tempCSVFile(name: String, from points: [ChartDataPoint], comparisonPoints: [ChartDataPoint] = []) -> URL? {
        tempFile(name: name, ext: "csv", content: csv(from: points, comparisonPoints: comparisonPoints))
    }

    static func tempJSONFile(name: String, from points: [ChartDataPoint], comparisonPoints: [ChartDataPoint] = []) -> URL? {
        tempFile(name: name, ext: "json", content: json(from: points, comparisonPoints: comparisonPoints))
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
