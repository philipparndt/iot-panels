import SwiftUI

private func getVersion() -> String {
    if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
       let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        return "\(marketingVersion).\(buildNumber)"
    } else {
        return "unknown"
    }
}

struct AboutView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingCredentialsWarning = false
    @State private var showingShareSheet = false
    @State private var showingFilePicker = false
    @State private var exportURL: URL?
    @State private var isProcessing = false
    @State private var resultMessage: String?
    @State private var showingResult = false

    var body: some View {
        VStack(alignment: .leading) {
            AboutTitleView()
                .padding([.top, .bottom])

            Text("""
            This project is open source. Contributions are welcome. Feel free to open an issue ticket and discuss new features.
            [Source Code](https://github.com/philipparndt/iot-panels), [License](https://github.com/philipparndt/iot-panels/blob/main/LICENSE), [Issue tracker](https://github.com/philipparndt/iot-panels/issues)

            **Dependencies**
            [CocoaMQTT](https://github.com/emqx/CocoaMQTT)
            """)
            .foregroundStyle(.secondary)
            .font(.footnote)

            Divider()
                .padding(.vertical, 8)

            // Backup & Restore
            VStack(spacing: 12) {
                Button {
                    showingCredentialsWarning = true
                } label: {
                    Label("Backup", systemImage: "arrow.up.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showingFilePicker = true
                } label: {
                    Label("Restore", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Backup contains credentials", isPresented: $showingCredentialsWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") { performBackup() }
        } message: {
            Text("The backup file will contain API tokens and passwords. Keep it secure.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                DataShareSheetView(items: [url])
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            BackupDocumentPicker { url in
                performRestore(from: url)
            }
        }
        .alert(resultMessage ?? "", isPresented: $showingResult) {
            Button("OK") {}
        }
        .overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Processing...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func performBackup() {
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            let url = BackupService.exportToFile(context: viewContext)
            await MainActor.run {
                isProcessing = false
                if let url {
                    exportURL = url
                    showingShareSheet = true
                } else {
                    resultMessage = "Backup failed"
                    showingResult = true
                }
            }
        }
    }

    private func performRestore(from url: URL) {
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            do {
                try BackupService.restoreFromFile(url: url, context: viewContext)
                await MainActor.run {
                    isProcessing = false
                    resultMessage = "Restore complete"
                    showingResult = true
                    WidgetHelper.reloadWidgets()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    resultMessage = "Restore failed: \(error.localizedDescription)"
                    showingResult = true
                }
            }
        }
    }
}

/// Document picker for importing JSON backup files.
struct BackupDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            // Copy to temp to avoid sandbox issues
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.copyItem(at: url, to: tempURL)
            onPick(tempURL)
        }
    }
}

struct AboutTitleView: View {
    var body: some View {
        HStack {
            Image("AboutIcon")
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.trailing)

            VStack(alignment: .leading) {
                Text("IoT Panels")
                    .font(.title)

                Text("[© 2026 Philipp Arndt](https://github.com/philipparndt)")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(getVersion())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding([.top, .bottom])
    }
}
