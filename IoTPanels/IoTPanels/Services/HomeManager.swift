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

        // Create "Demo Home" if missing
        if demoHomes.isEmpty {
            let demo = Home(context: context)
            demo.id = UUID()
            demo.name = "Demo Home"
            demo.icon = "house.and.flag"
            demo.isDemo = true
            demo.sortOrder = 1
            demo.createdAt = Date()
        }

        try? context.save()
        return myHome
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
