## Context

The app stores all configuration in Core Data with CloudKit sync. The entity hierarchy is: Home → (DataSources → SavedQueries, Dashboards → DashboardPanels, WidgetDesigns → WidgetDesignItems). Relationships between DashboardPanel/WidgetDesignItem and SavedQuery are cross-references by UUID.

## Goals / Non-Goals

**Goals:**
- Export all non-demo Homes and their full subtree as a single JSON file
- Import a JSON backup, recreating all entities and relationships
- Exclude cached data (cachedResultJSON, cachedComparisonJSON, cachedAt) from backup to keep file size small
- Show progress during backup/restore
- Handle duplicate UUIDs on restore (skip or replace)

**Non-Goals:**
- Incremental/differential backups
- Backing up MQTT certificates (binary files stored separately)
- Automatic scheduled backups

## Decisions

### 1. JSON structure

```json
{
  "version": 1,
  "exportedAt": "2026-04-01T12:00:00Z",
  "homes": [
    {
      "id": "...", "name": "...", "icon": "...", "sortOrder": 0,
      "dataSources": [
        {
          "id": "...", "name": "...", "backendType": "influxDB2", ...
          "savedQueries": [
            { "id": "...", "name": "...", "measurement": "...", ... }
          ]
        }
      ],
      "dashboards": [
        {
          "id": "...", "name": "...",
          "panels": [
            { "id": "...", "title": "...", "savedQueryId": "...", ... }
          ]
        }
      ],
      "widgetDesigns": [
        {
          "id": "...", "name": "...",
          "items": [
            { "id": "...", "title": "...", "savedQueryId": "...", ... }
          ]
        }
      ]
    }
  ]
}
```

DashboardPanels and WidgetDesignItems reference their SavedQuery by `savedQueryId` (UUID string). On restore, the importer looks up the SavedQuery by this ID.

### 2. Codable structs for serialization

Create lightweight `Codable` structs that mirror the Core Data entities but only include user-configured fields (no cache, no managed object references). The `BackupService` converts between Core Data objects and these structs.

### 3. Restore strategy: replace per home

When restoring, if a Home with the same UUID already exists, delete it and recreate from backup. Homes with different UUIDs are added alongside. This gives a clean per-home replacement without affecting unrelated homes.

### 4. Sensitive data warning

Tokens and passwords are included in the backup (they're needed for the connections to work). Show a warning before export that the file contains credentials.

## Risks / Trade-offs

- **[Credentials in backup]** API tokens and passwords are stored in plain text in the JSON → Show warning before export. Users should treat the backup file as sensitive.
- **[Large backups]** Many queries with large tag filters could make the file big → Excluding cached data keeps it manageable (configs only).
- **[UUID collisions]** If user imports a backup that was already imported → Replace strategy handles this cleanly.
