## ADDED Requirements

### Requirement: MQTTDataStore persists data points in SQLite
The system SHALL provide an `MQTTDataStore` backed by a local SQLite database that accumulates `ChartDataPoint` values, keyed by a store key derived from the MQTT connection, topic, and fields. Data SHALL survive app restarts.

#### Scenario: Append new data points
- **WHEN** a new MQTT message is received and parsed into data points
- **THEN** the data points SHALL be inserted into the SQLite database under the appropriate store key

#### Scenario: Data persists across app restarts
- **WHEN** the app is terminated and relaunched
- **THEN** previously stored MQTT data points SHALL still be available for querying

#### Scenario: Data persists across view refreshes
- **WHEN** a panel's view is recreated or settings are changed (e.g., time range)
- **THEN** the store SHALL still contain all previously accumulated data points

### Requirement: Time-range queries
The store SHALL support querying data points within a time window using indexed SQLite queries.

#### Scenario: Query with time range
- **WHEN** a panel queries the store with a key and a duration of 7200 seconds (2 hours)
- **THEN** the store SHALL return all data points for that key with timestamps within `[now - 7200s, now]`

#### Scenario: Changing time range does not discard data
- **WHEN** a panel changes its time range from 2 hours to 30 minutes
- **THEN** the store SHALL return only data from the last 30 minutes, but data older than 30 minutes SHALL remain in the store for future queries

### Requirement: Deduplication
The store SHALL NOT insert duplicate data points with the same store key, timestamp, and field.

#### Scenario: Duplicate message
- **WHEN** a data point with timestamp T and field F is appended to a key that already contains a point with the same timestamp T and field F
- **THEN** the store SHALL ignore the duplicate via `INSERT OR IGNORE`

### Requirement: Retention
The store SHALL remove data points older than a retention period to prevent unbounded storage growth.

#### Scenario: Default retention
- **WHEN** data points are older than 24 hours
- **THEN** they SHALL be deleted from the database during the next pruning cycle

#### Scenario: Pruning frequency
- **WHEN** new data points are appended
- **THEN** pruning SHALL run at most once per minute to avoid performance overhead

### Requirement: Thread safety
The store SHALL be safe to access from multiple threads concurrently via a serial dispatch queue.

#### Scenario: Concurrent access
- **WHEN** one thread appends data while another thread queries
- **THEN** neither operation SHALL crash or return corrupted data

### Requirement: Write buffering
The store SHALL buffer incoming data points in memory and flush them to SQLite periodically to handle high-frequency messages efficiently.

#### Scenario: Buffered writes
- **WHEN** multiple data points arrive within a short interval
- **THEN** they SHALL be batched and written to SQLite in a single transaction

#### Scenario: Buffer included in queries
- **WHEN** a query is executed while unflushed data points exist in the buffer
- **THEN** the query result SHALL include both persisted and buffered data points

### Requirement: MQTT panels query the store
MQTT panels SHALL read data from `MQTTDataStore` instead of re-querying the raw message cache. The query SHALL use the panel's configured time range.

#### Scenario: Panel loads data
- **WHEN** an MQTT panel calls `loadData()` with a 2-hour time range
- **THEN** it SHALL query the store for the last 2 hours of data for its topic and fields

#### Scenario: Live update appends and re-reads
- **WHEN** a new MQTT message arrives for a subscribed panel
- **THEN** the message SHALL be parsed, appended to the store, and the panel SHALL re-read from the store with its current time range

### Requirement: Store key derivation
The store key SHALL be derived from the MQTT connection key, topic pattern, and sorted field names, ensuring that each unique panel configuration maps to a distinct data series.

#### Scenario: Same topic different fields
- **WHEN** panel A watches topic `sensors/temp` for field `temperature` and panel B watches the same topic for field `humidity`
- **THEN** they SHALL use different store keys and maintain independent data series
