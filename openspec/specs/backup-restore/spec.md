## ADDED Requirements

### Requirement: Export full backup as JSON
The system SHALL export all non-demo Homes with their DataSources, SavedQueries, Dashboards, DashboardPanels, WidgetDesigns, and WidgetDesignItems as a single JSON file.

#### Scenario: Export backup
- **WHEN** user taps "Backup" in the app settings
- **THEN** a JSON file containing all configuration is generated and shared via the iOS share sheet

#### Scenario: Cached data excluded
- **WHEN** a backup is exported
- **THEN** cached data (cachedResultJSON, cachedComparisonJSON, cachedAt) is NOT included in the file

#### Scenario: Demo homes excluded
- **WHEN** a backup is exported
- **THEN** homes marked as demo are NOT included

#### Scenario: Credentials warning
- **WHEN** user initiates a backup
- **THEN** a warning is shown that the file contains credentials (API tokens, passwords)

### Requirement: Import backup from JSON
The system SHALL import a backup JSON file and recreate all entities and relationships in Core Data.

#### Scenario: Restore backup
- **WHEN** user selects a backup JSON file to restore
- **THEN** all Homes, DataSources, SavedQueries, Dashboards, Panels, WidgetDesigns, and Items are created

#### Scenario: Duplicate home replacement
- **WHEN** a backup contains a Home with the same UUID as an existing Home
- **THEN** the existing Home is deleted and replaced with the backup version

#### Scenario: Cross-references resolved
- **WHEN** a DashboardPanel references a SavedQuery by UUID
- **THEN** the restore process links the panel to the correct SavedQuery object

### Requirement: Backup/restore accessible from app settings
The system SHALL provide "Backup" and "Restore" buttons in the About/Settings screen.

#### Scenario: Access backup
- **WHEN** user navigates to the About screen
- **THEN** "Backup" and "Restore" buttons are visible

### Requirement: Progress indication during backup/restore
The system SHALL show a progress indicator during backup export and restore import.

#### Scenario: Progress during restore
- **WHEN** a large backup is being restored
- **THEN** a progress overlay with spinner is shown until complete
