import Foundation
import SwiftUI

/// Shared data loading logic for widget previews and real home screen widgets.
enum WidgetDataLoader {

    /// Fetches chart series data for a widget item, handling band charts and comparison overlays.
    /// When `cache` is true, results are persisted on the item and used as fallback on failure.
    static func fetchSeries(for item: WidgetDesignItem, cache: Bool = false) async -> [ChartSeries] {
        guard let ds = item.savedQuery?.dataSource,
              let queryString = item.buildQuery(for: ds) else {
            return cache ? cachedSeries(for: item) : []
        }

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

            // Cache on success
            if cache {
                let compPoints = compSeries.flatMap(\.dataPoints)
                await cacheData(item: item, points: points, compPoints: compPoints)
            }

            return series
        } catch {
            // Fall back to cache
            if cache {
                return cachedSeries(for: item)
            }
            return [ChartSeries(id: item.wrappedId.uuidString, label: item.wrappedTitle, color: item.color, dataPoints: [])]
        }
    }

    /// Fetches series data for all groups in a widget design.
    static func fetchAllGroups(for design: WidgetDesign, cache: Bool = false) async -> [String: [ChartSeries]] {
        var result: [String: [ChartSeries]] = [:]

        for group in design.resolvedGroups {
            var groupSeries: [ChartSeries] = []
            for item in group.items {
                let itemSeries = await fetchSeries(for: item, cache: cache)
                groupSeries.append(contentsOf: itemSeries)
            }
            result[group.id] = groupSeries
        }

        return result
    }

    /// Returns cached series for all groups synchronously (no network).
    static func cachedGroups(for design: WidgetDesign) -> [String: [ChartSeries]] {
        var result: [String: [ChartSeries]] = [:]
        for group in design.resolvedGroups {
            var groupSeries: [ChartSeries] = []
            for item in group.items {
                let series = cachedSeries(for: item)
                let hasData = series.contains { !$0.dataPoints.isEmpty }
                if hasData {
                    groupSeries.append(contentsOf: series)
                }
            }
            if !groupSeries.isEmpty {
                result[group.id] = groupSeries
            }
        }
        return result
    }

    @MainActor
    private static func cacheData(item: WidgetDesignItem, points: [ChartDataPoint], compPoints: [ChartDataPoint]) {
        item.cacheResult(points)
        if !compPoints.isEmpty {
            item.cacheComparisonResult(compPoints)
        } else {
            item.clearComparisonCache()
        }
        try? item.managedObjectContext?.save()
    }

    // MARK: - Private

    /// Builds series from cached data for an item.
    private static func cachedSeries(for item: WidgetDesignItem) -> [ChartSeries] {
        guard let points = item.cachedDataPoints, !points.isEmpty else {
            return [ChartSeries(id: item.wrappedId.uuidString, label: item.wrappedTitle, color: item.color, dataPoints: [])]
        }

        var series = buildPrimarySeries(item: item, points: points)

        if let compPoints = item.cachedComparisonDataPoints, !compPoints.isEmpty {
            series.append(contentsOf: buildComparisonSeries(item: item, compPoints: compPoints))
        }

        return series
    }

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

    private static func buildComparisonSeries(item: WidgetDesignItem, compPoints: [ChartDataPoint]) -> [ChartSeries] {
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

        return buildComparisonSeries(item: item, compPoints: compPoints)
    }
}
