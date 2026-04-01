## Why

InfluxDB 1.x remains widely used in home automation and IoT setups. Many users run InfluxDB 1.8 alongside tools like Telegraf, Home Assistant, or Grafana. Adding InfluxDB 1.x support allows IoT Panels to connect to these existing installations without requiring users to migrate to InfluxDB 2 or 3.

## What Changes

- **New backend type `influxDB1`** in `BackendType` enum with display name "InfluxDB 1"
- **New `InfluxDB1Service`** implementing `DataSourceServiceProtocol` using the InfluxDB 1.x HTTP API (`/query` endpoint with InfluxQL)
- **Optional basic auth** — InfluxDB 1.x supports no auth, username/password via query params, or basic auth
- **InfluxQL query builder** generating InfluxQL instead of Flux/SQL (`SELECT ... FROM ... WHERE time > now() - ...`)
- **Schema discovery** using InfluxQL: `SHOW DATABASES`, `SHOW MEASUREMENTS`, `SHOW FIELD KEYS`, `SHOW TAG KEYS`, `SHOW TAG VALUES`
- **Setup wizard** for InfluxDB 1 — connect, select database, done
- **`ServiceFactory` update** to route `influxDB1` to the new service
- **`SavedQuery+Wrapped` update** to build InfluxQL queries

## Capabilities

### New Capabilities
- `influx1-connection`: InfluxDB 1.x connection configuration, optional auth, and connection testing
- `influx1-query`: InfluxQL query building, execution, and result parsing
- `influx1-schema-discovery`: Schema discovery via InfluxQL SHOW commands

### Modified Capabilities

## Impact

- `BackendType.swift`: Add new case
- `DataSource` Core Data model: Reuse existing `url`, `username`, `password`, `database` attributes
- `ServiceFactory` / `DataSourceService.swift`: Add routing
- New `InfluxDB1Service.swift`: Service implementation
- `SavedQuery+Wrapped.swift`: Add InfluxQL query building methods
- `DataSourceDetailView.swift`: Add InfluxDB 1 configuration and setup wizard
- New `InfluxDB1SetupView.swift`: Setup wizard
