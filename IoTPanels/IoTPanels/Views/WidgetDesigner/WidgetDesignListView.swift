import SwiftUI
import CoreData

struct WidgetDesignListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(NavigationState.self) private var navigationState

    let home: Home?

    @FetchRequest private var designs: FetchedResults<WidgetDesign>
    @FetchRequest private var dataSources: FetchedResults<DataSource>

    @State private var showingNew = false
    @State private var navigationPath = NavigationPath()

    init(home: Home?) {
        self.home = home
        let predicate: NSPredicate
        if let home {
            predicate = NSPredicate(format: "home == %@", home)
        } else {
            predicate = NSPredicate(format: "home == nil")
        }
        _designs = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \WidgetDesign.name, ascending: true)],
            predicate: predicate,
            animation: .default
        )
        _dataSources = FetchRequest(
            sortDescriptors: [],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            listContent
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
                .navigationDestination(for: NSManagedObjectID.self) { objectID in
                    if let design = viewContext.object(with: objectID) as? WidgetDesign {
                        WidgetDesignEditorView(design: design)
                    }
                }
        }
        .onChange(of: navigationState.navigateToWidgetDesignId, initial: true) {
            guard let targetId = navigationState.navigateToWidgetDesignId else { return }
            navigationState.navigateToWidgetDesignId = nil
            if let design = designs.first(where: { $0.id == targetId }) {
                // Replace entire path with just the target (clears any existing stack)
                var newPath = NavigationPath()
                newPath.append(design.objectID)
                navigationPath = newPath
            }
        }
    }

    private var listContent: some View {
        List {
            if dataSources.isEmpty {
                ContentUnavailableView {
                    Label("No Data Sources", systemImage: "server.rack")
                } description: {
                    Text("Connect a data source first to start designing widgets.")
                } actions: {
                    Button("Add Data Source") {
                        navigationState.showAddDataSource = true
                        navigationState.selectedTab = .dataSources
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if designs.isEmpty {
                ContentUnavailableView(
                    "No Widget Designs",
                    systemImage: "rectangle.on.rectangle.angled",
                    description: Text("Tap + to design your first home screen widget.")
                )
            } else {
                ForEach(Array(designs.enumerated()), id: \.element.objectID) { _, design in
                    NavigationLink(value: design.objectID) {
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
    }

    private func createDesign(name: String, size: WidgetSizeType) {
        let design = WidgetDesign(context: viewContext)
        design.id = UUID()
        design.name = name
        design.sizeType = size.rawValue
        design.home = navigationState.selectedHome
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
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("New Widget")
            .inlineNavigationTitle()
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
