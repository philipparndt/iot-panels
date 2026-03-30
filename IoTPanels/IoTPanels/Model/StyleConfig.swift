import SwiftUI

// MARK: - Style Configuration (stored as JSON per item/panel)

struct StyleConfig: Codable, Equatable {
    // Gauge settings
    var gaugeMin: Double?       // nil = auto from data
    var gaugeMax: Double?       // nil = auto from data
    var gaugeColorScheme: String = GaugeColorScheme.blueToRed.rawValue
    var heatmapColor: String = HeatmapColor.green.rawValue

    static let `default` = StyleConfig()

    var resolvedGaugeColorScheme: GaugeColorScheme {
        GaugeColorScheme(rawValue: gaugeColorScheme) ?? .blueToRed
    }

    var resolvedHeatmapColor: HeatmapColor {
        HeatmapColor(rawValue: heatmapColor) ?? .green
    }
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
