## 1. Data Model & Backend Type

- [x] 1.1 Add `influxDB3` case to `BackendType` enum with display name "InfluxDB 3"
- [x] 1.2 Add `database` attribute to `DataSource` Core Data entity
- [x] 1.3 Add `wrappedDatabase` property to `DataSource+Wrapped.swift`

## 2. InfluxDB 3 Service

- [x] 2.1 Create `InfluxDB3Service.swift` implementing `DataSourceServiceProtocol`
- [x] 2.2 Implement `testConnection()` — lightweight SQL query via `/api/v3/query_sql`
- [x] 2.3 Implement `query()` — POST SQL to `/api/v3/query_sql`, parse JSON response to `QueryResult`
- [x] 2.4 Implement `fetchMeasurements()` — execute `SHOW TABLES`
- [x] 2.5 Implement `fetchFieldKeys()` — execute `SHOW COLUMNS` and filter for data fields
- [x] 2.6 Implement `fetchTagKeys()` — extract tag columns from `SHOW COLUMNS` metadata
- [x] 2.7 Implement `fetchTagValues()` — execute `SELECT DISTINCT` for tag values

## 3. ServiceFactory & Query Building

- [x] 3.1 Add `influxDB3` case to `ServiceFactory.service(for:)` routing
- [x] 3.2 Add `buildSQLQuery()` method to `SavedQuery+Wrapped.swift` for basic queries
- [x] 3.3 Add `buildBandSQLQuery()` for band chart aggregates (MIN/MAX/AVG with DATE_BIN)
- [x] 3.4 Add `buildComparisonSQLQuery()` for time-shifted comparison queries
- [x] 3.5 Update `buildQuery(for:)` dispatch to route `influxDB3` to SQL generation

## 4. UI — Configuration Form

- [x] 4.1 Create `InfluxDB3SettingsFormView.swift` with URL, token, and database fields
- [x] 4.2 Add InfluxDB 3 section to `DataSourceDetailView.swift` routing to the new form
- [x] 4.3 Wire up connection test button in the settings form

## 5. UI — Query Builder

- [x] 5.1 Update `QueryBuilderView.swift` to use InfluxDB 3 schema discovery when backend is `influxDB3`
- [x] 5.2 Ensure time range and aggregation pickers work for InfluxDB 3 queries

## 6. Localization

- [x] 6.1 Add localized strings for "InfluxDB 3", "Database", and any new UI labels
