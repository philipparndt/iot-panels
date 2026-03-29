import CoreData

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    static let appGroupIdentifier = "group.de.rnd7.iotpanels"

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

    @Published var isLoaded = false

    private(set) var container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "IoTPanels")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store descriptions found")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.shouldAddStoreAsynchronously = false
        } else if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            let appGroupStoreURL = containerURL.appendingPathComponent("IoTPanels.sqlite")
            Self.migrateStoreIfNeeded(to: appGroupStoreURL)
            description.url = appGroupStoreURL
            description.shouldAddStoreAsynchronously = true
        }

        // Only enable CloudKit sync in the main app, not in extensions
        if Bundle.main.bundlePath.hasSuffix(".app") {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.de.rnd7.iotpanels"
            )
        } else {
            description.cloudKitContainerOptions = nil
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data load error: \(error), \(error.userInfo)")
            }
            print("Core Data store loaded at: \(storeDescription.url?.absoluteString ?? "unknown")")

            DispatchQueue.main.async {
                self?.container.viewContext.automaticallyMergesChangesFromParent = true
                self?.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                self?.isLoaded = true
            }
        }

        if inMemory {
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            isLoaded = true
        }
    }

    /// Migrate the default Core Data store to the App Group container if the App Group store doesn't exist yet.
    private static func migrateStoreIfNeeded(to appGroupStoreURL: URL) {
        let fileManager = FileManager.default

        // If App Group store already exists, no migration needed
        if fileManager.fileExists(atPath: appGroupStoreURL.path) {
            return
        }

        // Find the old default store location
        guard let defaultStoreURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let oldStoreURL = defaultStoreURL.appendingPathComponent("IoTPanels.sqlite")

        guard fileManager.fileExists(atPath: oldStoreURL.path) else {
            return
        }

        print("Migrating Core Data store from \(oldStoreURL) to \(appGroupStoreURL)")

        // Copy all SQLite files (sqlite, sqlite-wal, sqlite-shm)
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let sourceURL = suffix.isEmpty ? oldStoreURL : URL(fileURLWithPath: oldStoreURL.path + suffix)
            let destURL = suffix.isEmpty ? appGroupStoreURL : URL(fileURLWithPath: appGroupStoreURL.path + suffix)

            if fileManager.fileExists(atPath: sourceURL.path) {
                do {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                    print("Migrated \(sourceURL.lastPathComponent)")
                } catch {
                    print("Failed to migrate \(sourceURL.lastPathComponent): \(error)")
                }
            }
        }
    }
}
