import SwiftUI

struct WidgetDesignListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WidgetDesign.name, ascending: true)],
        animation: .default
    )
    private var designs: FetchedResults<WidgetDesign>

    @State private var showingNew = false

    var body: some View {
        List {
            if designs.isEmpty {
                ContentUnavailableView(
                    "No Widget Designs",
                    systemImage: "rectangle.on.rectangle.angled",
                    description: Text("Tap + to design your first home screen widget.")
                )
            } else {
                ForEach(Array(designs.enumerated()), id: \.element.objectID) { _, design in
                    NavigationLink {
                        WidgetDesignEditorView(design: design)
                    } label: {
                        HStack(spacing: 12) {
                            WidgetSizeBadge(size: design.wrappedSizeType)

                            VStack(alignment: .leading) {
                                Text(design.wrappedName)
                                    .font(.headline)
                                Text("\(design.sortedItems.count) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteDesigns)
            }
        }
        .navigationTitle("Widgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNew = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewWidgetDesignSheet { name, size in
                createDesign(name: name, size: size)
            }
        }
    }

    private func createDesign(name: String, size: WidgetSizeType) {
        let design = WidgetDesign(context: viewContext)
        design.id = UUID()
        design.name = name
        design.sizeType = size.rawValue
        design.createdAt = Date()
        design.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
    }

    private func deleteDesigns(offsets: IndexSet) {
        withAnimation {
            offsets.map { designs[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
            WidgetHelper.reloadWidgets()
        }
    }
}

// MARK: - Size Badge

struct WidgetSizeBadge: View {
    let size: WidgetSizeType

    var body: some View {
        Text(size.displayName)
            .font(.caption2.weight(.bold).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - New Design Sheet

struct NewWidgetDesignSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, WidgetSizeType) -> Void

    @State private var name = ""
    @State private var size: WidgetSizeType = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Widget name", text: $name)
                }

                Section("Size") {
                    Picker("Size", selection: $size) {
                        ForEach(WidgetSizeType.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, size)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
