## ADDED Requirements

### Requirement: Raw query storage

The system SHALL store a raw query string and a flag indicating manual mode on `SavedQuery`.

#### Scenario: Save raw query
- **WHEN** the user saves a manual query
- **THEN** the `rawQuery` field SHALL contain the query text and `isRawQuery` SHALL be true

### Requirement: Raw query execution

When `isRawQuery` is true, the system SHALL use the stored `rawQuery` string directly instead of generating a query from structured fields.

#### Scenario: Execute raw query
- **WHEN** a panel uses a SavedQuery with `isRawQuery` = true
- **THEN** the system SHALL pass `rawQuery` to the service's `query()` method

### Requirement: Manual query editor

The system SHALL provide a multi-line text editor for writing raw queries with a monospace font.

#### Scenario: Editor display
- **WHEN** the user opens the manual query editor
- **THEN** a multi-line text editor SHALL be shown with monospace font

### Requirement: Syntax reference

The editor SHALL display collapsible syntax help sections appropriate to the backend type.

#### Scenario: Flux help for InfluxDB 2
- **WHEN** editing a manual query for an InfluxDB 2 datasource
- **THEN** Flux syntax examples and common functions SHALL be shown

#### Scenario: SQL help for InfluxDB 3
- **WHEN** editing a manual query for an InfluxDB 3 datasource
- **THEN** SQL syntax examples and InfluxDB 3 functions SHALL be shown

#### Scenario: InfluxQL help for InfluxDB 1
- **WHEN** editing a manual query for an InfluxDB 1 datasource
- **THEN** InfluxQL syntax examples and common functions SHALL be shown

### Requirement: Query preview

The editor SHALL allow executing the query and viewing results.

#### Scenario: Preview results
- **WHEN** the user taps preview in the manual editor
- **THEN** the query SHALL be executed and results displayed

### Requirement: Query creation entry point

When creating a new query, the user SHALL be able to choose between the structured builder and the manual editor.

#### Scenario: Choose editor mode
- **WHEN** the user creates a new query for an InfluxDB datasource
- **THEN** the system SHALL offer both "Query Builder" and "Manual Query" options
