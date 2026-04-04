import Foundation
import CoreData

// MARK: - Template Data Model

struct QueryTemplate {
    let name: String
    let rawQuery: String
    let timeRange: TimeRange
    let aggregateWindow: AggregateWindow
    let unit: String?
}

struct PanelTemplate {
    let title: String
    let displayStyle: PanelDisplayStyle
    let styleConfig: StyleConfig?
    let query: QueryTemplate
    let sortOrder: Int
}

struct DashboardTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let backendType: BackendType
    let panels: [PanelTemplate]
}

// MARK: - Template Application

extension DashboardTemplate {
    @discardableResult
    func apply(to home: Home, dataSource: DataSource, context: NSManagedObjectContext) -> Dashboard {
        let dashboard = Dashboard(context: context)
        dashboard.id = UUID()
        dashboard.name = name
        dashboard.home = home
        dashboard.createdAt = Date()
        dashboard.modifiedAt = Date()

        for panel in panels {
            let query = SavedQuery(context: context)
            query.id = UUID()
            query.name = panel.query.name
            query.isRawQuery = true
            query.rawQuery = panel.query.rawQuery
            query.wrappedTimeRange = panel.query.timeRange
            query.wrappedAggregateWindow = panel.query.aggregateWindow
            query.unit = panel.query.unit
            query.dataSource = dataSource
            query.createdAt = Date()
            query.modifiedAt = Date()

            let p = DashboardPanel(context: context)
            p.id = UUID()
            p.title = panel.title
            p.wrappedDisplayStyle = panel.displayStyle
            p.savedQuery = query
            p.dashboard = dashboard
            p.sortOrder = Int32(panel.sortOrder)
            p.createdAt = Date()
            p.modifiedAt = Date()

            if let config = panel.styleConfig {
                p.wrappedStyleConfig = config
            }
        }

        try? context.save()
        return dashboard
    }
}

// MARK: - Template Registry

enum DashboardTemplateRegistry {
    static func templates(for backendType: BackendType? = nil) -> [DashboardTemplate] {
        let all = [
            nodeExporterLite
        ]
        guard let backendType else { return all }
        return all.filter { $0.backendType == backendType }
    }

    static func availableTemplates(for dataSources: [DataSource]) -> [DashboardTemplate] {
        let backendTypes = Set(dataSources.map(\.wrappedBackendType))
        return templates().filter { backendTypes.contains($0.backendType) }
    }

    // MARK: - Node Exporter Lite

    static let nodeExporterLite = DashboardTemplate(
        id: "node-exporter-lite",
        name: "Node Exporter",
        description: "CPU, memory, disk, network monitoring for Linux servers",
        icon: "server.rack",
        backendType: .prometheus,
        panels: [
            PanelTemplate(
                title: "Uptime",
                displayStyle: .text,
                styleConfig: nil,
                query: QueryTemplate(
                    name: "Uptime",
                    rawQuery: "(time() - node_boot_time_seconds) / 86400",
                    timeRange: .twoHours,
                    aggregateWindow: .fiveMinutes,
                    unit: "days"
                ),
                sortOrder: 0
            ),
            PanelTemplate(
                title: "CPU Usage",
                displayStyle: .circularGauge,
                styleConfig: StyleConfig(gaugeMin: 0, gaugeMax: 100, gaugeColorScheme: GaugeColorScheme.greenToRed.rawValue),
                query: QueryTemplate(
                    name: "CPU Usage %",
                    rawQuery: "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                    timeRange: .twoHours,
                    aggregateWindow: .fiveMinutes,
                    unit: "%"
                ),
                sortOrder: 1
            ),
            PanelTemplate(
                title: "Memory Usage",
                displayStyle: .circularGauge,
                styleConfig: StyleConfig(gaugeMin: 0, gaugeMax: 100, gaugeColorScheme: GaugeColorScheme.greenToRed.rawValue),
                query: QueryTemplate(
                    name: "Memory Usage %",
                    rawQuery: "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",
                    timeRange: .twoHours,
                    aggregateWindow: .fiveMinutes,
                    unit: "%"
                ),
                sortOrder: 2
            ),
            PanelTemplate(
                title: "Disk Usage",
                displayStyle: .circularGauge,
                styleConfig: StyleConfig(gaugeMin: 0, gaugeMax: 100, gaugeColorScheme: GaugeColorScheme.greenToRed.rawValue),
                query: QueryTemplate(
                    name: "Disk Usage %",
                    rawQuery: "(1 - node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100",
                    timeRange: .twoHours,
                    aggregateWindow: .fiveMinutes,
                    unit: "%"
                ),
                sortOrder: 3
            ),
            PanelTemplate(
                title: "CPU Over Time",
                displayStyle: .chart,
                styleConfig: nil,
                query: QueryTemplate(
                    name: "CPU Over Time",
                    rawQuery: "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                    timeRange: .sixHours,
                    aggregateWindow: .oneMinute,
                    unit: "%"
                ),
                sortOrder: 4
            ),
            PanelTemplate(
                title: "Memory Over Time",
                displayStyle: .chart,
                styleConfig: nil,
                query: QueryTemplate(
                    name: "Memory Over Time",
                    rawQuery: "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes",
                    timeRange: .sixHours,
                    aggregateWindow: .oneMinute,
                    unit: "B"
                ),
                sortOrder: 5
            ),
            PanelTemplate(
                title: "Network Traffic",
                displayStyle: .chart,
                styleConfig: nil,
                query: QueryTemplate(
                    name: "Network Receive",
                    rawQuery: "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",
                    timeRange: .sixHours,
                    aggregateWindow: .oneMinute,
                    unit: "B/s"
                ),
                sortOrder: 6
            ),
            PanelTemplate(
                title: "Disk I/O",
                displayStyle: .chart,
                styleConfig: nil,
                query: QueryTemplate(
                    name: "Disk Read",
                    rawQuery: "rate(node_disk_read_bytes_total[5m])",
                    timeRange: .sixHours,
                    aggregateWindow: .oneMinute,
                    unit: "B/s"
                ),
                sortOrder: 7
            ),
        ]
    )
}
