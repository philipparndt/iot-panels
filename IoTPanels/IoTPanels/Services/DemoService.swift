import Foundation

/// Generates realistic, deterministic demo IoT data for offline use / demonstration.
struct DemoService: DataSourceServiceProtocol {

    func testConnection() async throws -> Bool {
        true
    }

    func query(_ queryString: String) async throws -> QueryResult {
        let measurement = extractValue(from: queryString, key: "_measurement")
        let fields = extractFields(from: queryString)
        let (rangeMinutes, stopMinutes) = extractRangeWithStop(from: queryString)
        let windowMinutes = extractWindow(from: queryString)
        let yieldNames = extractYieldNames(from: queryString)
        let isBandQuery = !yieldNames.isEmpty

        #if DEBUG
        print("[DemoService] measurement=\(measurement) fields=\(fields) range=\(rangeMinutes)m stop=\(stopMinutes)m window=\(windowMinutes)m yields=\(yieldNames) band=\(isBandQuery)")
        #endif

        let effectiveFields = fields.isEmpty ? demoFields(for: measurement) : fields
        let interval = windowMinutes > 0 ? windowMinutes * 60.0 : 300.0
        let count = max(1, Int(rangeMinutes * 60.0 / interval))

        var rows: [QueryResult.Row] = []
        let now = Date()
        let stopOffset = stopMinutes * 60.0
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for field in effectiveFields {
            let gen = dataGenerator(measurement: measurement, field: field)

            if isBandQuery {
                // Generate min/max/mean series with correct field suffixes
                for yieldName in yieldNames {
                    for i in 0..<count {
                        let time = now.addingTimeInterval(-Double(count - i) * interval - stopOffset)
                        let meanVal = gen(time)
                        let spread = spreadForField(measurement: measurement, field: field, time: time)
                        let value: Double
                        switch yieldName {
                        case "min": value = meanVal - spread
                        case "max": value = meanVal + spread
                        default: value = meanVal // mean
                        }
                        rows.append(QueryResult.Row(values: [
                            "_time": formatter.string(from: time),
                            "_measurement": measurement,
                            "_field": "\(field)_\(yieldName)",
                            "_value": String(format: "%.2f", value),
                            "result": yieldName,
                            "table": "0"
                        ]))
                    }
                }
            } else {
                for i in 0..<count {
                    let time = now.addingTimeInterval(-Double(count - i) * interval - stopOffset)
                    let value = gen(time)
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

    // MARK: - Deterministic Noise

    /// Produces a deterministic value between 0 and 1 from a timestamp and seed.
    /// Same inputs always produce the same output.
    private func noise(for date: Date, seed: Int = 0) -> Double {
        let t = Int(date.timeIntervalSince1970)
        let hash = (t &+ seed) &* 2654435761
        return Double(abs(hash) % 10000) / 10000.0
    }

    /// Produces a deterministic value in a range, varying smoothly over time.
    private func smoothNoise(for date: Date, seed: Int, period: TimeInterval) -> Double {
        let t = date.timeIntervalSince1970
        let bucket = t / period
        let frac = bucket - bucket.rounded(.down)

        let n0 = noise(for: Date(timeIntervalSince1970: bucket.rounded(.down) * period), seed: seed)
        let n1 = noise(for: Date(timeIntervalSince1970: (bucket.rounded(.down) + 1) * period), seed: seed)

        // Smooth interpolation (cosine)
        let blend = (1 - cos(frac * .pi)) / 2
        return n0 * (1 - blend) + n1 * blend
    }

    /// Stable hash from a string, used to derive base values.
    private func stableHash(_ string: String) -> Int {
        var hash = 5381
        for char in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return abs(hash)
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

    /// Spread for band chart min/max around the mean value.
    private func spreadForField(measurement: String, field: String, time: Date) -> Double {
        let variation = smoothNoise(for: time, seed: stableHash("\(measurement)_\(field)_spread"), period: 1800)
        switch (measurement, field) {
        case ("temperature", _): return 0.8 + variation * 1.5
        case ("humidity", _): return 3 + variation * 5
        case ("solar", _): return 100 + variation * 400
        case ("energy", "power"): return 30 + variation * 80
        case ("weather", "temperature"): return 1 + variation * 2
        case ("weather", "wind_speed"), ("weather", "wind_gust"): return 1 + variation * 3
        default: return 1 + variation * 5
        }
    }

    /// Deterministic daily variation — each day gets a different offset (±range).
    private func dailyOffset(for date: Date, seed: Int, range: Double) -> Double {
        let dayIndex = Int(date.timeIntervalSince1970 / 86400)
        let hash = (dayIndex &+ seed) &* 2654435761
        return (Double(abs(hash) % 10000) / 10000.0 - 0.5) * 2 * range
    }

    /// Returns a closure that generates a deterministic value for a given timestamp.
    private func dataGenerator(measurement: String, field: String) -> (Date) -> Double {
        let seed = stableHash("\(measurement)_\(field)")

        switch (measurement, field) {

        // Temperature — stable base with day/night cycle + daily variation
        case ("temperature", "value"):
            let base = 19.0 + Double(stableHash("temp_base") % 500) / 100.0 // 19-24°C, stable
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let dayWave = sin(Double(hour) / 24.0 * .pi * 2 - .pi / 2) * 3
                let daily = dailyOffset(for: date, seed: seed, range: 2.0) // ±2°C per day
                let variation = (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 1.0
                return base + dayWave + daily + variation
            }
        case ("temperature", "setpoint"):
            return { _ in 21.0 }

        // Humidity
        case ("humidity", "relative"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base = 52.0
                let dayWave = sin(Double(hour) / 24.0 * .pi * 2 + .pi / 3) * 10
                let daily = dailyOffset(for: date, seed: seed, range: 5.0)
                let variation = (smoothNoise(for: date, seed: seed, period: 2400) - 0.5) * 6
                return base + dayWave + daily + variation
            }
        case ("humidity", "absolute"):
            return { [self] date in
                8.0 + (smoothNoise(for: date, seed: seed, period: 3600) - 0.5) * 3
            }

        // Energy
        case ("energy", "power"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base: Double = (6...22).contains(hour) ? 400 : 150
                let variation = (smoothNoise(for: date, seed: seed, period: 600) - 0.3) * 300
                return max(50, base + variation)
            }
        case ("energy", "consumption"):
            return { [self] date in
                let hours = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 3600
                return hours * 0.52 + smoothNoise(for: date, seed: seed, period: 3600) * 0.5
            }
        case ("energy", "voltage"):
            return { [self] date in
                230.0 + (smoothNoise(for: date, seed: seed, period: 600) - 0.5) * 6
            }

        // Solar
        case ("solar", "production"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let sun = max(0, sin((Double(hour) - 6) / 12 * .pi)) * 5000
                let clouds = smoothNoise(for: date, seed: seed, period: 1800) * 0.3 + 0.7
                return sun * clouds
            }
        case ("solar", "feed_in"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let production = max(0, sin((Double(hour) - 6) / 12 * .pi)) * 5000
                let clouds = smoothNoise(for: date, seed: seed, period: 1800) * 0.3 + 0.7
                return max(0, production * clouds - 400)
            }
        case ("solar", "self_consumption"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base: Double = (6...22).contains(hour) ? 400 : 150
                let production = max(0, sin((Double(hour) - 6) / 12 * .pi)) * 5000
                return min(base + smoothNoise(for: date, seed: seed, period: 900) * 200, production * 0.9)
            }

        // Battery
        case ("battery", "level"):
            return { [self] date in
                let wave = sin(date.timeIntervalSince1970 / 7200 * .pi * 2) * 30
                return max(0, min(100, 65 + wave + (smoothNoise(for: date, seed: seed, period: 3600) - 0.5) * 10))
            }
        case ("battery", "voltage"):
            return { [self] date in
                3.5 + sin(date.timeIntervalSince1970 / 7200 * .pi * 2) * 0.5 + (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 0.1
            }
        case ("battery", "charging"):
            return { [self] date in noise(for: date, seed: seed) > 0.5 ? 1 : 0 }

        // Air quality
        case ("air_quality", "co2"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let occupied = (8...22).contains(hour) ? 300.0 : 0.0
                return 400 + occupied + (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 100
            }
        case ("air_quality", "pm25"):
            return { [self] date in
                10 + smoothNoise(for: date, seed: seed, period: 3600) * 20
            }
        case ("air_quality", "voc"):
            return { [self] date in
                50 + (smoothNoise(for: date, seed: seed, period: 2400) - 0.5) * 60
            }

        // Appliance
        case ("appliance", "remaining_min"):
            return { [self] date in
                let cycle = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 5400) // 90 min cycle
                return max(0, 90 - cycle / 60)
            }
        case ("appliance", "power"):
            return { [self] date in
                let cycle = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 5400)
                return cycle < 4320 ? 1800 + smoothNoise(for: date, seed: seed, period: 300) * 400 : 2.0
            }
        case ("appliance", "state"):
            return { [self] date in
                let cycle = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 5400)
                return cycle < 4320 ? 1 : 0
            }

        // Motion
        case ("motion", "detected"):
            return { [self] date in noise(for: date, seed: seed) > 0.7 ? 1 : 0 }
        case ("motion", "count"):
            return { [self] date in Double(Int(noise(for: date, seed: seed) * 5)) }

        // Water
        case ("water", "flow_rate"):
            return { [self] date in noise(for: date, seed: seed) > 0.6 ? 5 + smoothNoise(for: date, seed: seed &+ 1, period: 300) * 10 : 0 }
        case ("water", "total"):
            return { date in
                1234.5 + date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 86400 * 2.5
            }

        // Weather
        case ("weather", "temperature"):
            let base = 12.0
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let dayWave = sin(Double(hour) / 24.0 * .pi * 2 - .pi / 2) * 5
                let daily = dailyOffset(for: date, seed: seed, range: 3.0)
                return base + dayWave + daily + (smoothNoise(for: date, seed: seed, period: 3600) - 0.5) * 1.5
            }
        case ("weather", "wind_speed"):
            return { [self] date in
                max(0, 5 + (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 12)
            }
        case ("weather", "wind_gust"):
            return { [self] date in
                max(0, 10 + (smoothNoise(for: date, seed: seed, period: 1200) - 0.5) * 20)
            }
        case ("weather", "rain"):
            return { [self] date in noise(for: date, seed: seed) > 0.75 ? smoothNoise(for: date, seed: seed &+ 1, period: 600) * 4 : 0 }
        case ("weather", "humidity"):
            return { [self] date in
                60 + (smoothNoise(for: date, seed: seed, period: 3600) - 0.5) * 30
            }
        case ("weather", "pressure"):
            return { [self] date in
                1013 + (smoothNoise(for: date, seed: seed, period: 7200) - 0.5) * 16
            }

        default:
            return { [self] date in
                50 + (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 40
            }
        }
    }

    // MARK: - Query Parsing

    private func extractValue(from query: String, key: String) -> String {
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
        let fields = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: query) else { return nil }
            return String(query[range])
        }
        // Deduplicate (band queries repeat the field filter 3 times)
        return Array(Set(fields)).sorted()
    }

    /// Extracts range in minutes and optional stop offset in minutes.
    /// Supports: range(start: -2h), range(start: -172800s, stop: -86400s)
    private func extractRangeWithStop(from query: String) -> (range: Double, stop: Double) {
        // Try seconds-based format with stop: range(start: -Xs, stop: -Ys)
        let secStopPattern = "range\\(start:\\s*-([0-9]+)s,\\s*stop:\\s*-([0-9]+)s"
        if let regex = try? NSRegularExpression(pattern: secStopPattern),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
           let startRange = Range(match.range(at: 1), in: query),
           let stopRange = Range(match.range(at: 2), in: query),
           let startSec = Double(query[startRange]),
           let stopSec = Double(query[stopRange]) {
            return (range: (startSec - stopSec) / 60.0, stop: stopSec / 60.0)
        }

        // Try seconds-based format without stop: range(start: -Xs)
        let secPattern = "range\\(start:\\s*-([0-9]+)s[,\\)]"
        if let regex = try? NSRegularExpression(pattern: secPattern),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
           let startRange = Range(match.range(at: 1), in: query),
           let startSec = Double(query[startRange]) {
            return (range: startSec / 60.0, stop: 0)
        }

        // Fall back to duration format: range(start: -2h)
        let durPattern = "range\\(start:\\s*-([0-9]+)([mhd])"
        if let regex = try? NSRegularExpression(pattern: durPattern),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
           let numRange = Range(match.range(at: 1), in: query),
           let unitRange = Range(match.range(at: 2), in: query),
           let num = Double(query[numRange]) {
            let minutes: Double
            switch query[unitRange] {
            case "m": minutes = num
            case "h": minutes = num * 60
            case "d": minutes = num * 1440
            default: minutes = 60
            }
            return (range: minutes, stop: 0)
        }

        return (range: 60, stop: 0)
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

    /// Detects band query yield names: yield(name: "min"), yield(name: "max"), yield(name: "mean")
    private func extractYieldNames(from query: String) -> [String] {
        let pattern = "yield\\(name:\\s*\"(min|max|mean)\"\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: query, range: NSRange(query.startIndex..., in: query))
        let names = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: query) else { return nil }
            return String(query[range])
        }
        return Array(Set(names)).sorted() // deduplicate
    }
}
