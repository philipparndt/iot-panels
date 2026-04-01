## Why

Widget items have a configurable color (from `SeriesColors.palette`), but this color is only used for the series line in multi-item charts. Single value displays use the default text color, and single-series charts use `.accentColor` instead of the item's chosen color. The item color should be consistently applied to chart lines, single value text, and gauge accents. Additionally, the color palette is missing white (for dark backgrounds) and black (for light backgrounds).

## What Changes

- Use the widget item's color as the series color in `PanelRenderer` when rendering single-series charts (instead of `.accentColor`)
- Apply the item's color to the single value text
- Add adaptive colors to the palette: white (`#FFFFFF`) and black (`#000000`)
- The series color is already passed via `ChartSeries.color` — ensure `PanelRenderer` uses it consistently

## Capabilities

### New Capabilities
- `widget-color-theming`: Widget item colors applied consistently to all chart types and value displays

### Modified Capabilities

## Impact

- **PanelRenderer**: Use `series.first?.color` instead of `.accentColor` for single-series charts and single value text
- **SeriesColors.palette**: Add `#FFFFFF` and `#000000`
- **WidgetItemConfigView**: Color picker already uses the palette — new colors appear automatically
- **Dependencies**: None
