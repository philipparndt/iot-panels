## 1. Data Model & Backend Type

- [x] 1.1 Add `influxDB1` case to `BackendType` enum with display name "InfluxDB 1"

## 2. InfluxDB 1 Service

- [x] 2.1 Create `InfluxDB1Service.swift` implementing `DataSourceServiceProtocol`
- [x] 2.2 Implement HTTP layer — `GET /query?db=...&q=...` with optional `u`/`p` params, parse InfluxDB 1.x JSON response
- [x] 2.3 Implement `testConnection()` via `SHOW DATABASES`
- [x] 2.4 Implement `fetchDatabases()` via `SHOW DATABASES`
- [x] 2.5 Implement `fetchMeasurements()` via `SHOW MEASUREMENTS`
- [x] 2.6 Implement `fetchFieldKeys()` via `SHOW FIELD KEYS FROM <measurement>`
- [x] 2.7 Implement `fetchTagKeys()` via `SHOW TAG KEYS FROM <measurement>`
- [x] 2.8 Implement `fetchTagValues()` via `SHOW TAG VALUES FROM <measurement> WITH KEY = <tag>`

## 3. ServiceFactory & Query Building

- [x] 3.1 Add `influxDB1` case to `ServiceFactory.service(for:)` routing
- [x] 3.2 Add `buildInfluxQLQuery()` method to `SavedQuery+Wrapped.swift`
- [x] 3.3 Add `buildBandInfluxQLQuery()` for band chart aggregates
- [x] 3.4 Add `buildComparisonInfluxQLQuery()` for time-shifted comparison queries
- [x] 3.5 Update `buildQuery(for:)` and `buildQuery(for:panel:)` dispatch to route `influxDB1`
- [x] 3.6 Update `buildComparisonQuery(for:panel:)` dispatch to route `influxDB1`

## 4. UI — Setup Wizard & Configuration

- [x] 4.1 Create `InfluxDB1SetupView.swift` — connect, select database, test, done
- [x] 4.2 Add InfluxDB 1 sections to `DataSourceDetailView.swift` — setup wizard, settings link, canSave/canTest, persistFields, loadDataSource, testConnection
- [x] 4.3 Update `QueryBuilderView.swift` preview to generate InfluxQL for InfluxDB 1

## 5. Xcode Project & Localization

- [x] 5.1 Add new .swift files to Xcode project
