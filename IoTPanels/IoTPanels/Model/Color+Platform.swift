import SwiftUI
#if os(macOS)
import AppKit
#endif

// Cross-platform wrappers for the UIKit system colors the app used to reach for directly.
// Centralizing the `#if` here keeps the call sites readable and makes platform drift obvious.

extension Color {

    /// Background used for grouped content. iOS systemGroupedBackground / macOS window background.
    static var platformGroupedBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    /// Secondary grouped background — used for panel cards and form rows on iOS.
    static var platformSecondaryGroupedBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// Default opaque window / card background.
    static var platformSystemBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    /// Tertiary fill used for inline chips and subtle borders.
    static var platformTertiaryFill: Color {
        #if os(macOS)
        Color.secondary.opacity(0.12)
        #else
        Color(uiColor: .tertiarySystemFill)
        #endif
    }
}
