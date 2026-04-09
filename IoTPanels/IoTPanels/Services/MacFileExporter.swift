#if os(macOS)
import AppKit
import Foundation

/// Thin wrapper around NSSavePanel for exporting files on macOS.
/// Replaces the iOS UIActivityViewController / share-sheet flow.
enum MacFileExporter {

    /// Presents an NSSavePanel pre-filled with the given URL's filename.
    /// If the user confirms, copies the source file to the chosen destination.
    @MainActor
    static func revealOrExport(url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: url, to: destination)
        }
    }
}
#endif
