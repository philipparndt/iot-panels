import SwiftUI

// MARK: - Color Hex Support

extension Color {
    init(hex: String) {
        if hex == SeriesColors.adaptivePrimary {
            self = .primary
            return
        }
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

// MARK: - Complementary Color

extension Color {
    /// Returns the complementary color by rotating hue 180° in HSB space.
    ///
    /// Uses `Color.resolve(in:)` (iOS 17+ / macOS 14+) to read the RGB components
    /// via pure SwiftUI, without reaching into UIKit or AppKit.
    func complementary() -> Color {
        let resolved = self.resolve(in: EnvironmentValues())
        let (h, s, b) = Self.rgbToHsb(
            r: Double(resolved.red),
            g: Double(resolved.green),
            blue: Double(resolved.blue)
        )
        let newHue = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
        return Color(
            hue: newHue,
            saturation: s,
            brightness: b,
            opacity: Double(resolved.opacity)
        )
    }

    /// Converts an sRGB triple to HSB. Matches the behavior of `UIColor.getHue(_:saturation:brightness:alpha:)`.
    private static func rgbToHsb(r: Double, g: Double, blue b: Double) -> (h: Double, s: Double, b: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        let brightness = maxC
        let saturation = maxC == 0 ? 0 : delta / maxC

        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxC == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        var normalized = hue / 6
        if normalized < 0 { normalized += 1 }
        return (normalized, saturation, brightness)
    }
}

// MARK: - Series Color Palette

enum SeriesColors {
    /// Special value that resolves to adaptive primary color (white in dark mode, black in light mode).
    static let adaptivePrimary = "#PRIMARY"

    static let palette: [String] = [
        adaptivePrimary, // Adaptive (white/black based on theme)
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
