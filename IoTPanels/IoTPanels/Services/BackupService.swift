import Foundation
import CoreData

// MARK: - Backup Data Model

struct BackupData: Codable {
    let version: Int
    let exportedAt: String
    let homes: [BackupHome]
}

struct BackupHome: Codable {
    let id: String
    let name: String?
    let icon: String?
    let sortOrder: Int32
    let dataSources: [BackupDataSource]
    let dashboards: [BackupDashboard]
    let widgetDesigns: [BackupWidgetDesign]
}

struct BackupDataSource: Codable {
    let id: String
    let name: String?
    let backendType: String?

    // InfluxDB
    let url: String?
    let token: String?
    let organization: String?
    let bucket: String?
    let database: String?
    let influxAuthMethod: String?

    // MQTT
    let hostname: String?
    let port: Int32?
    let clientID: String?
    let username: String?
    let password: String?
    let ssl: Bool?
    let untrustedSSL: Bool?
    let protocolMethod: String?
    let protocolVersion: String?
    let basePath: String?
    let mqttBaseTopic: String?
    let subscriptionsJSON: String?
    let certificatesJSON: String?
    let certClientKeyPassword: String?
    let alpn: String?

    let savedQueries: [BackupSavedQuery]
}

struct BackupSavedQuery: Codable {
    let id: String
    let name: String?
    let measurement: String?
    let fieldsJSON: String?
    let tagFiltersJSON: String?
    let timeRange: String?
    let aggregateWindow: String?
    let aggregateFunction: String?
    let unit: String?
    let rawQuery: String?
    let isRawQuery: Bool
}

struct BackupDashboard: Codable {
    let id: String
    let name: String?
    let panels: [BackupDashboardPanel]
}

struct BackupDashboardPanel: Codable {
    let id: String
    let title: String?
    let displayStyle: String?
    let styleConfigJSON: String?
    let sortOrder: Int32
    let timeRange: String?
    let aggregateWindow: String?
    let aggregateFunction: String?
    let comparisonOffset: String?
    let savedQueryId: String?
    let widthSlot: String?
    let lineBreakBefore: Bool?
}

struct BackupWidgetDesign: Codable {
    let id: String
    let name: String?
    let sizeType: String?
    let textScale: String?
    let refreshInterval: Int32
    let backgroundColorHex: String?
    let items: [BackupWidgetDesignItem]
}

struct BackupWidgetDesignItem: Codable {
    let id: String
    let title: String?
    let displayStyle: String?
    let colorHex: String?
    let groupTag: String?
    let styleConfigJSON: String?
    let sortOrder: Int32
    let timeRange: String?
    let aggregateWindow: String?
    let aggregateFunction: String?
    let comparisonOffset: String?
    let savedQueryId: String?
}

// MARK: - BackupService

enum BackupService {

    // MARK: - Export

