import GRDB
import Shared
import SwiftUI

/// Root of the Complications settings screen. The modern entity/custom builder lives here; the
/// previous ClockKit-era complications are tucked under "Legacy complications".
struct ComplicationsRootView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    WatchComplicationBuilderView()
                } label: {
                    Label(title: { Text(L10n.Watch.Complications.Root.new) },
                          icon: { Image(systemSymbol: .plusCircle) })
                }
            } footer: {
                Text(L10n.Watch.Complications.Root.newFooter)
            }

            Section {
                NavigationLink {
                    ComplicationListView()
                } label: {
                    Label(title: { Text(L10n.Watch.Complications.Root.legacy) },
                          icon: { Image(systemSymbol: .clockArrowCirclepath) })
                }
            } footer: {
                Text(L10n.Watch.Complications.Root.legacyFooter)
            }
        }
        .navigationTitle(L10n.SettingsDetails.Watch.title)
    }
}

/// SwiftUI replacement for `ComplicationListViewController`.
struct ComplicationListView: View {
    @StateObject private var viewModel = ComplicationListViewModel()
    @State private var showFamilyPicker = false

    var body: some View {
        List {
            introSection
            manualUpdatesSection
            groupSections
            addSection
        }
        .navigationTitle(Text(L10n.Watch.Complications.Legacy.title))
        .sheet(isPresented: $showFamilyPicker) {
            NavigationView {
                ComplicationFamilySelectView(
                    allowMultiple: viewModel.supportsMultipleComplications,
                    currentFamilies: viewModel.currentFamilies,
                    onSaved: { showFamilyPicker = false }
                )
            }
            .navigationViewStyle(.stack)
        }
        .alert(
            L10n.errorLabel,
            isPresented: $viewModel.showError,
            presenting: viewModel.errorMessage
        ) { _ in
            Button(L10n.okLabel, role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            Text(L10n.Watch.Configurator.List.description)
                .foregroundColor(.primary)
            Link(destination: URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!) {
                HStack {
                    Text(L10n.Nfc.List.learnMore)
                    Spacer()
                    Image(systemSymbol: .arrowUpForwardSquare)
                        .font(.caption)
                }
            }
            Text(L10n.Watch.Configurator.Warning.templatingAdmin)
                .foregroundColor(.secondary)
        }
    }

    private var manualUpdatesSection: some View {
        Section {
            HStack {
                Text(L10n.Watch.Configurator.List.ManualUpdates.remaining)
                Spacer()
                Text(viewModel.remainingUpdatesDescription)
                    .foregroundColor(.secondary)
            }
            LoadingButton(
                title: L10n.Watch.Configurator.List.ManualUpdates.manuallyUpdate,
                isLoading: viewModel.isUpdatingComplications
            ) {
                viewModel.updateComplications()
            }
        } header: {
            Text(L10n.Watch.Configurator.List.ManualUpdates.title)
        } footer: {
            Text(L10n.Watch.Configurator.List.ManualUpdates.footer)
        }
    }

    @ViewBuilder
    private var groupSections: some View {
        ForEach(ComplicationGroup.allCases.sorted(), id: \.self) { group in
            if let items = viewModel.complicationsByGroup[group], !items.isEmpty {
                Section {
                    ForEach(items, id: \.identifier) { complication in
                        NavigationLink {
                            ComplicationEditView(
                                config: complication,
                                isNew: false,
                                onSaved: nil
                            )
                        } label: {
                            HStack {
                                Text(complication.Family.shortName)
                                Spacer()
                                Text(complication.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.name)
                } footer: {
                    Text(group.description)
                }
            }
        }
    }

    private var addSection: some View {
        Section {
            Button(L10n.addButtonLabel) {
                showFamilyPicker = true
            }
        }
    }
}

// MARK: - New (modern) complication builder

/// Lists the modern `WatchComplicationConfig`s and hosts the add/edit flow.
struct WatchComplicationBuilderView: View {
    @State private var configs: [WatchComplicationConfig] = []
    @State private var editing: WatchComplicationConfig?
    @State private var showAdd = false

    var body: some View {
        List {
            if configs.isEmpty {
                Section {
                    Text(L10n.Watch.Complications.Builder.empty)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(configs) { config in
                Button {
                    editing = config
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        ComplicationFamilyPreview(family: config.widgetFamily)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading) {
                            Text(config.displayName)
                                .foregroundColor(.primary)
                            Text(verbatim: config.widgetFamily.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
        .navigationTitle(Text(L10n.Watch.Complications.Builder.title))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemSymbol: .plus) }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationView { WatchComplicationBuilderEditView(existing: nil) }
        }
        .sheet(item: $editing) { config in
            NavigationView { WatchComplicationBuilderEditView(existing: config) }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: WatchComplicationConfig.didChangeNotification)) { _ in
            reload()
        }
    }

    private func reload() {
        configs = (try? WatchComplicationConfig.all()) ?? []
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? configs[index].delete()
        }
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        reload()
    }
}

/// Add/edit a modern complication: pick an entity (auto-designed) or a custom template.
struct WatchComplicationBuilderEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: WatchComplicationConfig
    @State private var selectedEntity: HAAppEntity?
    private let isNew: Bool

    init(existing: WatchComplicationConfig?) {
        isNew = existing == nil
        let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
        _config = State(initialValue: existing ?? WatchComplicationConfig(serverId: serverId))
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $config.widgetFamily) {
                    ForEach(WatchComplicationConfig.Family.allCases) { family in
                        Text(verbatim: family.title).tag(family)
                    }
                } label: {
                    Text(L10n.Watch.Complications.Builder.family)
                }
                HStack {
                    Spacer()
                    ComplicationFamilyPreview(family: config.widgetFamily)
                        .frame(width: 76, height: 76)
                        .padding(.vertical, DesignSystem.Spaces.one)
                    Spacer()
                }
            } header: {
                Text(L10n.Watch.Complications.Builder.style)
            }

            Section {
                Picker(selection: $config.kind) {
                    Text(L10n.Watch.Complications.Builder.sourceEntity).tag(WatchComplicationConfig.Kind.entity)
                    Text(L10n.Watch.Complications.Builder.sourceCustom).tag(WatchComplicationConfig.Kind.customTemplate)
                } label: {
                    Text(L10n.Watch.Complications.Builder.source)
                }
            }

            if config.kind == .entity {
                Section {
                    EntityPicker(
                        selectedServerId: config.serverId,
                        selectedEntity: $selectedEntity,
                        domainFilter: nil,
                        mode: .button
                    )
                    Toggle(isOn: $config.showValue) { Text(L10n.Watch.Complications.Builder.showValue) }
                } header: {
                    Text(L10n.Watch.Complications.Builder.entity)
                }

                Section {
                    numberField(title: L10n.Watch.Complications.Builder.minimum, value: $config.gaugeMin)
                    numberField(title: L10n.Watch.Complications.Builder.maximum, value: $config.gaugeMax)
                } header: {
                    Text(L10n.Watch.Complications.Builder.gaugeRange)
                } footer: {
                    Text(L10n.Watch.Complications.Builder.gaugeRangeFooter)
                }
            } else {
                Section {
                    TextField(text: stringBinding(\.customTextTemplate)) {
                        Text(verbatim: "{{ states('sensor.x') }}")
                    }
                    TextField(text: stringBinding(\.customGaugeTemplate)) {
                        Text(verbatim: "{{ … }} → 0–1")
                    }
                } header: {
                    Text(L10n.Watch.Complications.Builder.templates)
                }
            }

            Section {
                TextField(text: stringBinding(\.name)) {
                    Text(L10n.Watch.Complications.Builder.name)
                }
            }
        }
        .navigationTitle(Text(isNew ? L10n.Watch.Complications.Builder.newTitle : L10n.Watch.Complications.Builder
                .editTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.saveLabel) { save() }.disabled(!isValid)
            }
        }
        .onChange(of: selectedEntity?.id) { _ in
            guard let entity = selectedEntity else { return }
            config.entityId = entity.entityId
            config.entityDisplayName = entity.name
            config.iconName = entity.icon
        }
        .onAppear {
            if selectedEntity == nil, let entityId = config.entityId {
                let key = "\(config.serverId)-\(entityId)"
                selectedEntity = try? Current.database().read { db in
                    try HAAppEntity.fetchOne(db, key: key)
                }
            }
        }
    }

