## Why

Dashboard panels show charts with fixed time ranges and aggregation settings. When investigating anomalies or exploring trends, users must edit the panel configuration — changes that persist and affect the dashboard for everyone. There is no way to temporarily adjust the view, scroll through historical data, or compare different time windows without altering the saved configuration.

A non-destructive data explorer lets users drill into any chart on-the-fly without risking unintended changes to the dashboard layout.

## What Changes

- Add a fullscreen "Explorer" overlay that can be opened from any dashboard panel (e.g., tap or long-press action)
- Provide transient controls for:
  - **Time range** adjustment (shift earlier/later, zoom in/out, pick presets)
  - **Scrolling** through data by panning the time window forward and backward
  - **Comparison windows** (overlay a previous period for side-by-side analysis)
  - **Aggregation** changes (switch aggregate window and function on the fly)
- All explorer state is ephemeral — closing the overlay discards every change
- Reuse existing query execution, chart rendering, and data parsing infrastructure

## Capabilities

### New Capabilities
- `chart-explorer-overlay`: Fullscreen overlay UI that presents a panel's chart with transient exploration controls (time range, scrolling, comparison, aggregation)

### Modified Capabilities
<!-- No existing spec-level requirements are changing. The explorer reuses existing
     rendering and query infrastructure without modifying their contracts. -->

## Impact

- **Views**: New `ChartExplorerView` (fullscreen overlay) + supporting control views
- **PanelCardView**: Add gesture/button to launch the explorer
- **Query execution**: Reuses `DataSourceServiceProtocol` and `SavedQuery` query builders — no API changes
- **Chart rendering**: Reuses `PanelRenderer` and `ChartDataParser` — no changes needed
- **Dependencies**: No new external dependencies
- **Core Data**: No schema changes (explorer state is in-memory only)
