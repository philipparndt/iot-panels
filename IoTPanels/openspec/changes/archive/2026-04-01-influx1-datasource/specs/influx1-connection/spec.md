## ADDED Requirements

### Requirement: InfluxDB 1 backend type

The system SHALL support `influxDB1` as a backend type with display name "InfluxDB 1".

#### Scenario: Backend type available
- **WHEN** the user creates a new datasource
- **THEN** "InfluxDB 1" SHALL be available as a backend type option

### Requirement: InfluxDB 1 connection configuration

An InfluxDB 1 datasource SHALL be configured with a server URL, database name, and optional username/password.

#### Scenario: Configuration form
- **WHEN** the user selects "InfluxDB 1" as the backend type
- **THEN** the configuration SHALL allow URL, database, and optional username/password

### Requirement: InfluxDB 1 connection testing

The system SHALL test connections by executing `SHOW DATABASES` against the configured endpoint.

#### Scenario: Successful connection test
- **WHEN** the user tests an InfluxDB 1 connection with valid settings
- **THEN** the system SHALL report success

### Requirement: InfluxDB 1 authentication

The system SHALL support no auth and username/password auth via query parameters.

#### Scenario: No auth request
- **WHEN** the system makes a request without credentials configured
- **THEN** no auth parameters SHALL be sent

#### Scenario: Username/password request
- **WHEN** credentials are configured
- **THEN** the request SHALL include `u` and `p` query parameters
