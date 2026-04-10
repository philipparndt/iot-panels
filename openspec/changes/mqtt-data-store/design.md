## Context

MQTT panels currently rely on `ManagedConnection.messageCache` — a raw message buffer with a 1-hour TTL and 500-message-per-topic cap. The query path (`MQTTService.query()`) filters this cache by a short `rangeSeconds` window (5–30s), then `buildQueryResult()` parses payloads into rows, then `PanelCardView` converts rows into `[ChartDataPoint]` and **replaces** its state entirely. Any view refresh or setting change discards accumulated data.

Key files:
- `MQTTService.swift`: `ManagedConnection.messageCache`, `messages(for:within:)`, `buildQueryResult()`
- `SavedQuery+Wrapped.swift`: `buildMQTTQuery()` with the `rangeSeconds` mapping
- `PanelCardView.swift`: `subscribeMQTTUpdates()`, `loadData()`, `dataPoints` state

## Goals / Non-Goals

**Goals:**
- Persist MQTT data points in a local SQLite database so they survive app restarts and view refreshes
- Support time-range queries so panels can window into the stored data
- Apply retention to prevent unbounded storage growth
- Keep the raw `messageCache` intact for connection-level concerns (field discovery, waiters)

**Non-Goals:**
- iCloud sync of MQTT data (local-only by design — it's transient sensor data)
- Aggregation/downsampling of stored data
- Changing how non-MQTT data sources work

## Decisions

### 1. Introduce `MQTTDataStore` as a singleton backed by local SQLite

A new `MQTTDataStore` class wraps a SQLite database (via Swift's `sqlite3` C API — no additional dependencies). It provides:
- `append(points:forKey:)` — inserts new data points, ignoring duplicates
- `query(forKey:since:)` — returns points within a time window using an indexed query
- `prune(olderThan:)` — deletes rows beyond the retention period

The database file lives in the app's Application Support directory (not Documents — it's a cache, not user-visible content).

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS data_points (
    store_key TEXT NOT NULL,
    timestamp REAL NOT NULL,
    field TEXT NOT NULL,
    value REAL NOT NULL,
    PRIMARY KEY (store_key, timestamp, field)
);
CREATE INDEX IF NOT EXISTS idx_key_time ON data_points (store_key, timestamp);
```

The composite primary key `(store_key, timestamp, field)` provides built-in deduplication via `INSERT OR IGNORE`.

**Rationale**: Using `sqlite3` directly avoids adding a dependency. The C API is available on all Apple platforms. The schema is trivial — one table, one index. Core Data would add unnecessary complexity for this flat time-series use case.

**Alternative considered**: GRDB or other Swift SQLite wrappers. Rejected — adding a dependency for a single-table store is overkill. The raw API is simple enough.

### 2. Store key: `connectionKey + topic + sorted fields`

Each unique combination of MQTT connection, topic pattern, and field set gets its own data series. This matches how panels are configured.

**Rationale**: Two panels watching the same topic but different fields should not interfere with each other's data.

### 3. Parse-on-arrival: parse messages into `ChartDataPoint` at message time

When `ManagedConnection` receives a message, it still caches the raw message (for field discovery and other uses), but also parses it into `ChartDataPoint` values and inserts them into `MQTTDataStore`.

To know which store keys to write to, the store maintains a set of "active subscriptions" — registered by panels when they subscribe. Each subscription maps a topic pattern to a store key (with fields). When a message arrives matching a topic, it's parsed with the registered fields and inserted under the matching store keys.

**Rationale**: Parsing once at arrival time is more efficient than re-parsing on every query. The subscription registry ensures we only store data that panels actually need.

### 4. Panels query the store instead of re-querying raw messages

`MQTTService.query()` reads from `MQTTDataStore.query(forKey:since:)` using the panel's actual time range (e.g. 2 hours), not the short `rangeSeconds`. The `rangeSeconds` mapping in `buildMQTTQuery()` is replaced with the real `TimeRange.seconds` value.

`subscribeMQTTUpdates()` in `PanelCardView` still listens for new messages, but instead of re-querying the raw cache, it reads from the store with the panel's time range.

**Rationale**: The store is the source of truth. The panel just asks "give me data for the last 2 hours" and gets a complete, consistent result.

### 5. Default retention: 24 hours, pruned periodically

`MQTTDataStore` prunes rows older than 24 hours. Pruning runs on each `append()` call (throttled to at most once per minute to avoid overhead). A single `DELETE FROM data_points WHERE timestamp < ?` is efficient with the index.

**Rationale**: 24 hours covers all practical dashboard time ranges for MQTT. Pruning on append is simple and avoids timers.

### 6. Thread safety via serial DispatchQueue

All database access goes through a serial `DispatchQueue`. This is simpler than managing locks and matches SQLite's single-writer model. Read queries can use synchronous dispatch; writes are asynchronous fire-and-forget for performance.

### 7. In-memory write buffer for high-frequency messages

To avoid hitting SQLite on every single MQTT message, the store batches inserts. Incoming points are buffered in memory and flushed to SQLite every 1 second or when the buffer exceeds 100 points, whichever comes first.

**Rationale**: IoT topics can fire multiple times per second. Batching reduces I/O without meaningful latency — the in-memory buffer is also consulted during queries so unflushed points are never invisible.

## Risks / Trade-offs

- **[Storage size]** → 24h of data at 1 msg/s per topic ≈ 86,400 rows × ~50 bytes ≈ 4 MB per topic. Acceptable for typical IoT use. The `DELETE` pruning keeps it bounded.
- **[No iCloud sync]** → MQTT data is local-only. This is intentional — sensor time-series data is device-specific and ephemeral.
- **[sqlite3 C API ergonomics]** → More verbose than a wrapper, but the surface area is small (one table, three operations). Wrapping in a clean Swift API keeps the rest of the codebase isolated.
- **[Write buffer adds complexity]** → Queries must merge buffered + persisted results. Mitigated by keeping the buffer small and flushing frequently.
