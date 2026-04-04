import Foundation

extension SavedQuery {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedMeasurement: String {
        get { measurement ?? "" }
        set { measurement = newValue }
    }

    var wrappedFields: [String] {
        get {
            guard let json = fieldsJSON, let data = json.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }
        set {
            fieldsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    var wrappedTagFilters: [String: [String]] {
        get {
            guard let json = tagFiltersJSON, let data = json.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
            return dict
        }
        set {
            tagFiltersJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
        }
    }

    var wrappedTimeRange: TimeRange {
        get { TimeRange(rawValue: timeRange ?? "") ?? .twoHours }
        set { timeRange = newValue.rawValue }
    }

    var wrappedAggregateFunction: AggregateFunction {
        get { AggregateFunction(rawValue: aggregateFunction ?? "") ?? .mean }
        set { aggregateFunction = newValue.rawValue }
    }

    var wrappedAggregateWindow: AggregateWindow {
        get { AggregateWindow(rawValue: aggregateWindow ?? "") ?? .fiveMinutes }
        set { aggregateWindow = newValue.rawValue }
    }

    var wrappedUnit: String {
        get { unit ?? "" }
        set { unit = newValue }
    }

    var wrappedRawQuery: String {
        get { rawQuery ?? "" }
        set { rawQuery = newValue }
    }

    var wrappedIsRawQuery: Bool {
        get { isRawQuery }
        set { isRawQuery = newValue }
    }

    var wrappedCachedAt: Date? {
        get { cachedAt }
        set { cachedAt = newValue }
    }

    func cacheResult(_ dataPoints: [ChartDataPoint]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        cachedResultJSON = (try? String(data: encoder.encode(dataPoints), encoding: .utf8)) ?? "[]"
        cachedAt = Date()
    }

    var cachedDataPoints: [ChartDataPoint]? {
        guard let json = cachedResultJSON, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([ChartDataPoint].self, from: data)
    }

    /// Computes local min/max/mean band data from cached data points grouped by aggregate window.
    func computeLocalBandData(window: AggregateWindow) -> (min: [ChartDataPoint], max: [ChartDataPoint], mean: [ChartDataPoint]) {
        guard let points = cachedDataPoints, !points.isEmpty else {
            return ([], [], [])
        }

        let windowSeconds = window.seconds
        guard windowSeconds > 0 else {
            // Raw mode: each point is its own min/max/mean
            return (points, points, points)
        }

        // Group points by window bucket
        let grouped = Dictionary(grouping: points) { point -> TimeInterval in
            (point.time.timeIntervalSince1970 / windowSeconds).rounded(.down) * windowSeconds
        }

        var minPoints: [ChartDataPoint] = []
        var maxPoints: [ChartDataPoint] = []
        var meanPoints: [ChartDataPoint] = []

        for (bucketTime, bucket) in grouped.sorted(by: { $0.key < $1.key }) {
            let time = Date(timeIntervalSince1970: bucketTime)
            let field = bucket.first?.field ?? "value"
            let values = bucket.map(\.value)
            minPoints.append(ChartDataPoint(time: time, value: values.min()!, field: "\(field)_min"))
            maxPoints.append(ChartDataPoint(time: time, value: values.max()!, field: "\(field)_max"))
            meanPoints.append(ChartDataPoint(time: time, value: values.reduce(0, +) / Double(values.count), field: "\(field)_mean"))
        }

        return (minPoints, maxPoints, meanPoints)
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }

    /// Builds the appropriate query string based on the data source backend type.
    func buildQuery(for dataSource: DataSource) -> String {
        if wrappedIsRawQuery && dataSource.wrappedBackendType != .prometheus {
            return wrappedRawQuery
        }
        switch dataSource.wrappedBackendType {
        case .influxDB1:
            return buildInfluxQLQuery(database: dataSource.wrappedDatabase)
        case .influxDB2:
            return buildFluxQuery(bucket: dataSource.wrappedBucket)
        case .influxDB3:
            return buildSQLQuery(database: dataSource.wrappedDatabase)
        case .prometheus:
            return buildPrometheusQuery(timeRange: wrappedTimeRange)
        case .mqtt:
            #if canImport(CocoaMQTT)
            return buildMQTTQuery()
            #else
            return ""
            #endif
        case .demo:
            return buildFluxQuery(bucket: "demo")
        }
    }

    #if canImport(CocoaMQTT)
    func buildMQTTQuery() -> String {
        let fields = wrappedFields
        let rangeSeconds: Int
        switch wrappedTimeRange {
        case .twoHours: rangeSeconds = 10
        case .sixHours: rangeSeconds = 15
        case .twelveHours: rangeSeconds = 15
        case .twentyFourHours: rangeSeconds = 20
        case .sevenDays: rangeSeconds = 25
        case .fourteenDays: rangeSeconds = 30
        case .thirtyDays: rangeSeconds = 30
        case .ninetyDays: rangeSeconds = 30
        case .oneYear, .twoYears, .fiveYears: rangeSeconds = 30
        }
        return MQTTQueryParser.build(topic: wrappedMeasurement, fields: fields, rangeSeconds: TimeInterval(rangeSeconds))
    }
    #endif

    /// Builds a multi-aggregate Flux query (min/max/mean) for band charts.
    func buildBandFluxQuery(bucket: String, timeRange: TimeRange? = nil, window: AggregateWindow? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let aw = window ?? wrappedAggregateWindow

        var base = """
        from(bucket: "\(bucket)")
          |> range(start: \(tr.fluxValue))
          |> filter(fn: (r) => r["_measurement"] == "\(wrappedMeasurement)")
        """

        if !wrappedFields.isEmpty {
            let fieldFilter = wrappedFields
                .map { "r[\"_field\"] == \"\($0)\"" }
                .joined(separator: " or ")
            base += "\n  |> filter(fn: (r) => \(fieldFilter))"
        }

        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues
                .map { "r[\"\(tagKey)\"] == \"\($0)\"" }
                .joined(separator: " or ")
            base += "\n  |> filter(fn: (r) => \(tagFilter))"
        }

        let effectiveWindow = aw == .none ? tr.minimumWindow : aw
        let fns: [AggregateFunction] = [.min, .max, .mean]
        let unions = fns.map { fn in
            """
            \(base)
              |> aggregateWindow(every: \(effectiveWindow.rawValue), fn: \(fn.rawValue), createEmpty: false)
              |> map(fn: (r) => ({r with _field: r._field + "_\(fn.rawValue)"}))
              |> yield(name: "\(fn.rawValue)")
            """
        }

        return unions.joined(separator: "\n\n")
    }

    /// Builds a time-shifted Flux query for comparison overlays.
    func buildComparisonFluxQuery(bucket: String, timeRange: TimeRange, window: AggregateWindow, fn: AggregateFunction, offset: ComparisonOffset) -> String {
        let rangeSeconds = timeRange.seconds
        let offsetSeconds = offset.seconds
        let startSeconds = Int(rangeSeconds + offsetSeconds)
        let stopSeconds = Int(offsetSeconds)
        let effectiveWindow = window == .none ? timeRange.minimumWindow : window

        var query = """
        from(bucket: "\(bucket)")
          |> range(start: -\(startSeconds)s, stop: -\(stopSeconds)s)
          |> filter(fn: (r) => r["_measurement"] == "\(wrappedMeasurement)")
        """

        if !wrappedFields.isEmpty {
            let fieldFilter = wrappedFields
                .map { "r[\"_field\"] == \"\($0)\"" }
                .joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(fieldFilter))"
        }

        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues
                .map { "r[\"\(tagKey)\"] == \"\($0)\"" }
                .joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(tagFilter))"
        }

        if effectiveWindow != .none {
            query += "\n  |> aggregateWindow(every: \(effectiveWindow.rawValue), fn: \(fn.rawValue), createEmpty: false)"
        }

        query += "\n  |> yield(name: \"comparison\")"

        return query
    }

    /// Builds a time-shifted band query for comparison overlays on band charts.
    func buildComparisonBandFluxQuery(bucket: String, timeRange: TimeRange, window: AggregateWindow, offset: ComparisonOffset) -> String {
        let rangeSeconds = timeRange.seconds
        let offsetSeconds = offset.seconds
        let startSeconds = Int(rangeSeconds + offsetSeconds)
        let stopSeconds = Int(offsetSeconds)

        var base = """
        from(bucket: "\(bucket)")
          |> range(start: -\(startSeconds)s, stop: -\(stopSeconds)s)
          |> filter(fn: (r) => r["_measurement"] == "\(wrappedMeasurement)")
        """

        if !wrappedFields.isEmpty {
            let fieldFilter = wrappedFields
                .map { "r[\"_field\"] == \"\($0)\"" }
                .joined(separator: " or ")
            base += "\n  |> filter(fn: (r) => \(fieldFilter))"
        }

        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues
                .map { "r[\"\(tagKey)\"] == \"\($0)\"" }
                .joined(separator: " or ")
            base += "\n  |> filter(fn: (r) => \(tagFilter))"
        }

        let effectiveWindow = window == .none ? timeRange.minimumWindow : window
        let fns: [AggregateFunction] = [.min, .max, .mean]
        let unions = fns.map { fn in
            """
            \(base)
              |> aggregateWindow(every: \(effectiveWindow.rawValue), fn: \(fn.rawValue), createEmpty: false)
              |> map(fn: (r) => ({r with _field: r._field + "_\(fn.rawValue)"}))
              |> yield(name: "comparison_\(fn.rawValue)")
            """
        }

        return unions.joined(separator: "\n\n")
    }

    // MARK: - Prometheus Query Building

    /// Builds a Prometheus query string with time range prefix.
    /// Format: `TIMERANGE:<seconds>|<promql>`
    func buildPrometheusQuery(timeRange: TimeRange? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let promql = wrappedRawQuery.isEmpty ? wrappedMeasurement : wrappedRawQuery
        return "TIMERANGE:\(Int(tr.seconds))|\(promql)"
    }

    // MARK: - InfluxDB 1 InfluxQL Query Building

    func buildInfluxQLQuery(database: String, timeRange: TimeRange? = nil, window: AggregateWindow? = nil, fn: AggregateFunction? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let aw = window ?? wrappedAggregateWindow
        let af = fn ?? wrappedAggregateFunction
        let effectiveWindow = aw == .none ? tr.minimumWindow : aw

        let measurement = "\"\(wrappedMeasurement)\""

        var conditions = ["time > now() - \(tr.rawValue)"]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues.map { "\"\(tagKey)\" = '\($0)'" }.joined(separator: " OR ")
            conditions.append("(\(tagFilter))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        if effectiveWindow != .none && !wrappedFields.isEmpty {
            let fields = wrappedFields.map { "\(influxQLFn(af))(\"\($0)\") AS \"\($0)\"" }
            return "SELECT \(fields.joined(separator: ", ")) FROM \(measurement) WHERE \(whereClause) GROUP BY time(\(effectiveWindow.rawValue)) fill(none)"
        }

        let selectFields = wrappedFields.isEmpty ? "*" : wrappedFields.map { "\"\($0)\"" }.joined(separator: ", ")
        return "SELECT \(selectFields) FROM \(measurement) WHERE \(whereClause)"
    }

    func buildBandInfluxQLQuery(database: String, timeRange: TimeRange? = nil, window: AggregateWindow? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let aw = window ?? wrappedAggregateWindow
        let effectiveWindow = aw == .none ? tr.minimumWindow : aw
        let measurement = "\"\(wrappedMeasurement)\""

        var conditions = ["time > now() - \(tr.rawValue)"]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues.map { "\"\(tagKey)\" = '\($0)'" }.joined(separator: " OR ")
            conditions.append("(\(tagFilter))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        let fieldList = wrappedFields.isEmpty ? ["value"] : wrappedFields
        let selectFields = fieldList.flatMap { field -> [String] in
            [
                "MIN(\"\(field)\") AS \"\(field)_min\"",
                "MAX(\"\(field)\") AS \"\(field)_max\"",
                "MEAN(\"\(field)\") AS \"\(field)_mean\""
            ]
        }

        return "SELECT \(selectFields.joined(separator: ", ")) FROM \(measurement) WHERE \(whereClause) GROUP BY time(\(effectiveWindow.rawValue)) fill(none)"
    }

    func buildComparisonInfluxQLQuery(database: String, timeRange: TimeRange, window: AggregateWindow, fn: AggregateFunction, offset: ComparisonOffset) -> String {
        let rangeSeconds = Int(timeRange.seconds)
        let offsetSeconds = Int(offset.seconds)
        let effectiveWindow = window == .none ? timeRange.minimumWindow : window
        let measurement = "\"\(wrappedMeasurement)\""

        var conditions = [
            "time > now() - \(rangeSeconds + offsetSeconds)s",
            "time < now() - \(offsetSeconds)s"
        ]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues.map { "\"\(tagKey)\" = '\($0)'" }.joined(separator: " OR ")
            conditions.append("(\(tagFilter))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        if effectiveWindow != .none && !wrappedFields.isEmpty {
            let fields = wrappedFields.map { "\(influxQLFn(fn))(\"\($0)\") AS \"\($0)\"" }
            return "SELECT \(fields.joined(separator: ", ")) FROM \(measurement) WHERE \(whereClause) GROUP BY time(\(effectiveWindow.rawValue)) fill(none)"
        }

        let selectFields = wrappedFields.isEmpty ? "*" : wrappedFields.map { "\"\($0)\"" }.joined(separator: ", ")
        return "SELECT \(selectFields) FROM \(measurement) WHERE \(whereClause)"
    }

    func buildComparisonBandInfluxQLQuery(database: String, timeRange: TimeRange, window: AggregateWindow, offset: ComparisonOffset) -> String {
        let rangeSeconds = Int(timeRange.seconds)
        let offsetSeconds = Int(offset.seconds)
        let effectiveWindow = window == .none ? timeRange.minimumWindow : window
        let measurement = "\"\(wrappedMeasurement)\""

        var conditions = [
            "time > now() - \(rangeSeconds + offsetSeconds)s",
            "time < now() - \(offsetSeconds)s"
        ]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues.map { "\"\(tagKey)\" = '\($0)'" }.joined(separator: " OR ")
            conditions.append("(\(tagFilter))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        let fieldList = wrappedFields.isEmpty ? ["value"] : wrappedFields
        let selectFields = fieldList.flatMap { field -> [String] in
            [
                "MIN(\"\(field)\") AS \"\(field)_min\"",
                "MAX(\"\(field)\") AS \"\(field)_max\"",
                "MEAN(\"\(field)\") AS \"\(field)_mean\""
            ]
        }

        return "SELECT \(selectFields.joined(separator: ", ")) FROM \(measurement) WHERE \(whereClause) GROUP BY time(\(effectiveWindow.rawValue)) fill(none)"
    }

    private func influxQLFn(_ fn: AggregateFunction) -> String {
        switch fn {
        case .mean: return "MEAN"
        case .last: return "LAST"
        case .max: return "MAX"
        case .min: return "MIN"
        case .sum: return "SUM"
        }
    }

    // MARK: - InfluxDB 3 SQL Query Building

    func buildSQLQuery(database: String, timeRange: TimeRange? = nil, window: AggregateWindow? = nil, fn: AggregateFunction? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let aw = window ?? wrappedAggregateWindow
        let af = fn ?? wrappedAggregateFunction
        let effectiveWindow = aw == .none ? tr.minimumWindow : aw

        let measurement = "\"\(escapeSQLId(wrappedMeasurement))\""
        let timeFilter = "time >= NOW() - INTERVAL '\(Int(tr.seconds)) seconds'"

        var conditions = [timeFilter]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let valueList = tagValues.map { "'\(escapeSQLString($0))'" }.joined(separator: ", ")
            conditions.append("\"\(escapeSQLId(tagKey))\" IN (\(valueList))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        if effectiveWindow != .none {
            let sqlFn = sqlAggregateFunction(af)
            let selectFields = wrappedFields.isEmpty ? ["\(sqlFn)(value) AS value"] : wrappedFields.map { "\(sqlFn)(\"\(escapeSQLId($0))\") AS \"\(escapeSQLId($0))\"" }
            return """
            SELECT DATE_BIN(INTERVAL '\(Int(effectiveWindow.seconds)) seconds', time) AS time, \(selectFields.joined(separator: ", "))
            FROM \(measurement)
            WHERE \(whereClause)
            GROUP BY 1
            ORDER BY 1
            """
        }

        let fields = wrappedFields.isEmpty ? ["*"] : wrappedFields.map { "\"\(escapeSQLId($0))\"" }
        return """
        SELECT time, \(fields.joined(separator: ", "))
        FROM \(measurement)
        WHERE \(whereClause)
        ORDER BY time
        """
    }

    func buildBandSQLQuery(database: String, timeRange: TimeRange? = nil, window: AggregateWindow? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let aw = window ?? wrappedAggregateWindow
        let effectiveWindow = aw == .none ? tr.minimumWindow : aw

        let measurement = "\"\(escapeSQLId(wrappedMeasurement))\""
        let timeFilter = "time >= NOW() - INTERVAL '\(Int(tr.seconds)) seconds'"

        var conditions = [timeFilter]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let valueList = tagValues.map { "'\(escapeSQLString($0))'" }.joined(separator: ", ")
            conditions.append("\"\(escapeSQLId(tagKey))\" IN (\(valueList))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        let fieldList = wrappedFields.isEmpty ? ["value"] : wrappedFields
        let selectFields = fieldList.flatMap { field -> [String] in
            let f = "\"\(escapeSQLId(field))\""
            return [
                "MIN(\(f)) AS \"\(escapeSQLId(field))_min\"",
                "MAX(\(f)) AS \"\(escapeSQLId(field))_max\"",
                "AVG(\(f)) AS \"\(escapeSQLId(field))_mean\""
            ]
        }

        return """
        SELECT DATE_BIN(INTERVAL '\(Int(effectiveWindow.seconds)) seconds', time) AS time, \(selectFields.joined(separator: ", "))
        FROM \(measurement)
        WHERE \(whereClause)
        GROUP BY 1
        ORDER BY 1
        """
    }

    func buildComparisonSQLQuery(database: String, timeRange: TimeRange, window: AggregateWindow, fn: AggregateFunction, offset: ComparisonOffset) -> String {
        let rangeSeconds = Int(timeRange.seconds)
        let offsetSeconds = Int(offset.seconds)

        let measurement = "\"\(escapeSQLId(wrappedMeasurement))\""
        let startFilter = "time >= NOW() - INTERVAL '\(rangeSeconds + offsetSeconds) seconds'"
        let stopFilter = "time < NOW() - INTERVAL '\(offsetSeconds) seconds'"

        var conditions = [startFilter, stopFilter]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let valueList = tagValues.map { "'\(escapeSQLString($0))'" }.joined(separator: ", ")
            conditions.append("\"\(escapeSQLId(tagKey))\" IN (\(valueList))")
        }

        if !wrappedFields.isEmpty {
            // Field filter is implicit in SELECT for SQL
        }

        let whereClause = conditions.joined(separator: " AND ")
        let sqlFn = sqlAggregateFunction(fn)
        let fields = wrappedFields.isEmpty ? ["value"] : wrappedFields
        let effectiveWindow = window == .none ? timeRange.minimumWindow : window

        if effectiveWindow != .none {
            let selectFields = fields.map { "\(sqlFn)(\"\(escapeSQLId($0))\") AS \"\(escapeSQLId($0))\"" }
            return """
            SELECT DATE_BIN(INTERVAL '\(Int(effectiveWindow.seconds)) seconds', time) + INTERVAL '\(offsetSeconds) seconds' AS time, \(selectFields.joined(separator: ", "))
            FROM \(measurement)
            WHERE \(whereClause)
            GROUP BY 1
            ORDER BY 1
            """
        }

        let selectFields = fields.map { "\"\(escapeSQLId($0))\"" }
        return """
        SELECT time + INTERVAL '\(offsetSeconds) seconds' AS time, \(selectFields.joined(separator: ", "))
        FROM \(measurement)
        WHERE \(whereClause)
        ORDER BY time
        """
    }

    func buildComparisonBandSQLQuery(database: String, timeRange: TimeRange, window: AggregateWindow, offset: ComparisonOffset) -> String {
        let rangeSeconds = Int(timeRange.seconds)
        let offsetSeconds = Int(offset.seconds)
        let effectiveWindow = window == .none ? timeRange.minimumWindow : window

        let measurement = "\"\(escapeSQLId(wrappedMeasurement))\""
        let startFilter = "time >= NOW() - INTERVAL '\(rangeSeconds + offsetSeconds) seconds'"
        let stopFilter = "time < NOW() - INTERVAL '\(offsetSeconds) seconds'"

        var conditions = [startFilter, stopFilter]
        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let valueList = tagValues.map { "'\(escapeSQLString($0))'" }.joined(separator: ", ")
            conditions.append("\"\(escapeSQLId(tagKey))\" IN (\(valueList))")
        }
        let whereClause = conditions.joined(separator: " AND ")

        let fieldList = wrappedFields.isEmpty ? ["value"] : wrappedFields
        let selectFields = fieldList.flatMap { field -> [String] in
            let f = "\"\(escapeSQLId(field))\""
            return [
                "MIN(\(f)) AS \"\(escapeSQLId(field))_min\"",
                "MAX(\(f)) AS \"\(escapeSQLId(field))_max\"",
                "AVG(\(f)) AS \"\(escapeSQLId(field))_mean\""
            ]
        }

        return """
        SELECT DATE_BIN(INTERVAL '\(Int(effectiveWindow.seconds)) seconds', time) + INTERVAL '\(offsetSeconds) seconds' AS time, \(selectFields.joined(separator: ", "))
        FROM \(measurement)
        WHERE \(whereClause)
        GROUP BY 1
        ORDER BY 1
        """
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

    private func escapeSQLId(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func escapeSQLString(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    // MARK: - InfluxDB 2 Flux Query Building

    func buildFluxQuery(bucket: String, timeRange: TimeRange? = nil, window: AggregateWindow? = nil, fn: AggregateFunction? = nil) -> String {
        let tr = timeRange ?? wrappedTimeRange
        let aw = window ?? wrappedAggregateWindow
        let af = fn ?? wrappedAggregateFunction
        let effectiveWindow = aw == .none ? tr.minimumWindow : aw

        var query = """
        from(bucket: "\(bucket)")
          |> range(start: \(tr.fluxValue))
          |> filter(fn: (r) => r["_measurement"] == "\(wrappedMeasurement)")
        """

        if !wrappedFields.isEmpty {
            let fieldFilter = wrappedFields
                .map { "r[\"_field\"] == \"\($0)\"" }
                .joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(fieldFilter))"
        }

        for (tagKey, tagValues) in wrappedTagFilters where !tagValues.isEmpty {
            let tagFilter = tagValues
                .map { "r[\"\(tagKey)\"] == \"\($0)\"" }
                .joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(tagFilter))"
        }

        if effectiveWindow != .none {
            query += "\n  |> aggregateWindow(every: \(effectiveWindow.rawValue), fn: \(af.rawValue), createEmpty: false)"
        }

        query += "\n  |> yield(name: \"results\")"

        return query
    }

    /// Build query using panel-local overrides for time range and aggregation.
    func buildQuery(for dataSource: DataSource, panel: DashboardPanel) -> String {
        if wrappedIsRawQuery && dataSource.wrappedBackendType != .prometheus {
            return wrappedRawQuery
        }
        let tr = panel.effectiveTimeRange
        let aw = panel.effectiveAggregateWindow
        let af = panel.effectiveAggregateFunction

        switch dataSource.wrappedBackendType {
        case .influxDB1:
            if panel.needsBandAggregates {
                return buildBandInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw)
            }
            return buildInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af)
        case .influxDB2:
            if panel.needsBandAggregates {
                return buildBandFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw)
            }
            return buildFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw, fn: af)
        case .influxDB3:
            if panel.needsBandAggregates {
                return buildBandSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw)
            }
            return buildSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af)
        case .prometheus:
            return buildPrometheusQuery(timeRange: tr)
        case .mqtt:
            #if canImport(CocoaMQTT)
            return buildMQTTQuery()
            #else
            return ""
            #endif
        case .demo:
            if panel.needsBandAggregates {
                return buildBandFluxQuery(bucket: "demo", timeRange: tr, window: aw)
            }
            return buildFluxQuery(bucket: "demo", timeRange: tr, window: aw, fn: af)
        }
    }

    /// Build comparison query for a panel with comparison offset.
    func buildComparisonQuery(for dataSource: DataSource, panel: DashboardPanel) -> String? {
        if wrappedIsRawQuery { return nil }
        let offset = panel.wrappedComparisonOffset
        guard offset != .none else { return nil }
        let tr = panel.effectiveTimeRange
        let aw = panel.effectiveAggregateWindow
        let af = panel.effectiveAggregateFunction

        switch dataSource.wrappedBackendType {
        case .influxDB1:
            if panel.needsBandAggregates {
                return buildComparisonBandInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, offset: offset)
            }
            return buildComparisonInfluxQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af, offset: offset)
        case .influxDB2:
            if panel.needsBandAggregates {
                return buildComparisonBandFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw, offset: offset)
            }
            return buildComparisonFluxQuery(bucket: dataSource.wrappedBucket, timeRange: tr, window: aw, fn: af, offset: offset)
        case .influxDB3:
            if panel.needsBandAggregates {
                return buildComparisonBandSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, offset: offset)
            }
            return buildComparisonSQLQuery(database: dataSource.wrappedDatabase, timeRange: tr, window: aw, fn: af, offset: offset)
        case .prometheus:
            return nil
        case .mqtt:
            return nil
        case .demo:
            if panel.needsBandAggregates {
                return buildComparisonBandFluxQuery(bucket: "demo", timeRange: tr, window: aw, offset: offset)
            }
            return buildComparisonFluxQuery(bucket: "demo", timeRange: tr, window: aw, fn: af, offset: offset)
        }
    }
}
