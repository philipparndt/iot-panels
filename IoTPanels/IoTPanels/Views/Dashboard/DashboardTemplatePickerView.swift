import SwiftUI

struct DashboardTemplatePickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let home: Home?
    let dataSources: [DataSource]
    let onCreated: (Dashboard) -> Void

    @State private var dashboardName = ""
    @State private var selectedTemplate: DashboardTemplate?
    @State private var selectedDataSource: DataSource?
    @State private var showingNameInput = false

    private var templates: [DashboardTemplate] {
        DashboardTemplateRegistry.availableTemplates(for: dataSources)
    }

    var body: some View {
        NavigationStack {
            List {
                // Blank dashboard
                Section {
                    Button {
                        showingNameInput = true
                        selectedTemplate = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blank Dashboard")
                                    .font(.headline)
                                Text("Start from scratch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // Templates
                if !templates.isEmpty {
                    Section("Templates") {
                        ForEach(templates) { template in
                            Button {
                                applyOrPickDataSource(for: template)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: template.icon)
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.headline)
                                        Text(template.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(template.panels.count) panels · \(template.backendType.displayName)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Dashboard")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Dashboard", isPresented: $showingNameInput) {
                TextField("Dashboard name", text: $dashboardName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    createBlankDashboard()
                }
                .disabled(dashboardName.isEmpty)
            }
            .sheet(item: $selectedTemplate) { template in
                DataSourcePickerForTemplate(
                    template: template,
                    dataSources: dataSources.filter { $0.wrappedBackendType == template.backendType },
                    home: home,
                    onCreated: { dashboard in
                        onCreated(dashboard)
                        dismiss()
                    }
                )
            }
        }
        .macSheet()
    }

    private func applyOrPickDataSource(for template: DashboardTemplate) {
        let compatible = dataSources.filter { $0.wrappedBackendType == template.backendType }
        if compatible.count == 1, let ds = compatible.first {
            // Auto-select if only one compatible source
            applyTemplate(template, dataSource: ds)
        } else {
            // Multiple sources — show picker sheet
            selectedTemplate = template
        }
    }

    private func applyTemplate(_ template: DashboardTemplate, dataSource: DataSource) {
        let dashboard = template.apply(to: home!, dataSource: dataSource, context: viewContext)
        onCreated(dashboard)
        dismiss()
    }

    private func createBlankDashboard() {
        let dashboard = Dashboard(context: viewContext)
        dashboard.id = UUID()
        dashboard.name = dashboardName
        dashboard.home = home
        dashboard.createdAt = Date()
        dashboard.modifiedAt = Date()
        try? viewContext.save()
        onCreated(dashboard)
        dismiss()
    }
}

// MARK: - Data Source Picker for Template

struct DataSourcePickerForTemplate: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let template: DashboardTemplate
    let dataSources: [DataSource]
    let home: Home?
    let onCreated: (Dashboard) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select a \(template.backendType.displayName) data source for the \"\(template.name)\" template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data Sources") {
                    ForEach(dataSources, id: \.objectID) { ds in
                        Button {
                            let dashboard = template.apply(to: home!, dataSource: ds, context: viewContext)
                            onCreated(dashboard)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(ds.wrappedName)
                                        .font(.headline)
                                    Text(ds.wrappedUrl)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Choose Data Source")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension DashboardTemplate: Equatable {
    static func == (lhs: DashboardTemplate, rhs: DashboardTemplate) -> Bool {
        lhs.id == rhs.id
    }
}
