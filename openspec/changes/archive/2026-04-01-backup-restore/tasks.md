## 1. Backup Data Model (Codable structs)

- [x] 1.1 Create `BackupData` root struct with `version: Int`, `exportedAt: String`, `homes: [BackupHome]`
- [x] 1.2 Create `BackupHome` struct with all Home attributes + nested `dataSources`, `dashboards`, `widgetDesigns`
- [x] 1.3 Create `BackupDataSource` struct with all DataSource attributes (excluding isDemo) + nested `savedQueries`
- [x] 1.4 Create `BackupSavedQuery` struct with all SavedQuery attributes (excluding cached fields)
- [x] 1.5 Create `BackupDashboard` struct with attributes + nested `panels`
- [x] 1.6 Create `BackupDashboardPanel` struct with attributes + `savedQueryId` UUID reference (excluding cached fields)
- [x] 1.7 Create `BackupWidgetDesign` struct with attributes + nested `items`
- [x] 1.8 Create `BackupWidgetDesignItem` struct with attributes + `savedQueryId` UUID reference (excluding cached fields)

## 2. BackupService — Export

- [x] 2.1 Create `BackupService.export(context:) -> BackupData` that reads all non-demo Homes and converts to Codable structs
- [x] 2.2 Create `BackupService.exportToFile(context:) -> URL?` that serializes to pretty-printed JSON and writes to temp file

## 3. BackupService — Import

- [x] 3.1 Create `BackupService.restore(from data: BackupData, context:)` that creates all entities from the backup
- [x] 3.2 Handle Home UUID collision — delete existing Home with same UUID before importing
- [x] 3.3 Resolve SavedQuery cross-references — build a UUID→SavedQuery map, link panels and widget items
- [x] 3.4 Create `BackupService.restoreFromFile(url:context:)` that reads JSON, parses, and calls restore

## 4. UI Integration

- [x] 4.1 Add "Backup" and "Restore" buttons to AboutView
- [x] 4.2 Show credentials warning alert before backup export
- [x] 4.3 Present share sheet after backup export
- [x] 4.4 Present document picker for restore (accept .json files)
- [x] 4.5 Show progress overlay during backup and restore
- [x] 4.6 Show success/error alert after restore completes

## 5. Translations

- [x] 5.1 Add translations for backup/restore UI strings across all 8 languages

## 6. Testing

- [ ] 6.1 Verify backup contains all homes, data sources, queries, dashboards, panels, widgets, items
- [ ] 6.2 Verify restore recreates all entities with correct relationships
- [ ] 6.3 Verify duplicate home is replaced on restore
- [ ] 6.4 Verify cached data is excluded from backup
- [ ] 6.5 Verify demo homes are excluded from backup
