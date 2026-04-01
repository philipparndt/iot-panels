## 1. Connection Manager — Fresh Discovery

- [x] 1.1 Add `refreshSubscription(for topic:)` method to `ManagedConnection` that unsubscribes, removes from `subscribedTopics`, clears cached messages for the topic, and resubscribes
- [x] 1.2 Add `unsubscribe(from:)` method to `ManagedConnection` for MQTT3/MQTT5
- [x] 1.3 Expose `refreshSubscription` through a public method on `MQTTConnectionManager` for discovery use

## 2. Topic Discovery Page

- [x] 2.1 Call `refreshSubscription` when discovery starts to force broker to resend retained messages
- [x] 2.2 Clear the local `topicCounts`, `topicPayloads`, and `discoveredTopics` state when starting a new discovery session

## 3. Value Filtering

- [x] 3.1 Support plain numeric payloads (not just JSON) — when payload is a valid number, treat it as a field named "value"
- [x] 3.2 Filter out topics from the discovery list that have no parseable numeric values (no JSON numeric fields and not a plain number)

## 4. Testing

- [ ] 4.1 Verify discovery shows retained messages on second run
- [ ] 4.2 Verify plain numeric payloads (e.g., "21.5") are detected as "value" field
- [ ] 4.3 Verify topics with non-numeric payloads (e.g., "online") are hidden
