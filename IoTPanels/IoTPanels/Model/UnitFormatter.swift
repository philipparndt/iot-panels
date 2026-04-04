import Foundation

/// Auto-scales numeric values to human-readable magnitudes within the same unit family.
enum UnitFormatter {

    struct FormattedValue {
        let value: String
        let unit: String

        /// Combined display string, e.g. "4.94 GB"
        var display: String {
            unit.isEmpty ? value : "\(value) \(unit)"
        }
    }

    /// Formats a value with optional auto-scaling based on the unit family.
    /// Returns the formatted value string and the scaled unit string separately.
    static func format(value: Double, unit: String) -> FormattedValue {
        // Split rate units: "B/s" → prefix "B", suffix "/s"
        let (prefix, suffix) = splitRateUnit(unit)

        if let family = unitFamilies[prefix] {
            let (scaledValue, scaledUnit) = scale(value: value, baseUnit: prefix, family: family)
            return FormattedValue(
                value: smartFormat(scaledValue),
                unit: scaledUnit + suffix
            )
        }

        // Unknown unit — pass through with standard formatting
        return FormattedValue(
            value: smartFormat(value),
            unit: unit
        )
    }

    /// Convenience: returns "4.94 GB" or "42.1 °C" as a single string.
    static func formatDisplay(value: Double, unit: String) -> String {
        format(value: value, unit: unit).display
    }

    // MARK: - Scaling Logic

    private static func scale(value: Double, baseUnit: String, family: UnitFamily) -> (Double, String) {
        // Find the index of the base unit in the family
        guard let baseIndex = family.scales.firstIndex(where: { $0.unit == baseUnit }) else {
            return (value, baseUnit)
        }

        // Convert to the family's base unit (index 0)
        let baseValue = value * family.scales[baseIndex].factor

        // Find the best scale: largest where |value| >= 1, or smallest if all < 1
        var bestIndex = 0
        let absBase = abs(baseValue)
        for i in family.scales.indices.reversed() {
            if absBase >= family.scales[i].factor {
                bestIndex = i
                break
            }
        }

        let scaledValue = baseValue / family.scales[bestIndex].factor
        return (scaledValue, family.scales[bestIndex].unit)
    }

    // MARK: - Smart Formatting

    /// Formats with decimal places appropriate to the magnitude.
    static func smartFormat(_ value: Double) -> String {
        let absVal = abs(value)
        if absVal == 0 { return "0" }
        if absVal >= 100 {
            return String(format: "%.0f", value)
        } else if absVal >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    // MARK: - Rate Unit Splitting

    /// Splits "B/s" into ("B", "/s"), "KB/s" into ("KB", "/s"), "W" into ("W", "")
    private static func splitRateUnit(_ unit: String) -> (prefix: String, suffix: String) {
        if let slashIndex = unit.firstIndex(of: "/") {
            let prefix = String(unit[unit.startIndex..<slashIndex])
            let suffix = String(unit[slashIndex...])
            return (prefix, suffix)
        }
        return (unit, "")
    }

    // MARK: - Unit Family Definitions

    private struct UnitScale {
        let unit: String
        let factor: Double
    }

    private struct UnitFamily {
        let scales: [UnitScale] // Ordered from smallest to largest
    }

    private static let unitFamilies: [String: UnitFamily] = {
        var families: [String: UnitFamily] = [:]

        // Bytes (1024-based)
        let bytesFamily = UnitFamily(scales: [
            UnitScale(unit: "B", factor: 1),
            UnitScale(unit: "KB", factor: 1024),
            UnitScale(unit: "MB", factor: 1024 * 1024),
            UnitScale(unit: "GB", factor: 1024 * 1024 * 1024),
            UnitScale(unit: "TB", factor: 1024 * 1024 * 1024 * 1024),
        ])
        for s in bytesFamily.scales { families[s.unit] = bytesFamily }

        // Bits per second (1000-based)
        let bitsFamily = UnitFamily(scales: [
            UnitScale(unit: "bit", factor: 1),
            UnitScale(unit: "kbit", factor: 1000),
            UnitScale(unit: "Mbit", factor: 1_000_000),
            UnitScale(unit: "Gbit", factor: 1_000_000_000),
        ])
        for s in bitsFamily.scales { families[s.unit] = bitsFamily }

        // Watts (1000-based)
        let wattsFamily = UnitFamily(scales: [
            UnitScale(unit: "mW", factor: 0.001),
            UnitScale(unit: "W", factor: 1),
            UnitScale(unit: "kW", factor: 1000),
            UnitScale(unit: "MW", factor: 1_000_000),
        ])
        for s in wattsFamily.scales { families[s.unit] = wattsFamily }

        // Watt-hours (1000-based)
        let whFamily = UnitFamily(scales: [
            UnitScale(unit: "Wh", factor: 1),
            UnitScale(unit: "kWh", factor: 1000),
            UnitScale(unit: "MWh", factor: 1_000_000),
        ])
        for s in whFamily.scales { families[s.unit] = whFamily }

        // Volts (1000-based)
        let voltsFamily = UnitFamily(scales: [
            UnitScale(unit: "µV", factor: 0.000001),
            UnitScale(unit: "mV", factor: 0.001),
            UnitScale(unit: "V", factor: 1),
            UnitScale(unit: "kV", factor: 1000),
        ])
        for s in voltsFamily.scales { families[s.unit] = voltsFamily }

        // Amps (1000-based)
        let ampsFamily = UnitFamily(scales: [
            UnitScale(unit: "µA", factor: 0.000001),
            UnitScale(unit: "mA", factor: 0.001),
            UnitScale(unit: "A", factor: 1),
        ])
        for s in ampsFamily.scales { families[s.unit] = ampsFamily }

        // Time (mixed factors)
        let timeFamily = UnitFamily(scales: [
            UnitScale(unit: "ms", factor: 0.001),
            UnitScale(unit: "s", factor: 1),
            UnitScale(unit: "min", factor: 60),
            UnitScale(unit: "h", factor: 3600),
            UnitScale(unit: "days", factor: 86400),
        ])
        for s in timeFamily.scales { families[s.unit] = timeFamily }

        // Frequency (1000-based)
        let freqFamily = UnitFamily(scales: [
            UnitScale(unit: "Hz", factor: 1),
            UnitScale(unit: "kHz", factor: 1000),
            UnitScale(unit: "MHz", factor: 1_000_000),
            UnitScale(unit: "GHz", factor: 1_000_000_000),
        ])
        for s in freqFamily.scales { families[s.unit] = freqFamily }

        return families
    }()
}
