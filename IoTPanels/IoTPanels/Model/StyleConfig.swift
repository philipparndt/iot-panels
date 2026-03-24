import SwiftUI

// MARK: - Style Configuration (stored as JSON per item/panel)

struct StyleConfig: Codable, Equatable {
    // Gauge settings
    var gaugeMin: Double?       // nil = auto from data
    var gaugeMax: Double?       // nil = auto from data
    var gaugeColorScheme: String = GaugeColorScheme.blueToRed.rawValue

    static let `default` = StyleConfig()

    var resolvedGaugeColorScheme: GaugeColorScheme {
        GaugeColorScheme(rawValue: gaugeColorScheme) ?? .blueToRed
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
