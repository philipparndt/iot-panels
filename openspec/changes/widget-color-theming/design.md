## Context

`PanelRenderer` receives series data via `[ChartSeries]` where each series has a `.color`. For single-series rendering, it ignores this color and uses `.accentColor`. For multi-series, it uses `.foregroundStyle(by:)` with automatic coloring. The single value body uses default text color. Widget items set their color via `item.color` which is passed as `ChartSeries.color`, but PanelRenderer doesn't use it for single-series.

## Goals / Non-Goals

**Goals:**
- Single-series charts use the series color (not `.accentColor`)
- Single value text uses the series color
- Add white and black to the color palette

**Non-Goals:**
- Changing multi-series color behavior (already works via series colors)
- Changing dashboard panel colors (they don't have per-panel color selection)

## Decisions

### 1. Use series color throughout PanelRenderer

Replace hardcoded `.accentColor` with `series.first?.color ?? .accentColor` in:
- `singleSeriesPrimaryMarks` — line, area, bar, scatter, point marks
- `singleSeriesChartView` — comparison marks use complementary of series color
- `singleValueBody` — value text color
- `bandChartDefaultHeader` — value text could use series color
- Chart area gradient — use series color instead of accentColor

### 2. Add white and black to palette

Append `#FFFFFF` and `#000000` to `SeriesColors.palette`. These appear automatically in the widget color picker grid.

## Risks / Trade-offs

- **[White on white]** White text/lines on a light widget background would be invisible → User's responsibility since they choose both background and item color. White is primarily useful on dark backgrounds.
- **[Dashboard impact]** Dashboard panels create series with `.accentColor` in `buildSeries()`. This change only affects PanelRenderer's rendering, not how dashboard series are built, so dashboard charts continue using accent color.
