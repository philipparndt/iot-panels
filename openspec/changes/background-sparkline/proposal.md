## Why

Compact panel types like "Value" and "Circular Gauge" show only the current reading with no visual context for how the value has been trending. Adding a subtle background sparkline lets users see at a glance whether a value is rising, falling, or stable — without switching to a full chart panel.

## What Changes

- Add an optional background sparkline layer to the `singleValue` and `circularGauge` panel display styles.
- The sparkline renders as a filled area chart (no axes, no labels, no grid) behind the existing content.
- A new `StyleConfig` toggle (`showTrendLine`) controls whether the background sparkline is visible (default off).
- New `StyleConfig` fields (`trendMin` / `trendMax`) allow defining a fixed Y-axis range for the sparkline. When nil, the range is derived from the data. When the unit is `%`, the range defaults to 0–100.
- The sparkline uses a subtle, semi-transparent fill so it doesn't compete with the primary value display.

## Capabilities

### New Capabilities
- `background-sparkline`: Background trend sparkline overlay for compact panel types (singleValue, circularGauge), with configurable Y-range and toggle.

### Modified Capabilities

_(none)_

## Impact

- **Model**: `StyleConfig` gains three new optional fields (`showTrendLine`, `trendMin`, `trendMax`).
- **Views**: `PanelCardView` — `singleValueBody` and `circularGaugeBody` gain a `ZStack` background layer.
- **Config UI**: `DashboardView` and `WidgetItemConfigView` panel config sections show the trend line toggle and optional range fields for applicable styles.
- **No breaking changes** — new fields default to nil/off, preserving existing behavior.
