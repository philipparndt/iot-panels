import SwiftUI
import Charts

struct PanelCardView: View {
    @ObservedObject var panel: DashboardPanel

    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                loadingView
            } else if let errorMessage {
                errorView(errorMessage)
            } else if let result {
                contentView(result: result)
            } else {
                loadingView
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .onAppear { loadData() }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentView(result: QueryResult) -> some View {
        let dataPoints = parseChartData(result: result)

        if dataPoints.isEmpty && result.rows.isEmpty {
            noDataView
        } else if dataPoints.count <= 2 {
            singleValueView(dataPoints: dataPoints)
        } else {
            chartValueView(dataPoints: dataPoints)
        }
    }

    private func singleValueView(dataPoints: [ChartDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(panel.wrappedTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let last = dataPoints.last {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatValue(last.value))
                        .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())

                    Text(last.field)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if dataPoints.count >= 2, let first = dataPoints.first {
                    let diff = last.value - first.value
                    let sign = diff >= 0 ? "+" : ""
                    let icon = diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "arrow.right"
                    let color: Color = diff > 0 ? .red : diff < 0 ? .blue : .secondary

                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.caption2.weight(.semibold))
                        Text("\(sign)\(formatValue(diff))")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(color)
                }
            } else if let firstRow = result?.rows.first, let value = firstRow.values["_value"] {
                Text(value)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartValueView(dataPoints: [ChartDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(panel.wrappedTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if let last = dataPoints.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatValue(last.value))
                            .font(.title2.weight(.semibold).monospacedDigit())

                        Text(last.field)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Chart {
                ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Field", point.field))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel()
                        .font(.system(size: 9))
                }
            }
            .frame(height: 180)
        }
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Text(panel.wrappedTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("No data")
                .font(.headline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Text(panel.wrappedTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ProgressView()
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(panel.wrappedTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Label(message, systemImage: "xmark.circle")
                .foregroundStyle(.red)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

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

    private func formatValue(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.01 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func parseChartData(result: QueryResult) -> [ChartDataPoint] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        return result.rows.compactMap { row in
            guard let timeStr = row.values["_time"],
                  let valueStr = row.values["_value"],
                  let value = Double(valueStr) else { return nil }
            guard let time = formatter.date(from: timeStr) ?? fallback.date(from: timeStr) else { return nil }
            return ChartDataPoint(time: time, value: value, field: row.values["_field"] ?? "value")
        }
    }
}

struct ChartDataPoint {
    let time: Date
    let value: Double
    let field: String
}
