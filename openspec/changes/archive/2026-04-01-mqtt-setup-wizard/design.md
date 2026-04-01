## Context

InfluxDB2SetupView uses a 4-step wizard with a visual step indicator, NavigationStack, and auto-advancing when selections are made. MQTT currently uses MQTTFormView (reusable form sections) and MQTTBrokerFormView (single-page settings). The existing MQTTFormView components (server section, TLS section, auth section) can be reused inside wizard steps.

## Goals / Non-Goals

**Goals:**
- Sequential wizard matching InfluxDB setup UX
- Connection test before finishing
- Reuse existing MQTTFormView components
- Keep full form accessible for editing after setup

**Non-Goals:**
- Removing the existing MQTTFormView/MQTTBrokerFormView
- Auto-discovery of broker settings (mDNS, etc.)
- Topic/query setup in the wizard (that happens separately when creating queries)

## Decisions

### 1. Four wizard steps

1. **Connect**: Hostname, port, protocol (MQTT/WebSocket), version, basepath. Common ports shown as hints.
2. **Security**: TLS toggle, allow untrusted, server CA, ALPN. Authentication method (none, username/password, client certificate).
3. **Test**: Run connection test, show success/failure, allow retry. Advanced settings expandable (client ID, discovery base topic).
4. **Finish**: Summary of configured settings, "Done" button that saves and dismisses.

### 2. Reuse MQTTFormView sections

The existing `MQTTFormView` already has modular sections (serverSection, tlsSection, authSection, etc.). Extract these as standalone views or pass bindings to the wizard steps.

### 3. Route from DataSourceDetailView

When adding a new MQTT data source, show the wizard. When editing an existing one, show the full form (MQTTBrokerFormView) as before.

## Risks / Trade-offs

- **[Step count]** 4 steps might feel like too many for experienced users → "Advanced" mode or skip-ahead could be added later. The wizard is only for initial setup.
- **[Certificate setup]** Certificate import during a wizard step can be complex → Keep the certificate picker as-is (file picker + storage choice), it works well enough in a form context.
