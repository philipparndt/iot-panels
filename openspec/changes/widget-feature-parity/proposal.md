## Why

Home screen widgets currently support only 3 chart types (line, single value, gauge) and lack per-item time/aggregation overrides and comparison overlays. Dashboard panels support 9 display styles, per-panel time range and aggregation overrides, and comparison periods. Users want consistent functionality across both surfaces — especially band charts (min/max area fill), bar charts, and the ability to set time range and aggregation per widget item.

## What Changes

- Add missing display styles to widget items: bar chart, scatter, line + points, calendar heatmap (dense), band chart
- Add per-item time range, aggregation window, and aggregation function overrides to `WidgetDesignItem` (same as `DashboardPanel`)
- Add comparison offset support to widget items (for line-based styles)
- Update `WidgetItemConfigView` to expose these new settings
- Update `WidgetDesignPreviewView` and `SingleValueWidget` to render the new chart types
- Ensure `PanelRenderer` is reused for all rendering (it already supports all styles)

## Capabilities

### New Capabilities
- `widget-chart-types`: Support for all dashboard display styles in widget items (bar, scatter, line+points, calendar heatmap, band chart)
- `widget-query-overrides`: Per-item time range, aggregation window, aggregation function, and comparison offset overrides for widget items

### Modified Capabilities
<!-- No existing spec-level requirements are changing. -->

## Impact

- **Core Data**: Add `timeRange`, `aggregateWindow`, `aggregateFunction`, `comparisonOffset` attributes to `WidgetDesignItem` entity
- **WidgetItemConfigView**: Add pickers for time range, aggregation, comparison, and all display styles
- **WidgetDesignPreviewView**: Update rendering to pass per-item overrides and support new chart types
- **SingleValueWidget**: Update widget timeline provider to use per-item query overrides
- **Dependencies**: None — reuses existing `PanelRenderer`, query builders, and `StyleConfig`
