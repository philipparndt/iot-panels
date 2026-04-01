## Context

IoT Panels currently supports InfluxDB 2 (Flux), MQTT, and Demo datasources via a protocol-based architecture (`DataSourceServiceProtocol`). Each backend type has a service, query builder, and UI form. InfluxDB 3 replaces Flux with SQL and uses a different HTTP API surface (`/api/v3/query_sql` with JSON responses instead of `/api/v2/query` with CSV).

The existing architecture cleanly separates backend types through `BackendType` enum, `ServiceFactory`, and per-backend query building in `SavedQuery+Wrapped`. Adding InfluxDB 3 follows the same pattern.

## Goals / Non-Goals

**Goals:**
- Support InfluxDB 3 as a first-class datasource alongside InfluxDB 2 and MQTT
- Reuse the existing `DataSourceServiceProtocol` and `QueryResult` model
- Support SQL-based schema discovery and query building
- Share existing UI components (time range, aggregation, chart rendering) across both InfluxDB versions

**Non-Goals:**
- Migrating existing InfluxDB 2 datasources to InfluxDB 3
- Supporting Arrow Flight SQL protocol (HTTP JSON API is sufficient for mobile)
- Supporting InfluxDB 3's InfluxQL compatibility layer
- Custom SQL editor — stick with the structured query builder approach

## Decisions

### 1. HTTP JSON API over Arrow Flight SQL

Use InfluxDB 3's `/api/v3/query_sql` HTTP endpoint which returns JSON, not the gRPC-based Arrow Flight SQL protocol.

**Rationale**: Arrow Flight requires gRPC dependencies (not trivially available on iOS) and is designed for high-throughput analytics workloads. The HTTP JSON API is lightweight, sufficient for dashboard queries, and matches the existing HTTP-based approach used for InfluxDB 2.

**Alternative considered**: Arrow Flight SQL via a Swift gRPC client — rejected due to dependency complexity and overkill for dashboard-scale queries.

### 2. SQL query generation in SavedQuery+Wrapped

Add `buildSQL()` method alongside existing `buildFluxQuery()` and `buildMQTTQuery()`. The query builder dispatch in `buildQuery(for:)` routes to SQL generation for `influxDB3`.

**Rationale**: Follows the established pattern. SQL generation is straightforward — `SELECT fields FROM measurement WHERE time >= NOW() - interval AND tag_filters GROUP BY time_bucket`.

### 3. Reuse `database` attribute instead of bucket/org

InfluxDB 3 uses "database" instead of "bucket" and doesn't require an organization. Add a `database` attribute to the Core Data model. The InfluxDB 3 form shows only URL, token, and database.

**Rationale**: Keeps the model clean. InfluxDB 3 authentication is token-only (no username/password session auth), simplifying the configuration form.

### 4. Schema discovery via system tables

Use `SHOW TABLES` for measurements and `SHOW COLUMNS FROM <table>` for fields/tags, via the same `/api/v3/query_sql` endpoint.

**Rationale**: InfluxDB 3 doesn't have the `schema.*` Flux helpers. SQL system queries are the standard discovery mechanism.

### 5. Dedicated InfluxDB3SettingsFormView

Create a new settings form rather than making the existing `InfluxDBSettingsFormView` conditional. InfluxDB 3 config is simpler (no org discovery, no auth method choice, no bucket discovery).

**Rationale**: Keeps each form focused and avoids conditional complexity in the InfluxDB 2 form.

## Risks / Trade-offs

- [InfluxDB 3 API may vary between Cloud Serverless, Cloud Dedicated, and OSS] → Start with the common `/api/v3/query_sql` endpoint which is consistent across all editions. Test connection validates compatibility.
- [JSON response format may differ from CSV in edge cases (nulls, special types)] → Parse JSON robustly, map to existing `QueryResult` model with string values like the CSV parser does.
- [Core Data model migration needed for new `database` attribute] → Lightweight migration handles adding a new optional attribute with no default. No data loss risk.

## Open Questions

- Should the query API path be configurable for self-hosted instances that may use a different base path?
