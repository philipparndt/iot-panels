## ADDED Requirements

### Requirement: MQTT setup uses a guided wizard for new data sources
The system SHALL present a multi-step wizard when adding a new MQTT data source, guiding the user through connection, security, testing, and completion.

#### Scenario: New MQTT data source triggers wizard
- **WHEN** user adds a new MQTT data source
- **THEN** the setup wizard is presented instead of the flat settings form

#### Scenario: Editing existing MQTT data source uses full form
- **WHEN** user edits an existing MQTT data source
- **THEN** the full settings form (MQTTBrokerFormView) is shown, not the wizard

### Requirement: Wizard Step 1 — Connect
The system SHALL present hostname, port, protocol (MQTT/WebSocket), protocol version, and optional basepath in the first step.

#### Scenario: Enter broker address
- **WHEN** user enters hostname and port on the Connect step
- **THEN** the values are stored and the user can proceed to the next step

### Requirement: Wizard Step 2 — Security
The system SHALL present TLS settings and authentication options in the second step, including username/password and client certificate (mTLS).

#### Scenario: Configure TLS and auth
- **WHEN** user enables TLS and enters username/password
- **THEN** the settings are stored and the user can proceed to the test step

### Requirement: Wizard Step 3 — Test Connection
The system SHALL test the MQTT connection using the configured settings and show success or failure before allowing the user to finish.

#### Scenario: Connection test succeeds
- **WHEN** the connection test succeeds
- **THEN** a success indicator is shown and the user can proceed to finish

#### Scenario: Connection test fails
- **WHEN** the connection test fails
- **THEN** an error message is shown with a retry option and the option to go back and adjust settings

### Requirement: Wizard Step 4 — Finish
The system SHALL show a summary of the configured settings and allow the user to complete the setup.

#### Scenario: Complete setup
- **WHEN** user taps Done on the finish step
- **THEN** the data source is saved and the wizard is dismissed
