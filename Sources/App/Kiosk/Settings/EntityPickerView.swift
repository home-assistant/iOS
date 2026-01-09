import HAKit
import Shared
import SwiftUI

// MARK: - Entity Picker View

/// View for selecting an entity from available HA entities
public struct EntityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEntityId: String

    /// Optional filter for entity domains (e.g., ["sensor", "binary_sensor"])
    let domainFilter: [String]?

    /// Title for the picker
    let title: String

    @State private var availableEntities: [HAEntity] = []
    @State private var filteredEntities: [HAEntity] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var searchText = ""
    @State private var selectedDomain: String = "all"

    private var domains: [String] {
        var uniqueDomains = Set<String>()
        for entity in availableEntities {
            let domain = entity.entityId.components(separatedBy: ".").first ?? ""
            uniqueDomains.insert(domain)
        }
        return ["all"] + uniqueDomains.sorted()
    }

    public init(
        selectedEntityId: Binding<String>,
        domainFilter: [String]? = nil,
        title: String = "Select Entity"
    ) {
        _selectedEntityId = selectedEntityId
        self.domainFilter = domainFilter
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Domain filter
            if domainFilter == nil && !domains.isEmpty {
                domainPicker
            }

            // Entity list
            entityList
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadEntities()
        }
        .onChange(of: searchText) { _ in
            filterEntities()
        }
        .onChange(of: selectedDomain) { _ in
            filterEntities()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search entities...", text: $searchText)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Domain Picker

    private var domainPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(domains, id: \.self) { domain in
                    Button {
                        selectedDomain = domain
                    } label: {
                        Text(domain == "all" ? "All" : domain)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedDomain == domain ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(selectedDomain == domain ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Entity List

    private var entityList: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading entities...")
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Could not load entities")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if filteredEntities.isEmpty {
                Text(searchText.isEmpty ? "No entities found" : "No matching entities")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredEntities, id: \.entityId) { entity in
                    EntityRow(
                        entity: entity,
                        isSelected: selectedEntityId == entity.entityId
                    ) {
                        selectedEntityId = entity.entityId
                        dismiss()
                    }
                }
            }

            // Custom entity ID entry
            Section {
                HStack {
                    TextField("Custom entity ID", text: Binding(
                        get: { selectedEntityId },
                        set: { selectedEntityId = $0 }
                    ))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                    if !selectedEntityId.isEmpty {
                        Button("Use") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text("Or Enter Manually")
            } footer: {
                Text("Enter an entity ID if it's not listed above.")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Data Loading

    private func loadEntities() {
        isLoading = true
        loadError = nil

        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            loadError = "No Home Assistant server configured"
            isLoading = false
            return
        }

        api.connection.caches.states().once { states in
            Task { @MainActor in
                var entities = states.all

                // Apply domain filter if specified
                if let filter = domainFilter, !filter.isEmpty {
                    entities = entities.filter { entity in
                        let domain = entity.entityId.components(separatedBy: ".").first ?? ""
                        return filter.contains(domain)
                    }
                }

                // Sort by friendly name
                self.availableEntities = entities.sorted { e1, e2 in
                    let name1 = e1.attributes["friendly_name"] as? String ?? e1.entityId
                    let name2 = e2.attributes["friendly_name"] as? String ?? e2.entityId
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }

                self.filterEntities()
                self.isLoading = false
            }
        }
    }

    private func filterEntities() {
        var result = availableEntities

        // Filter by domain
        if selectedDomain != "all" {
            result = result.filter { entity in
                entity.entityId.hasPrefix("\(selectedDomain).")
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter { entity in
                let friendlyName = entity.attributes["friendly_name"] as? String ?? ""
                return entity.entityId.lowercased().contains(search) ||
                    friendlyName.lowercased().contains(search)
            }
        }

        filteredEntities = result
    }
}

// MARK: - Entity Row

private struct EntityRow: View {
    let entity: HAEntity
    let isSelected: Bool
    let onSelect: () -> Void

    private var friendlyName: String {
        entity.attributes["friendly_name"] as? String ?? entity.entityId
    }

    private var icon: String? {
        entity.attributes["icon"] as? String
    }

    private var domain: String {
        entity.entityId.components(separatedBy: ".").first ?? ""
    }

    private var stateValue: String {
        let state = entity.state
        if let unit = entity.attributes["unit_of_measurement"] as? String {
            return "\(state) \(unit)"
        }
        return state
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Icon
                if let iconName = icon {
                    Image(systemName: IconMapper.sfSymbol(from: iconName, default: defaultIconForDomain))
                        .foregroundColor(.accentColor)
                        .frame(width: 28)
                } else {
                    Image(systemName: defaultIconForDomain)
                        .foregroundColor(.accentColor)
                        .frame(width: 28)
                }

                // Name and entity ID
                VStack(alignment: .leading, spacing: 2) {
                    Text(friendlyName)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack {
                        Text(entity.entityId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(stateValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private var defaultIconForDomain: String {
        switch domain {
        case "sensor": return "gauge"
        case "binary_sensor": return "sensor.fill"
        case "switch": return "lightswitch.on"
        case "light": return "lightbulb.fill"
        case "climate": return "thermometer"
        case "weather": return "cloud.sun.fill"
        case "person": return "person.fill"
        case "device_tracker": return "location.fill"
        case "camera": return "camera.fill"
        case "media_player": return "play.rectangle.fill"
        case "automation": return "gearshape.fill"
        case "script": return "scroll.fill"
        case "scene": return "photo.artframe"
        case "input_boolean": return "togglepower"
        case "input_number": return "slider.horizontal.3"
        case "input_select": return "list.bullet"
        case "input_text": return "text.cursor"
        case "lock": return "lock.fill"
        case "cover": return "blinds.horizontal.closed"
        case "fan": return "fan.fill"
        case "vacuum": return "powercord.fill"
        case "alarm_control_panel": return "shield.fill"
        case "sun": return "sun.max.fill"
        case "zone": return "mappin.circle.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    NavigationView {
        EntityPickerView(
            selectedEntityId: .constant("sensor.temperature"),
            domainFilter: ["sensor", "binary_sensor"]
        )
    }
}
