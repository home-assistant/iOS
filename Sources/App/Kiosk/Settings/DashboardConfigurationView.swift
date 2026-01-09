import HAKit
import Shared
import SwiftUI

// MARK: - Dashboard Picker View

/// View for selecting a dashboard from available HA dashboards
public struct DashboardPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPath: String

    @State private var availableDashboards: [HAPanel] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var customPath = ""

    public init(selectedPath: Binding<String>) {
        _selectedPath = selectedPath
        _customPath = State(initialValue: selectedPath.wrappedValue)
    }

    public var body: some View {
        Form {
            // Available dashboards from HA
            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading dashboards...")
                            .foregroundColor(.secondary)
                    }
                } else if let error = loadError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Could not load dashboards")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if availableDashboards.isEmpty {
                    Text("No dashboards found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableDashboards, id: \.path) { dashboard in
                        Button {
                            selectedPath = "/\(dashboard.path)"
                            customPath = selectedPath
                        } label: {
                            HStack {
                                if let icon = dashboard.icon {
                                    Image(systemName: IconMapper.sfSymbol(from: icon, default: "rectangle.grid.1x2"))
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dashboard.title)
                                        .foregroundColor(.primary)
                                    Text("/\(dashboard.path)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedPath == "/\(dashboard.path)" {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Available Dashboards")
            } footer: {
                Text("Dashboards are loaded from your Home Assistant instance.")
            }

            // Custom path entry
            Section {
                TextField("Custom Path (e.g., /lovelace/kiosk)", text: $customPath)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onSubmit {
                        selectedPath = customPath
                    }

                if !customPath.isEmpty && customPath != selectedPath {
                    Button("Use Custom Path") {
                        selectedPath = customPath
                    }
                }
            } header: {
                Text("Custom Path")
            } footer: {
                Text("Enter a custom dashboard path if it's not listed above.")
            }

            // Clear selection
            if !selectedPath.isEmpty {
                Section {
                    Button(role: .destructive) {
                        selectedPath = ""
                        customPath = ""
                    } label: {
                        Label("Clear Selection", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .navigationTitle("Select Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDashboards()
        }
        .refreshable {
            await refreshDashboards()
        }
    }

    private func loadDashboards() {
        isLoading = true
        loadError = nil

        // Get the first available server
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            loadError = "No Home Assistant server configured"
            isLoading = false
            return
        }

        // Fetch panels (dashboards) from HA
        api.connection.caches.panels.once { panels in
            Task { @MainActor in
                // Filter to only lovelace dashboards
                self.availableDashboards = panels.allPanels.filter { $0.component == "lovelace" }
                self.isLoading = false
            }
        }
    }

    private func refreshDashboards() async {
        await withCheckedContinuation { continuation in
            loadDashboards()
            // Give it a moment to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Dashboard Configuration View

/// View for configuring dashboard URLs and rotation settings
public struct DashboardConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dashboards: [DashboardConfig]
    @Binding var primaryURL: String

    @State private var newDashboardName = ""
    @State private var newDashboardURL = ""
    @State private var showAddSheet = false
    @State private var editingDashboard: DashboardConfig?

    public init(dashboards: Binding<[DashboardConfig]>, primaryURL: Binding<String>) {
        _dashboards = dashboards
        _primaryURL = primaryURL
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Primary Dashboard URL", text: $primaryURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Primary Dashboard")
                } footer: {
                    Text("The main dashboard to display when kiosk mode starts.")
                }

                Section {
                    ForEach($dashboards) { $dashboard in
                        DashboardRow(dashboard: $dashboard) {
                            editingDashboard = dashboard
                        }
                    }
                    .onDelete(perform: deleteDashboards)
                    .onMove(perform: moveDashboards)

                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Dashboard", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Dashboard Rotation")
                } footer: {
                    Text("Add multiple dashboards for rotation. Reorder by dragging.")
                }
            }
            .navigationTitle("Dashboard Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                DashboardEditSheet(
                    name: $newDashboardName,
                    url: $newDashboardURL,
                    isNew: true
                ) {
                    if !newDashboardURL.isEmpty {
                        let dashboard = DashboardConfig(
                            name: newDashboardName.isEmpty ? "Dashboard" : newDashboardName,
                            url: newDashboardURL
                        )
                        dashboards.append(dashboard)
                    }
                    newDashboardName = ""
                    newDashboardURL = ""
                }
            }
            .sheet(item: $editingDashboard) { dashboard in
                if let index = dashboards.firstIndex(where: { $0.id == dashboard.id }) {
                    DashboardEditSheet(
                        name: $dashboards[index].name,
                        url: $dashboards[index].url,
                        isNew: false
                    ) {}
                }
            }
        }
    }

    private func deleteDashboards(at offsets: IndexSet) {
        dashboards.remove(atOffsets: offsets)
    }

    private func moveDashboards(from source: IndexSet, to destination: Int) {
        dashboards.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Dashboard Row

struct DashboardRow: View {
    @Binding var dashboard: DashboardConfig
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dashboard.name)
                .font(.headline)

            Text(dashboard.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

// MARK: - Dashboard Edit Sheet

struct DashboardEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var url: String
    let isNew: Bool
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                } footer: {
                    Text("A friendly name for this dashboard.")
                }

                Section {
                    NavigationLink {
                        DashboardPickerView(selectedPath: $url)
                    } label: {
                        HStack {
                            Text("Dashboard")
                            Spacer()
                            Text(url.isEmpty ? "Not Set" : url)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } footer: {
                    Text("Select a dashboard from Home Assistant or enter a custom path.")
                }
            }
            .navigationTitle(isNew ? "Add Dashboard" : "Edit Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    DashboardConfigurationView(
        dashboards: .constant([
            DashboardConfig(name: "Home", url: "http://homeassistant.local:8123/lovelace/home"),
            DashboardConfig(name: "Weather", url: "http://homeassistant.local:8123/lovelace/weather"),
        ]),
        primaryURL: .constant("http://homeassistant.local:8123")
    )
}
