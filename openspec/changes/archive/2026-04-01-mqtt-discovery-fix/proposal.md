## Why

MQTT topic discovery only works on the first attempt. On subsequent discovery runs, the connection manager reuses the existing connection, the `subscribedTopics` set prevents re-subscription, and the broker never resends retained messages. The message cache also retains stale data from the first run while the time filter (`rangeSeconds: 0`) excludes it, resulting in empty results.

## What Changes

- Add the ability to force a fresh discovery by unsubscribing and resubscribing to topics
- Clear the message cache when starting a new discovery session
- Reset the `subscribedTopics` set for the relevant topics so `ensureSubscribed` actually re-subscribes
- Alternatively, disconnect and reconnect the connection to force the broker to resend retained messages

## Capabilities

### New Capabilities
- `mqtt-fresh-discovery`: MQTT topic discovery works reliably on every attempt, not just the first

### Modified Capabilities

## Impact

- **MQTTConnectionManager**: Add method to reset/refresh a subscription (unsubscribe + clear cache + resubscribe)
- **MQTTTopicDiscoveryPage**: Call the refresh method when starting discovery
- **ManagedConnection**: Add `resetSubscription(for:)` or `clearCache()` methods
- **Dependencies**: None
