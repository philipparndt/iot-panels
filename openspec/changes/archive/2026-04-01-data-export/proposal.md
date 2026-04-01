## Why

Users can view chart data in the app but cannot export it for external analysis, reporting, or sharing. When investigating sensor trends or anomalies, they often need to get the raw data into a spreadsheet or share it with others. There is no way to extract data from the app currently.

## What Changes

- Add CSV export for chart data, accessible from:
  - Dashboard panel context menu ("Export CSV")
  - Chart data explorer toolbar
- Export the currently displayed data points (primary + comparison if active) as a CSV file
- Use iOS share sheet to let users save, AirDrop, email, or copy the CSV

## Capabilities

### New Capabilities
- `data-export`: Export chart data as CSV from dashboard panels and the data explorer

### Modified Capabilities

## Impact

- **New**: `CSVExporter` utility that converts `[ChartDataPoint]` to CSV string
- **DashboardView**: Add "Export CSV" to panel context menu
- **ChartExplorerView**: Add export button to toolbar
- **Dependencies**: None — uses iOS `ShareLink` or `UIActivityViewController`
