### Requirement: User can open a panel in fullscreen explorer mode
The system SHALL provide a way to open any dashboard panel in a fullscreen explorer overlay. The overlay SHALL display the same chart as the panel, using the panel's current settings as initial values.

#### Scenario: Open explorer from dashboard panel
- **WHEN** user taps the explore action on a dashboard panel
- **THEN** a fullscreen overlay opens showing the panel's chart with the same time range, aggregation, and display style

#### Scenario: Close explorer discards changes
- **WHEN** user dismisses the explorer overlay
- **THEN** all transient setting changes are discarded and the dashboard panel retains its original persisted settings

### Requirement: User can change the time range in the explorer
The system SHALL provide time range presets in the explorer toolbar. Changing the time range SHALL re-execute the query with the new range and update the chart.

#### Scenario: Select a different time range
- **WHEN** user selects a different time range preset (e.g., from 24h to 7d)
- **THEN** the chart re-fetches data for the new time range and displays the updated result

#### Scenario: Time range change does not persist
- **WHEN** user changes the time range and then closes the explorer
- **THEN** the original panel's time range remains unchanged

### Requirement: User can scroll through data by shifting the time window
The system SHALL provide step-forward and step-backward controls that shift the visible time window. The step size SHALL equal the current time range width (e.g., viewing 24h steps by 24h). A reset control SHALL return to the current time.

#### Scenario: Step backward
- **WHEN** user taps the step-backward button while viewing the last 24 hours
- **THEN** the chart shows data for the previous 24-hour period (24h–48h ago)

#### Scenario: Step forward
- **WHEN** user has stepped backward and taps the step-forward button
- **THEN** the time window shifts forward by the current range width

#### Scenario: Reset to current time
- **WHEN** user has scrolled away from the current time and taps the reset button
- **THEN** the time window resets to show the most recent data (offset returns to zero)

#### Scenario: Step forward disabled at current time
- **WHEN** the time window offset is zero (showing current time)
- **THEN** the step-forward button SHALL be disabled

### Requirement: User can change the aggregation settings in the explorer
The system SHALL provide controls to change the aggregate window and aggregate function. Changes SHALL re-execute the query and update the chart.

#### Scenario: Change aggregate window
- **WHEN** user selects a different aggregate window (e.g., from 1h to 5m)
- **THEN** the chart re-fetches data with the new aggregation and displays the updated result

#### Scenario: Change aggregate function
- **WHEN** user selects a different aggregate function (e.g., from mean to max)
- **THEN** the chart re-fetches data with the new function and displays the updated result

### Requirement: User can set a comparison window in the explorer
The system SHALL provide a control to enable or change the comparison offset. When a comparison is active, the chart SHALL overlay the comparison period's data alongside the current data.

#### Scenario: Enable comparison
- **WHEN** user selects a comparison offset (e.g., 7 days ago)
- **THEN** the chart fetches and overlays data from 7 days prior to the current time window

#### Scenario: Disable comparison
- **WHEN** user deselects the comparison offset (sets to none)
- **THEN** the comparison overlay is removed from the chart

### Requirement: Explorer shows loading and error states
The system SHALL show a loading indicator while fetching data and display an error message if the query fails. The previous chart data SHALL remain visible during loading.

#### Scenario: Loading indicator during fetch
- **WHEN** the explorer is fetching new data after a settings change
- **THEN** a loading indicator is displayed while the previous chart remains visible

#### Scenario: Query error
- **WHEN** a query fails in the explorer
- **THEN** an error message is displayed and the previous chart data remains visible

### Requirement: MQTT panels have limited explorer controls
For MQTT data source panels, the system SHALL disable time range and scrolling controls since MQTT does not support historical queries. Aggregation controls SHALL remain available for cached data.

#### Scenario: MQTT panel explorer
- **WHEN** user opens the explorer for an MQTT-backed panel
- **THEN** time range presets and step controls are disabled, and aggregation controls remain functional
