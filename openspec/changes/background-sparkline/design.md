## Context

Compact panel types (`singleValue`, `circularGauge`) currently display only the latest value with no historical context. The existing `sparkline` display style already renders a minimal line chart — this change reuses similar drawing logic but as a background layer behind existing panel content rather than a standalone chart type.

The data is already available: `PanelCardView` receives the full `series: [ChartSeries]` including all historical data points. No additional data fetching is needed.

## Goals / Non-Goals

**Goals:**
- Add a toggleable background trend line to `singleValue` and `circularGauge` panels
- Provide optional fixed Y-range configuration (`trendMin` / `trendMax`)
- Auto-default to 0–100 range when the unit is `%`
- Keep the background subtle so the primary value remains the focal point

**Non-Goals:**
- No interactivity (no tap/hover on the background sparkline)
- No axes, labels, or grid lines on the background sparkline
- Not extending this to other panel types (gauge, text, statusIndicator) in this change
- No per-series sparkline in multi-series mode — use all data points from the first series

## Decisions

### 1. Reusable `BackgroundSparklineView` extracted as a shared component

Render the sparkline as a standalone SwiftUI `View` that takes data points, a Y-range, and styling. Both `singleValueBody` and `circularGaugeBody` wrap their existing content in a `ZStack` with this view as the background layer.

**Rationale**: Avoids duplicating drawing logic. The sparkline `Path` code can be shared and tested independently.

**Alternative considered**: Inline the path drawing in each panel body. Rejected — unnecessary duplication.

### 2. Filled area style with low opacity

The sparkline renders as a filled area (line + fill to bottom) using the panel's accent color at ~0.08 opacity, with the line stroke at ~0.15 opacity. This keeps the trend visible but ensures the primary value text dominates.

**Rationale**: A stroke-only line is too subtle at small sizes. A filled area gives a clear visual shape without overwhelming the value.

### 3. StyleConfig fields for configuration

Three new fields on `StyleConfig`:
- `showTrendLine: Bool?` — nil/false = hidden, true = visible
- `trendMin: Double?` — nil = auto from data (or 0 if unit is `%`)
- `trendMax: Double?` — nil = auto from data (or 100 if unit is `%`)

**Rationale**: Follows the established pattern of optional `StyleConfig` fields (like `gaugeMin`/`gaugeMax`). Using `Bool?` with nil default ensures backward compatibility — existing panels remain unchanged.

### 4. Config UI gated by `supportsTrendLine`

Add a new computed property `supportsTrendLine` on `PanelDisplayStyle` returning true for `.singleValue` and `.circularGauge`. The config section shows a toggle and optional min/max fields (similar to the gauge range section).

**Rationale**: Follows the existing pattern (`supportsGaugeConfig`, `supportsThresholds`, etc.).

### 5. Circular gauge: sparkline behind the ring

For `circularGauge`, the sparkline is clipped to a circle and placed behind the gauge ring. This creates a cohesive look where the trend fills the interior of the gauge.

**Rationale**: A rectangular sparkline behind a circular element looks disjointed. Circular clipping integrates naturally.

## Risks / Trade-offs

- **[Visual clutter]** → Mitigated by very low opacity defaults and an explicit opt-in toggle.
- **[Performance with many data points]** → The sparkline uses a simple `Path` with no animation. SwiftUI handles this efficiently even with hundreds of points. Can downsample if needed in a future change.
