## ADDED Requirements

### Requirement: Topic discovery works reliably on every attempt
The system SHALL deliver retained messages on every discovery session, not just the first.

#### Scenario: Second discovery shows retained messages
- **WHEN** user runs topic discovery a second time without restarting the app
- **THEN** all retained messages are received and topics are displayed

#### Scenario: Discovery after connection was idle
- **WHEN** user returns to discovery after the connection has been idle
- **THEN** the broker resends retained messages and all topics appear

### Requirement: Topics without discoverable values are hidden
The system SHALL hide topics from the discovery list when no parseable value (numeric JSON field or plain numeric message) has been received.

#### Scenario: Topic with JSON payload containing numeric fields
- **WHEN** a topic publishes `{"temperature": 21.5, "humidity": 65}`
- **THEN** the topic is shown with fields "temperature" and "humidity"

#### Scenario: Topic with plain numeric payload
- **WHEN** a topic publishes `21.5` (a plain number, not JSON)
- **THEN** the topic is shown with a "value" field

#### Scenario: Topic with non-numeric payload
- **WHEN** a topic publishes `"online"` or `{}` (no numeric values)
- **THEN** the topic is hidden from the discovery list
