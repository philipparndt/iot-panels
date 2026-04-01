## 1. CSV Exporter

- [x] 1.1 Create `CSVExporter` utility with `csv(from:comparisonPoints:) -> String` method
- [x] 1.2 Format: ISO 8601 timestamp, field name, numeric value — sorted by timestamp
- [x] 1.3 Create temporary CSV file helper that writes to a temp URL with `.csv` extension

## 2. Dashboard Panel Export

- [x] 2.1 Add "Export CSV" button to panel context menu in `DashboardView`
- [x] 2.2 Generate CSV from panel's cached data points + comparison
- [x] 2.3 Present share sheet with the CSV file

## 3. Explorer Export

- [x] 3.1 Add export button to `ChartExplorerView` toolbar
- [x] 3.2 Generate CSV from explorer's `state.dataPoints` + `state.comparisonDataPoints`
- [x] 3.3 Present share sheet with the CSV file

## 4. Translations

- [x] 4.1 Add translations for "Export CSV" across all 8 languages

## 5. Testing

- [ ] 5.1 Verify CSV export from dashboard panel contains correct data
- [ ] 5.2 Verify CSV export from explorer contains correct data
- [ ] 5.3 Verify comparison data is included when active
