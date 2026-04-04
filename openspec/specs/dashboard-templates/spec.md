## ADDED Requirements

### Requirement: Dashboard template data model
The system SHALL define a `DashboardTemplate` struct containing:
- `id`: Unique string identifier
- `name`: Display name
- `description`: Short description of what the template provides
- `icon`: SF Symbol name
- `backendType`: Required `BackendType`
- `panels`: Array of `PanelTemplate` (each with title, display style, style config, sort order, and a `QueryTemplate`)

A `QueryTemplate` SHALL contain: name, raw PromQL expression, time range, aggregate window, and unit.

#### Scenario: Template defines a complete dashboard
- **WHEN** a `DashboardTemplate` is instantiated
- **THEN** it SHALL contain all information needed to create a Dashboard, DashboardPanels, and SavedQueries

### Requirement: Dashboard template registry
The system SHALL provide a `DashboardTemplateRegistry` that returns all available templates. Templates SHALL be filterable by `BackendType`.

#### Scenario: Retrieve templates for Prometheus
- **WHEN** the registry is queried with `backendType: .prometheus`
- **THEN** it SHALL return only templates that require the Prometheus backend

#### Scenario: Retrieve all templates
- **WHEN** the registry is queried without a filter
- **THEN** it SHALL return all available templates

### Requirement: Node Exporter Lite template
The system SHALL include a built-in "Node Exporter Lite" template for Prometheus that creates a dashboard with panels for:
- System uptime (text style)
- CPU usage percentage (circular gauge, 0–100%)
- Memory usage percentage (circular gauge, 0–100%)
- Disk usage percentage (circular gauge, 0–100%)
- CPU usage over time (line chart)
- Memory usage over time (line chart)
- Network traffic (line chart)
- Disk I/O (line chart)

All queries SHALL use raw PromQL expressions targeting standard node_exporter metric names.

#### Scenario: Apply Node Exporter Lite template
- **WHEN** user selects the Node Exporter Lite template for a Prometheus datasource
- **THEN** the system SHALL create a dashboard named "Node Exporter" with 8 panels and corresponding saved queries

#### Scenario: Template queries use raw PromQL
- **WHEN** the template is applied
- **THEN** all created SavedQuery objects SHALL have `isRawQuery` set to true with the PromQL expression in `rawQuery`

### Requirement: Template application
The system SHALL apply a template by creating Core Data entities:
1. A `Dashboard` linked to the current home
2. A `SavedQuery` for each panel's query, linked to the selected `DataSource`
3. A `DashboardPanel` for each panel, linked to the dashboard and its query

#### Scenario: Apply template creates all entities
- **WHEN** a template with N panels is applied to a data source
- **THEN** the system SHALL create 1 Dashboard, N SavedQueries, and N DashboardPanels

#### Scenario: Applied dashboard is immediately usable
- **WHEN** a template is applied
- **THEN** the created dashboard SHALL appear in the dashboard list and all panels SHALL load data from the selected datasource

### Requirement: Template picker UI
The system SHALL present a template picker when the user creates a new dashboard. The picker SHALL show:
- A "Blank Dashboard" option (existing behavior)
- A list of available templates filtered by the user's configured data source backend types
- Each template with its name, description, icon, and panel count

#### Scenario: Show template picker
- **WHEN** user taps "Add Dashboard"
- **THEN** the system SHALL show a picker with "Blank Dashboard" and compatible templates

#### Scenario: Filter by available backends
- **WHEN** user has only InfluxDB data sources configured (no Prometheus)
- **THEN** the Prometheus-only templates SHALL NOT appear in the picker

#### Scenario: Select blank dashboard
- **WHEN** user selects "Blank Dashboard"
- **THEN** the system SHALL create an empty dashboard (existing behavior)

#### Scenario: Select template
- **WHEN** user selects a template and chooses a data source
- **THEN** the system SHALL apply the template and navigate to the new dashboard
