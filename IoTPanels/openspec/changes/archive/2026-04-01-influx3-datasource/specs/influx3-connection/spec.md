## ADDED Requirements

### Requirement: InfluxDB 3 backend type

The system SHALL support `influxDB3` as a backend type in the `BackendType` enum with display name "InfluxDB 3".

#### Scenario: Backend type available in datasource creation
- **WHEN** the user creates a new datasource
- **THEN** "InfluxDB 3" SHALL be available as a backend type option

### Requirement: InfluxDB 3 connection configuration

An InfluxDB 3 datasource SHALL be configured with a server URL, API token, and database name. Organization and bucket fields are not required.

#### Scenario: Configuration form fields
- **WHEN** the user selects "InfluxDB 3" as the backend type
- **THEN** the configuration form SHALL show fields for server URL, API token, and database name
- **AND** the form SHALL NOT show organization, bucket, or auth method fields

#### Scenario: Configuration persisted in Core Data
- **WHEN** the user saves an InfluxDB 3 datasource
- **THEN** the URL, token, and database SHALL be persisted in the DataSource entity

### Requirement: InfluxDB 3 connection testing

The system SHALL test InfluxDB 3 connections by executing a lightweight SQL query against the configured endpoint.

#### Scenario: Successful connection test
- **WHEN** the user tests an InfluxDB 3 connection with valid credentials
- **THEN** the system SHALL execute a test query via `/api/v3/query_sql`
- **AND** SHALL report success

#### Scenario: Failed connection test
- **WHEN** the user tests an InfluxDB 3 connection with invalid credentials or unreachable server
- **THEN** the system SHALL report the connection failure

### Requirement: InfluxDB 3 authentication

The system SHALL authenticate InfluxDB 3 requests using a Bearer token in the Authorization header.

#### Scenario: Token sent with requests
- **WHEN** the system makes an HTTP request to an InfluxDB 3 endpoint
- **THEN** the request SHALL include `Authorization: Bearer <token>` header
