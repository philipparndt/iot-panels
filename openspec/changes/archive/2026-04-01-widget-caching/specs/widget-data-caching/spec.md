## ADDED Requirements

### Requirement: Widget data is cached per item after successful fetch
The system SHALL cache fetched data on each `WidgetDesignItem` after a successful query. The cache SHALL include both primary and comparison data.

#### Scenario: Successful fetch caches data
- **WHEN** a widget item's data is fetched successfully
- **THEN** the result is stored in the item's `cachedResultJSON` and `cachedAt` is updated

#### Scenario: Comparison data is cached
- **WHEN** a widget item has a comparison offset and comparison data is fetched successfully
- **THEN** the comparison result is stored in the item's `cachedComparisonJSON`

### Requirement: Widget falls back to cached data on failure
The system SHALL return previously cached data when a live query fails, so the widget displays stale data instead of nothing.

#### Scenario: Network failure with cached data
- **WHEN** a widget item's live query fails and cached data exists
- **THEN** the cached data is returned as the result

#### Scenario: Network failure without cached data
- **WHEN** a widget item's live query fails and no cached data exists
- **THEN** an empty series is returned

### Requirement: In-app preview always fetches live data
The system SHALL NOT use cached data for the in-app widget preview. Caching SHALL only be used by the home screen widget timeline provider.

#### Scenario: Preview ignores cache
- **WHEN** the widget design editor loads preview data
- **THEN** fresh data is always fetched from the backend, never from cache
