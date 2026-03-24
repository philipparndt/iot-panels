import SwiftUI

// MARK: - Color Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Series Color Palette

enum SeriesColors {
    static let palette: [String] = [
        "#4A90D9", // Blue
        "#E74C3C", // Red
        "#2ECC71", // Green
        "#F39C12", // Orange
        "#9B59B6", // Purple
        "#1ABC9C", // Teal
        "#E67E22", // Dark Orange
        "#3498DB", // Light Blue
    ]

    static let paletteColors: [Color] = palette.map { Color(hex: $0) }

    static func color(at index: Int) -> String {
        palette[index % palette.count]
    }
}
