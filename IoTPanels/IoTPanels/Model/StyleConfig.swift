import SwiftUI

// MARK: - Style Configuration (stored as JSON per item/panel)

struct StyleConfig: Codable, Equatable {
    // Gauge settings
    var gaugeMin: Double?       // nil = auto from data
    var gaugeMax: Double?       // nil = auto from data
    var gaugeColorScheme: String = GaugeColorScheme.blueToRed.rawValue
    var heatmapColor: String = HeatmapColor.green.rawValue

    // Band chart settings
    var bandOpacity: Double?    // nil = default 0.2
    var bandColor: String?      // nil = use series accent color

    // Threshold color rules
    var thresholds: [ThresholdRule]?

    // State timeline color mapping
    var stateColors: [StateColorEntry]?

    // State timeline value-to-state aliases (map numeric ranges to state labels)
    var stateAliases: [StateAlias]?

    static let `default` = StyleConfig()

    var resolvedGaugeColorScheme: GaugeColorScheme {
        GaugeColorScheme(rawValue: gaugeColorScheme) ?? .blueToRed
    }

    var resolvedHeatmapColor: HeatmapColor {
        HeatmapColor(rawValue: heatmapColor) ?? .green
    }

    var resolvedBandOpacity: Double {
        bandOpacity ?? 0.2
    }

    /// Returns the threshold-resolved color for a given value, or the base color if no threshold matches.
    func resolvedColor(for value: Double, baseColor: Color) -> Color {
        guard let rules = thresholds, !rules.isEmpty else { return baseColor }
        let sorted = rules.sorted { $0.value < $1.value }
        var result = baseColor
        for rule in sorted {
            if value >= rule.value {
                result = Color(hex: rule.colorHex)
            } else {
                break
            }
        }
        return result
    }
}

// MARK: - State Color Entry

struct StateColorEntry: Codable, Equatable, Identifiable {
    var id: String { state }
    var state: String
    var colorHex: String
}

// MARK: - State Color Resolver

enum StateColorResolver {
    private static let semanticDefaults: [Set<String>: [String: String]] = [
        Set(["on", "off"]): ["on": "#34C759", "off": "#FF3B30"],
        Set(["open", "closed"]): ["open": "#34C759", "closed": "#FF3B30"],
        Set(["home", "away"]): ["home": "#34C759", "away": "#8E8E93"],
        Set(["true", "false"]): ["true": "#34C759", "false": "#FF3B30"],
    ]

    static let palette: [(hex: String, name: String)] = [
        ("#007AFF", "Blue"),
        ("#34C759", "Green"),
        ("#FF9500", "Orange"),
        ("#FF3B30", "Red"),
        ("#AF52DE", "Purple"),
        ("#5AC8FA", "Cyan"),
        ("#FFD60A", "Yellow"),
        ("#FF2D55", "Pink"),
        ("#64D2FF", "Light Blue"),
        ("#30D158", "Mint"),
    ]

    static let paletteHexValues: [String] = palette.map(\.hex)

    static func color(for state: String, allStates: [String], userColors: [StateColorEntry]?) -> Color {
        // 1. Check user-configured colors
        if let entry = userColors?.first(where: { $0.state == state }) {
            return Color(hex: entry.colorHex)
        }

        // 2. Check semantic defaults for known binary pairs
        let stateSet = Set(allStates.map { $0.lowercased() })
        for (pair, mapping) in semanticDefaults {
            if stateSet == pair, let hex = mapping[state.lowercased()] {
                return Color(hex: hex)
            }
        }

        // 3. Fall back to automatic palette by order of first appearance
        let index = allStates.firstIndex(of: state) ?? 0
        let hex = palette[index % palette.count].hex
        return Color(hex: hex)
    }
}

// MARK: - State Alias

struct StateAlias: Codable, Equatable, Identifiable {
    var id: Double { value }
    var value: Double
    var label: String
}

extension Array where Element == StateAlias {
    /// Returns the alias label for a given numeric value, or nil if no aliases match.
    func resolve(_ value: Double) -> String? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted { $0.value < $1.value }
        var result: String?
        for alias in sorted {
            if value >= alias.value {
                result = alias.label
            } else {
                break
            }
        }
        return result
    }
}

