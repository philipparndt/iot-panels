## Context

Widgets currently render a limited subset of chart types via `WidgetDesignPreviewView` and `SingleValueWidget`. Dashboard panels use `PanelRenderer` which supports all 9 display styles including band charts, bar charts, scatter plots, calendar heatmaps, and comparison overlays. Widget items (`WidgetDesignItem`) lack the Core Data attributes for per-item time range, aggregation, and comparison overrides that `DashboardPanel` has.

The existing `PanelRenderer` is already a standalone `View` that accepts series data, display style, and style config — it can be reused directly in the widget rendering path.

## Goals / Non-Goals

**Goals:**
- Support all `PanelDisplayStyle` cases in widget items
- Add per-item time range, aggregation window, aggregation function overrides
- Add comparison offset support for line-based styles
- Expose all new settings in `WidgetItemConfigView`
- Reuse `PanelRenderer` for widget rendering to avoid duplicating chart code
- Maintain compact rendering appropriate for widget sizes

**Non-Goals:**
- Adding the data explorer overlay to widgets (iOS widgets are non-interactive)
- Per-item caching on `WidgetDesignItem` (widget timeline provider handles freshness)
- Changing the widget grouping/multi-series model (groupTag stays as-is)

## Decisions

### 1. Add query override attributes to WidgetDesignItem

Add `timeRange`, `aggregateWindow`, `aggregateFunction`, and `comparisonOffset` optional String attributes to the `WidgetDesignItem` Core Data entity. Mirror the same wrapper pattern used by `DashboardPanel` (`effectiveTimeRange`, etc.) that falls back to the `SavedQuery` default when nil.

**Alternative considered**: Pass overrides as parameters through the rendering chain without persisting — rejected because widgets need to reconstruct query parameters in the background timeline provider without UI state.

### 2. Reuse PanelRenderer for all widget chart types

`PanelRenderer` already handles all 9 display styles with compact mode support. Update `WidgetDesignPreviewView` to pass the item's display style and full series data to `PanelRenderer` instead of its current custom rendering for chart/singleValue/gauge.

**Alternative considered**: Duplicate chart rendering code in the widget — rejected as it would double maintenance burden and diverge over time.

### 3. Expand display style picker in WidgetItemConfigView

Currently hardcoded to chart/singleValue/gauge. Change to use `PanelDisplayStyle.allCases` with the same icon-based picker used in `EditPanelView`.

### 4. Build queries with item overrides in widget timeline provider

Update `SingleValueWidget`'s timeline provider to use per-item time range and aggregation overrides when building queries, similar to how `PanelCardView.loadData()` uses panel overrides via `buildQuery(for:panel:)`. Create analogous methods on `WidgetDesignItem`.

## Risks / Trade-offs

- **[Widget size constraints]** Calendar heatmaps and scatter plots may look cramped on 2×2 widgets → Mitigated by PanelRenderer's `compact` mode which already adapts layout. Some styles may naturally be less useful at small sizes but still functional.
- **[Lightweight migration]** Adding 4 optional attributes to `WidgetDesignItem` requires a Core Data migration → Mitigated by all attributes being optional strings with no default, which qualifies for automatic lightweight migration.
- **[Widget refresh budget]** More complex queries (band charts, comparison) use more network/CPU → Mitigated by iOS widget timeline system which controls refresh frequency. No additional refresh requests.
