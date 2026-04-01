import Foundation
import SwiftUI

/// Shared data loading logic for widget previews and real home screen widgets.
enum WidgetDataLoader {

    /// Fetches chart series data for a widget item, handling band charts and comparison overlays.
    static func fetchSeries(for item: WidgetDesignItem) async -> [ChartSeries] {
        guard let ds = item.savedQuery?.dataSource,
              let queryString = item.buildQuery(for: ds) else { return [] }

        let service = ServiceFactory.service(for: ds)
        let comparisonQueryString = item.buildComparisonQuery(for: ds)
        let comparisonOffsetSeconds = item.wrappedComparisonOffset.seconds

        do {
            let result = try await service.query(queryString)
            let points = ChartDataParser.parse(result: result)
            var series = buildPrimarySeries(item: item, points: points)

            let compSeries = await fetchComparisonSeries(
                item: item,
                service: service,
                queryString: comparisonQueryString,
                offsetSeconds: comparisonOffsetSeconds
            )
            series.append(contentsOf: compSeries)

            return series
        } catch {
            return [ChartSeries(id: item.wrappedId.uuidString, label: item.wrappedTitle, color: item.color, dataPoints: [])]
        }
    }

    /// Fetches series data for all groups in a widget design.
    static func fetchAllGroups(for design: WidgetDesign) async -> [String: [ChartSeries]] {
        var result: [String: [ChartSeries]] = [:]

        for group in design.resolvedGroups {
            var groupSeries: [ChartSeries] = []
            for item in group.items {
                let itemSeries = await fetchSeries(for: item)
                groupSeries.append(contentsOf: itemSeries)
            }
            result[group.id] = groupSeries
        }

        return result
    }

    // MARK: - Private

    private static func buildPrimarySeries(item: WidgetDesignItem, points: [ChartDataPoint]) -> [ChartSeries] {
        if item.needsBandAggregates {
            let grouped = Dictionary(grouping: points, by: \.field)
            return grouped.keys.sorted().map { key in
                ChartSeries(
                    id: "\(item.wrappedId.uuidString)_\(key)",
                    label: key,
                    color: item.color,
                    dataPoints: grouped[key] ?? []
                )
            }
        } else {
            return [ChartSeries(
                id: item.wrappedId.uuidString,
                label: item.wrappedTitle,
                color: item.color,
                dataPoints: points
            )]
        }
    }

    private static func fetchComparisonSeries(
        item: WidgetDesignItem,
        service: any DataSourceServiceProtocol,
        queryString: String?,
        offsetSeconds: TimeInterval
    ) async -> [ChartSeries] {
        guard let compQuery = queryString,
              let compResult = try? await service.query(compQuery) else { return [] }

        let compPoints = ChartDataParser.parse(result: compResult).map { point in
            ChartDataPoint(
                time: point.time.addingTimeInterval(offsetSeconds),
                value: point.value,
                field: point.field
            )
        }
        guard !compPoints.isEmpty else { return [] }

        if item.needsBandAggregates {
            let grouped = Dictionary(grouping: compPoints, by: \.field)
            return grouped.keys.sorted().map { key in
                ChartSeries(
                    id: "cmp_\(item.wrappedId.uuidString)_\(key)",
                    label: "cmp_\(key)",
                    color: item.color.complementary(),
                    dataPoints: grouped[key] ?? []
                )
            }
        } else {
            return [ChartSeries(
                id: "cmp_\(item.wrappedId.uuidString)",
                label: "cmp_\(item.wrappedTitle)",
                color: item.color.complementary(),
                dataPoints: compPoints
            )]
        }
    }
}
