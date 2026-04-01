## ADDED Requirements

### Requirement: Fetch databases

The system SHALL discover databases via `SHOW DATABASES`.

#### Scenario: List databases
- **WHEN** the setup wizard connects to an InfluxDB 1 server
- **THEN** the system SHALL execute `SHOW DATABASES` and return database names

### Requirement: Fetch measurements

The system SHALL discover measurements via `SHOW MEASUREMENTS`.

#### Scenario: List measurements
- **WHEN** the query builder requests measurements
- **THEN** the system SHALL execute `SHOW MEASUREMENTS` and return measurement names

### Requirement: Fetch field keys

The system SHALL discover fields via `SHOW FIELD KEYS FROM <measurement>`.

#### Scenario: List fields
- **WHEN** the query builder requests fields for a measurement
- **THEN** the system SHALL return field names from `SHOW FIELD KEYS`

### Requirement: Fetch tag keys

The system SHALL discover tags via `SHOW TAG KEYS FROM <measurement>`.

#### Scenario: List tags
- **WHEN** the query builder requests tag keys
- **THEN** the system SHALL return tag names from `SHOW TAG KEYS`

### Requirement: Fetch tag values

The system SHALL discover tag values via `SHOW TAG VALUES FROM <measurement> WITH KEY = <tag>`.

#### Scenario: List tag values
- **WHEN** the query builder requests values for a tag
- **THEN** the system SHALL return distinct tag values

### Requirement: Query builder UI support

The query builder SHALL work with InfluxDB 1 using the same flow as other backends.

#### Scenario: Query builder with InfluxDB 1
- **WHEN** the user creates a query for an InfluxDB 1 datasource
- **THEN** the query builder SHALL use InfluxDB 1 schema discovery methods
