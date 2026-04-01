import SwiftUI

/// Renders a widget design preview at the correct aspect ratio, matching home screen appearance.
struct WidgetDesignPreviewView: View {
    let sizeType: WidgetSizeType
    let groups: [WidgetRenderGroup]
    let seriesData: [String: [ChartSeries]] // keyed by group id
    var textScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let maxWidth: CGFloat = sizeType == .small ? min(geo.size.width * 0.5, 170) : geo.size.width
            let width = maxWidth
            let height = width / sizeType.aspectRatio

            HStack {
                if sizeType == .small { Spacer() }
                canvas
                    .padding(16)
                    .frame(width: width, height: height)
                    .background(Color(uiColor: .tertiarySystemBackground))
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

    @ViewBuilder
    private var canvas: some View {
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
            switch sizeType {
            case .small:
                if let g = visibleGroups.first {
                    cellView(for: g, compact: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .medium:
                HStack(spacing: 12) {
                    ForEach(Array(visibleGroups.enumerated()), id: \.element.id) { _, g in
                        cellView(for: g, compact: visibleGroups.count > 1)
                            .frame(maxWidth: .infinity)
                    }
                }
            case .large:
                VStack(spacing: 8) {
                    ForEach(Array(visibleGroups.enumerated()), id: \.element.id) { _, g in
                        cellView(for: g, compact: visibleGroups.count > 2)
                    }
                    Spacer(minLength: 0)
                }
            }
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
            styleConfig: config
        )
    }
}
