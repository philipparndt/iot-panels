## Why

Users have no way to back up their configuration or transfer it between devices (outside of iCloud sync). If something goes wrong — accidental deletion, new device setup, or wanting to share a configuration — all dashboards, data sources, queries, and widgets must be recreated from scratch. A JSON backup/restore feature enables full portability.

## What Changes

- Add full backup export: serialize all Homes with their DataSources, SavedQueries, Dashboards, DashboardPanels, WidgetDesigns, and WidgetDesignItems to a single JSON file
- Add restore import: parse a backup JSON file and recreate all entities in Core Data, resolving relationships by UUID
- Expose backup/restore in the About or Settings screen
- Exclude cached data and demo homes from the backup
- On restore, optionally merge with or replace existing data
- Use iOS share sheet for export and document picker for import

## Capabilities

### New Capabilities
- `backup-restore`: Full JSON backup and restore of all app configuration

### Modified Capabilities

## Impact

- **New**: `BackupService` that serializes/deserializes the full Core Data graph to/from JSON
- **AboutView or Settings**: Add "Backup" and "Restore" buttons
- **Core Data**: Read-only for backup, insert for restore — no schema changes
- **Dependencies**: None
