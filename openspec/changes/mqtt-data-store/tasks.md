## 1. MQTTDataStore with SQLite

- [x] 1.1 Create `MQTTDataStore.swift` in `Services/` with SQLite database setup (create table, index) in Application Support directory
- [x] 1.2 Implement `append(points:forKey:)` with in-memory write buffer and periodic flush (1s / 100 points)
- [x] 1.3 Implement `query(forKey:since:)` that merges buffered + persisted results, ordered by timestamp
- [x] 1.4 Implement retention pruning (24h default, throttled to once per minute via `DELETE WHERE timestamp < ?`)
- [x] 1.5 Add store key helper: `storeKey(connectionKey:topic:fields:) -> String`
- [x] 1.6 Thread safety via serial DispatchQueue for all database and buffer access

## 2. Parse-on-arrival integration

- [x] 2.1 In `ManagedConnection.handleMessage()`, parse incoming messages into `ChartDataPoint` and append to `MQTTDataStore`
- [x] 2.2 Add subscription registry to `MQTTDataStore` so it knows which topic+fields combinations to store for

## 3. Query pipeline

- [x] 3.1 Update `MQTTService.query()` to read from `MQTTDataStore` using the actual time range instead of the raw message cache
- [x] 3.2 Update `buildMQTTQuery()` in `SavedQuery+Wrapped.swift` to pass the real `TimeRange.seconds` instead of the short rangeSeconds mapping
- [x] 3.3 Update `MQTTQueryParser` to support the new range value (already works — parses any numeric range)

## 4. Panel integration

- [x] 4.1 Update `subscribeMQTTUpdates()` in `PanelCardView` to register with the store and re-read with the current time range on new messages
- [x] 4.2 Update `loadData()` for MQTT panels to query the store instead of re-fetching (handled by MQTTService.query() reading from store)

## 5. Verify

- [x] 5.1 Build and verify no compiler errors across all targets
