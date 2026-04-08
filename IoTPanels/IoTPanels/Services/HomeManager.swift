import Foundation
import CoreData

/// Manages the creation and bootstrapping of Home entities.
enum HomeManager {

    private static var hasBootstrapped = false

    /// Ensures default homes exist. Returns the "My Home" instance.
    @discardableResult
    static func bootstrap(context: NSManagedObjectContext) -> Home {
        guard !hasBootstrapped else {
            // Already bootstrapped this session — just return existing My Home
            let request: NSFetchRequest<Home> = Home.fetchRequest()
            request.predicate = NSPredicate(format: "isDemo == NO")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Home.sortOrder, ascending: true)]
            request.fetchLimit = 1
            if let home = (try? context.fetch(request))?.first {
                return home
            }
            hasBootstrapped = false // fallthrough to create
            return bootstrap(context: context)
        }
        hasBootstrapped = true

        let request: NSFetchRequest<Home> = Home.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Home.sortOrder, ascending: true)]
        let existing = (try? context.fetch(request)) ?? []

        // Deduplicate: keep the oldest of each type, delete extras
        let nonDemoHomes = existing.filter { !$0.isDemo }
        let demoHomes = existing.filter { $0.isDemo }

        if nonDemoHomes.count > 1 {
            for home in nonDemoHomes.dropFirst() {
                context.delete(home)
            }
        }
        if demoHomes.count > 1 {
            for home in demoHomes.dropFirst() {
                context.delete(home)
            }
        }

        // Create "My Home" if missing
        let myHome: Home
        if let found = nonDemoHomes.first {
            myHome = found
        } else {
            myHome = Home(context: context)
            myHome.id = UUID()
            myHome.name = "My Home"
            myHome.icon = "house"
            myHome.isDemo = false
            myHome.sortOrder = 0
            myHome.createdAt = Date()
        }

        // Note: the demo home is no longer auto-created here. CloudKit has no
        // unique constraints, so creating one per device on first launch led to
        // demo homes accumulating across devices. The demo home is now created
        // on demand via the "Try Demo Home" button in DashboardListView.

        // Remove orphaned entities (home == nil) from older app versions
        deleteOrphans(of: Dashboard.self, context: context)
        deleteOrphans(of: DataSource.self, context: context)
        deleteOrphans(of: WidgetDesign.self, context: context)
        deleteOrphans(of: SavedQuery.self, key: "dataSource", context: context)
        deleteOrphans(of: DashboardPanel.self, key: "dashboard", context: context)
        deleteOrphans(of: WidgetDesignItem.self, key: "widgetDesign", context: context)

        try? context.save()
        return myHome
    }

    private static func deleteOrphans<T: NSManagedObject>(of type: T.Type, key: String = "home", context: NSManagedObjectContext) {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "%K == nil", key)
        guard let orphans = try? context.fetch(request) as? [T] else { return }
        for orphan in orphans {
            context.delete(orphan)
        }
    }

    /// Returns the demo home, creating it if needed.
    static func demoHome(context: NSManagedObjectContext) -> Home {
        let request: NSFetchRequest<Home> = Home.fetchRequest()
        request.predicate = NSPredicate(format: "isDemo == YES")
        request.fetchLimit = 1
        if let home = (try? context.fetch(request))?.first {
            return home
        }
        let home = Home(context: context)
        home.id = UUID()
        home.name = "Demo Home"
        home.icon = "house.and.flag"
        home.isDemo = true
        home.sortOrder = 1
        home.createdAt = Date()
        try? context.save()
        return home
    }

    /// Creates a new demo home (always a fresh record). Caller is responsible
    /// for populating it with `DemoSetup.install(into:context:)`.
    @discardableResult
    static func createDemoHome(name: String = "Demo Home", context: NSManagedObjectContext) -> Home {
        let request: NSFetchRequest<Home> = Home.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0

        let home = Home(context: context)
        home.id = UUID()
        home.name = name
        home.icon = "house.and.flag"
        home.isDemo = true
        home.sortOrder = Int32(count)
        home.createdAt = Date()
        try? context.save()
        return home
    }

    /// Creates a new custom home.
    @discardableResult
    static func createHome(name: String, icon: String = "house", context: NSManagedObjectContext) -> Home {
        let request: NSFetchRequest<Home> = Home.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0

        let home = Home(context: context)
        home.id = UUID()
        home.name = name
        home.icon = icon
        home.isDemo = false
        home.sortOrder = Int32(count)
        home.createdAt = Date()
        try? context.save()
        return home
    }
}
