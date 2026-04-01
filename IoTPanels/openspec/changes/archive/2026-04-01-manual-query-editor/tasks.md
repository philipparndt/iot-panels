## 1. Data Model

- [x] 1.1 Add `rawQuery` (String, optional) and `isRawQuery` (Boolean) attributes to `SavedQuery` Core Data entity
- [x] 1.2 Add `wrappedRawQuery` and `wrappedIsRawQuery` properties to `SavedQuery+Wrapped.swift`

## 2. Query Dispatch

- [x] 2.1 Update `buildQuery(for:)` to return `rawQuery` when `isRawQuery` is true
- [x] 2.2 Update `buildQuery(for:panel:)` to return `rawQuery` when `isRawQuery` is true
- [x] 2.3 Update `buildComparisonQuery(for:panel:)` to return nil for raw queries (comparison not supported)

## 3. Manual Query Editor View

- [x] 3.1 Create `ManualQueryEditorView.swift` with name field, TextEditor (monospace), unit picker, save/cancel toolbar
- [x] 3.2 Add Flux syntax reference section (common patterns, functions, examples)
- [x] 3.3 Add SQL syntax reference section for InfluxDB 3
- [x] 3.4 Add InfluxQL syntax reference section for InfluxDB 1
- [x] 3.5 Show the appropriate reference based on datasource backend type
- [x] 3.6 Add preview button that executes the query and shows results

## 4. Entry Point

- [x] 4.1 Update query creation flow to offer "Query Builder" vs "Manual Query" choice for InfluxDB datasources
- [x] 4.2 When editing an existing raw query, open ManualQueryEditorView instead of QueryBuilderView

## 5. Xcode Project

- [x] 5.1 Add new .swift files to Xcode project
