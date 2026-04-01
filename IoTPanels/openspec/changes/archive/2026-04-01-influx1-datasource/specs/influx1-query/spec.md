## ADDED Requirements

### Requirement: InfluxQL query generation

The system SHALL generate InfluxQL queries for InfluxDB 1 datasources.

#### Scenario: Basic query
- **WHEN** a saved query targets InfluxDB 1 with measurement "temperature", field "value", time range "2h"
- **THEN** the system SHALL generate `SELECT "value" FROM "temperature" WHERE time > now() - 2h`

#### Scenario: Query with aggregation
- **WHEN** a saved query specifies aggregate window 5m and function mean
- **THEN** the system SHALL generate a query with `GROUP BY time(5m)` and `MEAN("field")`

#### Scenario: Query with tag filters
- **WHEN** a saved query includes tag filters
- **THEN** the generated InfluxQL SHALL include WHERE clauses for tag values

### Requirement: InfluxQL query execution

The system SHALL execute InfluxQL queries via `GET /query?db=...&q=...` and parse JSON responses into `QueryResult`.

#### Scenario: Successful query
- **WHEN** the system executes an InfluxQL query
- **THEN** the system SHALL parse the `results[].series[].values` JSON structure into `QueryResult`

### Requirement: Band chart InfluxQL queries

The system SHALL generate InfluxQL queries for band charts with MIN/MAX/MEAN aggregates.

#### Scenario: Band query
- **WHEN** a panel uses band chart with InfluxDB 1
- **THEN** the system SHALL generate a query computing MIN, MAX, MEAN per time bucket

### Requirement: Comparison InfluxQL queries

The system SHALL generate time-shifted InfluxQL queries for comparison mode.

#### Scenario: Comparison query
- **WHEN** comparison mode is enabled with an offset
- **THEN** the system SHALL generate a time-shifted InfluxQL query

### Requirement: ServiceFactory routing

The `ServiceFactory` SHALL route `influxDB1` to the `InfluxDB1Service`.

#### Scenario: Service creation
- **WHEN** `ServiceFactory.service(for:)` is called with an InfluxDB 1 datasource
- **THEN** it SHALL return an `InfluxDB1Service` instance
