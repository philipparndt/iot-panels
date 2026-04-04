import Foundation
import Combine

@Observable
final class ChartExplorerState {
    var timeRange: TimeRange
    var aggregateWindow: AggregateWindow
    var aggregateFunction: AggregateFunction
    var comparisonOffset: ComparisonOffset
    var windowOffset: TimeInterval = 0

    var dataPoints: [ChartDataPoint] = []
    var comparisonDataPoints: [ChartDataPoint] = []
    var isLoading = false
    var errorMessage: String?

    private let panel: DashboardPanel
    private var debounceTask: Task<Void, Never>?

    init(panel: DashboardPanel) {
        self.panel = panel
        self.timeRange = panel.effectiveTimeRange
        self.aggregateWindow = panel.effectiveAggregateWindow
        self.aggregateFunction = panel.effectiveAggregateFunction
        self.comparisonOffset = panel.wrappedComparisonOffset
    }

    // MARK: - Computed Properties

    var stepSize: TimeInterval { timeRange.seconds }

    var canStepForward: Bool { windowOffset < 0 }

    var isMQTT: Bool {
        panel.savedQuery?.dataSource?.wrappedBackendType == .mqtt
    }

    var displayStyle: PanelDisplayStyle {
        panel.wrappedDisplayStyle
    }

    var styleConfig: StyleConfig {
        panel.wrappedStyleConfig
    }

    var title: String {
        panel.wrappedTitle
    }

    var unit: String {
        panel.savedQuery?.wrappedUnit ?? ""
    }

    var needsBandAggregates: Bool {
        panel.wrappedDisplayStyle == .bandChart
    }

    var allowedWindows: [AggregateWindow] {
        timeRange.allowedWindows
    }

    // MARK: - Actions

    func stepBackward() {
        windowOffset -= stepSize
        debouncedLoad()
    }

    func stepForward() {
        windowOffset = min(0, windowOffset + stepSize)
        debouncedLoad()
    }

    func resetOffset() {
        windowOffset = 0
        debouncedLoad()
    }

    func resetAll() {
        timeRange = panel.effectiveTimeRange
        aggregateWindow = panel.effectiveAggregateWindow
        aggregateFunction = panel.effectiveAggregateFunction
        comparisonOffset = panel.wrappedComparisonOffset
        windowOffset = 0
        debouncedLoad()
    }

    var hasChanges: Bool {
        timeRange != panel.effectiveTimeRange
            || aggregateWindow != panel.effectiveAggregateWindow
            || aggregateFunction != panel.effectiveAggregateFunction
            || comparisonOffset != panel.wrappedComparisonOffset
            || windowOffset != 0
    }

    func settingsChanged() {
        debouncedLoad()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let query = panel.savedQuery,
              let dataSource = query.dataSource else {
            errorMessage = "Query or data source missing"
            return
        }

        isLoading = true
        errorMessage = nil

        let service = ServiceFactory.service(for: dataSource)
        let queryString = buildQuery(query: query, dataSource: dataSource)
        let comparisonQueryString = buildComparisonQuery(query: query, dataSource: dataSource)
        let comparisonOffsetSeconds = comparisonOffset.seconds

        Task {
            await performLoad(
                service: service,
                queryString: queryString,
                comparisonQueryString: comparisonQueryString,
                comparisonOffsetSeconds: comparisonOffsetSeconds
            )
        }
    }

