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

// MARK: - Scaled Widget Container

/// Renders widget content at a reference size, then scales it to fit the actual container.
/// This ensures pixel-perfect matching between preview and real widget.
struct ScaledWidgetContainer<Content: View>: View {
    let referenceSize: CGSize
    let content: Content

    init(referenceSize: CGSize, @ViewBuilder content: () -> Content) {
        self.referenceSize = referenceSize
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let scaleX = geo.size.width / referenceSize.width
            let scaleY = geo.size.height / referenceSize.height
            let scale = min(scaleX, scaleY)

            content
                .frame(width: referenceSize.width, height: referenceSize.height)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
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

    /// Reference width used for rendering. The real widget scales to match.
    static let referenceWidth: CGFloat = 340

    var body: some View {
        let refWidth = sizeType == .small ? Self.referenceWidth * 0.5 : Self.referenceWidth
        let refHeight = refWidth / sizeType.aspectRatio

        GeometryReader { geo in
            let displayWidth = sizeType == .small ? min(geo.size.width * 0.5, 170) : geo.size.width
            let displayHeight = displayWidth / sizeType.aspectRatio

            HStack {
                if sizeType == .small { Spacer() }
                ScaledWidgetContainer(referenceSize: CGSize(width: refWidth, height: refHeight)) {
                    WidgetCanvas(
                        sizeType: sizeType,
                        groups: groups,
                        seriesData: seriesData,
                        textScale: textScale
                    )
                    .padding(10)
                }
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
