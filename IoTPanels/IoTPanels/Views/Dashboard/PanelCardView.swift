import SwiftUI
import Charts
import Combine

// MARK: - Data Types

struct PanelCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                Color(white: 0.12)
            } else {
                #if os(watchOS)
                Color(white: 0.2)
                #else
                Color(uiColor: .secondarySystemGroupedBackground)
                #endif
            }
        }
    }
}

struct ChartDataPoint: Codable {
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
    let unit: String
    let textScale: CGFloat
    let styleConfig: StyleConfig

    /// Single-series convenience init (backward compatible)
    init(title: String, style: PanelDisplayStyle, dataPoints: [ChartDataPoint], compact: Bool, unit: String = "", textScale: CGFloat = 1.0, styleConfig: StyleConfig = .default) {
        self.title = title
        self.style = style
        self.series = [ChartSeries(id: "default", label: dataPoints.first?.field ?? "value", color: .accentColor, dataPoints: dataPoints)]
        self.compact = compact
        self.unit = unit
        self.textScale = textScale
        self.styleConfig = styleConfig
    }

    /// Multi-series init
    init(title: String, style: PanelDisplayStyle, series: [ChartSeries], compact: Bool, unit: String = "", textScale: CGFloat = 1.0, styleConfig: StyleConfig = .default) {
        self.title = title
        self.style = style
        self.series = series
        self.compact = compact
        self.unit = unit
        self.textScale = textScale
        self.styleConfig = styleConfig
    }

    @State private var selectedTime: Date?

