## Why

MQTT data points are currently held only in a transient message cache (`ManagedConnection.messageCache`) that is pruned to 1 hour and filtered through a short-lived query window (5–30 seconds). Any action that triggers `loadData()` — changing the time range, switching tabs, or a view recreation — re-queries this cache and replaces the panel's data points entirely. This causes accumulated values to be lost, sparklines to reset, and the user experience to be unreliable for sporadic MQTT data.

## What Changes

- Introduce `MQTTDataStore`, a persistent per-topic time-series store backed by local SQLite that accumulates parsed `ChartDataPoint` values across app sessions.
- MQTT messages are parsed into data points and appended to the store as they arrive. The store is the single source of truth for MQTT panel data.
- Panels query the store by time range instead of re-querying the raw message cache. Changing the time range simply filters the store — no data is lost.
- The store supports a configurable retention period (default: 24 hours) to prevent unbounded storage growth. Pruning happens periodically.
- Remove the short `rangeSeconds` parameter from MQTT queries — it is no longer needed since the store handles time windowing.

## Capabilities

### New Capabilities
- `mqtt-data-store`: SQLite-backed persistent time-series store for MQTT data points with retention, time-range queries, and append-only accumulation.

### Modified Capabilities

_(none — the MQTT query pipeline is an implementation detail, not a spec-level capability)_

## Impact

- **Services**: `MQTTService.swift` — query method reads from `MQTTDataStore` instead of `messageCache` for panel data. Message arrival appends parsed points to the store.
- **Model**: `SavedQuery+Wrapped.swift` — `buildMQTTQuery()` no longer needs the `rangeSeconds` mapping; the time range is passed directly to the store query.
- **Views**: `PanelCardView.swift` — `subscribeMQTTUpdates()` and `loadData()` read from the store with a time range filter. Data is no longer fully replaced on each message.
- **New file**: `MQTTDataStore.swift` — the store itself.
- **No breaking changes** — all changes are internal to the MQTT pipeline.
