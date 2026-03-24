import Foundation
import CoreData

enum PanelDisplayStyle: String, CaseIterable, Identifiable {
    case auto
    case chart
    case singleValue
    case gauge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .chart: return "Curve"
        case .singleValue: return "Value"
        case .gauge: return "Gauge"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .chart: return "chart.xyaxis.line"
        case .singleValue: return "number"
        case .gauge: return "gauge.medium"
        }
    }
}

extension Dashboard {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    var sortedPanels: [DashboardPanel] {
        let set = panels as? Set<DashboardPanel> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension DashboardPanel {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedTitle: String {
        get { title ?? "" }
        set { title = newValue }
    }

    var wrappedDisplayStyle: PanelDisplayStyle {
        get { PanelDisplayStyle(rawValue: displayStyle ?? "") ?? .auto }
        set { displayStyle = newValue.rawValue }
    }

    var wrappedStyleConfig: StyleConfig {
        get { StyleConfig.decode(from: styleConfigJSON) }
        set { styleConfigJSON = newValue.encode() }
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
