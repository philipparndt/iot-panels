import SwiftUI
import Charts

// MARK: - Data Types

struct ChartDataPoint {
    let time: Date
    let value: Double
    let field: String
}

// MARK: - Shared Panel Renderer (single and multi-series)

struct PanelRenderer: View {
    let title: String
    let style: PanelDisplayStyle
    let series: [ChartSeries]
    let compact: Bool

    /// Single-series convenience init (backward compatible)
    init(title: String, style: PanelDisplayStyle, dataPoints: [ChartDataPoint], compact: Bool) {
        self.title = title
        self.style = style
        self.series = [ChartSeries(id: "default", label: dataPoints.first?.field ?? "value", color: .accentColor, dataPoints: dataPoints)]
        self.compact = compact
    }

    /// Multi-series init
    init(title: String, style: PanelDisplayStyle, series: [ChartSeries], compact: Bool) {
        self.title = title
        self.style = style
        self.series = series
        self.compact = compact
    }

    private var allDataPoints: [ChartDataPoint] {
        series.flatMap(\.dataPoints)
    }

    private var effectiveStyle: PanelDisplayStyle {
        if style != .auto { return style }
        if allDataPoints.isEmpty { return .singleValue }
        if allDataPoints.count <= 2 { return .singleValue }
        return .chart
    }

    private var lastValue: String? {
        series.first?.dataPoints.last.map { formatValue($0.value) }
    }

    private var fieldName: String? {
        series.first?.dataPoints.first?.field
    }

    private var isMultiSeries: Bool { series.count > 1 }

    var body: some View {
        switch effectiveStyle {
        case .auto, .chart:
            chartBody
        case .singleValue:
            singleValueBody
        case .gauge:
            gaugeBody
        }
    }

    // MARK: - Chart

    private var chartBody: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(compact ? .system(size: 10, weight: .medium) : .subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if !isMultiSeries, let lastValue {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(lastValue)
                            .font(compact ? .subheadline.weight(.semibold).monospacedDigit() : .title2.weight(.semibold).monospacedDigit())
                        if let fieldName {
                            Text(fieldName)
                                .font(.system(size: compact ? 8 : 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if allDataPoints.count > 2 {
                if isMultiSeries {
                    multiSeriesChart
                } else {
                    singleSeriesChart
                }
            } else if allDataPoints.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: compact ? 30 : 60)
            }
        }
    }

    private var singleSeriesChart: some View {
        let points = series.first?.dataPoints ?? []
        return Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(x: .value("T", point.time), y: .value("V", point.value))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                LineMark(x: .value("T", point.time), y: .value("V", point.value))
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))
            }
        }
        .chartXAxis(compact ? .hidden : .automatic)
        .chartYAxis(compact ? .hidden : .automatic)
        .frame(height: compact ? 40 : 160)
    }

    private var multiSeriesChart: some View {
        let seriesLabels = series.map(\.label)
        let seriesColors = series.map(\.color)

        return Chart {
            ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                ForEach(Array(s.dataPoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value),
                        series: .value("Series", s.label)
                    )
                    .foregroundStyle(by: .value("Series", s.label))
                    .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))
                }
            }
        }
        .chartForegroundStyleScale(domain: seriesLabels, range: seriesColors)
        .chartXAxis(compact ? .hidden : .automatic)
        .chartYAxis(compact ? .hidden : .automatic)
        .chartLegend(compact ? .hidden : .visible)
        .frame(height: compact ? 40 : 160)
    }

    // MARK: - Single Value

    private var singleValueBody: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text(title)
                .font(compact ? .system(size: 10, weight: .medium) : .subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(lastValue ?? "—")
                    .font(compact ?
                        .system(size: 24, weight: .semibold, design: .rounded).monospacedDigit() :
                        .system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
                    )
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if let fieldName {
                    Text(fieldName)
                        .font(compact ? .system(size: 9) : .caption)
                        .foregroundStyle(.tertiary)
                }
            }

            trendView
        }
    }

    // MARK: - Gauge

    private var gaugeBody: some View {
        let dataPoints = series.first?.dataPoints ?? []
        return VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text(title)
                .font(compact ? .system(size: 10, weight: .medium) : .subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let last = dataPoints.last {
                let minVal = dataPoints.map(\.value).min() ?? 0
                let maxVal = dataPoints.map(\.value).max() ?? 100
                let range = maxVal - minVal
                let progress = range > 0 ? (last.value - minVal) / range : 0.5

                Gauge(value: progress) {
                    EmptyView()
                } currentValueLabel: {
                    Text(formatValue(last.value))
                        .font(compact ? .caption.weight(.semibold).monospacedDigit() : .title3.weight(.semibold).monospacedDigit())
                } minimumValueLabel: {
                    Text(formatValue(minVal))
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text(formatValue(maxVal))
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundStyle(.secondary)
                }
                .gaugeStyle(.accessoryLinear)
                .tint(LinearGradient(colors: [.blue, .green, .orange, .red], startPoint: .leading, endPoint: .trailing))
            } else {
                Text("—")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            if let fieldName {
                Text(fieldName)
                    .font(.system(size: compact ? 8 : 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Trend

    @ViewBuilder
    private var trendView: some View {
        let dataPoints = series.first?.dataPoints ?? []
        if dataPoints.count >= 2, let first = dataPoints.first, let last = dataPoints.last {
            let diff = last.value - first.value
            let threshold = abs(first.value) * 0.02
            let icon = diff > threshold ? "arrow.up.right" : diff < -threshold ? "arrow.down.right" : "arrow.right"
            let color: Color = diff > threshold ? .red : diff < -threshold ? .blue : .secondary
            let sign = diff >= 0 ? "+" : ""

            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 8 : 10, weight: .semibold))
                Text("\(sign)\(formatValue(diff))")
                    .font(.system(size: compact ? 9 : 11).monospacedDigit())
            }
            .foregroundStyle(color)
        }
    }

    private func formatValue(_ value: Double) -> String {
        abs(value - value.rounded()) < 0.01 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

// MARK: - App Panel Card (wraps PanelRenderer with data loading)

struct PanelCardView: View {
    @ObservedObject var panel: DashboardPanel

    @State private var dataPoints: [ChartDataPoint] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    Text(panel.wrappedTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    ProgressView()
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(panel.wrappedTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Label(errorMessage, systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                PanelRenderer(
                    title: panel.wrappedTitle,
                    style: panel.wrappedDisplayStyle,
                    dataPoints: dataPoints,
                    compact: false
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
                let result = try await service.query(flux)
                let parsed = Self.parseChartData(result: result)
                await MainActor.run {
                    dataPoints = parsed
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

    static func parseChartData(result: QueryResult) -> [ChartDataPoint] {
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