    private func performLoad(
        service: any DataSourceServiceProtocol,
        queryString: String,
        comparisonQueryString: String?,
        comparisonOffsetSeconds: TimeInterval
    ) async {
        do {
            let result = try await withThrowingTaskGroup(of: QueryResult.self) { group in
                group.addTask {
                    try await service.query(queryString)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    throw CancellationError()
                }
                let first = try await group.next()!
                group.cancelAll()
                return first
            }
            let parsed = ChartDataParser.parse(result: result)
            let compParsed = await fetchComparisonData(
                queryString: comparisonQueryString,
                service: service,
                offsetSeconds: comparisonOffsetSeconds
            )

            await MainActor.run {
                if !parsed.isEmpty {
                    dataPoints = parsed
                    comparisonDataPoints = compParsed
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if dataPoints.isEmpty {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    // MARK: - Private

    private func fetchComparisonData(
        queryString: String?,
        service: any DataSourceServiceProtocol,
        offsetSeconds: TimeInterval
    ) async -> [ChartDataPoint] {
        guard let compQuery = queryString,
              let compResult = try? await service.query(compQuery) else {
            return []
        }
        return ChartDataParser.parse(result: compResult).map { point in
            ChartDataPoint(
                time: point.time.addingTimeInterval(offsetSeconds),
                value: point.value,
                field: point.field
            )
        }
    }

    private func debouncedLoad() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                loadData()
            }
        }
    }

    // MARK: - Query Building

    /// Seconds ago from "now" for the start of the viewed window.
    /// windowOffset is <= 0 (negative = past), so -windowOffset is the stop point,
    /// and timeRange.seconds further back is the start.
    private var windowStartSecondsAgo: Int {
        Int(timeRange.seconds - windowOffset)
    }

    /// Seconds ago from "now" for the end of the viewed window.
    private var windowStopSecondsAgo: Int {
        Int(-windowOffset)
    }

    private func buildQuery(query: SavedQuery, dataSource: DataSource) -> String {
        if query.wrappedIsRawQuery { return query.wrappedRawQuery }

        switch dataSource.wrappedBackendType {
        case .influxDB1:
            return needsBandAggregates
                ? buildWindowInfluxQLBandQuery(query: query, database: dataSource.wrappedDatabase)
                : buildWindowInfluxQLQuery(query: query, database: dataSource.wrappedDatabase)
        case .influxDB2:
            return needsBandAggregates
                ? buildWindowFluxBandQuery(query: query, bucket: dataSource.wrappedBucket)
                : buildWindowFluxQuery(query: query, bucket: dataSource.wrappedBucket)
        case .influxDB3:
            return needsBandAggregates
                ? buildWindowSQLBandQuery(query: query, database: dataSource.wrappedDatabase)
                : buildWindowSQLQuery(query: query, database: dataSource.wrappedDatabase)
        case .prometheus:
            let promql = query.wrappedRawQuery.isEmpty ? query.wrappedMeasurement : query.wrappedRawQuery
            return "TIMERANGE:\(windowStartSecondsAgo)|\(promql)"
        case .mqtt:
            #if canImport(CocoaMQTT)
            return query.buildMQTTQuery()
            #else
            return ""
            #endif
        case .demo:
            return needsBandAggregates
                ? buildWindowFluxBandQuery(query: query, bucket: "demo")
                : buildWindowFluxQuery(query: query, bucket: "demo")
        }
    }

    private func buildComparisonQuery(query: SavedQuery, dataSource: DataSource) -> String? {
        if query.wrappedIsRawQuery { return nil }
        guard comparisonOffset != .none else { return nil }

        // Comparison window is the same as the primary window, but shifted further back by comparisonOffset.
        let cmpStartSecondsAgo = windowStartSecondsAgo + Int(comparisonOffset.seconds)
        let cmpStopSecondsAgo = windowStopSecondsAgo + Int(comparisonOffset.seconds)

        switch dataSource.wrappedBackendType {
        case .influxDB1:
            return needsBandAggregates
                ? buildWindowInfluxQLBandQuery(query: query, database: dataSource.wrappedDatabase, startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
                : buildWindowInfluxQLQuery(query: query, database: dataSource.wrappedDatabase, startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
        case .influxDB2:
            return needsBandAggregates
                ? buildWindowFluxBandQuery(query: query, bucket: dataSource.wrappedBucket, startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
                : buildWindowFluxQuery(query: query, bucket: dataSource.wrappedBucket, startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
        case .influxDB3:
            return needsBandAggregates
                ? buildWindowSQLBandQuery(query: query, database: dataSource.wrappedDatabase, startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
                : buildWindowSQLQuery(query: query, database: dataSource.wrappedDatabase, startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
        case .prometheus:
            return nil
        case .mqtt:
            return nil
        case .demo:
            return needsBandAggregates
                ? buildWindowFluxBandQuery(query: query, bucket: "demo", startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
                : buildWindowFluxQuery(query: query, bucket: "demo", startAgo: cmpStartSecondsAgo, stopAgo: cmpStopSecondsAgo)
        }
    }

    // MARK: - Flux Query Builders

    private func fluxFilters(query: SavedQuery) -> String {
        var filters = ""
        if !query.wrappedFields.isEmpty {
            let fieldFilter = query.wrappedFields.map { "r[\"_field\"] == \"\($0)\"" }.joined(separator: " or ")
            filters += "\n  |> filter(fn: (r) => \(fieldFilter))"
        }
        for (tagKey, tagValues) in query.wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues.map { "r[\"\(tagKey)\"] == \"\($0)\"" }.joined(separator: " or ")
            filters += "\n  |> filter(fn: (r) => \(tagFilter))"
        }
        return filters
    }

    private func buildWindowFluxQuery(query: SavedQuery, bucket: String, startAgo: Int? = nil, stopAgo: Int? = nil) -> String {
        let start = startAgo ?? windowStartSecondsAgo
        let stop = stopAgo ?? windowStopSecondsAgo
        let aw = aggregateWindow
        let af = aggregateFunction

        var q = """
        from(bucket: "\(bucket)")
          |> range(start: -\(start)s\(stop > 0 ? ", stop: -\(stop)s" : ""))
          |> filter(fn: (r) => r["_measurement"] == "\(query.wrappedMeasurement)")
        """
        q += fluxFilters(query: query)
        if aw != .none {
            q += "\n  |> aggregateWindow(every: \(aw.rawValue), fn: \(af.rawValue), createEmpty: false)"
        }
        q += "\n  |> yield(name: \"results\")"
        return q
    }

    private func buildWindowFluxBandQuery(query: SavedQuery, bucket: String, startAgo: Int? = nil, stopAgo: Int? = nil) -> String {
        let start = startAgo ?? windowStartSecondsAgo
        let stop = stopAgo ?? windowStopSecondsAgo
        let aw = aggregateWindow
        let effectiveWindow = aw == .none ? timeRange.minimumWindow : aw

        var base = """
        from(bucket: "\(bucket)")
          |> range(start: -\(start)s\(stop > 0 ? ", stop: -\(stop)s" : ""))
          |> filter(fn: (r) => r["_measurement"] == "\(query.wrappedMeasurement)")
        """
        base += fluxFilters(query: query)

        let fns: [AggregateFunction] = [.min, .max, .mean]
        return fns.map { fn in
            """
            \(base)
              |> aggregateWindow(every: \(effectiveWindow.rawValue), fn: \(fn.rawValue), createEmpty: false)
              |> map(fn: (r) => ({r with _field: r._field + "_\(fn.rawValue)"}))
              |> yield(name: "\(fn.rawValue)")
            """
        }.joined(separator: "\n\n")
    }

    // MARK: - InfluxQL Query Builders

    private func influxQLConditions(query: SavedQuery, startAgo: Int, stopAgo: Int) -> String {
        var conditions = ["time > now() - \(startAgo)s"]
        if stopAgo > 0 {
            conditions.append("time < now() - \(stopAgo)s")
        }
        for (tagKey, tagValues) in query.wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues.map { "\"\(tagKey)\" = '\($0)'" }.joined(separator: " OR ")
            conditions.append("(\(tagFilter))")
        }
        return conditions.joined(separator: " AND ")
    }

    private func influxQLFnName(_ fn: AggregateFunction) -> String {
        switch fn {
        case .mean: return "MEAN"
        case .last: return "LAST"
        case .max: return "MAX"
        case .min: return "MIN"
        case .sum: return "SUM"
        }
    }

    private func buildWindowInfluxQLQuery(query: SavedQuery, database: String, startAgo: Int? = nil, stopAgo: Int? = nil) -> String {
        let start = startAgo ?? windowStartSecondsAgo
        let stop = stopAgo ?? windowStopSecondsAgo
        let aw = aggregateWindow
        let af = aggregateFunction
        let measurement = "\"\(query.wrappedMeasurement)\""
        let whereClause = influxQLConditions(query: query, startAgo: start, stopAgo: stop)

        if aw != .none && !query.wrappedFields.isEmpty {
            let fnStr = influxQLFnName(af)
            let fields = query.wrappedFields.map { "\(fnStr)(\"\($0)\") AS \"\($0)\"" }
            return "SELECT \(fields.joined(separator: ", ")) FROM \(measurement) WHERE \(whereClause) GROUP BY time(\(aw.rawValue)) fill(none)"
        }

        let selectFields = query.wrappedFields.isEmpty ? "*" : query.wrappedFields.map { "\"\($0)\"" }.joined(separator: ", ")
        return "SELECT \(selectFields) FROM \(measurement) WHERE \(whereClause)"
    }

    private func buildWindowInfluxQLBandQuery(query: SavedQuery, database: String, startAgo: Int? = nil, stopAgo: Int? = nil) -> String {
        let start = startAgo ?? windowStartSecondsAgo
        let stop = stopAgo ?? windowStopSecondsAgo
        let aw = aggregateWindow
        let effectiveWindow = aw == .none ? timeRange.minimumWindow : aw
        let measurement = "\"\(query.wrappedMeasurement)\""
        let whereClause = influxQLConditions(query: query, startAgo: start, stopAgo: stop)

        let fieldList = query.wrappedFields.isEmpty ? ["value"] : query.wrappedFields
        let selectFields = fieldList.flatMap { field -> [String] in
            ["MIN(\"\(field)\") AS \"\(field)_min\"", "MAX(\"\(field)\") AS \"\(field)_max\"", "MEAN(\"\(field)\") AS \"\(field)_mean\""]
        }
        return "SELECT \(selectFields.joined(separator: ", ")) FROM \(measurement) WHERE \(whereClause) GROUP BY time(\(effectiveWindow.rawValue)) fill(none)"
    }

    // MARK: - SQL Query Builders

    private func sqlConditions(query: SavedQuery, startAgo: Int, stopAgo: Int) -> String {
        var conditions = ["time >= NOW() - INTERVAL '\(startAgo) seconds'"]
        if stopAgo > 0 {
            conditions.append("time < NOW() - INTERVAL '\(stopAgo) seconds'")
        }
        for (tagKey, tagValues) in query.wrappedTagFilters where !tagValues.isEmpty {
            let valueList = tagValues.map { "'\(escapeSQLString($0))'" }.joined(separator: ", ")
            conditions.append("\"\(escapeSQLId(tagKey))\" IN (\(valueList))")
        }
        return conditions.joined(separator: " AND ")
    }

    private func buildWindowSQLQuery(query: SavedQuery, database: String, startAgo: Int? = nil, stopAgo: Int? = nil) -> String {
        let start = startAgo ?? windowStartSecondsAgo
        let stop = stopAgo ?? windowStopSecondsAgo
        let aw = aggregateWindow
        let af = aggregateFunction
        let measurement = "\"\(escapeSQLId(query.wrappedMeasurement))\""
        let whereClause = sqlConditions(query: query, startAgo: start, stopAgo: stop)

        if aw != .none {
            let sqlFn = sqlAggregateFunction(af)
            let selectFields = query.wrappedFields.isEmpty
                ? ["\(sqlFn)(value) AS value"]
                : query.wrappedFields.map { "\(sqlFn)(\"\(escapeSQLId($0))\") AS \"\(escapeSQLId($0))\"" }
            return """
            SELECT DATE_BIN(INTERVAL '\(Int(aw.seconds)) seconds', time) AS time, \(selectFields.joined(separator: ", "))
            FROM \(measurement)
            WHERE \(whereClause)
            GROUP BY 1
            ORDER BY 1
            """
        }

        let fields = query.wrappedFields.isEmpty ? ["*"] : query.wrappedFields.map { "\"\(escapeSQLId($0))\"" }
        return """
        SELECT time, \(fields.joined(separator: ", "))
        FROM \(measurement)
        WHERE \(whereClause)
        ORDER BY time
        """
    }

    private func buildWindowSQLBandQuery(query: SavedQuery, database: String, startAgo: Int? = nil, stopAgo: Int? = nil) -> String {
        let start = startAgo ?? windowStartSecondsAgo
        let stop = stopAgo ?? windowStopSecondsAgo
        let aw = aggregateWindow
        let effectiveWindow = aw == .none ? timeRange.minimumWindow : aw
        let measurement = "\"\(escapeSQLId(query.wrappedMeasurement))\""
        let whereClause = sqlConditions(query: query, startAgo: start, stopAgo: stop)

        let fieldList = query.wrappedFields.isEmpty ? ["value"] : query.wrappedFields
        let selectFields = fieldList.flatMap { field -> [String] in
            let f = "\"\(escapeSQLId(field))\""
            return ["MIN(\(f)) AS \"\(escapeSQLId(field))_min\"", "MAX(\(f)) AS \"\(escapeSQLId(field))_max\"", "AVG(\(f)) AS \"\(escapeSQLId(field))_mean\""]
        }
        return """
        SELECT DATE_BIN(INTERVAL '\(Int(effectiveWindow.seconds)) seconds', time) AS time, \(selectFields.joined(separator: ", "))
        FROM \(measurement)
        WHERE \(whereClause)
        GROUP BY 1
        ORDER BY 1
        """
    }

    // MARK: - Helpers

    private func escapeSQLId(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func escapeSQLString(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func sqlAggregateFunction(_ fn: AggregateFunction) -> String {
        switch fn {
        case .mean: return "AVG"
        case .last: return "LAST_VALUE"
        case .max: return "MAX"
        case .min: return "MIN"
        case .sum: return "SUM"
        }
    }
}
