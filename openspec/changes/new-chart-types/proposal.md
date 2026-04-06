## Why

IoT Panels currently covers core time-series and gauge visualizations but lacks several chart types that are common in monitoring dashboards. Sparklines provide glanceable trends in compact spaces, stacked charts show composition, status indicators give at-a-glance health, and tables display raw data. Adding these rounds out the visualization toolkit and makes IoT Panels competitive with tools like Grafana.

## What Changes

- Add `sparkline` display style — a minimal, no-axis line chart optimized for compact spaces and iOS widgets
- Add `stackedBar` display style — a bar chart where multi-series data is stacked to show composition over time
- Add `stackedArea` display style — an area chart where multi-series data is stacked to show composition over time
- Add `statusIndicator` display style — a colored dot/icon with label for simple up/down/warning status
- Add `table` display style — a tabular view showing raw query results with columns and rows
- Add each new type to both dashboard panels and widget items
- Add demo data support for each new type

## Capabilities

### New Capabilities
- `sparkline-chart`: Minimal no-axis line chart for compact trend display
- `stacked-charts`: Stacked bar and stacked area charts for showing data composition
- `status-indicator`: Colored status dot with label for at-a-glance health monitoring
- `table-view`: Tabular display of raw query result data

### Modified Capabilities
- `widget-chart-types`: Add all new display styles to widget item style picker

## Impact

- `PanelDisplayStyle` enum gains 5 new cases
- `PanelRenderer` needs 4 new rendering paths (stacked bar and stacked area can share logic)
- `StyleConfig` may need new configuration fields (status thresholds, table column config)
- `AddPanelView` and `WidgetItemConfigView` pickers updated (ideally after chart-type-picker-sections is implemented)
- `DemoService` needs demo data for each new type
