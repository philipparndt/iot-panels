import SwiftUI
import Charts

struct PanelCardView: View {
    @ObservedObject var panel: DashboardPanel

    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(panel.wrappedTitle)
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let result {
                if result.rows.isEmpty {
                    Text("No data")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    chartView(result: result)
                        .frame(height: 200)
                }
            } else {
                Color.clear.frame(height: 200)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .onAppear { loadData() }
    }

    private func loadData() {
        guard let query = panel.savedQuery,
              let dataSource = query.dataSource else {
            errorMessage = "Query or data source missing"
            return
        }

        isLoading = true
        errorMessage = nil

        let service = InfluxDB2Service(dataSource: dataSource)
        let flux = query.buildFluxQuery(bucket: dataSource.wrappedBucket)

        Task {
            do {
                let queryResult = try await service.query(flux)
                await MainActor.run {
                    result = queryResult
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    @ViewBuilder
    private func chartView(result: QueryResult) -> some View {
        let dataPoints = parseChartData(result: result)
        if dataPoints.isEmpty {
            QueryResultTableView(result: result)
        } else {
            Chart {
                ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Field", point.field))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
    }

    private func parseChartData(result: QueryResult) -> [ChartDataPoint] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        return result.rows.compactMap { row in
            guard let timeStr = row.values["_time"],
                  let valueStr = row.values["_value"],
                  let value = Double(valueStr) else { return nil }

            let time = formatter.date(from: timeStr) ?? fallbackFormatter.date(from: timeStr)
            guard let time else { return nil }

            let field = row.values["_field"] ?? "value"
            return ChartDataPoint(time: time, value: value, field: field)
        }
    }
}

struct ChartDataPoint {
    let time: Date
    let value: Double
    let field: String
}
