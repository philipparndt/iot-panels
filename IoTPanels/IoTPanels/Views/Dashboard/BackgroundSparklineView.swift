import SwiftUI

/// A minimal filled-area sparkline rendered as a `Path`, designed to sit
/// behind compact panel content (singleValue, circularGauge).
///
/// Data points are positioned by their timestamp within the time window
/// `[now - timeRangeSeconds, now]`. Gaps where no data exists are left blank.
/// Redraws every 30 seconds so the window slides forward even without new data.
struct BackgroundSparklineView: View {
    let dataPoints: [ChartDataPoint]
    let minVal: Double
    let maxVal: Double
    let color: Color
    /// Duration of the visible time window in seconds (e.g. 7200 for 2h).
    /// When 0, the window spans from the earliest to the latest data point.
    let timeRangeSeconds: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            Canvas { context, size in
                drawSparkline(context: context, size: size, now: timeline.date)
            }
        }
    }

    private func drawSparkline(context: GraphicsContext, size: CGSize, now: Date) {
        let range = maxVal - minVal
        guard !dataPoints.isEmpty, range > 0 else { return }

        let w = size.width
        let h = size.height

        let windowStart: Date
        let windowEnd: Date
        if timeRangeSeconds > 0 {
            windowStart = now.addingTimeInterval(-timeRangeSeconds)
            windowEnd = now
        } else if let first = dataPoints.first, let last = dataPoints.last, first.time < last.time {
            windowStart = first.time
            windowEnd = last.time
        } else {
            windowStart = now.addingTimeInterval(-3600)
            windowEnd = now
        }

        let windowDuration = windowEnd.timeIntervalSince(windowStart)
        guard windowDuration > 0 else { return }

        // Build visible points, keeping the last point before the window
        // so we can hold its value from the left edge.
        var points: [(x: CGFloat, y: CGFloat)] = []
        var lastBeforeWindow: ChartDataPoint?

        for dp in dataPoints {
            let t = dp.time.timeIntervalSince(windowStart) / windowDuration
            if t < 0 {
                lastBeforeWindow = dp
                continue
            }
            if t > 1 { break }
            let normalized = max(0, min(1, (dp.value - minVal) / range))
            points.append((x: w * CGFloat(t), y: h * CGFloat(1 - normalized)))
        }

        // If the earliest visible point doesn't start at x=0, extend the
        // last value from before the window to the left edge.
        if let pre = lastBeforeWindow {
            let normalized = max(0, min(1, (pre.value - minVal) / range))
            let y = h * CGFloat(1 - normalized)
            points.insert((x: 0, y: y), at: 0)
        }

        guard !points.isEmpty else { return }

        // Extend the last value to the right edge (now)
        let lastY = points[points.count - 1].y
        if points[points.count - 1].x < w {
            points.append((x: w, y: lastY))
        }

        // Build step-interpolated paths: hold each value flat until the next point
        var areaPath = Path()
        var linePath = Path()

        areaPath.move(to: CGPoint(x: points[0].x, y: h))
        areaPath.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
        linePath.move(to: CGPoint(x: points[0].x, y: points[0].y))

        for i in 1..<points.count {
            // Horizontal step to the next point's x at the previous y
            areaPath.addLine(to: CGPoint(x: points[i].x, y: points[i - 1].y))
            linePath.addLine(to: CGPoint(x: points[i].x, y: points[i - 1].y))
            // Vertical step to the new y
            areaPath.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
            linePath.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
        }

        areaPath.addLine(to: CGPoint(x: points[points.count - 1].x, y: h))
        areaPath.closeSubpath()

        context.fill(areaPath, with: .color(color.opacity(0.08)))
        context.stroke(linePath, with: .color(color.opacity(0.15)), lineWidth: 1)
    }
}
