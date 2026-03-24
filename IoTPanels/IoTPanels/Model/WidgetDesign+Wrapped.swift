import Foundation
import SwiftUI

// MARK: - Widget Size

enum WidgetSizeType: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "2×2"
        case .medium: return "4×2"
        case .large: return "4×4"
        }
    }

    var iconName: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "square.fill"
        }
    }

    /// Preview aspect ratio (width/height)
    var aspectRatio: CGFloat {
        switch self {
        case .small: return 1.0
        case .medium: return 2.14
        case .large: return 0.95
        }
    }

    var maxCells: Int {
        switch self {
        case .small: return 1
        case .medium: return 3
        case .large: return 4
        }
    }
}

// MARK: - Chart Series (multi-series rendering)

struct ChartSeries: Identifiable {
    let id: String
    let label: String
    let color: Color
    let dataPoints: [ChartDataPoint]
}

// MARK: - Render Group (items grouped by groupTag)

struct WidgetRenderGroup: Identifiable {
    let id: String
    let title: String
    let style: PanelDisplayStyle
    let items: [WidgetDesignItem]
}

// MARK: - WidgetDesign

extension WidgetDesign {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedSizeType: WidgetSizeType {
        get { WidgetSizeType(rawValue: sizeType ?? "") ?? .medium }
        set { sizeType = newValue.rawValue }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    var sortedItems: [WidgetDesignItem] {
        let set = items as? Set<WidgetDesignItem> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Group items by groupTag. Ungrouped items (nil/empty groupTag) each become their own group.
    var resolvedGroups: [WidgetRenderGroup] {
        var groups: [WidgetRenderGroup] = []
        var seenGroups: [String: Int] = [:]

        for item in sortedItems {
            let tag = item.groupTag ?? ""
            if !tag.isEmpty, let existingIdx = seenGroups[tag] {
                var existing = groups[existingIdx]
                var updatedItems = existing.items
                updatedItems.append(item)
                groups[existingIdx] = WidgetRenderGroup(
                    id: existing.id,
                    title: existing.title,
                    style: existing.style,
                    items: updatedItems
                )
            } else if !tag.isEmpty {
                seenGroups[tag] = groups.count
                groups.append(WidgetRenderGroup(
                    id: tag,
                    title: item.wrappedTitle,
                    style: item.wrappedDisplayStyle,
                    items: [item]
                ))
            } else {
                groups.append(WidgetRenderGroup(
                    id: item.wrappedId.uuidString,
                    title: item.wrappedTitle,
                    style: item.wrappedDisplayStyle,
                    items: [item]
                ))
            }
        }

        return groups
    }
}

// MARK: - WidgetDesignItem

extension WidgetDesignItem {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedTitle: String {
        get { (title?.isEmpty ?? true) ? (savedQuery?.wrappedName ?? "") : (title ?? "") }
        set { title = newValue }
    }

    var wrappedDisplayStyle: PanelDisplayStyle {
        get { PanelDisplayStyle(rawValue: displayStyle ?? "") ?? .chart }
        set { displayStyle = newValue.rawValue }
    }

    var wrappedColorHex: String {
        get { colorHex ?? SeriesColors.palette[0] }
        set { colorHex = newValue }
    }

    var color: Color {
        Color(hex: wrappedColorHex)
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }
}
