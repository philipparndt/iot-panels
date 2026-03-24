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

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
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
