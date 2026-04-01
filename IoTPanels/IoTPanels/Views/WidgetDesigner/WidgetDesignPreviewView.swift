import SwiftUI

/// Shared widget canvas that renders groups at a reference size.
/// Used by both the in-app preview and the real home screen widget.
struct WidgetCanvas: View {
    let sizeType: WidgetSizeType
    let groups: [WidgetRenderGroup]
    let seriesData: [String: [ChartSeries]]
    var textScale: CGFloat = 1.0

    var body: some View {
        let visibleGroups = Array(groups.prefix(sizeType.maxCells))

        if visibleGroups.isEmpty {
            VStack {
                Image(systemName: "plus.circle.dashed")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                Text("Add items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            gridLayout(groups: visibleGroups)
        }
    }

    private func gridLayout(groups: [WidgetRenderGroup]) -> some View {
        let columns = sizeType.gridColumns(for: groups.count)
        let rows = chunked(groups, size: columns)
        let isCompact = sizeType != .large || columns > 1 || rows.count > 1

        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.id) { group in
                        cellView(for: group, compact: isCompact)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// Splits an array into chunks of a given size.
    private func chunked(_ array: [WidgetRenderGroup], size: Int) -> [[WidgetRenderGroup]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }

    private func cellView(for group: WidgetRenderGroup, compact: Bool) -> some View {
        let groupSeries = seriesData[group.id] ?? group.items.map { item in
            ChartSeries(id: item.wrappedId.uuidString, label: item.wrappedTitle, color: item.color, dataPoints: [])
        }
        let groupUnit = group.items.first?.savedQuery?.wrappedUnit ?? ""
        let config = group.items.first?.wrappedStyleConfig ?? .default

        return PanelRenderer(
            title: group.title,
            style: group.style,
            series: groupSeries,
            compact: compact,
            unit: groupUnit,
            textScale: textScale,
            styleConfig: config,
            fillHeight: true
        )
        .frame(maxHeight: .infinity)
    }
}

// MARK: - In-App Preview

/// Renders a widget design preview at the correct aspect ratio, matching home screen appearance.
struct WidgetDesignPreviewView: View {
    let sizeType: WidgetSizeType
    let groups: [WidgetRenderGroup]
    let seriesData: [String: [ChartSeries]]
    var textScale: CGFloat = 1.0
    var backgroundColor: Color = Color(hex: "#1C1C1E")

    var body: some View {
        GeometryReader { geo in
            let displayWidth = sizeType == .small ? min(geo.size.width * 0.5, 170) : geo.size.width
            let displayHeight = displayWidth / sizeType.aspectRatio

            HStack {
                if sizeType == .small { Spacer() }
                WidgetCanvas(
                    sizeType: sizeType,
                    groups: groups,
                    seriesData: seriesData,
                    textScale: textScale
                )
                .padding(10)
                .frame(width: displayWidth, height: displayHeight)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                if sizeType == .small { Spacer() }
            }
        }
        .aspectRatio(sizeType == .small ? 2.0 : sizeType.aspectRatio, contentMode: .fit)
    }
}
