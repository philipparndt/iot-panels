## Why

The current line chart panels only support a single aggregate function (e.g., mean) per series. When monitoring IoT sensor data over longer time ranges, users lose visibility into the actual data spread — they see the average but not the variance. Additionally, there is no way to compare the same metric across different time periods (e.g., this week vs. last week) to spot trends or anomalies. These two capabilities — band charts and historical comparison — are essential for meaningful IoT data analysis.

## What Changes

- **Band chart display style**: A new `PanelDisplayStyle` that queries min, max, and mean aggregates simultaneously, rendering a filled translucent area between min and max with a solid mean line overlay. This gives users immediate insight into data variance.
- **Historical comparison overlay**: The ability to overlay a previous time period's data on top of the current period in any line-based chart. For example, show "last 7 days" with a dimmed "previous 7 days" behind it for trend comparison.
- **Multi-aggregate query support**: Extend `SavedQuery` to support fetching multiple aggregate functions in a single query (min + max + mean), since today each query uses exactly one `AggregateFunction`.
- **Panel configuration UI**: Add configuration options for the band chart (color, opacity) and comparison period selection in the panel editor.

## Capabilities

### New Capabilities
- `band-chart`: A new chart display style that renders a min/max filled band with a mean line, including styling options (band color, opacity)
- `historical-compare`: Overlay a previous time period's data on any line-based chart for trend comparison, with configurable comparison period offset

### Modified Capabilities

_(none — no existing specs to modify)_

## Impact

- **Model layer**: `PanelDisplayStyle` enum gains a new case. `SavedQuery` or `DashboardPanel` needs to support multi-aggregate queries (min+max+mean) and comparison period configuration.
- **Query layer**: `SavedQuery.buildFluxQuery()` must support generating queries that return multiple aggregates. MQTT queries may need similar adaptation.
- **View layer**: `PanelRenderer` needs a new band chart rendering path using Swift Charts `AreaMark` + `LineMark`. Comparison overlay needs a secondary series with distinct styling.
- **CoreData**: `StyleConfig` gains band chart and comparison options. `DashboardPanel` may need a `comparisonOffset` property.
- **No breaking changes** to existing panels or queries.
