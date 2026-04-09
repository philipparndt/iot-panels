import SwiftUI
import UniformTypeIdentifiers

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
        .inlineNavigationTitle()
        .alert("Backup contains credentials", isPresented: $showingCredentialsWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") { performBackup() }
        } message: {
            Text("The backup file will contain API tokens and passwords. Keep it secure.")
        }
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                DataShareSheetView(items: [url])
            }
        }
        #else
        .onChange(of: showingShareSheet) { _, newValue in
            if newValue, let url = exportURL {
                MacFileExporter.revealOrExport(url: url)
                showingShareSheet = false
            }
        }
        #endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let needsScoped = url.startAccessingSecurityScopedResource()
                defer { if needsScoped { url.stopAccessingSecurityScopedResource() } }

                // Copy to temp to avoid sandbox issues during async restore.
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                performRestore(from: tempURL)
            case .failure:
                break
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
        let context = viewContext
        Task.detached(priority: .userInitiated) {
            let url = BackupService.exportToFile(context: context)
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
        let context = viewContext
        Task.detached(priority: .userInitiated) {
            do {
                try BackupService.restoreFromFile(url: url, context: context)
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
