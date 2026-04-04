import XCTest
@testable import IoTPanels

final class PrometheusServiceTests: XCTestCase {

    // MARK: - Result Parsing

    func testParseMatrixResult() async throws {
        let service = PrometheusService(url: "http://localhost:9090")
        let json: [String: Any] = [
            "status": "success",
            "data": [
                "resultType": "matrix",
                "result": [
                    [
                        "metric": ["__name__": "temperature", "location": "kitchen"],
                        "values": [
                            [1704067200.0, "21.5"],
                            [1704067215.0, "21.6"]
                        ]
                    ],
                    [
                        "metric": ["__name__": "temperature", "location": "bedroom"],
                        "values": [
                            [1704067200.0, "19.2"],
                            [1704067215.0, "19.3"]
                        ]
                    ]
                ] as [[String: Any]]
            ] as [String: Any]
        ]

        let data = json["data"] as! [String: Any]
        let result = service.parseMatrixResult(data)

        XCTAssertEqual(result.columns.count, 3) // time, value, location
        XCTAssertEqual(result.columns.map(\.name), ["time", "value", "location"])
        XCTAssertEqual(result.rows.count, 4) // 2 series * 2 points

        // First series, first point
        XCTAssertEqual(result.rows[0].values["value"], "21.5")
        XCTAssertEqual(result.rows[0].values["location"], "kitchen")

        // Second series, first point
        XCTAssertEqual(result.rows[2].values["value"], "19.2")
        XCTAssertEqual(result.rows[2].values["location"], "bedroom")
    }

    func testParseVectorResult() async throws {
        let service = PrometheusService(url: "http://localhost:9090")
        let data: [String: Any] = [
            "resultType": "vector",
            "result": [
                [
                    "metric": ["__name__": "up", "job": "api"],
                    "value": [1704067200.0, "1"]
                ]
            ] as [[String: Any]]
        ]

        let result = service.parseVectorResult(data)

        XCTAssertEqual(result.columns.count, 3) // time, value, job
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0].values["value"], "1")
        XCTAssertEqual(result.rows[0].values["job"], "api")
    }

    func testParseScalarResult() async throws {
        let service = PrometheusService(url: "http://localhost:9090")
        let data: [String: Any] = [
            "resultType": "scalar",
            "result": [1704067200.0, "42"] as [Any]
        ]

        let result = service.parseScalarResult(data)

        XCTAssertEqual(result.columns.count, 2)
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0].values["value"], "42")
    }

    // MARK: - PromQL Builder

    func testBuildSimpleMetric() {
        let result = PromQLBuilder.build(metric: "temperature", labelFilters: [:], aggregateFunction: nil)
        XCTAssertEqual(result, "temperature")
    }

    func testBuildWithSingleLabelFilter() {
        let result = PromQLBuilder.build(
            metric: "temperature",
            labelFilters: ["location": Set(["kitchen"])],
            aggregateFunction: nil
        )
        XCTAssertEqual(result, "temperature{location=\"kitchen\"}")
    }

    func testBuildWithMultipleLabelValues() {
        let result = PromQLBuilder.build(
            metric: "temperature",
            labelFilters: ["location": Set(["kitchen", "bedroom"])],
            aggregateFunction: nil
        )
        // Multiple values use regex match
        XCTAssertTrue(result.contains("location=~"))
        XCTAssertTrue(result.contains("bedroom"))
        XCTAssertTrue(result.contains("kitchen"))
    }

    func testBuildWithAggregateFunction() {
        let result = PromQLBuilder.build(
            metric: "temperature",
            labelFilters: [:],
            aggregateFunction: "avg"
        )
        XCTAssertEqual(result, "avg(temperature)")
    }

    func testBuildWithFiltersAndAggregation() {
        let result = PromQLBuilder.build(
            metric: "cpu_usage",
            labelFilters: ["host": Set(["server1"])],
            aggregateFunction: "sum"
        )
        XCTAssertEqual(result, "sum(cpu_usage{host=\"server1\"})")
    }

    func testBuildIgnoresEmptyFilters() {
        let result = PromQLBuilder.build(
            metric: "temperature",
            labelFilters: ["location": Set<String>()],
            aggregateFunction: nil
        )
        XCTAssertEqual(result, "temperature")
    }

    // MARK: - Step Calculation

    func testStepForShortRange() {
        let service = PrometheusService(url: "http://localhost:9090")
        XCTAssertEqual(service.stepForRange(seconds: 3600), "15s")    // 1h
        XCTAssertEqual(service.stepForRange(seconds: 7200), "15s")    // 2h
    }

    func testStepForMediumRange() {
        let service = PrometheusService(url: "http://localhost:9090")
        XCTAssertEqual(service.stepForRange(seconds: 86400), "5m")    // 24h
    }

    func testStepForLongRange() {
        let service = PrometheusService(url: "http://localhost:9090")
        XCTAssertEqual(service.stepForRange(seconds: 604800), "15m")  // 7d
        XCTAssertEqual(service.stepForRange(seconds: 2592000), "1h")  // 30d
    }

    func testStepForVeryLongRange() {
        let service = PrometheusService(url: "http://localhost:9090")
        XCTAssertEqual(service.stepForRange(seconds: 31536000), "6h") // 1 year
    }
}
