## Why

The InfluxDB data sources have a guided setup wizard that walks users through connection, organization/bucket selection, and finish steps. MQTT setup instead presents all settings on a single dense form (hostname, port, TLS, auth, certificates, discovery topic, client ID). This is overwhelming for new users and inconsistent with the InfluxDB experience. A stepped wizard would make MQTT setup approachable while still supporting advanced options.

## What Changes

- Create a new `MQTTSetupView` wizard with sequential steps, matching the InfluxDB setup pattern
- Steps: Connect (hostname, port, protocol) → TLS & Auth → Test Connection → Finish
- Reuse the existing `MQTTFormView` components for individual sections
- Keep the existing form available as an "Advanced" option for power users
- Add connection test step that validates MQTT CONNACK before proceeding

## Capabilities

### New Capabilities
- `mqtt-setup-wizard`: Guided multi-step MQTT broker setup wizard

### Modified Capabilities

## Impact

- **Views**: New `MQTTSetupView` with stepped navigation
- **DataSourceDetailView**: Route to wizard instead of (or alongside) the existing form
- **MQTTService**: Reuse existing `testConnection()` for the test step
- **Existing MQTTFormView**: Unchanged — still available for editing after initial setup
- **Dependencies**: None
