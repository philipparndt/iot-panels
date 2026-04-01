## Why

Currently, widget items and dashboard panels use a single static color for their chart or value display. Users monitoring IoT sensors often want visual feedback based on value ranges — e.g., green when temperature is normal, yellow when elevated, red when critical. Threshold-based coloring makes it instantly obvious when values are out of range, without needing to read the actual number.

## What Changes

- Add threshold color rules to `StyleConfig` — an ordered list of (value, color) pairs that define color breakpoints
- When thresholds are configured, the single value text, gauge, and chart elements use the color matching the current value's range
- Add a threshold editor in both `EditPanelView` and `WidgetItemConfigView` to define rules (e.g., "below 15 → blue, 15-25 → green, above 25 → red")
- When no thresholds are defined, behavior is unchanged (uses the item/series color as before)

## Capabilities

### New Capabilities
- `threshold-colors`: Value-based color rules that change the display color based on configurable value ranges

### Modified Capabilities

## Impact

- **StyleConfig**: Add `thresholds` array of `(value: Double, colorHex: String)` pairs, stored as JSON
- **PanelRenderer**: Resolve `primaryColor` through thresholds when configured, based on the current value
- **EditPanelView / WidgetItemConfigView**: Add threshold editor section
- **Gauge**: Already has color schemes based on value — thresholds would override the scheme when set
- **Dependencies**: None
