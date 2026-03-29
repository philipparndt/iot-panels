import Foundation

/// Generates realistic demo IoT data for offline use / demonstration.
struct DemoService: DataSourceServiceProtocol {

    func testConnection() async throws -> Bool {
        true
    }

    func query(_ queryString: String) async throws -> QueryResult {
        // Parse the query to determine what data to generate
        let measurement = extractValue(from: queryString, key: "_measurement")
        let fields = extractFields(from: queryString)
        let rangeMinutes = extractRange(from: queryString)
        let windowMinutes = extractWindow(from: queryString)

        let effectiveFields = fields.isEmpty ? demoFields(for: measurement) : fields
        let interval = windowMinutes > 0 ? windowMinutes * 60.0 : 300.0
        let count = max(1, Int(rangeMinutes * 60.0 / interval))

        var rows: [QueryResult.Row] = []
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for field in effectiveFields {
            let generator = dataGenerator(measurement: measurement, field: field)
            for i in 0..<count {
                let time = now.addingTimeInterval(-Double(count - i) * interval)
                let value = generator(Double(i) / Double(max(count - 1, 1)), time)
                rows.append(QueryResult.Row(values: [
                    "_time": formatter.string(from: time),
                    "_measurement": measurement,
                    "_field": field,
                    "_value": String(format: "%.2f", value),
                    "result": "_result",
                    "table": "0"
                ]))
            }
        }

        let columns = ["", "result", "table", "_time", "_measurement", "_field", "_value"]
            .map { QueryResult.Column(name: $0, type: "string") }

        return QueryResult(columns: columns, rows: rows)
    }

    // MARK: - Schema Discovery

    func fetchMeasurements() async throws -> [String] {
        ["temperature", "humidity", "energy", "solar", "battery", "air_quality", "appliance", "motion", "water", "weather"]
    }

    func fetchFieldKeys(measurement: String) async throws -> [String] {
        demoFields(for: measurement)
    }

    func fetchTagKeys(measurement: String) async throws -> [String] {
        switch measurement {
        case "temperature", "humidity": return ["location", "sensor"]
        case "energy", "solar": return ["device", "phase"]
        case "battery": return ["device"]
        case "air_quality": return ["room"]
        case "appliance": return ["name"]
        case "motion": return ["zone"]
        case "water": return ["meter"]
        case "weather": return ["station"]
        default: return ["tag"]
        }
    }

    func fetchTagValues(measurement: String, tag: String) async throws -> [String] {
        switch tag {
        case "location": return ["living_room", "bedroom", "kitchen", "bathroom", "garden", "garage"]
        case "sensor": return ["dht22", "bme280", "ds18b20"]
        case "device": return ["inverter", "meter", "battery_1"]
        case "phase": return ["L1", "L2", "L3"]
        case "room": return ["living_room", "bedroom", "office"]
        case "name": return ["dishwasher", "washing_machine", "dryer", "oven"]
        case "zone": return ["entrance", "garden", "driveway"]
        case "meter": return ["main", "garden"]
        case "station": return ["garden"]
        default: return ["value_1", "value_2"]
        }
    }

    // MARK: - Demo Data Definitions

    private func demoFields(for measurement: String) -> [String] {
        switch measurement {
        case "temperature": return ["value", "setpoint"]
        case "humidity": return ["relative", "absolute"]
        case "energy": return ["power", "consumption", "voltage"]
        case "solar": return ["production", "feed_in", "self_consumption"]
        case "battery": return ["level", "voltage", "charging"]
        case "air_quality": return ["co2", "pm25", "voc"]
        case "appliance": return ["remaining_min", "power", "state"]
        case "motion": return ["detected", "count"]
        case "water": return ["flow_rate", "total"]
        case "weather": return ["temperature", "wind_speed", "wind_gust", "rain", "humidity", "pressure"]
        default: return ["value"]
        }
    }

