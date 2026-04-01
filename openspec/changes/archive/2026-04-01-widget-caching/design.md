## Context

`SingleValueWidget` already caches via `SavedQuery.cacheResult()` and falls back to `query.cachedDataPoints` on failure. The main `IoTPanelsWidget` uses `WidgetDataLoader` which makes live queries with no caching. When the network fails, the widget has no data to show.

`DashboardPanel` already has `cachedResultJSON`, `cachedComparisonJSON`, and `cachedAt` attributes. `WidgetDesignItem` does not have these yet.

## Goals / Non-Goals

**Goals:**
- Cache fetched data per `WidgetDesignItem` after successful queries
- Fall back to cached data when live queries fail
- Cache comparison data alongside primary data
- Keep the caching transparent — callers of `WidgetDataLoader` get data regardless of source

**Non-Goals:**
- Cache invalidation strategies (data is always refreshed on next widget timeline update)
- Caching in the in-app preview (preview always fetches live)

## Decisions

### 1. Cache on WidgetDesignItem

Add `cachedResultJSON`, `cachedComparisonJSON`, and `cachedAt` to `WidgetDesignItem` entity. This mirrors `DashboardPanel`'s caching and keeps each item's cache independent (different queries, different time ranges).

### 2. Cache in WidgetDataLoader

After a successful fetch in `fetchSeries(for:)`, encode the resulting `[ChartSeries]` data points into the item's cache. On failure, decode and return the cached series. The caching is done inside `WidgetDataLoader` so both the real widget and any future callers benefit.

### 3. Only cache in widget context

The in-app preview should always show live data. Add a `cache` parameter to `WidgetDataLoader.fetchSeries` (default `false`) that the real widget's timeline provider sets to `true`.

## Risks / Trade-offs

- **[Stale data]** Cached data could be hours old if the network is down for a long time → Acceptable since the alternative is no data at all. The widget's `cachedAt` timestamp could optionally be shown.
- **[Core Data save in background]** The widget timeline provider runs in a background extension. Saving Core Data there is safe as long as both app and extension use the same persistent container (already the case via `PersistenceController.shared`).
