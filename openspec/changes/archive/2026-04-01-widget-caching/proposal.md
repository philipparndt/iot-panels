## Why

The main widget (`IoTPanelsWidget`) always fetches fresh data from the backend with no caching or fallback. If the network is unavailable or the query times out, the widget shows empty/stale data. In contrast, `SingleValueWidget` already has a cache-and-fallback strategy via `SavedQuery.cacheResult()`. The `WidgetDataLoader` (used by both the in-app preview and the real widget) should cache results per widget item and fall back to cached data when live queries fail.

## What Changes

- Add caching to `WidgetDataLoader` — after a successful fetch, cache the result on the `WidgetDesignItem` (or `SavedQuery`)
- On fetch failure, fall back to previously cached data
- Show cached data immediately while loading fresh data (same pattern as `PanelCardView`)
- Cache comparison data alongside primary data

## Capabilities

### New Capabilities
- `widget-data-caching`: Cache widget data per item with fallback on network failure

### Modified Capabilities

## Impact

- **Core Data**: Add `cachedResultJSON` and `cachedAt` attributes to `WidgetDesignItem` (if not already present from widget-feature-parity)
- **WidgetDataLoader**: Add caching after successful fetch and fallback on failure
- **WidgetDesign+Wrapped**: Add cache wrapper methods on `WidgetDesignItem`
- **Dependencies**: None
