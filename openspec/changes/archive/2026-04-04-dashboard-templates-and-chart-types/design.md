## Context

IoT Panels already has a programmatic dashboard creation pattern in `DemoSetup.swift` — it creates `Dashboard`, `SavedQuery`, and `DashboardPanel` Core Data objects with helper functions. The gauge rendering in `PanelCardView.swift` uses a horizontal slider bar with animated dots. There are currently 10 display styles in `PanelDisplayStyle`. StyleConfig stores gauge min/max, color schemes, and thresholds as JSON.

## Goals / Non-Goals

**Goals:**
- Define a reusable template data model that describes a complete dashboard (panels, queries, styles)
- Ship a "Node Exporter Lite" template for Prometheus that covers CPU, memory, disk, network, and uptime
- Add a circular gauge display style using SwiftUI's native `Gauge` view with `.accessoryCircularCapacity` style
- Add a text display style that renders the latest query value as a prominent text label
- Provide a template picker UI when creating a new dashboard

**Non-Goals:**
- User-created or editable templates (templates are code-defined for now)
- Importing Grafana JSON dashboards directly
- Full parity with Grafana's "Node Exporter Full" (which has 30+ panels) — we aim for a compact, useful subset
- Template marketplace or remote template fetching

## Decisions

### 1. Templates as Swift structs — no Core Data storage

Templates are defined as `DashboardTemplate` structs with nested `PanelTemplate` and `QueryTemplate` structs. They live in a `DashboardTemplateRegistry` enum that returns the available templates. Applying a template creates standard Core Data entities.

**Why over Core Data entities**: Templates are static, versioned with the app, and don't need sync. Keeping them as code avoids migration complexity and makes it easy to add/update templates in future releases.

### 2. Template model references backend type for filtering

Each template declares a `backendType: BackendType` so the picker can filter templates to those compatible with the selected data source. The Node Exporter template requires `.prometheus`.

**Why**: Prevents users from applying a Prometheus template to an InfluxDB data source where the PromQL queries would fail.

### 3. Circular gauge using SwiftUI Gauge view

The circular gauge will use SwiftUI's native `Gauge` view with a custom circular style, rendering a ring that fills based on the current value. It reuses `StyleConfig` for min/max and color scheme, just like the existing slider gauge.

**Why over a custom `Path`-based implementation**: SwiftUI's `Gauge` handles accessibility, animation, and layout automatically. It's consistent with Apple's design language and requires minimal code.

### 4. Text panel renders latest value with optional unit

The text display style extracts the most recent value from the query result and displays it as a large, centered text label. If a unit is configured, it's appended. This is ideal for string-like values (uptime, hostname, version) or simple numeric displays without chart context.

**Why as a separate style vs. extending singleValue**: `singleValue` already has specific formatting (numeric with trend arrows). Text needs different treatment — no trend, no sparkline, potentially multi-line, and may display non-numeric strings.

### 5. Node Exporter Lite template contents

A compact template with 8 panels covering the most useful node_exporter metrics:

| Panel | PromQL | Style |
|-------|--------|-------|
| Uptime | `time() - node_boot_time_seconds` | text |
| CPU Usage | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | circularGauge (0–100%) |
| Memory Usage | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | circularGauge (0–100%) |
| Disk Usage | `(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100` | circularGauge (0–100%) |
| CPU Over Time | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | chart |
| Memory Over Time | `node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes` | chart |
| Network Traffic | `rate(node_network_receive_bytes_total{device!="lo"}[5m])` + `rate(node_network_transmit_bytes_total{device!="lo"}[5m])` | chart |
| Disk I/O | `rate(node_disk_read_bytes_total[5m])` + `rate(node_disk_written_bytes_total[5m])` | chart |

### 6. Template picker integrated into dashboard creation flow

When the user taps "Add Dashboard", a sheet presents:
1. "Blank Dashboard" (existing behavior)
2. A list of templates grouped by backend type, filtered to compatible templates for the user's data sources

Selecting a template creates the dashboard with all panels and queries, then navigates to it.

## Risks / Trade-offs

- **PromQL queries may not match all node_exporter versions** → The template uses standard metric names from node_exporter 1.x. If metrics are missing, individual panels will show errors but the dashboard still works. Users can edit or delete individual panels.

- **Circular gauge may not look great at very small sizes** → SwiftUI's Gauge adapts to size, but at very compact panel sizes the ring may be hard to read. Mitigation: use the same size constraints as the existing gauge.

- **Template queries use raw PromQL** → The `isRawQuery` flag is set to true, so queries bypass the guided builder. This is intentional — the PromQL expressions use functions like `rate()` that can't be expressed in the guided builder. Users can still edit via the raw query editor.
