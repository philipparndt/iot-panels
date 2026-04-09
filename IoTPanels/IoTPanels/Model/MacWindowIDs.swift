#if os(macOS)
import Foundation

/// Distinct Codable/Hashable wrapper types so each macOS `WindowGroup(for:)`
/// scene has its own value type. Using plain `UUID` for multiple window kinds
/// would collide because SwiftUI keys scenes by value type.

struct ChartExplorerWindowID: Codable, Hashable {
    let panelID: UUID
}
#endif