    static func export(context: NSManagedObjectContext) -> BackupData {
        let request = Home.fetchRequest()
        request.predicate = NSPredicate(format: "isDemo == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Home.sortOrder, ascending: true)]
        let homes = (try? context.fetch(request)) ?? []

        let backupHomes = homes.map { home in
            BackupHome(
                id: home.id?.uuidString ?? UUID().uuidString,
                name: home.name,
                icon: home.icon,
                sortOrder: home.sortOrder,
                dataSources: exportDataSources(for: home),
                dashboards: exportDashboards(for: home),
                widgetDesigns: exportWidgetDesigns(for: home)
            )
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return BackupData(
            version: 1,
            exportedAt: formatter.string(from: Date()),
            homes: backupHomes
        )
    }

    static func exportToFile(context: NSManagedObjectContext) -> URL? {
        let data = export(context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }

        return DataExporter.tempFile(name: "iot-panels-backup", ext: "json", content: jsonString)
    }

    // MARK: - Import

    static func restore(from backup: BackupData, context: NSManagedObjectContext) throws {
        for backupHome in backup.homes {
            // Delete existing home with same UUID if present
            if let uuid = UUID(uuidString: backupHome.id) {
                let request = Home.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                if let existing = (try? context.fetch(request))?.first {
                    context.delete(existing)
                }
            }

            let home = Home(context: context)
            home.id = UUID(uuidString: backupHome.id) ?? UUID()
            home.name = backupHome.name
            home.icon = backupHome.icon
            home.sortOrder = backupHome.sortOrder
            home.isDemo = false
            home.createdAt = Date()
            
            // Build SavedQuery UUID map for cross-references
            var queryMap: [String: SavedQuery] = [:]

            // Import DataSources + SavedQueries
            for backupDS in backupHome.dataSources {
                let ds = DataSource(context: context)
                ds.id = UUID(uuidString: backupDS.id) ?? UUID()
                ds.name = backupDS.name
                ds.backendType = backupDS.backendType
                ds.url = backupDS.url
                ds.token = backupDS.token
                ds.organization = backupDS.organization
                ds.bucket = backupDS.bucket
                ds.database = backupDS.database
                ds.influxAuthMethod = backupDS.influxAuthMethod
                ds.hostname = backupDS.hostname
                ds.port = backupDS.port ?? 1883
                ds.clientID = backupDS.clientID
                ds.username = backupDS.username
                ds.password = backupDS.password
                ds.ssl = backupDS.ssl ?? false
                ds.untrustedSSL = backupDS.untrustedSSL ?? false
                ds.protocolMethod = backupDS.protocolMethod
                ds.protocolVersion = backupDS.protocolVersion
                ds.basePath = backupDS.basePath
                ds.mqttBaseTopic = backupDS.mqttBaseTopic
                ds.subscriptionsJSON = backupDS.subscriptionsJSON
                ds.certificatesJSON = backupDS.certificatesJSON
                ds.certClientKeyPassword = backupDS.certClientKeyPassword
                ds.alpn = backupDS.alpn
                ds.isDemo = false
                ds.createdAt = Date()
                ds.modifiedAt = Date()
                ds.home = home

                for backupQuery in backupDS.savedQueries {
                    let query = SavedQuery(context: context)
                    query.id = UUID(uuidString: backupQuery.id) ?? UUID()
                    query.name = backupQuery.name
                    query.measurement = backupQuery.measurement
                    query.fieldsJSON = backupQuery.fieldsJSON
                    query.tagFiltersJSON = backupQuery.tagFiltersJSON
                    query.timeRange = backupQuery.timeRange
                    query.aggregateWindow = backupQuery.aggregateWindow
                    query.aggregateFunction = backupQuery.aggregateFunction
                    query.unit = backupQuery.unit
                    query.rawQuery = backupQuery.rawQuery
                    query.isRawQuery = backupQuery.isRawQuery
                    query.createdAt = Date()
                    query.modifiedAt = Date()
                    query.dataSource = ds

                    queryMap[backupQuery.id] = query
                }
            }

            // Import Dashboards + Panels
            for backupDash in backupHome.dashboards {
                let dash = Dashboard(context: context)
                dash.id = UUID(uuidString: backupDash.id) ?? UUID()
                dash.name = backupDash.name
                dash.isDemo = false
                dash.createdAt = Date()
                dash.modifiedAt = Date()
                dash.home = home

                for backupPanel in backupDash.panels {
                    let panel = DashboardPanel(context: context)
                    panel.id = UUID(uuidString: backupPanel.id) ?? UUID()
                    panel.title = backupPanel.title
                    panel.displayStyle = backupPanel.displayStyle
                    panel.styleConfigJSON = backupPanel.styleConfigJSON
                    panel.sortOrder = backupPanel.sortOrder
                    panel.timeRange = backupPanel.timeRange
                    panel.aggregateWindow = backupPanel.aggregateWindow
                    panel.aggregateFunction = backupPanel.aggregateFunction
                    panel.comparisonOffset = backupPanel.comparisonOffset
                    panel.widthSlot = backupPanel.widthSlot
                    panel.lineBreakBefore = backupPanel.lineBreakBefore ?? false
                    panel.createdAt = Date()
                    panel.modifiedAt = Date()
                    panel.dashboard = dash

                    if let qid = backupPanel.savedQueryId {
                        panel.savedQuery = queryMap[qid]
                    }
                }
            }

            // Import WidgetDesigns + Items
            for backupWidget in backupHome.widgetDesigns {
                let widget = WidgetDesign(context: context)
                widget.id = UUID(uuidString: backupWidget.id) ?? UUID()
                widget.name = backupWidget.name
                widget.sizeType = backupWidget.sizeType
                widget.textScale = backupWidget.textScale
                widget.refreshInterval = backupWidget.refreshInterval
                widget.backgroundColorHex = backupWidget.backgroundColorHex
                widget.isDemo = false
                widget.createdAt = Date()
                widget.modifiedAt = Date()
                widget.home = home

                for backupItem in backupWidget.items {
                    let item = WidgetDesignItem(context: context)
                    item.id = UUID(uuidString: backupItem.id) ?? UUID()
                    item.title = backupItem.title
                    item.displayStyle = backupItem.displayStyle
                    item.colorHex = backupItem.colorHex
                    item.groupTag = backupItem.groupTag
                    item.styleConfigJSON = backupItem.styleConfigJSON
                    item.sortOrder = backupItem.sortOrder
                    item.timeRange = backupItem.timeRange
                    item.aggregateWindow = backupItem.aggregateWindow
                    item.aggregateFunction = backupItem.aggregateFunction
                    item.comparisonOffset = backupItem.comparisonOffset
                    item.createdAt = Date()
                    item.modifiedAt = Date()
                    item.widgetDesign = widget

                    if let qid = backupItem.savedQueryId {
                        item.savedQuery = queryMap[qid]
                    }
                }
            }
        }

        try context.save()
    }

    static func restoreFromFile(url: URL, context: NSManagedObjectContext) throws {
        let data = try Data(contentsOf: url)
        let backup = try JSONDecoder().decode(BackupData.self, from: data)
        try restore(from: backup, context: context)
    }

    // MARK: - Private Export Helpers

    private static func exportDataSources(for home: Home) -> [BackupDataSource] {
        let sources = (home.dataSources as? Set<DataSource>) ?? []
        return sources.filter { !$0.isDemo }.map { ds in
            let isMQTT = ds.backendType == "mqtt"
            let isInflux = !isMQTT

            return BackupDataSource(
                id: ds.id?.uuidString ?? UUID().uuidString,
                name: ds.name,
                backendType: ds.backendType,
                // InfluxDB fields
                url: isInflux ? ds.url : nil,
                token: isInflux ? nilIfEmpty(ds.token) : nil,
                organization: isInflux ? nilIfEmpty(ds.organization) : nil,
                bucket: isInflux ? nilIfEmpty(ds.bucket) : nil,
                database: isInflux ? nilIfEmpty(ds.database) : nil,
                influxAuthMethod: isInflux ? ds.influxAuthMethod : nil,
                // MQTT fields
                hostname: isMQTT ? ds.hostname : nil,
                port: isMQTT ? ds.port : nil,
                clientID: isMQTT ? nilIfEmpty(ds.clientID) : nil,
                username: nilIfEmpty(ds.username),
                password: nilIfEmpty(ds.password),
                ssl: isMQTT ? ds.ssl : nil,
                untrustedSSL: isMQTT && ds.ssl ? ds.untrustedSSL : nil,
                protocolMethod: isMQTT ? ds.protocolMethod : nil,
                protocolVersion: isMQTT ? ds.protocolVersion : nil,
                basePath: isMQTT ? nilIfEmpty(ds.basePath) : nil,
                mqttBaseTopic: isMQTT ? nilIfEmpty(ds.mqttBaseTopic) : nil,
                subscriptionsJSON: isMQTT ? ds.subscriptionsJSON : nil,
                certificatesJSON: isMQTT ? ds.certificatesJSON : nil,
                certClientKeyPassword: isMQTT ? nilIfEmpty(ds.certClientKeyPassword) : nil,
                alpn: isMQTT ? nilIfEmpty(ds.alpn) : nil,
                savedQueries: exportSavedQueries(for: ds)
            )
        }
    }

    private static func nilIfEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func exportSavedQueries(for ds: DataSource) -> [BackupSavedQuery] {
        let queries = (ds.savedQueries as? Set<SavedQuery>) ?? []
        return queries.map { q in
            BackupSavedQuery(
                id: q.id?.uuidString ?? UUID().uuidString,
                name: q.name, measurement: q.measurement,
                fieldsJSON: q.fieldsJSON, tagFiltersJSON: q.tagFiltersJSON,
                timeRange: q.timeRange, aggregateWindow: q.aggregateWindow,
                aggregateFunction: q.aggregateFunction, unit: q.unit,
                rawQuery: q.rawQuery, isRawQuery: q.isRawQuery
            )
        }
    }

    private static func exportDashboards(for home: Home) -> [BackupDashboard] {
        let dashboards = (home.dashboards as? Set<Dashboard>) ?? []
        return dashboards.filter { !$0.isDemo }.map { dash in
            let panels = (dash.panels as? Set<DashboardPanel>) ?? []
            return BackupDashboard(
                id: dash.id?.uuidString ?? UUID().uuidString,
                name: dash.name,
                panels: panels.sorted(by: { $0.sortOrder < $1.sortOrder }).map { panel in
                    BackupDashboardPanel(
                        id: panel.id?.uuidString ?? UUID().uuidString,
                        title: panel.title, displayStyle: panel.displayStyle,
                        styleConfigJSON: panel.styleConfigJSON,
                        sortOrder: panel.sortOrder,
                        timeRange: panel.timeRange, aggregateWindow: panel.aggregateWindow,
                        aggregateFunction: panel.aggregateFunction,
                        comparisonOffset: panel.comparisonOffset,
                        savedQueryId: panel.savedQuery?.id?.uuidString,
                        widthSlot: panel.widthSlot,
                        lineBreakBefore: panel.lineBreakBefore ? true : nil
                    )
                }
            )
        }
    }

    private static func exportWidgetDesigns(for home: Home) -> [BackupWidgetDesign] {
        let designs = (home.widgetDesigns as? Set<WidgetDesign>) ?? []
        return designs.filter { !$0.isDemo }.map { design in
            let items = (design.items as? Set<WidgetDesignItem>) ?? []
            return BackupWidgetDesign(
                id: design.id?.uuidString ?? UUID().uuidString,
                name: design.name, sizeType: design.sizeType,
                textScale: design.textScale,
                refreshInterval: design.refreshInterval,
                backgroundColorHex: design.backgroundColorHex,
                items: items.sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
                    BackupWidgetDesignItem(
                        id: item.id?.uuidString ?? UUID().uuidString,
                        title: item.title, displayStyle: item.displayStyle,
                        colorHex: item.colorHex, groupTag: item.groupTag,
                        styleConfigJSON: item.styleConfigJSON,
                        sortOrder: item.sortOrder,
                        timeRange: item.timeRange, aggregateWindow: item.aggregateWindow,
                        aggregateFunction: item.aggregateFunction,
                        comparisonOffset: item.comparisonOffset,
                        savedQueryId: item.savedQuery?.id?.uuidString
                    )
                }
            )
        }
    }
}
