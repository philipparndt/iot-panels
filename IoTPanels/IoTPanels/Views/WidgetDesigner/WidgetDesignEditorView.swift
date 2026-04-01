import SwiftUI

struct WidgetDesignEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var design: WidgetDesign

    @State private var showingAddItem = false
    @State private var editingItem: WidgetDesignItem?
    @State private var seriesData: [String: [ChartSeries]] = [:]
    @State private var isLoadingPreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Size picker
                sizePicker

                // Text scale
                textScalePicker

                // Refresh rate
                refreshPicker

                // Live preview
                previewSection

                // Items list
                itemsSection
            }
            .padding()
        }
        .navigationTitle(design.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddItem = true }) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem, onDismiss: loadPreviewData) {
            AddWidgetItemView(design: design)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingItem, onDismiss: loadPreviewData) { item in
            WidgetItemConfigView(item: item, design: design)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear { loadPreviewData() }
    }

    // MARK: - Size Picker

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Widget Size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Size", selection: Binding(
                get: { design.wrappedSizeType },
                set: {
                    design.wrappedSizeType = $0
                    design.modifiedAt = Date()
                    try? viewContext.save()
                    WidgetHelper.reloadWidgets()
                }
            )) {
                ForEach(WidgetSizeType.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Text Scale Picker

    private var textScalePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Text Size", selection: Binding(
                get: { design.wrappedTextScale },
                set: {
                    design.wrappedTextScale = $0
                    design.modifiedAt = Date()
                    try? viewContext.save()
                    WidgetHelper.reloadWidgets()
                }
            )) {
                ForEach(TextScale.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Refresh Picker

    private var refreshPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refresh Rate")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Refresh", selection: Binding(
                get: { design.wrappedRefreshInterval },
                set: {
                    design.wrappedRefreshInterval = $0
                    design.modifiedAt = Date()
                    try? viewContext.save()
                    WidgetHelper.reloadWidgets()
                }
            )) {
                ForEach(RefreshInterval.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoadingPreview {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(action: loadPreviewData) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }

            WidgetDesignPreviewView(
                sizeType: design.wrappedSizeType,
                groups: design.resolvedGroups,
                seriesData: seriesData,
                textScale: design.wrappedTextScale.factor
            )
            .environmentObject(HeatmapSelectionState())
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Items")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            let items = design.sortedItems

            if items.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No items yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(Array(items.enumerated()), id: \.element.objectID) { index, item in
                    itemRow(item: item, index: index, totalCount: items.count)
                }
            }
        }
    }

    private func itemRow(item: WidgetDesignItem, index: Int, totalCount: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.wrappedTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(item.wrappedDisplayStyle.displayName, systemImage: item.wrappedDisplayStyle.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let tag = item.groupTag, !tag.isEmpty {
                        Text("Group \(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Reorder buttons
            VStack(spacing: 0) {
                Button {
                    moveItem(item, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                }
                .disabled(index == 0)

                Button {
                    moveItem(item, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .disabled(index == totalCount - 1)
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    viewContext.delete(item)
                    renumberItems()
                    try? viewContext.save()
                    WidgetHelper.reloadWidgets()
                    loadPreviewData()
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func moveItem(_ item: WidgetDesignItem, direction: Int) {
        var items = design.sortedItems
        guard let idx = items.firstIndex(of: item) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < items.count else { return }
        items.swapAt(idx, newIdx)
        for (i, it) in items.enumerated() { it.sortOrder = Int32(i) }
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        loadPreviewData()
    }

    private func renumberItems() {
        for (i, item) in design.sortedItems.enumerated() {
            item.sortOrder = Int32(i)
        }
    }

    private func loadPreviewData() {
        isLoadingPreview = true

        Task {
            let newData = await WidgetDataLoader.fetchAllGroups(for: design)
            await MainActor.run {
                seriesData = newData
                isLoadingPreview = false
            }
        }
    }
}
