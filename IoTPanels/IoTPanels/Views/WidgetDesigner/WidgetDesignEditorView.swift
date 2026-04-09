import SwiftUI

struct WidgetDesignEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var design: WidgetDesign

    @State private var showingAddItem = false
    @State private var editingItem: WidgetDesignItem?
    @State private var seriesData: [String: [ChartSeries]] = [:]
    @State private var isLoadingPreview = false
    @State private var isRearranging = false
    @State private var editItems: [WidgetDesignItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !isRearranging {
                    sizePicker
                    textScalePicker
                    refreshPicker
                    backgroundColorPicker
                }
                if !design.sortedItems.isEmpty {
                    previewSection
                }
                itemsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(design.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isRearranging {
                    Button("Done") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRearranging = false
                        }
                        loadPreviewData()
                    }
                    .fontWeight(.semibold)
                } else {
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
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
            .labelsHidden()
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
            .labelsHidden()
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
            .labelsHidden()
        }
    }

    // MARK: - Background Color

    /// Special sentinel for adaptive background (black in dark mode, light in light mode).
    private static let adaptiveBackground = "#ADAPTIVE"

    private static let backgroundPresets: [(String, String)] = [
        (adaptiveBackground, "Auto"),
        ("#1C1C1E", "Dark"),
        ("#000000", "Black"),
        ("#2C2C2E", "Charcoal"),
        ("#F2F2F7", "Light"),
        ("#FFFFFF", "White"),
    ]

    private var backgroundColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(Self.backgroundPresets, id: \.0) { hex, label in
                    VStack(spacing: 4) {
                        Group {
                            if hex == Self.adaptiveBackground {
                                GeometryReader { geo in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.white)
                                        RoundedRectangle(cornerRadius: 8).fill(Color.black)
                                            .mask(Rectangle().offset(x: geo.size.width / 2))
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.gray.opacity(0.4), lineWidth: 0.5)
                                    }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: hex))
                            }
                        }
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    design.wrappedBackgroundColorHex == hex ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: design.wrappedBackgroundColorHex == hex ? 2 : 1
                                )
                        )
                            .onTapGesture {
                                design.wrappedBackgroundColorHex = hex
                                design.modifiedAt = Date()
                                try? viewContext.save()
                                WidgetHelper.reloadWidgets()
                            }
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
                textScale: design.wrappedTextScale.factor,
                backgroundColor: design.backgroundColor
            )
            .environmentObject(HeatmapSelectionState())
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Items")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !isRearranging, design.sortedItems.count > 1 {
                    Button {
                        editItems = design.sortedItems
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRearranging = true
                        }
                    } label: {
                        Label("Rearrange", systemImage: "arrow.up.arrow.down")
                            .font(.caption)
                    }
                }
            }

            let items = design.sortedItems

            if isRearranging {
                List {
                    ForEach(editItems, id: \.objectID) { item in
                        rearrangeRow(item: item)
                    }
                    .onMove { from, to in
                        editItems.move(fromOffsets: from, toOffset: to)
                        saveItemOrder()
                    }
                }
                #if os(iOS)
                .environment(\.editMode, .constant(.active))
                #endif
                .frame(minHeight: CGFloat(editItems.count) * 52)
                .listStyle(.plain)
                .scrollDisabled(true)
            } else {
                ForEach(items, id: \.objectID) { item in
                    itemRow(item: item)
                }

                Button {
                    showingAddItem = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Add Item")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.platformSecondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                            .foregroundStyle(.quaternary)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rearrange Row

    private func rearrangeRow(item: WidgetDesignItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    if let idx = editItems.firstIndex(of: item) {
                        editItems.remove(at: idx)
                    }
                    viewContext.delete(item)
                    saveItemOrder()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(item.color)
                .frame(width: 12, height: 12)

            Text(item.wrappedTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer()

            Label(item.wrappedDisplayStyle.displayName, systemImage: item.wrappedDisplayStyle.icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }

    private func saveItemOrder() {
        for (i, item) in editItems.enumerated() {
            item.sortOrder = Int32(i)
        }
        design.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
    }

    // MARK: - Item Row

    private func itemRow(item: WidgetDesignItem) -> some View {
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
        }
        .padding(12)
        .background(Color.platformSecondaryGroupedBackground)
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

    private func renumberItems() {
        for (i, item) in design.sortedItems.enumerated() {
            item.sortOrder = Int32(i)
        }
    }

    private func loadPreviewData() {
        // Show cached data immediately
        let cachedData = WidgetDataLoader.cachedGroups(for: design)
        if !cachedData.isEmpty {
            seriesData = cachedData
        }

        // Fetch fresh data in background
        isLoadingPreview = true
        Task {
            let newData = await WidgetDataLoader.fetchAllGroups(for: design, cache: true)
            await MainActor.run {
                seriesData = newData
                isLoadingPreview = false
            }
        }
    }
}
