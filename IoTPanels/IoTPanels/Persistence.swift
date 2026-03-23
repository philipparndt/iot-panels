import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let source = DataSource(context: viewContext)
        source.id = UUID()
        source.name = "My InfluxDB"
        source.backendType = BackendType.influxDB2.rawValue
        source.url = "http://localhost:8086"
        source.token = "my-token"
        source.organization = "my-org"
        source.bucket = "my-bucket"
        source.createdAt = Date()
        source.modifiedAt = Date()

        do {
            try viewContext.save()
        } catch {
            fatalError("Preview persistence error: \(error)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "IoTPanels")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data load error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
