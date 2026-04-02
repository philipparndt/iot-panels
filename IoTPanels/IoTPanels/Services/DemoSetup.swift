import Foundation
import CoreData

/// Creates a complete demo environment with data source, queries, dashboards, and widgets.
enum DemoSetup {

    static func reset(context: NSManagedObjectContext) {
        let home = HomeManager.demoHome(context: context)

        // Delete all existing demo content
        for ds in (home.dataSources as? Set<DataSource>) ?? [] { context.delete(ds) }
        for d in (home.dashboards as? Set<Dashboard>) ?? [] { context.delete(d) }
        for w in (home.widgetDesigns as? Set<WidgetDesign>) ?? [] { context.delete(w) }
        try? context.save()

        install(context: context)
    }

    static func install(context: NSManagedObjectContext) {
        let home = HomeManager.demoHome(context: context)
        let ds = createDataSource(context: context, home: home)

        // Queries
        let tempLiving = createQuery(context: context, dataSource: ds, name: "Living Room Temperature",
                                     measurement: "temperature", fields: ["value"],
                                     tags: ["location": ["living_room"]],
                                     timeRange: .sixHours, window: .fiveMinutes, unit: "°C")

        let tempBedroom = createQuery(context: context, dataSource: ds, name: "Bedroom Temperature",
                                      measurement: "temperature", fields: ["value"],
                                      tags: ["location": ["bedroom"]],
                                      timeRange: .sixHours, window: .fiveMinutes, unit: "°C")

        let humidityLiving = createQuery(context: context, dataSource: ds, name: "Living Room Humidity",
                                         measurement: "humidity", fields: ["relative"],
                                         tags: ["location": ["living_room"]],
                                         timeRange: .sixHours, window: .fiveMinutes, unit: "%")

        let solarProduction = createQuery(context: context, dataSource: ds, name: "Solar Production",
                                          measurement: "solar", fields: ["production"],
                                          timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "W")

        let solarFeedIn = createQuery(context: context, dataSource: ds, name: "Solar Feed-in",
                                      measurement: "solar", fields: ["feed_in"],
                                      timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "W")

        let energyPower = createQuery(context: context, dataSource: ds, name: "Power Consumption",
                                      measurement: "energy", fields: ["power"],
                                      timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "W")

        let energyConsumption = createQuery(context: context, dataSource: ds, name: "Power Usage (7 Days)",
                                            measurement: "energy", fields: ["power"],
                                            timeRange: .sevenDays, window: .oneHour, fn: .mean, unit: "W")

        let batteryLevel = createQuery(context: context, dataSource: ds, name: "Battery Level",
                                       measurement: "battery", fields: ["level"],
                                       timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "%")

        let airCO2 = createQuery(context: context, dataSource: ds, name: "CO₂ Level",
                                 measurement: "air_quality", fields: ["co2"],
                                 tags: ["room": ["living_room"]],
                                 timeRange: .sixHours, window: .fiveMinutes, unit: "ppm")

        let airPM25 = createQuery(context: context, dataSource: ds, name: "PM2.5",
                                  measurement: "air_quality", fields: ["pm25"],
                                  tags: ["room": ["living_room"]],
                                  timeRange: .sixHours, window: .fiveMinutes, unit: "µg/m³")

        // Dashboard: Climate
        let climate = createDashboard(context: context, name: "Climate", home: home)
        addPanel(context: context, dashboard: climate, query: tempLiving, title: "Living Room", style: .chart, order: 0)
        addPanel(context: context, dashboard: climate, query: tempBedroom, title: "Bedroom", style: .chart, order: 1)
        addPanel(context: context, dashboard: climate, query: humidityLiving, title: "Humidity", style: .chart, order: 2)
        addPanel(context: context, dashboard: climate, query: airCO2, title: "CO₂", style: .chart, order: 3)
        addPanel(context: context, dashboard: climate, query: airPM25, title: "PM2.5", style: .chart, order: 4)

        // Dashboard: Energy
        let energy = createDashboard(context: context, name: "Energy", home: home)
        addPanel(context: context, dashboard: energy, query: solarProduction, title: "Solar Production", style: .barChart, order: 0)
        addPanel(context: context, dashboard: energy, query: solarFeedIn, title: "Feed-in", style: .chart, order: 1)
        addPanel(context: context, dashboard: energy, query: energyPower, title: "Power Consumption", style: .barChart, order: 2)
        addPanel(context: context, dashboard: energy, query: energyConsumption, title: "Daily Consumption", style: .chart, order: 3)
        let batteryPanel = addPanel(context: context, dashboard: energy, query: batteryLevel, title: "Battery", style: .gauge, order: 4)
        batteryPanel.wrappedStyleConfig = StyleConfig(gaugeMin: 0, gaugeMax: 100, gaugeColorScheme: GaugeColorScheme.greenToRed.rawValue)

        // Queries: Garden/Weather
        let gardenTemp = createQuery(context: context, dataSource: ds, name: "Outdoor Temperature",
                                     measurement: "weather", fields: ["temperature"],
                                     timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "°C")

        let windSpeed = createQuery(context: context, dataSource: ds, name: "Wind Speed",
                                    measurement: "weather", fields: ["wind_speed"],
                                    timeRange: .sixHours, window: .fiveMinutes, unit: "km/h")

        let windGust = createQuery(context: context, dataSource: ds, name: "Wind Gusts",
                                   measurement: "weather", fields: ["wind_gust"],
                                   timeRange: .sixHours, window: .fiveMinutes, unit: "km/h")

        let rain = createQuery(context: context, dataSource: ds, name: "Rain",
                               measurement: "weather", fields: ["rain"],
                               timeRange: .twentyFourHours, window: .fifteenMinutes, fn: .sum, unit: "mm")

        let pressure = createQuery(context: context, dataSource: ds, name: "Pressure",
                                   measurement: "weather", fields: ["pressure"],
                                   timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "hPa")

        // Band chart query for temperature range
        let tempRange = createQuery(context: context, dataSource: ds, name: "Temperature Range",
                                    measurement: "temperature", fields: ["value"],
                                    tags: ["location": ["living_room"]],
                                    timeRange: .twentyFourHours, window: .fifteenMinutes, unit: "°C")

        // Band chart panel on Climate dashboard
        addPanel(context: context, dashboard: climate, query: tempRange, title: "Temperature Band", style: .bandChart, order: 5)

        // Comparison demo: same as Living Room but with comparison offset
        let compPanel = addPanel(context: context, dashboard: climate, query: tempLiving, title: "Temperature (vs. Yesterday)", style: .chart, order: 6)
        compPanel.comparisonOffset = ComparisonOffset.twentyFourHours.rawValue

        // Dashboard: Garden
        let garden = createDashboard(context: context, name: "Garden", home: home)
        addPanel(context: context, dashboard: garden, query: gardenTemp, title: "Temperature", style: .chart, order: 0)
        addPanel(context: context, dashboard: garden, query: windSpeed, title: "Wind Speed", style: .chart, order: 1)
        addPanel(context: context, dashboard: garden, query: windGust, title: "Wind Gusts", style: .chart, order: 2)
        addPanel(context: context, dashboard: garden, query: rain, title: "Rain", style: .barChart, order: 3)
        addPanel(context: context, dashboard: garden, query: pressure, title: "Pressure", style: .chart, order: 4)

        // Widget: Home Overview (medium)
        let widget = createWidgetDesign(context: context, name: "Home Overview", size: .medium, home: home)
        addWidgetItem(context: context, design: widget, query: tempLiving, title: "Temperature", style: .singleValue, color: "#4A90D9", order: 0)
        addWidgetItem(context: context, design: widget, query: humidityLiving, title: "Humidity", style: .singleValue, color: "#2ECC71", order: 1)
        let batteryWidget = addWidgetItem(context: context, design: widget, query: batteryLevel, title: "Battery", style: .gauge, color: "#F39C12", order: 2)
        batteryWidget.wrappedStyleConfig = StyleConfig(gaugeMin: 0, gaugeMax: 100, gaugeColorScheme: GaugeColorScheme.greenToRed.rawValue)

        try? context.save()
        WidgetHelper.reloadWidgets()
    }

