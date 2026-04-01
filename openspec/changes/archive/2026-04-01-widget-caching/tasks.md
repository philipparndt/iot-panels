## 1. Core Data Model

- [x] 1.1 Add `cachedResultJSON`, `cachedComparisonJSON`, and `cachedAt` attributes to `WidgetDesignItem` entity
- [x] 1.2 Add cache wrapper methods on `WidgetDesignItem`: `cacheResult(_:)`, `cachedDataPoints`, `cacheComparisonResult(_:)`, `cachedComparisonDataPoints`, `clearComparisonCache()`

## 2. WidgetDataLoader Caching

- [x] 2.1 Add `cache: Bool` parameter to `fetchSeries(for:)` and `fetchAllGroups(for:)` (default `false`)
- [x] 2.2 On successful fetch with `cache: true`, save data points to item's cache and call `managedObjectContext?.save()`
- [x] 2.3 On fetch failure with `cache: true`, fall back to item's cached data and build series from it
- [x] 2.4 Handle comparison data caching — cache comparison points separately, restore on failure

## 3. Integration

- [x] 3.1 Update `WidgetDesignTimelineProvider.fetchEntry` to pass `cache: true` to `WidgetDataLoader`
- [x] 3.2 Verify in-app preview (`WidgetDesignEditorView.loadPreviewData`) does NOT pass `cache: true`

## 4. Testing

- [ ] 4.1 Verify widget shows cached data when network is unavailable
- [ ] 4.2 Verify widget updates cache on successful fetch
- [ ] 4.3 Verify preview always shows live data
