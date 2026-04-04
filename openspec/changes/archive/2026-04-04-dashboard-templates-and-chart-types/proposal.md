## Why

With Prometheus support now in place, users need a fast way to get started with common monitoring setups. Grafana's "Node Exporter Full" dashboard is one of the most popular templates — but recreating it query-by-query in IoT Panels is tedious. Dashboard templates let users bootstrap a fully-configured dashboard with a single tap. Additionally, two new display styles — a circular gauge and a text panel — are needed to faithfully represent the types of data shown in these templates (e.g., uptime text, CPU percentage as a radial gauge).

## What Changes

- **Dashboard template system**: A template registry that defines pre-built dashboards (name, description, required backend type, list of panels with queries and styles). Applying a template creates a Dashboard, SavedQueries, and DashboardPanels in one operation.
- **"Node Exporter" template**: A compact Prometheus dashboard template inspired by Grafana's Node Exporter Full, covering CPU, memory, disk, network, and system uptime.
- **Circular gauge display style**: A new `circularGauge` panel display style that renders a radial/ring gauge instead of the existing horizontal slider gauge.
- **Text display style**: A new `text` panel display style that renders the latest query result as formatted text (useful for uptime strings, version info, hostnames).
- **Template picker UI**: A sheet presented when creating a new dashboard that offers "Blank Dashboard" or a list of available templates, filtered by the selected data source's backend type.

## Capabilities

### New Capabilities
- `dashboard-templates`: Template registry, template data model, template application logic, and template picker UI
- `circular-gauge`: New circular/radial gauge panel display style with configurable min/max and color schemes
- `text-panel`: New text panel display style that renders the latest value as formatted text

### Modified Capabilities

## Impact

- **PanelDisplayStyle enum**: Two new cases (`.circularGauge`, `.text`)
- **PanelCardView**: New rendering branches for circular gauge and text display
- **DashboardListView**: Template picker integration when creating a new dashboard
- **New files**: `DashboardTemplate.swift` (template model + registry), `DashboardTemplatePickerView.swift` (UI), rendering code for circular gauge and text panel
- **No Core Data migration**: Templates are defined in code, not stored in the database. Applying a template creates standard Dashboard/SavedQuery/DashboardPanel entities.
- **Localization**: New strings for template names, descriptions, and UI labels
