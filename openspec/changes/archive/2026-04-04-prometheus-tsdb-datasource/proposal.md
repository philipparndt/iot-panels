## Why

Prometheus is one of the most widely used monitoring and time-series databases in the IoT and infrastructure world. Adding Prometheus as a datasource allows IoT Panels users to visualize metrics from Prometheus-based monitoring stacks (e.g., node_exporter, smart home exporters, custom exporters) without needing to duplicate data into InfluxDB.

## What Changes

- Add `prometheus` as a new `BackendType` alongside InfluxDB 1/2/3, MQTT, and Demo
- Implement `PrometheusService` conforming to `DataSourceServiceProtocol`, querying the Prometheus HTTP API (`/api/v1/query`, `/api/v1/query_range`, `/api/v1/label/__name__/values`, `/api/v1/series`)
- Add Prometheus-specific setup UI (`PrometheusSetupView`, `PrometheusFormView`) for configuring server URL, authentication (none, basic auth, bearer token), and TLS settings
- Add a Prometheus query builder view that supports metric selection, label filtering, and PromQL editing
- Extend the Core Data `DataSource` entity to store Prometheus-specific connection settings (reusing existing `url`, `username`, `password`, `token` fields)
- Map Prometheus query results (matrix/vector/scalar) to the existing `QueryResult` format used by dashboards and widgets
- Support Prometheus in the widget data loader for Home Screen and watchOS widgets

## Capabilities

### New Capabilities
- `prometheus-connection`: Configuration and connection management for Prometheus datasources (server URL, authentication, TLS, connection testing)
- `prometheus-query`: Query building and execution against Prometheus HTTP API, including metric discovery, label-based filtering, and raw PromQL support

### Modified Capabilities

## Impact

- **Core Data model**: No schema migration needed — reuses existing `DataSource` attributes (`url`, `token`, `username`, `password`, `ssl`, `untrustedSSL`)
- **BackendType enum**: New `.prometheus` case added
- **ServiceFactory**: New case routing to `PrometheusService`
- **DataSourceListView / DataSourceDetailView**: Must include Prometheus in the datasource type picker
- **QueryBuilderView**: Must route to Prometheus-specific query builder when datasource is Prometheus
- **Widget extensions**: `WidgetDataLoader` already works through `ServiceFactory`, so Prometheus support flows through automatically
- **Dependencies**: No new external dependencies — Prometheus HTTP API is a simple REST API queryable via `URLSession`
- **Localization**: New strings for Prometheus UI labels, error messages, and setup guidance
