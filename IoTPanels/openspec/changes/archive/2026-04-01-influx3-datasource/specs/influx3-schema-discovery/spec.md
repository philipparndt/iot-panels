## ADDED Requirements

### Requirement: Fetch measurements (tables)

The system SHALL discover available measurements in an InfluxDB 3 database by executing `SHOW TABLES`.

#### Scenario: List measurements
- **WHEN** the query builder requests available measurements for an InfluxDB 3 datasource
- **THEN** the system SHALL execute `SHOW TABLES` and return the table names as measurements

### Requirement: Fetch field keys (columns)

The system SHALL discover available fields for a measurement by executing `SHOW COLUMNS FROM <table>` and filtering for data columns.

#### Scenario: List fields for a measurement
- **WHEN** the query builder requests field keys for a specific measurement on InfluxDB 3
- **THEN** the system SHALL execute `SHOW COLUMNS FROM "<measurement>"` and return column names that represent data fields (excluding `time` and tag columns)

### Requirement: Fetch tag keys

The system SHALL discover available tag keys for a measurement from the column metadata.

#### Scenario: List tag keys for a measurement
- **WHEN** the query builder requests tag keys for a specific measurement on InfluxDB 3
- **THEN** the system SHALL return columns identified as tags (Dictionary type or string-typed non-field columns)

### Requirement: Fetch tag values

The system SHALL discover available values for a specific tag by querying distinct values.

#### Scenario: List tag values
- **WHEN** the query builder requests tag values for a specific tag on InfluxDB 3
- **THEN** the system SHALL execute `SELECT DISTINCT "<tag>" FROM "<measurement>"` and return the results

### Requirement: Query builder UI supports InfluxDB 3

The existing query builder UI SHALL work with InfluxDB 3 datasources using the same flow: select measurement, select fields, configure filters, set time range.

#### Scenario: Query builder with InfluxDB 3 datasource
- **WHEN** the user creates a query for an InfluxDB 3 datasource
- **THEN** the query builder SHALL use InfluxDB 3 schema discovery methods to populate measurement, field, and tag pickers
- **AND** SHALL follow the same UI flow as InfluxDB 2
