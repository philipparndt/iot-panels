## ADDED Requirements

### Requirement: Prometheus backend type
The system SHALL support `prometheus` as a backend type in the `BackendType` enum, with display name "Prometheus".

#### Scenario: Prometheus appears in datasource type picker
- **WHEN** user taps "Add Data Source"
- **THEN** "Prometheus" SHALL appear as a selectable backend type alongside InfluxDB and MQTT options

### Requirement: Prometheus connection configuration
The system SHALL allow users to configure a Prometheus datasource with the following settings:
- Server URL (required, e.g., `http://prometheus:9090`)
- Authentication method: none, basic auth (username + password), or bearer token
- TLS: enable/disable SSL, allow untrusted certificates

#### Scenario: Configure Prometheus with no authentication
- **WHEN** user enters a Prometheus server URL and selects "No Authentication"
- **THEN** the system SHALL store the URL and set no credentials

#### Scenario: Configure Prometheus with basic authentication
- **WHEN** user enters a server URL, selects "Basic Auth", and provides username and password
- **THEN** the system SHALL store URL, username, and password for HTTP Basic authentication

#### Scenario: Configure Prometheus with bearer token
- **WHEN** user enters a server URL, selects "Bearer Token", and provides a token
- **THEN** the system SHALL store URL and token for Authorization header

#### Scenario: Configure TLS settings
- **WHEN** user enables SSL and optionally allows untrusted certificates
- **THEN** the system SHALL use HTTPS and respect the untrusted certificate setting

### Requirement: Prometheus connection testing
The system SHALL test the Prometheus connection by querying the `/api/v1/status/buildinfo` or `/api/v1/query?query=up` endpoint and verifying a successful response.

#### Scenario: Successful connection test
- **WHEN** user taps "Test Connection" and the Prometheus server responds successfully
- **THEN** the system SHALL indicate the connection is working

#### Scenario: Failed connection test
- **WHEN** user taps "Test Connection" and the server is unreachable or returns an error
- **THEN** the system SHALL display an error message describing the failure

### Requirement: Prometheus setup wizard
The system SHALL provide a step-based setup wizard for Prometheus with the following steps:
1. **Connect** — Enter server URL, select auth method, provide credentials, test connection
2. **Finish** — Confirm successful connection and save the datasource

#### Scenario: Complete setup wizard
- **WHEN** user enters valid connection details and the connection test passes
- **THEN** the system SHALL allow the user to proceed to the finish step and save the datasource

#### Scenario: Connection test blocks progression
- **WHEN** user has not successfully tested the connection
- **THEN** the system SHALL NOT allow progression to the finish step

### Requirement: Prometheus datasource persistence
The system SHALL persist Prometheus datasource configuration using existing Core Data `DataSource` entity fields: `url`, `token`, `username`, `password`, `ssl`, `untrustedSSL`, with `backendType` set to `"prometheus"`.

#### Scenario: Save and reload Prometheus datasource
- **WHEN** user saves a Prometheus datasource and reopens the app
- **THEN** the datasource SHALL be restored with all connection settings intact

#### Scenario: CloudKit sync
- **WHEN** a Prometheus datasource is saved on one device
- **THEN** it SHALL sync to other devices via CloudKit like all other datasource types

### Requirement: Prometheus service factory integration
The `ServiceFactory` SHALL create a `PrometheusService` instance when the datasource's backend type is `.prometheus`.

#### Scenario: Service creation
- **WHEN** `ServiceFactory.service(for:)` is called with a Prometheus datasource
- **THEN** it SHALL return a `PrometheusService` configured with the datasource's URL, auth, and TLS settings