    // MARK: - Builders

    private static func createDataSource(context: NSManagedObjectContext, home: Home) -> DataSource {
        let ds = DataSource(context: context)
        ds.id = UUID()
        ds.name = "Demo Sensors"
        ds.backendType = BackendType.demo.rawValue
        ds.isDemo = true
        ds.home = home
        ds.createdAt = Date()
        ds.modifiedAt = Date()
        return ds
    }

    private static func createQuery(
        context: NSManagedObjectContext,
        dataSource: DataSource,
        name: String,
        measurement: String,
        fields: [String],
        tags: [String: [String]] = [:],
        timeRange: TimeRange = .twoHours,
        window: AggregateWindow = .fiveMinutes,
        fn: AggregateFunction = .mean,
        unit: String? = nil
    ) -> SavedQuery {
        let q = SavedQuery(context: context)
        q.id = UUID()
        q.name = name
        q.measurement = measurement
        q.wrappedFields = fields
        q.wrappedTagFilters = tags
        q.wrappedTimeRange = timeRange
        q.wrappedAggregateWindow = window
        q.wrappedAggregateFunction = fn
        q.unit = unit
        q.dataSource = dataSource
        q.createdAt = Date()
        q.modifiedAt = Date()
        return q
    }

    private static func createDashboard(context: NSManagedObjectContext, name: String, home: Home) -> Dashboard {
        let d = Dashboard(context: context)
        d.id = UUID()
        d.name = name
        d.isDemo = true
        d.home = home
        d.createdAt = Date()
        d.modifiedAt = Date()
        return d
    }

    @discardableResult
    private static func addPanel(
        context: NSManagedObjectContext,
        dashboard: Dashboard,
        query: SavedQuery,
        title: String,
        style: PanelDisplayStyle = .auto,
        order: Int
    ) -> DashboardPanel {
        let p = DashboardPanel(context: context)
        p.id = UUID()
        p.title = title
        p.wrappedDisplayStyle = style
        p.savedQuery = query
        p.dashboard = dashboard
        p.sortOrder = Int32(order)
        p.createdAt = Date()
        p.modifiedAt = Date()
        return p
    }

    private static func createWidgetDesign(context: NSManagedObjectContext, name: String, size: WidgetSizeType, home: Home) -> WidgetDesign {
        let w = WidgetDesign(context: context)
        w.id = UUID()
        w.name = name
        w.sizeType = size.rawValue
        w.isDemo = true
        w.home = home
        w.createdAt = Date()
        w.modifiedAt = Date()
        return w
    }

    @discardableResult
    private static func addWidgetItem(
        context: NSManagedObjectContext,
        design: WidgetDesign,
        query: SavedQuery,
        title: String,
        style: PanelDisplayStyle = .singleValue,
        color: String = "#4A90D9",
        order: Int
    ) -> WidgetDesignItem {
        let item = WidgetDesignItem(context: context)
        item.id = UUID()
        item.title = title
        item.displayStyle = style.rawValue
        item.colorHex = color
        item.savedQuery = query
        item.widgetDesign = design
        item.sortOrder = Int32(order)
        item.createdAt = Date()
        item.modifiedAt = Date()
        return item
    }
}
