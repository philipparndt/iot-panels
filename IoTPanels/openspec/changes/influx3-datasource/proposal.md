## Why

InfluxDB 3 (Cloud Dedicated, Cloud Serverless, and OSS) replaces Flux with SQL as the query language and uses a different API surface. Users running InfluxDB 3 cannot use the existing InfluxDB 2 datasource. Adding native InfluxDB 3 support lets IoT Panels connect to the latest InfluxDB platform.

## What Changes

- **New backend type `influxDB3`** in `BackendType` enum with display name "InfluxDB 3"
- **New `InfluxDB3Service`** implementing `DataSourceServiceProtocol` using InfluxDB 3's HTTP query API (`/api/v3/query_sql`) with SQL queries
- **New Core Data attributes** on `DataSource` for InfluxDB 3 configuration: `database` (replaces bucket/org concepts)
- **New SQL query builder** that generates SQL instead of Flux for InfluxDB 3 datasources
- **Query builder UI adaptation** for InfluxDB 3 — SQL-based schema discovery using `SHOW TABLES` / `SHOW COLUMNS`
- **`ServiceFactory` update** to route `influxDB3` to the new service
- **`SavedQuery+Wrapped` update** to build SQL queries for InfluxDB 3

## Capabilities

### New Capabilities
- `influx3-connection`: InfluxDB 3 connection configuration, authentication, and connection testing
- `influx3-query`: SQL query building, execution, and result parsing for InfluxDB 3
- `influx3-schema-discovery`: Schema discovery (tables, columns) for the query builder UI

### Modified Capabilities

## Impact

- `BackendType.swift`: Add new case
- `DataSource` Core Data model: Add `database` attribute for InfluxDB 3
- `DataSource+Wrapped.swift`: Add wrapped property for database
- `ServiceFactory` / `DataSourceService.swift`: Add routing for new backend type
- New `InfluxDB3Service.swift`: Service implementation
- `SavedQuery+Wrapped.swift`: Add SQL query building methods
- `QueryBuilderView.swift`: Adapt for InfluxDB 3 schema discovery
- `DataSourceDetailView.swift`: Add InfluxDB 3 configuration form