    private var isValid: Bool {
        switch config.kind {
        case .entity: return config.entityId != nil
        case .customTemplate: return !(config.customTextTemplate ?? "").isEmpty
        }
    }

    private func save() {
        do {
            try config.save()
        } catch {
            Current.Log.error("Failed to save complication config: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        dismiss()
    }

    private func stringBinding(_ keyPath: WritableKeyPath<WatchComplicationConfig, String?>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath] ?? "" },
            set: { config[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private func numberField(title: String, value: Binding<Double?>) -> some View {
        let text = Binding<String>(
            get: { value.wrappedValue.map { String($0) } ?? "" },
            set: { value.wrappedValue = Double($0) }
        )
        HStack {
            Text(verbatim: title)
            Spacer()
            TextField(text: text) { Text(verbatim: "—") }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
    }
}

// MARK: - Mock family previews (Phase E)

/// A small styled mock of how each WidgetKit accessory family looks, used in the builder.
struct ComplicationFamilyPreview: View {
    let family: WatchComplicationConfig.Family

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch family {
                case .circular:
                    Circle().stroke(Color.accentColor, lineWidth: side * 0.12)
                    Image(systemSymbol: .houseFill).font(.system(size: side * 0.32))
                case .corner:
                    Circle()
                        .trim(from: 0.5, to: 0.75)
                        .stroke(Color.accentColor, lineWidth: side * 0.12)
                    Image(systemSymbol: .houseFill).font(.system(size: side * 0.22))
                case .rectangular:
                    RoundedRectangle(cornerRadius: side * 0.12)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    VStack(alignment: .leading, spacing: side * 0.06) {
                        Capsule().fill(Color.accentColor).frame(width: side * 0.7, height: side * 0.12)
                        Capsule().fill(Color.secondary.opacity(0.5)).frame(width: side * 0.5, height: side * 0.1)
                    }
                    .padding(side * 0.12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .inline:
                    Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    Capsule().fill(Color.accentColor).frame(width: side * 0.6, height: side * 0.12)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationView { WatchComplicationBuilderView() }
}
