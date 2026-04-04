## 1. Backend Type & Service Factory

- [x] 1.1 Add `.prometheus` case to `BackendType` enum with display name "Prometheus" in `Model/BackendType.swift`
- [x] 1.2 Add `.prometheus` case to `ServiceFactory` in `Services/DataSourceService.swift` routing to `PrometheusService`

## 2. Prometheus Service Implementation

- [x] 2.1 Create `Services/PrometheusService.swift` with struct conforming to `DataSourceServiceProtocol`, initializer accepting `DataSource`, and HTTP helper methods for Prometheus API calls (GET with URL-encoded params, auth headers, TLS config)
- [x] 2.2 Implement `testConnection()` — query `/api/v1/query?query=up` and verify successful response
- [x] 2.3 Implement Prometheus JSON response parsing — handle matrix, vector, and scalar result types, map to `QueryResult` with time/value/label columns
- [x] 2.4 Implement `query(_:)` — execute PromQL via `/api/v1/query_range` with default time range, parse and return as `QueryResult`
- [x] 2.5 Implement `fetchMeasurements()` — call `/api/v1/label/__name__/values` to return metric names
- [x] 2.6 Implement `fetchFieldKeys(measurement:)` — return `["value"]`
- [x] 2.7 Implement `fetchTagKeys(measurement:)` — call `/api/v1/labels?match[]=<metric>` and return label names excluding `__name__`
- [x] 2.8 Implement `fetchTagValues(measurement:tag:)` — call `/api/v1/label/<tag>/values?match[]=<metric>` and return values
- [x] 2.9 Implement time range to step auto-calculation (1h→15s, 24h→1m, 7d→5m, etc.)

## 3. Authentication Support

- [x] 3.1 Add `PrometheusAuthMethod` enum (none, basicAuth, bearerToken) to `Model/BackendType.swift` or a new `PrometheusModels.swift`
- [x] 3.2 Implement auth header injection in `PrometheusService` HTTP helpers — Basic auth (base64 username:password) and Bearer token

## 4. Setup Wizard UI

- [x] 4.1 Create `Views/DataSource/PrometheusSetupView.swift` with step-based wizard (Connect → Finish), following the `InfluxDB3SetupView` pattern
- [x] 4.2 Create `Views/DataSource/PrometheusFormView.swift` with server URL field, auth method picker, credential fields (username/password or token), and TLS toggles
- [x] 4.3 Implement connection test button in setup wizard that calls `PrometheusService.testConnection()` and shows success/error state
- [x] 4.4 Wire up PrometheusSetupView in `DataSourceListView` / `DataSourceDetailView` — add Prometheus to the add datasource sheet and show Prometheus form for existing Prometheus datasources

## 5. Query Builder UI

- [x] 5.1 Create `Views/QueryBuilder/PrometheusQueryBuilderView.swift` with metric picker (searchable list), label filter builder, and aggregate function selector
- [x] 5.2 Implement PromQL generation from guided selections (metric + label filters + aggregation)
- [x] 5.3 Add raw PromQL editor mode with toggle, pre-filling from guided builder when switching
- [x] 5.4 Wire up Prometheus query builder in `QueryBuilderView` — route to `PrometheusQueryBuilderView` when datasource is Prometheus

## 6. Integration & Polish

- [x] 6.1 Add localized strings for all Prometheus UI labels, error messages, and setup guidance in `Localizable.xcstrings`
- [x] 6.2 Update `DataSourceListView` empty state text to mention Prometheus alongside InfluxDB and MQTT
- [x] 6.3 Verify dashboard panels render Prometheus data correctly (charts, gauges, single values) via the existing `PanelCardView`
- [x] 6.4 Verify widget data loading works for Prometheus datasources through `WidgetDataLoader` → `ServiceFactory` path
- [x] 6.5 Add Prometheus to demo data generation in `DemoService` if applicable, or ensure demo mode is unaffected

## 7. Testing

- [x] 7.1 Add unit tests for `PrometheusService` response parsing (matrix, vector, scalar JSON → QueryResult)
- [x] 7.2 Add unit tests for PromQL generation from guided builder selections
- [x] 7.3 Add unit tests for time range → step calculation
- [x] 7.4 Test setup wizard flow end-to-end with a real or mocked Prometheus instance
