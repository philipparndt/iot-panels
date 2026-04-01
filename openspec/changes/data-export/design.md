## Context

Chart data is stored as `[ChartDataPoint]` (time, value, field). Dashboard panels have `dataPoints` and `comparisonDataPoints` state. The chart explorer has `ChartExplorerState` with the same. Both already have the data in memory — it just needs to be serialized and shared.

## Goals / Non-Goals

**Goals:**
- Export displayed data as CSV with columns: timestamp, field, value
- Support multi-field data (multiple series in one export)
- Include comparison data when active (marked with a "comparison" indicator)
- Use iOS share sheet for flexible output (save, share, copy)

**Non-Goals:**
- Custom date range picker for export (exports what's currently displayed)
- JSON or other formats (CSV covers the most common use case)
- Export from widgets (too small a surface, not interactive)

## Decisions

### 1. CSVExporter utility

Create a simple `CSVExporter` enum with a static method:
```
static func csv(from points: [ChartDataPoint], comparisonPoints: [ChartDataPoint]) -> String
```

Format:
```
timestamp,field,value
2026-04-01T12:00:00Z,temperature,21.5
2026-04-01T12:00:00Z,cmp_temperature,20.3
```

ISO 8601 timestamps, field names as-is, numeric values.

### 2. Share via ShareLink

Use SwiftUI's `ShareLink` (iOS 16+) which presents the system share sheet. The exported CSV is shared as a temporary file with a `.csv` extension so receiving apps recognize the format.

### 3. Export from two locations

- **Dashboard panel context menu**: New "Export CSV" button that uses the panel's current `dataPoints` + `comparisonDataPoints`
- **Explorer toolbar**: New export button that uses the explorer's current state data

## Risks / Trade-offs

- **[Large datasets]** Exporting 30 days of 1-minute data = ~43k rows → CSV handles this fine, but share sheet preview might be slow. Use file-based sharing, not in-memory string.
- **[Comparison data mixing]** Primary and comparison data in one CSV could confuse users → Prefix comparison field names with "cmp_" (already the convention) to distinguish them.
