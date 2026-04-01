## 1. Explorer State Model

- [x] 1.1 Create `ChartExplorerState` (`@Observable`) with properties: timeRange, aggregateWindow, aggregateFunction, comparisonOffset, windowOffset (TimeInterval), isLoading, error, dataPoints, comparisonDataPoints
- [x] 1.2 Add initializer that copies values from a `DashboardPanel`
- [x] 1.3 Add computed properties: effectiveStartDate/endDate (applying windowOffset to timeRange), stepSize (timeRange duration), canStepForward (offset < 0)

## 2. Query Overrides

- [x] 2.1 Create `QueryOverrides` struct with optional timeRange, aggregateWindow, aggregateFunction, comparisonOffset, and startDate/endDate overrides
- [x] 2.2 Extend `SavedQuery` query builder methods to accept an optional `QueryOverrides` parameter, falling back to persisted values when nil
- [x] 2.3 Verify existing call sites are unaffected (default nil parameter)

## 3. Explorer Data Fetching

- [x] 3.1 Add a `loadData` method on `ChartExplorerState` that builds a query using the panel's SavedQuery + QueryOverrides, executes it via the data source service, and parses results with `ChartDataParser`
- [x] 3.2 Add comparison data fetching when comparisonOffset is set
- [x] 3.3 Add 300ms debounce to prevent rapid re-fetching when controls change quickly
- [x] 3.4 Ensure previous chart data remains visible during loading

## 4. Explorer Toolbar Controls

- [x] 4.1 Create `ExplorerTimeRangeBar` — horizontal scrollable row of time range presets
- [x] 4.2 Create `ExplorerAggregationPicker` — menus for aggregate window and function
- [x] 4.3 Create `ExplorerComparisonPicker` — menu to select or clear comparison offset
- [x] 4.4 Create `ExplorerStepControls` — step-backward, reset, step-forward buttons with disabled states
- [x] 4.5 Compose controls into `ExplorerToolbar` view with compact bottom-bar layout

## 5. Fullscreen Explorer View

- [x] 5.1 Create `ChartExplorerView` that takes a `DashboardPanel`, initializes `ChartExplorerState`, and renders the chart using `PanelRenderer`
- [x] 5.2 Add loading indicator overlay that shows during data fetch without hiding the chart
- [x] 5.3 Add error display when queries fail
- [x] 5.4 Integrate `ExplorerToolbar` at the bottom of the view
- [x] 5.5 Add dismiss button (close/X) in the top bar

## 6. Panel Integration

- [x] 6.1 Add explore action to `PanelCardView` (button or context menu item)
- [x] 6.2 Present `ChartExplorerView` via `.fullScreenCover` from `PanelCardView`
- [x] 6.3 Disable time range and step controls for MQTT-backed panels in the explorer

## 7. Testing & Polish

- [ ] 7.1 Verify explorer opens and closes without side effects on the persisted panel
- [ ] 7.2 Test time range changes trigger correct queries across InfluxDB 1/2/3 backends
- [ ] 7.3 Test stepping backward/forward shifts the window correctly
- [ ] 7.4 Test comparison overlay renders correctly with shifted data
- [ ] 7.5 Test MQTT panels show limited controls
