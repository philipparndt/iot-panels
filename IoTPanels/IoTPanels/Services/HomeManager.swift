import Foundation
import CoreData

/// Manages the creation and bootstrapping of Home entities.
enum HomeManager {

    /// Ensures default homes exist. Returns the "My Home" instance.
    @discardableResult
    static func bootstrap(context: NSManagedObjectContext) -> Home {
        let request: NSFetchRequest<Home> = Home.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Home.sortOrder, ascending: true)]
        let existing = (try? context.fetch(request)) ?? []

        // Create "My Home" if missing
        let myHome: Home
        if let found = existing.first(where: { !$0.isDemo }) {
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
        if !existing.contains(where: { $0.isDemo }) {
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
        if let existing = try? context.fetch(request), let home = existing.first {
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
