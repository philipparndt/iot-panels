import Foundation

/// Generates realistic, deterministic demo IoT data for offline use / demonstration.
struct DemoService: DataSourceServiceProtocol {

    func testConnection() async throws -> Bool {
        true
    }

    func query(_ queryString: String) async throws -> QueryResult {
        // Demo answers for known PromQL strings (used by templates shipped
        // against demo-flagged Prometheus sources). The raw query is wrapped
        // by `SavedQuery.buildPrometheusQuery` as `TIMERANGE:<seconds>|<promql>`,
        // so we route any query with that prefix through the known-query path.
        if queryString.hasPrefix("TIMERANGE:"),
           let result = nodeExporterDemoResult(for: queryString) {
            return result
        }

        let measurement = extractValue(from: queryString, key: "_measurement")
        let fields = extractFields(from: queryString)
        let (rangeMinutes, stopMinutes) = extractRangeWithStop(from: queryString)
        let windowMinutes = extractWindow(from: queryString)
        let yieldNames = extractYieldNames(from: queryString)
        let isBandQuery = !yieldNames.isEmpty


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
                // Generate min/max/mean series with asymmetric spread
                for yieldName in yieldNames {
                    for i in 0..<count {
                        let time = now.addingTimeInterval(-Double(count - i) * interval - stopOffset)
                        let meanVal = gen(time)
                        let spread = spreadForField(measurement: measurement, field: field, time: time)

                        // Asymmetry: mean is not centered between min/max
                        // skew > 0.5 means peaks upward (max further from mean), < 0.5 means dips downward
                        let skew = smoothNoise(for: time, seed: stableHash("\(measurement)_\(field)_skew"), period: 2400)
                        let minSpread = spread * (0.3 + skew * 0.8)       // 30-110% of spread
                        let maxSpread = spread * (0.3 + (1 - skew) * 0.8) // inverse

                        let value: Double
                        switch yieldName {
                        case "min": value = meanVal - minSpread
                        case "max": value = meanVal + maxSpread
                        default: value = meanVal
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
            } else if let stateGen = stateGenerator(measurement: measurement, field: field) {
                // State-based data (string values)
                for i in 0..<count {
                    let time = now.addingTimeInterval(-Double(count - i) * interval - stopOffset)
                    let stateValue = stateGen(time)
                    rows.append(QueryResult.Row(values: [
                        "_time": formatter.string(from: time),
                        "_measurement": measurement,
                        "_field": field,
                        "_value": stateValue,
                        "result": "_result",
                        "table": "0"
                    ]))
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
        ["temperature", "humidity", "energy", "solar", "battery", "air_quality", "appliance", "motion", "water", "weather", "door_state", "hvac_mode"]
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
        case "door_state": return ["location"]
        case "hvac_mode": return ["zone"]
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
        case "door_state": return ["state"]
        case "hvac_mode": return ["mode"]
        default: return ["value"]
        }
    }

    private func stateGenerator(measurement: String, field: String) -> ((Date) -> String)? {
        switch (measurement, field) {
        case ("door_state", _):
            let states = ["open", "closed"]
            return { time in
                let noise = self.smoothNoise(for: time, seed: self.stableHash("door_state_state"), period: 1800)
                return states[noise > 0.6 ? 0 : 1]
            }
        case ("hvac_mode", _):
            let states = ["idle", "heating", "cooling", "fan"]
            return { time in
                let noise = self.smoothNoise(for: time, seed: self.stableHash("hvac_mode_mode"), period: 3600)
                let index = Int(noise * Double(states.count)) % states.count
                return states[index]
            }
        default:
            return nil
        }
    }

    /// Spread for band chart min/max around the mean value.
    private func spreadForField(measurement: String, field: String, time: Date) -> Double {
        let variation = smoothNoise(for: time, seed: stableHash("\(measurement)_\(field)_spread"), period: 1200)
        // Extra spiky variation on a faster period
        let spike = smoothNoise(for: time, seed: stableHash("\(measurement)_\(field)_spike"), period: 400)
        let spikeBoost = spike > 0.75 ? (spike - 0.75) * 8.0 : 0 // occasional large spikes
        switch (measurement, field) {
        case ("temperature", _): return 0.5 + variation * 2.0 + spikeBoost * 1.5
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

        // Temperature — realistic indoor with daily variation large enough for visible comparison crossings
        case ("temperature", "value"):
            let base = 20.5
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let minute = Calendar.current.component(.minute, from: date)
                let hourF = Double(hour) + Double(minute) / 60.0
                let dayIndex = Int(date.timeIntervalSince1970 / 86400)

                // Daily offset: ±3°C so yesterday and today visibly differ
                let daily = dailyOffset(for: date, seed: seed, range: 3.0)

                // Day/night wave with per-day phase shift — creates crossings
                let phaseShift = Double(abs((dayIndex &* 7919) % 100)) / 100.0 * 1.5 // 0-1.5h shift per day
                let dayWave = sin((hourF + phaseShift) / 24.0 * .pi * 2 - .pi / 2) * 2.5

                // Night setback
                let nightCool: Double = (0...6).contains(hour) ? -1.5 : 0

                // Per-day event timing: morning boost at slightly different hours
                let morningHour = 6 + abs((dayIndex &* 2411) % 3) // 6, 7, or 8
                let morningBoost: Double = hour == morningHour ? smoothNoise(for: date, seed: seed &+ 10, period: 600) * 2.0 : 0

                // Window opening: different hour each day, creates a distinctive dip
                let windowHour = 9 + abs((dayIndex &* 5381) % 6) // 9-14
                let windowDip: Double = hour == windowHour ? -2.5 * smoothNoise(for: date, seed: seed &+ 30, period: 300) : 0

                // Evening warmth: varies per day
                let eveningBoost: Double = (17...20).contains(hour)
                    ? smoothNoise(for: date, seed: seed &+ 20 &+ dayIndex, period: 900) * 1.5 : 0

                // Cold front event: yesterday between 10-15h, temperature drops ~10°C
                let yesterday = Int(Date().timeIntervalSince1970 / 86400) - 1
                let coldFront: Double
                if dayIndex == yesterday && (10...15).contains(hour) {
                    let depth = sin(Double(hour - 10) / 5.0 * .pi) // smooth bell curve over 10-15h
                    coldFront = -10.0 * depth
                } else {
                    coldFront = 0
                }

                let variation = (smoothNoise(for: date, seed: seed, period: 900) - 0.5) * 1.0
                return base + dayWave + nightCool + morningBoost + eveningBoost + windowDip + coldFront + daily + variation
            }
        case ("temperature", "setpoint"):
            return { date in
                let hour = Calendar.current.component(.hour, from: date)
                return (0...6).contains(hour) ? 18.0 : 21.0 // Night setback
            }

        // Humidity — inverse correlation with temperature, spikes from cooking/shower
        case ("humidity", "relative"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base = 48.0
                let daily = dailyOffset(for: date, seed: seed, range: 4.0)
                // Inverse of temperature: higher humidity when cooler
                let dayWave = -sin(Double(hour) / 24.0 * .pi * 2 - .pi / 2) * 8
                // Morning shower spike (7-8am)
                let shower: Double = hour == 7 ? 15.0 * smoothNoise(for: date, seed: seed &+ 5, period: 300) : 0
                // Evening cooking spike (18-19)
                let cooking: Double = (18...19).contains(hour) ? 10.0 * smoothNoise(for: date, seed: seed &+ 6, period: 600) : 0
                let variation = (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 5
                return max(30, min(80, base + dayWave + shower + cooking + daily + variation))
            }
        case ("humidity", "absolute"):
            return { [self] date in
                8.0 + dailyOffset(for: date, seed: seed, range: 1.5) + (smoothNoise(for: date, seed: seed, period: 3600) - 0.5) * 3
            }

        // Energy — realistic consumption with appliance spikes
        case ("energy", "power"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                // Base load profile: standby at night, active during day
                let base: Double
                switch hour {
                case 0...5: base = 120
                case 6...7: base = 350  // morning routine
                case 8...11: base = 250
                case 12...13: base = 500 // cooking lunch
                case 14...16: base = 200
                case 17...20: base = 600 // evening: cooking, TV, lights
                case 21...23: base = 300
                default: base = 200
                }
                // Appliance spikes (kettle, oven, etc.)
                let spike: Double = noise(for: date, seed: seed &+ 7) > 0.8 ? 1500 * smoothNoise(for: date, seed: seed &+ 8, period: 180) : 0
                let daily = dailyOffset(for: date, seed: seed, range: 50)
                let variation = (smoothNoise(for: date, seed: seed, period: 300) - 0.5) * 150
                return max(80, base + spike + daily + variation)
            }
        case ("energy", "consumption"):
            return { [self] date in
                let hours = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 3600
                let daily = dailyOffset(for: date, seed: seed, range: 1.5)
                return hours * 0.55 + daily + smoothNoise(for: date, seed: seed, period: 3600) * 0.8
            }
        case ("energy", "voltage"):
            return { [self] date in
                230.0 + (smoothNoise(for: date, seed: seed, period: 300) - 0.5) * 5
            }

        // Solar — cloud passages creating dips and recoveries
        case ("solar", "production"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let min = Calendar.current.component(.minute, from: date)
                let hourF = Double(hour) + Double(min) / 60.0
                let sun = max(0, sin((hourF - 5.5) / 13 * .pi)) * 5500
                let daily = 0.8 + dailyOffset(for: date, seed: seed, range: 0.15) // ±15% daily cloud cover

                // Cloud passages: sudden 30-70% dips lasting 10-30 min
                let cloudDip: Double
                let cloudChance = noise(for: date, seed: seed &+ 40)
                if cloudChance > 0.7 {
                    cloudDip = 0.3 + smoothNoise(for: date, seed: seed &+ 41, period: 600) * 0.4
                } else {
                    cloudDip = 1.0
                }
                return max(0, sun * daily * cloudDip)
            }
        case ("solar", "feed_in"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let min = Calendar.current.component(.minute, from: date)
                let hourF = Double(hour) + Double(min) / 60.0
                let sun = max(0, sin((hourF - 5.5) / 13 * .pi)) * 5500
                let daily = 0.8 + dailyOffset(for: date, seed: seed, range: 0.15)
                let cloudDip = noise(for: date, seed: seed &+ 40) > 0.7
                    ? 0.3 + smoothNoise(for: date, seed: seed &+ 41, period: 600) * 0.4 : 1.0
                let production = max(0, sun * daily * cloudDip)
                let consumption = 300 + smoothNoise(for: date, seed: seed &+ 50, period: 600) * 200
                return max(0, production - consumption)
            }
        case ("solar", "self_consumption"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base: Double = (6...22).contains(hour) ? 350 : 120
                let spike: Double = noise(for: date, seed: seed &+ 51) > 0.8 ? 800 : 0
                return base + spike + smoothNoise(for: date, seed: seed, period: 600) * 150
            }

        // Battery — solar charging during day, discharging at night
        case ("battery", "level"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let minute = Calendar.current.component(.minute, from: date)
                let hourF = Double(hour) + Double(minute) / 60.0
                // Charges during solar peak (10-16), discharges evening/night (17-6)
                let cycle: Double
                if (6...16).contains(hour) {
                    cycle = min(100, 20 + (hourF - 6) / 10 * 70) // ramp up to ~90%
                } else if (17...23).contains(hour) {
                    cycle = max(15, 90 - (hourF - 17) / 7 * 60) // drain to ~30%
                } else {
                    cycle = max(10, 30 - hourF / 6 * 15) // slow overnight drain
                }
                let daily = dailyOffset(for: date, seed: seed, range: 8)
                let variation = (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 5
                return max(0, min(100, cycle + daily + variation))
            }
        case ("battery", "voltage"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                // Correlate with battery level
                let levelProxy = (6...16).contains(hour) ? 0.8 : 0.4
                return 3.0 + levelProxy * 0.8 + (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 0.1
            }
        case ("battery", "charging"):
            return { date in
                let hour = Calendar.current.component(.hour, from: date)
                return (7...16).contains(hour) ? 1 : 0
            }

        // Air quality — CO2 builds during occupied hours, ventilation events
        case ("air_quality", "co2"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base: Double = 420
                // Build-up during occupied hours
                let occupancy: Double
                switch hour {
                case 0...6: occupancy = 50 // sleeping, low
                case 7...8: occupancy = 200 // morning, people active
                case 9...12: occupancy = 350 // working from home
                case 13...14: occupancy = 250 // after lunch ventilation
                case 15...18: occupancy = 400 // afternoon peak
                case 19...21: occupancy = 300 // evening
                default: occupancy = 100
                }
                // Ventilation drops (window opening)
                let ventDrop: Double = noise(for: date, seed: seed &+ 60) > 0.85 ? -200 : 0
                let daily = dailyOffset(for: date, seed: seed, range: 50)
                let variation = (smoothNoise(for: date, seed: seed, period: 900) - 0.5) * 80
                return max(380, base + occupancy + ventDrop + daily + variation)
            }
        case ("air_quality", "pm25"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base = 8.0
                // Cooking spikes
                let cooking: Double = (12...13).contains(hour) || (18...19).contains(hour) ? 15 * smoothNoise(for: date, seed: seed &+ 61, period: 300) : 0
                let daily = dailyOffset(for: date, seed: seed, range: 5)
                return max(1, base + cooking + daily + smoothNoise(for: date, seed: seed, period: 2400) * 10)
            }
        case ("air_quality", "voc"):
            return { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base = 40.0
                let occupied: Double = (8...22).contains(hour) ? 30 : 0
                let cleaning: Double = (10...11).contains(hour) && noise(for: date, seed: seed &+ 62) > 0.7 ? 80 : 0
                return max(10, base + occupied + cleaning + (smoothNoise(for: date, seed: seed, period: 1800) - 0.5) * 30)
            }

        // Appliance
        case ("appliance", "remaining_min"):
            return { date in
                let cycle = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 5400)
                return max(0, 90 - cycle / 60)
            }
        case ("appliance", "power"):
            return { [self] date in
                let cycle = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 5400)
                return cycle < 4320 ? 1800 + smoothNoise(for: date, seed: seed, period: 300) * 400 : 2
            }
        case ("appliance", "state"):
            return { date in
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

    // MARK: - Node Exporter Demo

    /// Returns a synthesized series for the exact PromQL strings used by the
    /// `nodeExporterLite` template, when executed against a demo-flagged
    /// Prometheus data source. Returns nil for any unrecognised query, in
    /// which case the caller falls through to the InfluxDB-style query path.
    private func nodeExporterDemoResult(for wrappedQuery: String) -> QueryResult? {
        // The query is wrapped by `SavedQuery.buildPrometheusQuery` as
        // "TIMERANGE:<seconds>|<promql>". Strip the prefix, parse the range,
        // and dispatch on the bare PromQL string.
        guard wrappedQuery.hasPrefix("TIMERANGE:") else { return nil }
        let afterPrefix = wrappedQuery.dropFirst("TIMERANGE:".count)
        guard let pipeIndex = afterPrefix.firstIndex(of: "|") else { return nil }
        let rangeString = String(afterPrefix[afterPrefix.startIndex..<pipeIndex])
        let promql = String(afterPrefix[afterPrefix.index(after: pipeIndex)...])
            .trimmingCharacters(in: .whitespaces)
        guard let rangeSeconds = Double(rangeString), rangeSeconds > 0 else { return nil }

        // Use 1-minute steps for nice smooth curves regardless of the
        // selected time range, capped to avoid huge series for very long
        // ranges. The chart renderer down-samples as needed.
        let interval: TimeInterval = 60
        let count = max(20, min(720, Int(rangeSeconds / interval)))

        // Each branch describes how to compute the value at a given time.
        let generator: ((Date) -> Double)?

        switch promql {
        case "(time() - node_boot_time_seconds) / 86400":
            // Uptime in days — slowly increasing.
            generator = { date in
                17.0 + Double(date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)) / 86400.0
            }
        case "sum(kubelet_running_pods) / sum(kube_node_status_allocatable{resource=\"pods\"}) * 100":
            // Pods used as % of allocatable — slow drift around ~58%.
            generator = { [self] date in
                let base = 58.0
                let n = smoothNoise(for: date, seed: stableHash("pods_pct"), period: 1800) * 18 - 8
                return min(98, max(10, base + n))
            }
        case "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)":
            // CPU usage % — varies with daily rhythm + spikes.
            generator = { [self] date in
                let hour = Calendar.current.component(.hour, from: date)
                let base = 18.0 + (Double(hour) - 12).magnitude * -0.8
                let n = smoothNoise(for: date, seed: stableHash("cpu_usage"), period: 600) * 35
                let spike = smoothNoise(for: date, seed: stableHash("cpu_spike"), period: 200)
                let spikeBoost = spike > 0.85 ? (spike - 0.85) * 120 : 0
                return min(99, max(2, base + n + spikeBoost))
            }
        case "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100":
            // Memory % used — slow drift around 62%.
            generator = { [self] date in
                62.0 + smoothNoise(for: date, seed: stableHash("mem_pct"), period: 1800) * 14 - 5
            }
        case "(1 - node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100":
            // Disk % used — very slow growth around 47%.
            generator = { [self] date in
                47.0 + smoothNoise(for: date, seed: stableHash("disk_pct"), period: 7200) * 6
            }
        case "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes":
            // Bytes used — drift around 10 GiB.
            generator = { [self] date in
                let pct = 0.62 + smoothNoise(for: date, seed: stableHash("mem_bytes"), period: 1800) * 0.14 - 0.05
                return pct * 17_179_869_184 // 16 GiB total
            }
        case "sum(rate(node_network_receive_bytes_total{device=~\"eth.*|en.*|wlan.*\"}[5m]))":
            // Bytes/s received — bursty around 2 MB/s.
            generator = { [self] date in
                let base = 2_000_000.0
                let n = smoothNoise(for: date, seed: stableHash("net_rx"), period: 800) * 4_000_000
                let spike = smoothNoise(for: date, seed: stableHash("net_rx_spike"), period: 250)
                return base + n + (spike > 0.8 ? spike * 8_000_000 : 0)
            }
        case "sum(rate(node_disk_read_bytes_total{device=~\"sd.*|nvme.*|vd.*\"}[5m]))":
            // Bytes/s read — usually low with periodic bursts.
            generator = { [self] date in
                let base = 400_000.0
                let n = smoothNoise(for: date, seed: stableHash("disk_io"), period: 600) * 2_500_000
                let spike = smoothNoise(for: date, seed: stableHash("disk_io_spike"), period: 180)
                return base + n + (spike > 0.85 ? spike * 12_000_000 : 0)
            }
        default:
            generator = nil
        }

        guard let gen = generator else { return nil }

        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var rows: [QueryResult.Row] = []
        for i in 0..<count {
            let time = now.addingTimeInterval(-Double(count - i) * interval)
            let value = gen(time)
            rows.append(QueryResult.Row(values: [
                "_time": formatter.string(from: time),
                "_field": "value",
                "_value": String(format: "%.4f", value),
                "result": "_result",
                "table": "0"
            ]))
        }

        let columns = ["", "result", "table", "_time", "_field", "_value"]
            .map { QueryResult.Column(name: $0, type: "string") }

        return QueryResult(columns: columns, rows: rows)
    }
}
