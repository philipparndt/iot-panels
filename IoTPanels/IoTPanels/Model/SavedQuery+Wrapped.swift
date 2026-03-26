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
        get { TimeRange(rawValue: timeRange ?? "") ?? .oneHour }
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
        switch dataSource.wrappedBackendType {
        case .influxDB2:
            return buildFluxQuery(bucket: dataSource.wrappedBucket)
        case .mqtt:
            return buildMQTTQuery()
        case .demo:
            return buildFluxQuery(bucket: "demo")
        }
    }

    func buildMQTTQuery() -> String {
        let fields = wrappedFields
        let rangeSeconds: Int
        switch wrappedTimeRange {
        case .oneHour: rangeSeconds = 10
        case .sixHours: rangeSeconds = 15
        case .twentyFourHours: rangeSeconds = 20
        case .sevenDays: rangeSeconds = 25
        case .thirtyDays: rangeSeconds = 30
        }
        return MQTTQueryParser.build(topic: wrappedMeasurement, fields: fields, rangeSeconds: TimeInterval(rangeSeconds))
    }

    func buildFluxQuery(bucket: String) -> String {
        var query = """
        from(bucket: "\(bucket)")
          |> range(start: \(wrappedTimeRange.fluxValue))
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

        if wrappedAggregateWindow != .none {
            query += "\n  |> aggregateWindow(every: \(wrappedAggregateWindow.rawValue), fn: \(wrappedAggregateFunction.rawValue), createEmpty: false)"
        }

        query += "\n  |> yield(name: \"results\")"

        return query
    }
}
