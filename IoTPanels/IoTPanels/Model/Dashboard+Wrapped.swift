import Foundation
import CoreData

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

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }
}
