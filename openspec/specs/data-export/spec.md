## ADDED Requirements

### Requirement: Export chart data as CSV from dashboard panels
The system SHALL provide an "Export CSV" action in the dashboard panel context menu that exports the panel's currently displayed data as a CSV file via the iOS share sheet.

#### Scenario: Export panel data
- **WHEN** user selects "Export CSV" from a panel's context menu
- **THEN** a CSV file containing all displayed data points is shared via the iOS share sheet

#### Scenario: Export includes comparison data
- **WHEN** a panel has comparison data active and user exports CSV
- **THEN** the CSV includes both primary and comparison data points, with comparison fields prefixed with "cmp_"

### Requirement: Export chart data as CSV from the data explorer
The system SHALL provide an export button in the chart data explorer that exports the explorer's current data as a CSV file via the iOS share sheet.

#### Scenario: Export from explorer
- **WHEN** user taps the export button in the explorer toolbar
- **THEN** a CSV file containing the explorer's current data points is shared via the iOS share sheet

### Requirement: CSV format
The system SHALL export data in CSV format with columns: timestamp (ISO 8601), field, value. One row per data point.

#### Scenario: Multi-field CSV
- **WHEN** data contains fields "temperature" and "humidity"
- **THEN** the CSV contains rows for both fields, sorted by timestamp
