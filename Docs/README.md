# IoT Panels

A native iOS app for visualizing IoT sensor data. Build customizable dashboards and home screen widgets to monitor your smart home in real time — powered by InfluxDB and MQTT.

Built with SwiftUI, Core Data, and CloudKit.

## Screenshots

### iOS
<p float="left">
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-1.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-2.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-3.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-4.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-5.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-6.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-7.png" width="80"/>
<img src="https://github.com/philipparndt/iot-panels/raw/main/Docs/screenshot-8.png" width="80"/>
</p>

## Features

### Dashboards
- Create multiple dashboards to organize your sensor data
- Real-time data updates from connected backends
- Interactive chart explorer for detailed data analysis
- Comparison overlays (e.g. today vs. yesterday)
- Data export to CSV and JSON

### Chart Types
- **Line charts** — time series visualization
- **Bar charts** — categorical data
- **Band charts** — range visualization (min/max bands)
- **Gauge charts** — with configurable color schemes (green-to-red, blue-to-red)
- **Single value** — current reading at a glance

### Home Screen Widgets
- Design custom widgets with the built-in widget editor
- Medium and large widget sizes
- Group multiple values into a single widget
- Adaptive background colors with dark/light mode support
- Threshold-based color indicators for quick status checks
- Visual stale-data indicator when data becomes outdated

### Data Sources

IoT Panels supports multiple backends:

| Backend | Protocol | Query Language |
|---------|----------|---------------|
| **InfluxDB 1.x** | HTTP API | InfluxQL |
| **InfluxDB 2.x** | HTTP API | Flux |
| **InfluxDB 3.x** | HTTP API | SQL |
| **MQTT** | Native / WebSocket | Topic subscription |

### Query Builder
- GUI-based query builder for InfluxDB (measurements, fields, tags, time ranges)
- Raw query editor for Flux and SQL
- MQTT topic discovery with live schema browser
- Saved queries for reuse across dashboards and widgets

### MQTT
- MQTT 3.1.1 and 5.0 protocol support
- Native TCP and WebSocket transports
- Authentication: none, username/password, client certificates, or both
- TLS/SSL with support for self-signed certificates
- Custom ALPN protocol negotiation
- Broker configuration import/export (`.mqttbroker` files)
- Persistent connection pooling for efficiency

### Multi-Home Support
Organize data sources, dashboards, and widgets across multiple homes or environments.

### CloudKit Sync
All data is synced via iCloud, keeping dashboards and configurations in sync across your devices.

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 6

## Building

Clone the repository and open the Xcode project:

```bash
git clone https://github.com/your-org/iot-panels.git
cd iot-panels
```

### Using Xcode

Open `IoTPanels/IoTPanels.xcodeproj` in Xcode, select a simulator or device, and build.

### Using the command line

```bash
# Build
make build

# Run tests
make test

# Clean
make clean
```

### Additional Make targets

```bash
make icon                # Generate app icon from icon/ exports
make check-translations  # Check for missing localizations
make screenshots         # Generate App Store screenshots (dark + light)
make bump-major          # Bump major version (X.0.0)
make bump-minor          # Bump minor version (x.X.0)
make bump-patch          # Bump patch version (x.x.X)
```

## Project Structure

```
IoTPanels/
├── IoTPanels/                  # Main iOS app
│   ├── IoTPanelsApp.swift      # App entry point
│   ├── Persistence.swift       # Core Data + CloudKit setup
│   ├── Model/                  # Data models and Core Data wrappers
│   ├── Services/               # Backend services (InfluxDB, MQTT, Demo)
│   ├── Views/                  # SwiftUI views
│   │   ├── Dashboard/          # Dashboard and panel views
│   │   ├── DataSource/         # Backend configuration
│   │   ├── QueryBuilder/       # Query building and topic discovery
│   │   └── WidgetDesigner/     # Widget editor and preview
│   └── Assets.xcassets/        # Images, icons, colors
├── IoTPanelsWidget/            # Home screen widget extension
├── IoTPanelsTests/             # Unit tests
├── IoTPanelsUITests/           # UI and screenshot tests
└── fastlane/                   # Screenshot automation
```

## Architecture

- **SwiftUI** for all UI with modern async/await concurrency
- **Core Data + CloudKit** for persistence and cross-device sync
- **WidgetKit** for home screen widgets with timeline-based refresh
- **Protocol-based service layer** — all backends conform to `DataSourceServiceProtocol`, making it straightforward to add new data sources
- **App Groups** for sharing data between the main app and widget extension

## Dependencies

| Package | Purpose |
|---------|---------|
| [CocoaMQTT](https://github.com/emqx/CocoaMQTT) | MQTT client library |
| [CocoaMQTTWebSocket](https://github.com/nicklama/CocoaMQTTWebSocket) | WebSocket transport for MQTT |

## Screenshots Automation

App Store screenshots are generated automatically using [fastlane snapshot](https://docs.fastlane.tools/actions/snapshot/):

```bash
make screenshots
```

This captures screenshots across multiple devices (iPhone and iPad) in both dark and light mode. The generated images are saved to the `screenshots/` directory.