    // Scaled font size helper
    private func sz(_ base: CGFloat) -> CGFloat { base * textScale }

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
        if !unit.isEmpty { return unit }
        return nil
    }

    private var isMultiSeries: Bool { series.count > 1 }

    var body: some View {
        switch effectiveStyle {
        case .auto, .chart:
            chartBody(chartType: .line)
        case .barChart:
            chartBody(chartType: .bar)
        case .scatterChart:
            chartBody(chartType: .scatter)
        case .linePointChart:
            chartBody(chartType: .linePoint)
        case .singleValue:
            singleValueBody
        case .gauge:
            gaugeBody
        case .calendarHeatmap:
            calendarHeatmapBody
        }
    }

    private enum ChartType {
        case line, bar, scatter, linePoint
    }

    /// Finds the closest data point to a given date across all series.
    private func closestPoint(to date: Date) -> ChartDataPoint? {
        allDataPoints.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
    }

    /// Selection overlay tooltip shown above the chart.
    @ViewBuilder
    private var selectionTooltip: some View {
        if let selectedTime, let point = closestPoint(to: selectedTime) {
            let unitSuffix = unit.isEmpty ? "" : " \(unit)"
            HStack(spacing: 6) {
                Text(formatTime(point.time))
                    .font(.system(size: sz(10)).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(formatValue(point.value) + unitSuffix)
                    .font(.system(size: sz(12), weight: .semibold).monospacedDigit())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    /// Adds a selection RuleMark inside the chart.
    @ChartContentBuilder
    private var selectionRuleMark: some ChartContent {
        if let selectedTime {
            RuleMark(x: .value("Selected", selectedTime))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }


    // MARK: - Chart

    private func chartBody(chartType: ChartType) -> some View {
        VStack(spacing: compact ? 4 : 8) {
            // Title row — shows selection tooltip when dragging, otherwise title + last value
            if let selectedTime, !compact, let point = closestPoint(to: selectedTime) {
                let unitSuffix = unit.isEmpty ? "" : " \(unit)"
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: sz(compact ? 10 : 14), weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatTime(point.time))
                            .font(.system(size: sz(12)).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(formatValue(point.value) + unitSuffix)
                            .font(.system(size: sz(compact ? 14 : 22), weight: .semibold, design: .default).monospacedDigit())
                    }
                }
            } else if isMultiSeries {
                Text(title)
                    .font(.system(size: sz(compact ? 10 : 14), weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: sz(compact ? 10 : 14), weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if let lastValue {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(lastValue)
                                .font(.system(size: sz(compact ? 14 : 22), weight: .semibold, design: .default).monospacedDigit())
                            if let fieldName {
                                Text(fieldName)
                                    .font(.system(size: sz(compact ? 8 : 10)))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            if allDataPoints.count > 2 {
                if isMultiSeries {
                    multiSeriesChartView(chartType: chartType)
                } else {
                    singleSeriesChartView(chartType: chartType)
                }
            } else if allDataPoints.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: compact ? 30 : 60)
            }

            // Custom legend for multi-series
            if isMultiSeries && !allDataPoints.isEmpty {
                customLegend
            }
        }
    }

    // Min/max annotations for a single series
    private func minMaxPoints(for points: [ChartDataPoint]) -> (min: ChartDataPoint, max: ChartDataPoint)? {
        guard points.count >= 3 else { return nil }
        guard let minPt = points.min(by: { $0.value < $1.value }),
              let maxPt = points.max(by: { $0.value < $1.value }) else { return nil }
        // Only show if there's meaningful difference
        let range = maxPt.value - minPt.value
        guard range > 0.01 else { return nil }
        return (min: minPt, max: maxPt)
    }

    private func singleSeriesChartView(chartType: ChartType) -> some View {
        let points = series.first?.dataPoints ?? []
        let minMax = chartType == .line ? minMaxPoints(for: points) : nil

        return VStack(spacing: 2) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    switch chartType {
                    case .line:
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

                    case .bar:
                        BarMark(x: .value("T", point.time), y: .value("V", point.value))
                            .foregroundStyle(Color.accentColor.gradient)

                    case .scatter:
                        PointMark(x: .value("T", point.time), y: .value("V", point.value))
                            .foregroundStyle(Color.accentColor)
                            .symbolSize(compact ? 20 : 40)

                    case .linePoint:
                        LineMark(x: .value("T", point.time), y: .value("V", point.value))
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))
                        PointMark(x: .value("T", point.time), y: .value("V", point.value))
                            .foregroundStyle(Color.accentColor)
                            .symbolSize(compact ? 15 : 30)
                    }
                }

                if !compact, let minMax {
                    PointMark(x: .value("T", minMax.min.time), y: .value("V", minMax.min.value))
                        .foregroundStyle(.blue)
                        .symbolSize(compact ? 15 : 30)
                        .annotation(position: .bottom, spacing: 2) {
                            Text(formatValue(minMax.min.value))
                                .font(.system(size: 8).monospacedDigit())
                                .foregroundStyle(.blue)
                        }
                    PointMark(x: .value("T", minMax.max.time), y: .value("V", minMax.max.value))
                        .foregroundStyle(.red)
                        .symbolSize(compact ? 15 : 30)
                        .annotation(position: .top, spacing: 2) {
                            Text(formatValue(minMax.max.value))
                                .font(.system(size: 8).monospacedDigit())
                                .foregroundStyle(.red)
                        }
                }

                selectionRuleMark
            }
            .chartXAxis(compact ? .hidden : .automatic)
            .chartYAxis(compact ? .hidden : .automatic)
            .chartXSelection(value: $selectedTime)
            .frame(height: compact ? 40 : 160)

            chartFooter(for: points)
        }
    }

    private func multiSeriesChartView(chartType: ChartType) -> some View {
        let seriesLabels = series.map(\.label)
        let seriesColors = series.map(\.color)

        return VStack(spacing: 2) {
            Chart {
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    ForEach(Array(s.dataPoints.enumerated()), id: \.offset) { _, point in
                        switch chartType {
                        case .line:
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("Value", point.value),
                                series: .value("Series", s.label)
                            )
                            .foregroundStyle(by: .value("Series", s.label))
                            .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))

                        case .bar:
                            BarMark(
                                x: .value("Time", point.time),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(by: .value("Series", s.label))

                        case .scatter:
                            PointMark(
                                x: .value("Time", point.time),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(by: .value("Series", s.label))
                            .symbolSize(compact ? 20 : 40)

                        case .linePoint:
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("Value", point.value),
                                series: .value("Series", s.label)
                            )
                            .foregroundStyle(by: .value("Series", s.label))
                            .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))
                            PointMark(
                                x: .value("Time", point.time),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(by: .value("Series", s.label))
                            .symbolSize(compact ? 15 : 30)
                        }
                    }
                }

                selectionRuleMark
            }
            .chartForegroundStyleScale(domain: seriesLabels, range: seriesColors)
            .chartXAxis(compact ? .hidden : .automatic)
            .chartYAxis(compact ? .hidden : .automatic)
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedTime)
            .frame(height: compact ? 40 : 160)

            chartFooter(for: allDataPoints)
        }
    }

    private func chartFooter(for points: [ChartDataPoint]) -> some View {
        let times = points.map(\.time).sorted()
        let values = points.map(\.value)
        let fontSize: CGFloat = sz(compact ? 9 : 11)
        let unitSuffix = unit.isEmpty ? "" : unit

        return HStack {
            if let first = times.first {
                Text(formatTime(first))
                    .font(.system(size: fontSize).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let minVal = values.min(), let maxVal = values.max(), maxVal - minVal > 0.01 {
                Text("\(formatValue(minVal))–\(formatValue(maxVal))\(unitSuffix.isEmpty ? "" : " ")\(unitSuffix)")
                    .font(.system(size: fontSize).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let last = times.last {
                Text(formatTime(last))
                    .font(.system(size: fontSize).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private var customLegend: some View {
        let unitSuffix = unit.isEmpty ? "" : " \(unit)"
        let fontSize: CGFloat = sz(compact ? 8 : 10)

        return HStack(spacing: compact ? 6 : 10) {
            ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                HStack(spacing: 3) {
                    Circle()
                        .fill(s.color)
                        .frame(width: compact ? 5 : 7, height: compact ? 5 : 7)
                    Text(s.label)
                        .font(.system(size: fontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let last = s.dataPoints.last {
                        let min = s.dataPoints.map(\.value).min() ?? last.value
                        let max = s.dataPoints.map(\.value).max() ?? last.value
                        if compact {
                            Text("\(formatValue(last.value))\(unitSuffix)")
                                .font(.system(size: fontSize).monospacedDigit())
                                .foregroundStyle(.primary)
                        } else {
                            Text("\(formatValue(min))–\(formatValue(max))\(unitSuffix)")
                                .font(.system(size: fontSize).monospacedDigit())
                                .foregroundStyle(.tertiary)
                            Text(formatValue(last.value) + unitSuffix)
                                .font(.system(size: fontSize, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Single Value

    private var singleValueBody: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text(title)
                .font(.system(size: sz(compact ? 10 : 14), weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if isMultiSeries {
                multiValueBody
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(lastValue ?? "—")
                        .font(.system(size: sz(compact ? 24 : 44), weight: .semibold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let fieldName {
                        Text(fieldName)
                            .font(.system(size: sz(compact ? 9 : 12)))
                            .foregroundStyle(.tertiary)
                    }
                }

                trendView
            }
        }
    }

    private var multiValueBody: some View {
        let unitSuffix = unit.isEmpty ? "" : " \(unit)"
        let valueFontSize = sz(compact ? 18 : 28)
        let labelFontSize = sz(compact ? 8 : 10)

        return ForEach(Array(series.enumerated()), id: \.offset) { _, s in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(s.color)
                    .frame(width: sz(compact ? 6 : 8), height: sz(compact ? 6 : 8))

                Text(s.label)
                    .font(.system(size: labelFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text((s.dataPoints.last.map { formatValue($0.value) } ?? "—") + unitSuffix)
                    .font(.system(size: valueFontSize, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Gauge

    private var gaugeBody: some View {
        let allDataValues = series.flatMap { $0.dataPoints.map(\.value) }
        let scheme = styleConfig.resolvedGaugeColorScheme
        let dataMin = allDataValues.min() ?? 0
        let dataMax = allDataValues.max() ?? 100
        // Add 10% padding to auto range so dots aren't at the very edges
        let padding = max((dataMax - dataMin) * 0.1, 1)
        let autoMin = dataMin - padding
        let autoMax = dataMax + padding
        let minVal = styleConfig.gaugeMin ?? autoMin
        let maxVal = styleConfig.gaugeMax ?? autoMax
        let unitSuffix = unit.isEmpty ? "" : " \(unit)"
        let range = maxVal - minVal

        return VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text(title)
                .font(.system(size: sz(compact ? 10 : 14), weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if allDataValues.isEmpty {
                Text("—")
                    .font(.system(size: sz(18), weight: .medium))
                    .foregroundStyle(.tertiary)
            } else if isMultiSeries {
                // Multi-series: values list + shared gauge bar with multiple dots
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    if let last = s.dataPoints.last {
                        let progress = range > 0 ? (last.value - minVal) / range : 0.5
                        HStack(spacing: 4) {
                            Circle()
                                .fill(s.color)
                                .frame(width: sz(compact ? 6 : 8), height: sz(compact ? 6 : 8))
                            Text(s.label)
                                .font(.system(size: sz(compact ? 8 : 10)))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(formatValue(last.value) + unitSuffix)
                                .font(.system(size: sz(compact ? 14 : 18), weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(scheme.color(at: progress))
                        }
                    }
                }

                // Shared gauge bar with multiple dots
                gaugeBar(values: series.compactMap { s in
                    s.dataPoints.last.map { (value: $0.value, color: s.color) }
                }, minVal: minVal, maxVal: maxVal, scheme: scheme)

                gaugeLabelRow(minVal: minVal, maxVal: maxVal, unitSuffix: unitSuffix)
            } else {
                // Single series
                let last = series.first!.dataPoints.last!
                let progress = range > 0 ? (last.value - minVal) / range : 0.5
                let dotColor = scheme.color(at: progress)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatValue(last.value))
                        .font(.system(size: sz(compact ? 16 : 24), weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(dotColor)
                    if !unitSuffix.isEmpty {
                        Text(unit)
                            .font(.system(size: sz(compact ? 8 : 10)))
                            .foregroundStyle(.tertiary)
                    }
                }

                gaugeBar(values: [(value: last.value, color: scheme.color(at: progress))], minVal: minVal, maxVal: maxVal, scheme: scheme)

                gaugeLabelRow(minVal: minVal, maxVal: maxVal, unitSuffix: unitSuffix)
            }
        }
    }

    private struct GaugeDot: Identifiable {
        let id: Int
        let value: Double
        let color: Color
    }

    private func gaugeBar(values: [(value: Double, color: Color)], minVal: Double, maxVal: Double, scheme: GaugeColorScheme) -> some View {
        let range = maxVal - minVal
        let dots = values.enumerated().map { GaugeDot(id: $0.offset, value: $0.element.value, color: $0.element.color) }

        return GeometryReader { geo in
            let barHeight: CGFloat = compact ? 4 : 6
            let dotSize: CGFloat = compact ? 12 : 16

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(LinearGradient(colors: scheme.colors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: barHeight)

                ForEach(dots) { dot in
                    let progress = range > 0 ? (dot.value - minVal) / range : 0.5
                    let clampedProgress = max(0, min(1, progress))
                    let xPos = geo.size.width * clampedProgress - dotSize / 2
                    Circle()
                        .fill(dot.color)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .frame(width: dotSize, height: dotSize)
                        .shadow(color: dot.color.opacity(0.5), radius: 3)
                        .offset(x: xPos)
                        .animation(.easeInOut(duration: 0.4), value: dot.value)
                }
            }
            .frame(height: dotSize)
        }
        .frame(height: compact ? 12 : 16)
    }

    private func gaugeLabelRow(minVal: Double, maxVal: Double, unitSuffix: String) -> some View {
        HStack {
            Text(formatValue(minVal) + unitSuffix)
                .font(.system(size: sz(compact ? 8 : 10)))
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatValue(maxVal) + unitSuffix)
                .font(.system(size: sz(compact ? 8 : 10)))
                .foregroundStyle(.secondary)
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
                    .font(.system(size: sz(compact ? 8 : 10), weight: .semibold))
                Text("\(sign)\(formatValue(diff))")
                    .font(.system(size: sz(compact ? 9 : 11)).monospacedDigit())
            }
            .foregroundStyle(color)
        }
    }

    // MARK: - Calendar Heatmap

    // MARK: - Calendar Heatmap

    private var calendarHeatmapBody: some View {
        var dayValues: [Date: Double] = [:]
        let cal = Calendar.current
        for dp in allDataPoints {
            let day = cal.startOfDay(for: dp.time)
            dayValues[day, default: 0] = dp.value
        }
        let values = dayValues.values
        let minVal = styleConfig.gaugeMin ?? (values.min() ?? 0)
        let maxVal = styleConfig.gaugeMax ?? (values.max() ?? 1)

        return CalendarHeatmapView(
            title: title,
            dayValues: dayValues,
            minVal: minVal,
            maxVal: maxVal,
            unit: unit,
            compact: compact,
            textScale: textScale,
            lastValue: allDataPoints.last?.value,
            heatmapColor: styleConfig.resolvedHeatmapColor
        )
    }

    private func formatValue(_ value: Double) -> String {
        abs(value - value.rounded()) < 0.01 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

// MARK: - Calendar Heatmap View

private struct CalendarHeatmapView: View {
    let title: String
    let dayValues: [Date: Double]
    let minVal: Double
    let maxVal: Double
    let unit: String
    let compact: Bool
    let textScale: CGFloat
    let lastValue: Double?
    let heatmapColor: HeatmapColor

    @State private var selectedDate: Date?

    private var range: Double { maxVal - minVal }

    private func sz(_ base: CGFloat) -> CGFloat { base * textScale }

    private func formatValue(_ value: Double) -> String {
        abs(value - value.rounded()) < 0.01 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = (calendar.component(.weekday, from: today) + 5) % 7
        let endOfWeek = calendar.date(byAdding: .day, value: 6 - todayWeekday, to: today)!
        let spacing: CGFloat = compact ? 1.5 : 2

        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text(title)
                .font(.system(size: sz(compact ? 10 : 14), weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Selected day or last value
            if let sel = selectedDate, let val = dayValues[sel] {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(val))
                        .font(.system(size: sz(compact ? 14 : 18), weight: .semibold, design: .rounded).monospacedDigit())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: sz(compact ? 8 : 10)))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(sel.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.system(size: sz(compact ? 9 : 11)))
                        .foregroundStyle(.secondary)
                }
            } else if let val = lastValue {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatValue(val))
                        .font(.system(size: sz(compact ? 14 : 18), weight: .semibold, design: .rounded).monospacedDigit())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: sz(compact ? 8 : 10)))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            GeometryReader { geo in
                let availableWidth = geo.size.width
                let targetCellSize: CGFloat = compact ? 12 : 16
                let weekCount = max(1, Int((availableWidth + spacing) / (targetCellSize + spacing)))
                let cellSize = (availableWidth - CGFloat(weekCount - 1) * spacing) / CGFloat(weekCount)
                let totalDays = weekCount * 7
                let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: endOfWeek)!

                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<weekCount, id: \.self) { week in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { weekday in
                                let dayOffset = week * 7 + weekday
                                let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
                                let day = calendar.startOfDay(for: date)
                                let value = dayValues[day]
                                let isFuture = date > today
                                let isSelected = selectedDate == day

                                RoundedRectangle(cornerRadius: compact ? 1 : 1.5)
                                    .fill(isFuture ? Color.clear : cellColor(value: value))
                                    .overlay(
                                        isSelected ? RoundedRectangle(cornerRadius: compact ? 1 : 1.5)
                                            .stroke(Color.primary, lineWidth: 1) : nil
                                    )
                                    .frame(width: cellSize, height: cellSize)
                                    .onTapGesture {
                                        if !isFuture {
                                            selectedDate = selectedDate == day ? nil : day
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .frame(height: 7 * (compact ? 12 : 16) + 6 * spacing + 20)
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private func cellColor(value: Double?) -> Color {
        guard let value else {
            return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92)
        }
        let progress = range > 0 ? max(0, min(1, (value - minVal) / range)) : 0
        return heatmapColor.color(at: progress, darkMode: colorScheme == .dark)
    }
}

// MARK: - App Panel Card (wraps PanelRenderer with data loading)

struct PanelCardView: View {
    @ObservedObject var panel: DashboardPanel
    @Environment(\.scenePhase) private var scenePhase

    @State private var dataPoints: [ChartDataPoint] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCachedData = false
    @State private var mqttSubscription: AnyCancellable?

    /// Whether this panel's data source is MQTT (push-based, needs live refresh).
    private var isMQTT: Bool {
        #if canImport(CocoaMQTT)
        return panel.savedQuery?.dataSource?.wrappedBackendType == .mqtt
        #else
        return false
        #endif
    }

    private var mqttConnectionKey: String? {
        #if canImport(CocoaMQTT)
        guard let ds = panel.savedQuery?.dataSource, ds.wrappedBackendType == .mqtt else { return nil }
        return MQTTService(dataSource: ds).connectionKey
        #else
        return nil
        #endif
    }

    private var mqttTopicPattern: String? {
        #if canImport(CocoaMQTT)
        guard let query = panel.savedQuery else { return nil }
        return MQTTQueryParser.parse(query.buildQuery(for: query.dataSource!)).topic
        #else
        return nil
        #endif
    }

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
            } else if dataPoints.isEmpty {
                VStack(spacing: 8) {
                    Text(panel.wrappedTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Label("Waiting for data…", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack(spacing: 0) {
                    PanelRenderer(
                        title: panel.wrappedTitle,
                        style: panel.wrappedDisplayStyle,
                        dataPoints: dataPoints,
                        compact: false,
                        unit: panel.savedQuery?.wrappedUnit ?? "",
                        styleConfig: panel.wrappedStyleConfig
                    )

                    HStack(spacing: 4) {
                        Image(systemName: "icloud.slash")
                            .font(.system(size: 8))
                        Text("Cached \(panel.savedQuery?.wrappedCachedAt ?? Date(), style: .relative) ago")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 4)
                    .opacity(isCachedData ? 1 : 0)
                }
            }
        }
        .frame(minHeight: 100)
        .padding()
        .background(PanelCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .animation(.none, value: dataPoints.count)
        .onAppear {
            loadData()
            subscribeMQTTUpdates()
        }
        .onDisappear {
            mqttSubscription?.cancel()
            mqttSubscription = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                loadData()
                subscribeMQTTUpdates()
            } else {
                mqttSubscription?.cancel()
                mqttSubscription = nil
            }
        }
    }

    private func subscribeMQTTUpdates() {
        guard isMQTT, mqttSubscription == nil,
              let connKey = mqttConnectionKey else { return }

        #if canImport(CocoaMQTT)
        mqttSubscription = MQTTConnectionManager.shared.messageReceived
            .filter { $0.connectionKey == connKey }
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [panel] _ in
                guard let query = panel.savedQuery,
                      let dataSource = query.dataSource else { return }
                let service = ServiceFactory.service(for: dataSource)
                let queryString = query.buildQuery(for: dataSource)
                Task {
                    guard let result = try? await service.query(queryString) else { return }
                    let parsed = Self.parseChartData(result: result)
                    guard !parsed.isEmpty else { return }
                    await MainActor.run {
                        dataPoints = parsed
                        isCachedData = false
                    }
                }
            }
        #endif
    }

    private func loadData() {
        guard let query = panel.savedQuery,
              let dataSource = query.dataSource else {
            errorMessage = "Query or data source missing"
            return
        }

        // Show cached data immediately while loading fresh data
        if let cached = query.cachedDataPoints, !cached.isEmpty {
            dataPoints = cached
            isCachedData = true
        }

        // Only show spinner if we have nothing to display at all
        if dataPoints.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        let service = ServiceFactory.service(for: dataSource)
        let flux = query.buildQuery(for: dataSource)

        Task {
            do {
                let result = try await withThrowingTaskGroup(of: QueryResult.self) { group in
                    group.addTask {
                        try await service.query(flux)
                    }
                    group.addTask {
                        try await Task.sleep(for: .seconds(10))
                        throw CancellationError()
                    }
                    let first = try await group.next()!
                    group.cancelAll()
                    return first
                }
                let parsed = Self.parseChartData(result: result)
                await MainActor.run {
                    if !parsed.isEmpty {
                        dataPoints = parsed
                        isCachedData = false
                        query.cacheResult(parsed)
                        try? query.managedObjectContext?.save()
                    } else if !dataPoints.isEmpty {
                        isCachedData = true
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    if dataPoints.isEmpty {
                        errorMessage = error.localizedDescription
                    } else {
                        isCachedData = true
                    }
                    isLoading = false
                }
            }
        }
    }

    static func parseChartData(result: QueryResult) -> [ChartDataPoint] {
        ChartDataParser.parse(result: result)
    }
}

enum ChartDataParser {
    nonisolated static func parse(result: QueryResult) -> [ChartDataPoint] {
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