    /// Returns a closure that generates realistic values for a given measurement + field.
    private func dataGenerator(measurement: String, field: String) -> (Double, Date) -> Double {
        switch (measurement, field) {

        // Temperature
        case ("temperature", "value"):
            let base = Double.random(in: 18...24)
            return { progress, date in
                let hour = Calendar.current.component(.hour, from: date)
                let dayWave = sin(Double(hour) / 24.0 * .pi * 2 - .pi / 2) * 3
                return base + dayWave + sin(progress * .pi * 6) * 0.5 + Double.random(in: -0.2...0.2)
            }
        case ("temperature", "setpoint"):
            return { _, _ in 21.0 }

        // Humidity
        case ("humidity", "relative"):
            let base = Double.random(in: 40...65)
            return { progress, _ in base + sin(progress * .pi * 4) * 8 + Double.random(in: -2...2) }
        case ("humidity", "absolute"):
            return { progress, _ in 8.0 + sin(progress * .pi * 3) * 2 + Double.random(in: -0.5...0.5) }

        // Energy
        case ("energy", "power"):
            return { _, date in
                let hour = Calendar.current.component(.hour, from: date)
                let base: Double = (6...22).contains(hour) ? 400 : 150
                return base + Double.random(in: -50...200)
            }
        case ("energy", "consumption"):
            return { progress, _ in progress * 12.5 + Double.random(in: 0...0.1) }
        case ("energy", "voltage"):
            return { _, _ in 230.0 + Double.random(in: -3...3) }

        // Solar
        case ("solar", "production"):
            return { _, date in
                let hour = Calendar.current.component(.hour, from: date)
                let sun = max(0, sin((Double(hour) - 6) / 12 * .pi)) * 5000
                return sun * Double.random(in: 0.7...1.0)
            }
        case ("solar", "feed_in"):
            return { _, date in
                let hour = Calendar.current.component(.hour, from: date)
                return max(0, sin((Double(hour) - 6) / 12 * .pi) * 3000 * Double.random(in: 0.5...1.0) - 400)
            }
        case ("solar", "self_consumption"):
            return { _, date in
                let hour = Calendar.current.component(.hour, from: date)
                let base: Double = (6...22).contains(hour) ? 400 : 150
                return min(base + Double.random(in: 0...200), max(0, sin((Double(hour) - 6) / 12 * .pi)) * 5000)
            }

        // Battery
        case ("battery", "level"):
            return { progress, _ in max(0, min(100, 80 + sin(progress * .pi * 2) * 30 + Double.random(in: -2...2))) }
        case ("battery", "voltage"):
            return { progress, _ in 3.2 + sin(progress * .pi * 2) * 0.6 + Double.random(in: -0.05...0.05) }
        case ("battery", "charging"):
            return { _, _ in Double.random(in: 0...1) > 0.5 ? 1 : 0 }

        // Air quality
        case ("air_quality", "co2"):
            return { progress, _ in 400 + sin(progress * .pi * 3) * 300 + Double.random(in: -20...20) }
        case ("air_quality", "pm25"):
            return { _, _ in Double.random(in: 5...35) }
        case ("air_quality", "voc"):
            return { progress, _ in 50 + sin(progress * .pi * 2) * 40 + Double.random(in: -5...5) }

        // Appliance
        case ("appliance", "remaining_min"):
            return { progress, _ in max(0, 90 * (1 - progress) + Double.random(in: -1...1)) }
        case ("appliance", "power"):
            return { progress, _ in progress < 0.8 ? Double.random(in: 1800...2200) : Double.random(in: 0...5) }
        case ("appliance", "state"):
            return { progress, _ in progress < 0.8 ? 1 : 0 }

        // Motion
        case ("motion", "detected"):
            return { _, _ in Double.random(in: 0...1) > 0.7 ? 1 : 0 }
        case ("motion", "count"):
            return { _, _ in Double(Int.random(in: 0...5)) }

        // Water
        case ("water", "flow_rate"):
            return { _, _ in Double.random(in: 0...1) > 0.6 ? Double.random(in: 5...15) : 0 }
        case ("water", "total"):
            return { progress, _ in 1234.5 + progress * 2.5 }

        // Weather
        case ("weather", "temperature"):
            let base = Double.random(in: 8...18)
            return { progress, date in
                let hour = Calendar.current.component(.hour, from: date)
                let dayWave = sin(Double(hour) / 24.0 * .pi * 2 - .pi / 2) * 5
                return base + dayWave + Double.random(in: -0.5...0.5)
            }
        case ("weather", "wind_speed"):
            return { progress, _ in max(0, 5 + sin(progress * .pi * 6) * 8 + Double.random(in: -2...2)) }
        case ("weather", "wind_gust"):
            return { progress, _ in max(0, 10 + sin(progress * .pi * 6) * 15 + Double.random(in: -3...5)) }
        case ("weather", "rain"):
            return { _, _ in Double.random(in: 0...1) > 0.7 ? Double.random(in: 0.1...4.0) : 0 }
        case ("weather", "humidity"):
            return { progress, _ in 60 + sin(progress * .pi * 3) * 20 + Double.random(in: -3...3) }
        case ("weather", "pressure"):
            return { progress, _ in 1013 + sin(progress * .pi * 2) * 8 + Double.random(in: -1...1) }

        default:
            return { progress, _ in sin(progress * .pi * 4) * 50 + 50 + Double.random(in: -5...5) }
        }
    }

    // MARK: - Query Parsing

    private func extractValue(from query: String, key: String) -> String {
        // Match r["_key"] == "value"
        let pattern = "r\\[\"" + NSRegularExpression.escapedPattern(for: key) + "\"\\]\\s*==\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let range = Range(match.range(at: 1), in: query) else { return "temperature" }
        return String(query[range])
    }

    private func extractFields(from query: String) -> [String] {
        let pattern = "r\\[\"_field\"\\]\\s*==\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: query, range: NSRange(query.startIndex..., in: query))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: query) else { return nil }
            return String(query[range])
        }
    }

    private func extractRange(from query: String) -> Double {
        // Match range(start: -1h) or -24h, -7d etc
        let pattern = "range\\(start:\\s*-([0-9]+)([mhd])"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let numRange = Range(match.range(at: 1), in: query),
              let unitRange = Range(match.range(at: 2), in: query),
              let num = Double(query[numRange]) else { return 60 }
        switch query[unitRange] {
        case "m": return num
        case "h": return num * 60
        case "d": return num * 1440
        default: return 60
        }
    }

    private func extractWindow(from query: String) -> Double {
        let pattern = "aggregateWindow\\(every:\\s*([0-9]+)([mhd])"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let numRange = Range(match.range(at: 1), in: query),
              let unitRange = Range(match.range(at: 2), in: query),
              let num = Double(query[numRange]) else { return 0 }
        switch query[unitRange] {
        case "m": return num
        case "h": return num * 60
        case "d": return num * 1440
        default: return 0
        }
    }
}
