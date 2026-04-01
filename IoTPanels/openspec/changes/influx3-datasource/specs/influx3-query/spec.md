## ADDED Requirements

### Requirement: SQL query generation

The system SHALL generate SQL queries for InfluxDB 3 datasources based on the saved query's measurement, fields, tag filters, time range, and aggregation settings.

#### Scenario: Basic query with fields and time range
- **WHEN** a saved query targets InfluxDB 3 with measurement "temperature", field "value", and time range "2h"
- **THEN** the system SHALL generate a SQL query selecting the field from the measurement with a time filter of the last 2 hours

#### Scenario: Query with tag filters
- **WHEN** a saved query includes tag filters (e.g., location = "kitchen")
- **THEN** the generated SQL SHALL include WHERE clauses for the tag filters

#### Scenario: Query with aggregation
- **WHEN** a saved query specifies an aggregate window (e.g., 5m) and function (e.g., mean)
- **THEN** the generated SQL SHALL use `DATE_BIN` for time bucketing and the appropriate aggregate function

### Requirement: SQL query execution

The system SHALL execute SQL queries against InfluxDB 3's `/api/v3/query_sql` endpoint and parse JSON responses into `QueryResult`.

#### Scenario: Successful query execution
- **WHEN** the system executes a SQL query against InfluxDB 3
- **THEN** the system SHALL POST to `/api/v3/query_sql` with the SQL in the request body
- **AND** SHALL parse the JSON response into columns and rows matching the `QueryResult` model

#### Scenario: Query with database parameter
- **WHEN** the system executes a query
- **THEN** the request SHALL include the configured database name as a parameter

### Requirement: Band chart SQL queries

The system SHALL generate SQL queries that produce min/max/mean aggregates for band chart rendering on InfluxDB 3.

#### Scenario: Band query generation
- **WHEN** a panel uses band chart display style with an InfluxDB 3 datasource
- **THEN** the system SHALL generate a SQL query that computes MIN, MAX, and AVG for the selected fields within each time bucket

### Requirement: Comparison SQL queries

The system SHALL generate time-shifted SQL queries for comparison mode on InfluxDB 3.

#### Scenario: Comparison query with offset
- **WHEN** a panel has comparison mode enabled with an offset (e.g., 7 days)
- **THEN** the system SHALL generate a SQL query that selects data from the comparison period and shifts timestamps forward to align with the primary period

### Requirement: ServiceFactory routing

The `ServiceFactory` SHALL route `influxDB3` backend type to the `InfluxDB3Service`.

#### Scenario: Service creation
- **WHEN** `ServiceFactory.service(for:)` is called with an InfluxDB 3 datasource
- **THEN** it SHALL return an `InfluxDB3Service` instance configured with the datasource's connection details
