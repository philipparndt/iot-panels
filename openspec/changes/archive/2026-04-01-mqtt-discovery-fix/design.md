## Context

`MQTTConnectionManager` is a singleton that maintains persistent MQTT connections keyed by `hostname:port:username:enableSSL`. Each `ManagedConnection` tracks `subscribedTopics` (a Set) and a `messageCache` (array of topic/payload/timestamp). The `ensureSubscribed` method skips subscription if the topic is already in the set. MQTT brokers only send retained messages on initial subscription — re-subscribing on the same connection requires an explicit unsubscribe first.

## Goals / Non-Goals

**Goals:**
- Topic discovery works reliably every time, not just the first
- Retained messages are always received during discovery
- Existing live panel subscriptions are not disrupted

**Non-Goals:**
- Changing the connection pooling strategy
- Supporting MQTT 5 subscription options (retain handling flags)

## Decisions

### 1. Add a `refreshSubscription` method to ManagedConnection

Add a method that:
1. Unsubscribes from the topic
2. Removes it from `subscribedTopics`
3. Clears cached messages for that topic
4. Re-subscribes to the topic

This forces the broker to resend retained messages. The method is called by `MQTTConnectionManager.getMessages` when a new `forceRefresh: Bool` parameter is set.

**Alternative considered**: Disconnect and reconnect the entire connection — rejected because this would disrupt all other subscriptions on the same connection (e.g., live panel data feeds).

### 2. Use `forceRefresh` in topic discovery

`MQTTTopicDiscoveryPage` passes `forceRefresh: true` when starting discovery, so each discovery session gets fresh retained messages.

## Risks / Trade-offs

- **[Brief message gap]** During the unsubscribe/resubscribe window, a few messages could be missed → Acceptable for discovery which is an interactive, user-initiated action.
- **[Retained message flood]** With many topics, resubscribing to `#` triggers all retained messages at once → Same as first-time behavior, already handled.