// MARK: - Threshold Rule

struct ThresholdRule: Codable, Equatable, Identifiable {
    var id: Double { value }
    var value: Double
    var colorHex: String
}

// MARK: - Heatmap Colors

enum HeatmapColor: String, CaseIterable, Identifiable {
    case green
    case blue
    case purple
    case orange
    case red
    case teal

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    /// The base hue (0–1) for generating the light-to-dark ramp.
    private var hue: Double {
        switch self {
        case .green: return 0.35
        case .blue: return 0.58
        case .purple: return 0.78
        case .orange: return 0.08
        case .red: return 0.0
        case .teal: return 0.48
        }
    }

    /// Returns a fully opaque color. Light mode: light→saturated→dark. Dark mode: dark→saturated→white.
    func color(at progress: Double, darkMode: Bool = false) -> Color {
        let p = max(0, min(1, progress))
        if darkMode {
            // Low: dark/desaturated → Mid: vivid → High: fades toward white
            let saturation: Double
            let brightness: Double
            if p < 0.6 {
                let t = p / 0.6
                saturation = 0.1 + t * 0.8
                brightness = 0.12 + t * 0.78
            } else {
                let t = (p - 0.6) / 0.4
                saturation = 0.9 - t * 0.7
                brightness = 0.9 + t * 0.1
            }
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        } else {
            // Low: light/desaturated → Mid: vivid → High: fades toward black
            let saturation: Double
            let brightness: Double
            if p < 0.6 {
                let t = p / 0.6
                saturation = 0.1 + t * 0.8
                brightness = 0.97 - t * 0.35
            } else {
                let t = (p - 0.6) / 0.4
                saturation = 0.9 - t * 0.3
                brightness = 0.62 - t * 0.4
            }
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }

    /// Preview swatch colors for the picker (light mode).
    var swatchColors: [Color] {
        [color(at: 0.0), color(at: 0.33), color(at: 0.66), color(at: 1.0)]
    }

    /// Preview swatch colors for the picker (dark mode).
    var swatchColorsDark: [Color] {
        [color(at: 0.0, darkMode: true), color(at: 0.33, darkMode: true), color(at: 0.66, darkMode: true), color(at: 1.0, darkMode: true)]
    }
}

// MARK: - Gauge Color Schemes

enum GaugeColorScheme: String, CaseIterable, Identifiable {
    case blueToRed
    case greenToRed
    case blueToGreen
    case purpleToOrange
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blueToRed: return "Cold → Hot"
        case .greenToRed: return "Good → Bad"
        case .blueToGreen: return "Cool"
        case .purpleToOrange: return "Energy"
        case .mono: return "Mono"
        }
    }

    var colors: [Color] {
        switch self {
        case .blueToRed: return [.blue, .green, .yellow, .orange, .red]
        case .greenToRed: return [.green, .yellow, .orange, .red]
        case .blueToGreen: return [.blue, .cyan, .green]
        case .purpleToOrange: return [.purple, .pink, .orange]
        case .mono: return [.accentColor.opacity(0.3), .accentColor]
        }
    }

    func color(at progress: Double) -> Color {
        let clamped = max(0, min(1, progress))
        switch self {
        case .blueToRed:
            switch clamped {
            case ..<0.25: return .blue
            case 0.25..<0.5: return .green
            case 0.5..<0.75: return .orange
            default: return .red
            }
        case .greenToRed:
            switch clamped {
            case ..<0.33: return .green
            case 0.33..<0.66: return .yellow
            default: return .red
            }
        case .blueToGreen:
            return clamped < 0.5 ? .blue : .green
        case .purpleToOrange:
            return clamped < 0.5 ? .purple : .orange
        case .mono:
            return .accentColor
        }
    }
}

// MARK: - Core Data Helpers

extension StyleConfig {
    static func decode(from json: String?) -> StyleConfig {
        guard let json, let data = json.data(using: .utf8),
              let config = try? JSONDecoder().decode(StyleConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func encode() -> String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{}"
    }
}
