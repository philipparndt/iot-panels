import XCTest
@testable import IoTPanels

final class DashboardTemplateTests: XCTestCase {

    // MARK: - Registry Filtering

    func testRegistryReturnsAllTemplates() {
        let all = DashboardTemplateRegistry.templates()
        XCTAssertFalse(all.isEmpty)
    }

    func testRegistryFiltersPrometheus() {
        let prometheusTemplates = DashboardTemplateRegistry.templates(for: .prometheus)
        XCTAssertFalse(prometheusTemplates.isEmpty)
        for template in prometheusTemplates {
            XCTAssertEqual(template.backendType, .prometheus)
        }
    }

    func testRegistryFiltersInfluxDB1() {
        let influxTemplates = DashboardTemplateRegistry.templates(for: .influxDB1)
        XCTAssertTrue(influxTemplates.isEmpty, "No InfluxDB 1 templates should exist yet")
    }

    func testRegistryFiltersMQTT() {
        let mqttTemplates = DashboardTemplateRegistry.templates(for: .mqtt)
        XCTAssertTrue(mqttTemplates.isEmpty, "No MQTT templates should exist yet")
    }

    // MARK: - Node Exporter Template

    func testNodeExporterLiteTemplate() {
        let template = DashboardTemplateRegistry.nodeExporterLite
        XCTAssertEqual(template.id, "node-exporter-lite")
        XCTAssertEqual(template.backendType, .prometheus)
        XCTAssertEqual(template.panels.count, 8)
    }

    func testNodeExporterPanelStyles() {
        let template = DashboardTemplateRegistry.nodeExporterLite
        let styles = template.panels.map(\.displayStyle)

        XCTAssertEqual(styles[0], .text, "Uptime should be text")
        XCTAssertEqual(styles[1], .circularGauge, "CPU should be circular gauge")
        XCTAssertEqual(styles[2], .circularGauge, "Memory should be circular gauge")
        XCTAssertEqual(styles[3], .circularGauge, "Disk should be circular gauge")
        XCTAssertEqual(styles[4], .chart, "CPU over time should be chart")
    }

    func testNodeExporterGaugesHaveStyleConfig() {
        let template = DashboardTemplateRegistry.nodeExporterLite
        let gaugePanels = template.panels.filter { $0.displayStyle == .circularGauge }

        for panel in gaugePanels {
            XCTAssertNotNil(panel.styleConfig, "\(panel.title) should have style config")
            XCTAssertEqual(panel.styleConfig?.gaugeMin, 0)
            XCTAssertEqual(panel.styleConfig?.gaugeMax, 100)
        }
    }

    func testNodeExporterQueriesAreRawPromQL() {
        let template = DashboardTemplateRegistry.nodeExporterLite
        for panel in template.panels {
            XCTAssertFalse(panel.query.rawQuery.isEmpty, "\(panel.title) should have a raw query")
        }
    }
}
